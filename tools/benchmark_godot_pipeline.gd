extends Node

const PROTOTYPE_SCENE := preload("res://scenes/prototype/momentum_prototype.tscn")
const SAMPLE_COUNT := 30
const VIEW_RECT := Rect2(-576.0, -324.0, 1152.0, 648.0)

class PipelineDriver:
	extends Node
	var simulation: SimulationController
	var construction: ConstructionController
	var world_view: NetworkWorldView
	var fog: FogOfWar
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

	func _process(delta: float) -> void:
		var simulation_started := Time.get_ticks_usec()
		simulation.native.step(1.0 / 60.0)
		var simulation_ms := float(Time.get_ticks_usec() - simulation_started) / 1000.0
		var boundary_started := Time.get_ticks_usec()
		simulation.native.sync_enemy_proxies(enemy_snapshot)
		var snapshot := simulation.native.get_render_snapshot(VIEW_RECT, 0.0)
		var boundary_ms := float(Time.get_ticks_usec() - boundary_started) / 1000.0
		visible_projectiles = snapshot.projectile_positions.size()
		visible_waves = snapshot.wave_positions.size()
		var upload_started := Time.get_ticks_usec()
		world_view.set_state(snapshot, construction.view_records(), 0, fog.texture)
		var upload_ms := float(Time.get_ticks_usec() - upload_started) / 1000.0
		if warmup_frames > 0:
			warmup_frames -= 1
			return
		simulation_samples.append(simulation_ms)
		boundary_samples.append(boundary_ms)
		upload_samples.append(upload_ms)
		draw_samples.append(world_view.last_draw_milliseconds)
		frame_samples.append(delta * 1000.0)
		if frame_samples.size() >= sample_target:
			finished = true
			set_process(false)


func _ready() -> void:
	_run.call_deferred()


func _percentile(values: Array[float], ratio: float) -> float:
	values.sort()
	return values[int(ratio * float(values.size() - 1))]


func _run() -> void:
	var prototype := PROTOTYPE_SCENE.instantiate()
	add_child(prototype)
	prototype.set("_auto_fire", false)
	await get_tree().process_frame
	await get_tree().process_frame

	var simulation: SimulationController = prototype.get("_simulation")
	var construction: ConstructionController = prototype.get("_construction")
	var catalog: DeviceCatalog = prototype.get("_catalog")
	var world_view: NetworkWorldView = prototype.get("_world_view")
	var fog: FogOfWar = prototype.get("_fog")

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

	var driver := PipelineDriver.new()
	driver.name = "PipelineBenchmarkDriver"
	driver.simulation = simulation
	driver.construction = construction
	driver.world_view = world_view
	driver.fog = fog
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
