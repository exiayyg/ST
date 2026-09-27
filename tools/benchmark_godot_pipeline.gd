extends Node

const PROTOTYPE_SCENE := preload("res://scenes/prototype/momentum_prototype.tscn")
const SAMPLE_COUNT := 30
const RENDER_WARMUP_FRAMES := 60
const VIEW_RECT := Rect2(-576.0, -324.0, 1152.0, 648.0)

class PipelineDriver:
	extends Node
	var simulation: SimulationController
	var construction: ConstructionController
	var world_view: NetworkWorldView
	var fog: FogOfWar
	var presentation: PresentationDirector
	var enemy_snapshot: Dictionary
	var boundary_samples: Array[float] = []
	var simulation_samples: Array[float] = []
	var upload_samples: Array[float] = []
	var draw_samples: Array[float] = []
	var frame_samples: Array[float] = []
	var visible_projectiles := 0
	var visible_waves := 0
	var warmup_frames := 5
	var sample_target := 30
	var finished := false
	var event_samples: Array[float] = []
	var presentation_samples: Array[float] = []
	var event_count := 0
	var ingestion_samples: Array[float] = []
	var advance_samples: Array[float] = []
	var wall_frame_samples: Array[float] = []
	var last_frame_usec := 0
	var probe_mode := "normal"

	func _process(delta: float) -> void:
		var simulation_started := Time.get_ticks_usec()
		var wall_frame_ms := float(simulation_started - last_frame_usec) / 1000.0
		last_frame_usec = simulation_started
		simulation.native.step(1.0 / 60.0)
		var simulation_ms := float(Time.get_ticks_usec() - simulation_started) / 1000.0
		var boundary_started := Time.get_ticks_usec()
		simulation.native.sync_enemy_proxies(enemy_snapshot)
		var snapshot := simulation.native.get_render_snapshot(VIEW_RECT, 0.0)
		var boundary_ms := float(Time.get_ticks_usec() - boundary_started) / 1000.0
		visible_projectiles = snapshot.projectile_positions.size()
		visible_waves = snapshot.wave_positions.size()
		var upload_started := Time.get_ticks_usec()
		var events: Array = simulation.native.consume_events()
		var event_ms := float(Time.get_ticks_usec() - upload_started) / 1000.0
		var presentation_started := Time.get_ticks_usec()
		if probe_mode != "no-presentation":
			for event: Dictionary in events:
				presentation.ingest_event(event)
		var ingestion_ms := float(Time.get_ticks_usec() - presentation_started) / 1000.0
		var advance_started := Time.get_ticks_usec()
		if probe_mode != "no-presentation":
			presentation.advance(1.0 / 60.0)
		var advance_ms := float(Time.get_ticks_usec() - advance_started) / 1000.0
		var presentation_ms := float(Time.get_ticks_usec() - presentation_started) / 1000.0
		world_view.presentation_effects = presentation.effects
		if probe_mode == "no-effects": world_view.presentation_effects = []
		world_view.decoration_time = presentation.decoration_time
		world_view.set_state(snapshot, construction.view_records(), 0, fog.texture)
		var upload_ms := float(Time.get_ticks_usec() - upload_started) / 1000.0
		if warmup_frames > 0:
			warmup_frames -= 1
			return
		simulation_samples.append(simulation_ms)
		event_samples.append(event_ms)
		presentation_samples.append(presentation_ms)
		ingestion_samples.append(ingestion_ms)
		advance_samples.append(advance_ms)
		wall_frame_samples.append(wall_frame_ms)
		event_count += events.size()
		boundary_samples.append(boundary_ms)
		upload_samples.append(upload_ms)
		draw_samples.append(world_view.last_draw_milliseconds)
		frame_samples.append(wall_frame_ms)
		if frame_samples.size() >= sample_target:
			finished = true
			set_process(false)


func _ready() -> void:
	_run.call_deferred()


func _percentile(values: Array[float], ratio: float) -> float:
	values.sort()
	return values[int(ratio * float(values.size() - 1))]


func _run() -> void:
	var window := get_tree().root
	print("pipeline_window_before mode=%s physical=%s render=%s" % [window.mode, window.size, window.get_texture().get_size()])
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(VIEW_RECT.size)
	window.content_scale_size = Vector2i(VIEW_RECT.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("pipeline_window_measured mode=%s physical=%s render=%s" % [window.mode, window.size, window.get_texture().get_size()])
	var prototype := PROTOTYPE_SCENE.instantiate()
	add_child(prototype)
	prototype.runtime.set("auto_fire", false)
	await get_tree().process_frame
	await get_tree().process_frame

	var simulation: SimulationController = prototype.runtime.simulation
	var construction: ConstructionController = prototype.runtime.construction
	var catalog: DeviceCatalog = prototype.runtime.catalog
	var world_view: NetworkWorldView = prototype.get("_world_view")
	var fog: FogOfWar = prototype.runtime.fog

	var converter := catalog.get_definition(&"wave_converter")
	var converter_id := construction.place(converter, Vector2.ZERO)
	var activation_commands: Array[Dictionary] = []
	for _index in 6:
		activation_commands.append({
			"position": Vector2(-40.0, 0.0), "velocity": Vector2(240.0, 0.0),
			"mass": 0.05, "tower_source": false,
		})
	simulation.native.emit_projectiles(activation_commands)
	simulation.native.step(0.1)
	var converter_snapshot: Array = simulation.native.get_device_snapshot()
	if converter_snapshot.is_empty() or not bool(converter_snapshot[0].active):
		push_error("Pipeline benchmark failed to activate the wave converter")
		get_tree().quit(2)
		return
	var conversion_commands: Array[Dictionary] = []
	for _index in 1042:
		conversion_commands.append({
			"position": Vector2(-40.0, 0.0),
			"velocity": Vector2(240.0, 0.0),
			"mass": 0.05,
			"tower_source": false,
		})
	simulation.native.emit_projectiles(conversion_commands)
	simulation.native.step(0.1)
	var converted_stats: Dictionary = simulation.native.get_stats()
	if int(converted_stats.wave_point_count) < 50000:
		push_error("Pipeline benchmark failed to create 50,000 wave points")
		get_tree().quit(3)
		return
	simulation.native.remove_device(converter_id)
	construction.devices.erase(converter_id)

	for index in 100:
		var definition := catalog.definitions[index % catalog.definitions.size()]
		var position := Vector2(
			1200.0 + float(index % 10) * 90.0,
			-1000.0 + float(index / 10) * 210.0
		)
		construction.place(definition, position, 0.0, position + Vector2(50.0, 50.0), 0.0)

	var random := RandomNumberGenerator.new()
	random.seed = 20260901
	var projectile_commands: Array[Dictionary] = []
	for _index in 10000:
		var angle := random.randf_range(0.0, TAU)
		projectile_commands.append({
			"position": Vector2(
				random.randf_range(VIEW_RECT.position.x + 8.0, VIEW_RECT.end.x - 8.0),
				random.randf_range(VIEW_RECT.position.y + 8.0, VIEW_RECT.end.y - 8.0)
			),
			"velocity": Vector2.RIGHT.rotated(angle) * 240.0,
			"mass": 0.05,
			"tower_source": false,
		})
	simulation.native.emit_projectiles(projectile_commands)
	var enemy_snapshot := {
		"ids": PackedInt64Array(), "positions": PackedVector2Array(),
		"radii": PackedFloat32Array(), "remaining_hp": PackedFloat32Array(),
		"momentum_absorption": PackedFloat32Array(), "damage_per_momentum": PackedFloat32Array(),
		"entropy_transfer_ratio": PackedFloat32Array(),
	}
	for index in 300:
		enemy_snapshot.ids.append(index + 1)
		enemy_snapshot.positions.append(Vector2(random.randf_range(-2200.0, 2200.0), random.randf_range(-1200.0, 1200.0)))
		enemy_snapshot.radii.append(18.0)
		enemy_snapshot.remaining_hp.append(1000000.0)
		enemy_snapshot.momentum_absorption.append(0.25)
		enemy_snapshot.damage_per_momentum.append(1.0)
		enemy_snapshot.entropy_transfer_ratio.append(0.5)
	prototype.set_process(false)
	# Warm renderer/driver without advancing or draining the representative population.
	# Startup shader compilation is separate from steady-state fixed-step throughput.
	world_view.set_state(simulation.native.get_render_snapshot(VIEW_RECT, 0.0), construction.view_records(), 0, fog.texture)
	for frame in RENDER_WARMUP_FRAMES:
		await get_tree().process_frame

	var driver := PipelineDriver.new()
	driver.name = "PipelineBenchmarkDriver"
	driver.simulation = simulation
	driver.construction = construction
	driver.world_view = world_view
	driver.fog = fog
	driver.presentation = prototype.presentation
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--presentation-probe="):
			driver.probe_mode = argument.trim_prefix("--presentation-probe=")
	if driver.probe_mode == "plain-particles":
		for child in world_view.get_children():
			if child is MultiMeshInstance2D: child.material = null
	driver.enemy_snapshot = enemy_snapshot
	driver.sample_target = SAMPLE_COUNT
	add_child(driver)
	while not driver.finished:
		await get_tree().process_frame

	var stats := simulation.native.get_stats()
	print("godot_pipeline projectiles=%d wave_points=%d devices=%d enemies=%d visible_projectiles=%d " % [
		int(stats.projectile_count), int(stats.wave_point_count), int(stats.device_count), int(stats.enemy_proxy_count), driver.visible_projectiles,
	] + "visible_waves=%d samples=%d simulation_60hz_p95_ms=%.3f boundary_p95_ms=%.3f " % [
		driver.visible_waves, SAMPLE_COUNT, _percentile(driver.simulation_samples, 0.95),
		_percentile(driver.boundary_samples, 0.95),
	] + "upload_p95_ms=%.3f " % [
		_percentile(driver.upload_samples, 0.95),
	] + "draw_p95_ms=%.3f frame_p95_ms=%.3f" % [
		_percentile(driver.draw_samples, 0.95), _percentile(driver.frame_samples, 0.95),
	])
	print("presentation_pipeline mode=%s events=%d consume_p95_ms=%.3f presentation_p95_ms=%.3f" % [
		driver.probe_mode, driver.event_count, _percentile(driver.event_samples, 0.95), _percentile(driver.presentation_samples, 0.95)])
	print("presentation_breakdown ingest_p95_ms=%.3f advance_p95_ms=%.3f output=%s" % [_percentile(driver.ingestion_samples, 0.95), _percentile(driver.advance_samples, 0.95), get_viewport().get_visible_rect().size])
	print("pipeline_actual_render physical=%s render=%s vsync=%s" % [window.size, window.get_texture().get_size(), DisplayServer.window_get_vsync_mode()])
	print("pipeline_wall_frame_p95_ms=%.3f" % _percentile(driver.wall_frame_samples, 0.95))
	driver.set_process(false)
	driver.simulation = null
	driver.construction = null
	driver.world_view = null
	driver.fog = null
	driver.queue_free()
	prototype.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
