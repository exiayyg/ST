class_name NetworkWorldView
extends Node2D

class OverlayLayer:
	extends Node2D
	var world_view

	func _draw() -> void:
		world_view._draw_overlay(self)

var _energy: RuntimeBalance.Presentation
var decoration_time := 0.0
var reduced_motion := false
var presentation_effects: Array[Dictionary] = []
var lit_query: Callable
var _playtest_config: RuntimeBalance.Playtest
var hold_progress := 0.0
var hold_position := Vector2.ZERO
var interaction_preview: Dictionary = {}
var _input_config: RuntimeBalance.ConstructionUx

var render_snapshot: Dictionary = {}
var device_records: Array = []
var selected_device_id := 0
var selected_anchor := 0
var dismantle_progress := 0.0
var world_cues: Array[Dictionary] = []
var teleport_effects: Array[Dictionary] = []
var target_positions: Array[Vector2] = []
var fog_texture: Texture2D
var last_draw_milliseconds := 0.0
var _projectile_instances: MultiMeshInstance2D
var _wave_instances: MultiMeshInstance2D
var _overlay: OverlayLayer
var map_rect := Rect2(-2304.0, -1296.0, 4608.0, 2592.0)
var target_radius := 34.0
var low_hp_ratio := 0.3
var low_hp_flash_milliseconds := 180
var device_bar_width := 62.0
var hp_bar_height := 5.0
var activation_bar_height := 4.0
var tower_position := Vector2.ZERO
var tower_collision_radius := 42.0
var enemy_records: Array[Dictionary] = []
var combat_tracers: Array[Dictionary] = []
var tower_hp := 0.0
var tower_max_hp := 1.0
var enemy_bar_width := 40.0
var enemy_bar_height := 4.0
var destruction_effects: Array[Dictionary] = []
var world_background_color := Color("0d121c")
var world_grid_color := Color("1b2637")
var world_axis_color := Color("2b3b52")
var map_border_color := Color("51627b")
var map_border_width := 5.0
var grid_spacing := 128.0
var tower_color := Color("79d7ff")
var tower_fill_color := Color("172a39")
var inactive_device_color := Color("697386")
var diagnostic_target_color := Color("ff6b7a")
var low_hp_color := Color("ff4d62")
var healthy_hp_color := Color("65eaa8")
var bar_background_color := Color("202938")
var enemy_entropy_color := Color("ff4d62")
var charge_color := Color("fff0a6")
var destruction_fill_color := Color("8c949e")
var destruction_stroke_color := Color("bfc7d1")
var destruction_fill_alpha := 0.32
var destruction_stroke_width := 3.0
var destruction_start_radius := 14.0
var destruction_end_radius := 44.0
var device_cull_margin := 200.0
var selection_extra_radius := 16.0
var selection_fill_alpha := 0.08
var tower_bar_width := 96.0
var tower_bar_height := 7.0
var tracer_line_width := 3.0
var enemy_fill_alpha := 0.28
var device_hit_flash_color := Color("fff2f4")
var dismantle_progress_color := Color("ffcf5c")
var dismantle_progress_width := 5.0
var tutorial_cue_color := Color("5ee6a8")
var tutorial_path_color := Color("79d7ff")
var tutorial_path_width := 2.0
var tutorial_cue_pulse_seconds := 1.2
var diode_teleport_pulse_color := Color("65f4ff")
var diode_teleport_pulse_start_radius := 14.0
var diode_teleport_pulse_end_radius := 42.0
var diode_teleport_pulse_width := 3.0


func configure(profile: BalanceProfile) -> void:
	_input_config = profile.runtime_config().construction_ux
	_energy = profile.runtime_config().presentation
	for instance in [_projectile_instances, _wave_instances]:
		if instance == null: continue
		instance.material.set_shader_parameter("edge_ratio", _energy.particle_edge_ratio)
		instance.material.set_shader_parameter("core_ratio", _energy.particle_core_ratio)
		instance.material.set_shader_parameter("white_ratio", _energy.particle_white_ratio)
	_playtest_config = profile.runtime_config().playtest
	map_rect = profile.map_rect()
	target_radius = float(profile.value("diagnostics/target_radius", target_radius))
	low_hp_ratio = float(profile.value("visuals/low_hp_ratio", low_hp_ratio))
	low_hp_flash_milliseconds = int(profile.value("visuals/low_hp_flash_milliseconds", low_hp_flash_milliseconds))
	device_bar_width = float(profile.value("visuals/device_bar_width", device_bar_width))
	hp_bar_height = float(profile.value("visuals/device_hp_bar_height", hp_bar_height))
	activation_bar_height = float(profile.value("visuals/device_activation_bar_height", activation_bar_height))
	tower_position = Vector2(float(profile.value("tower/position_x", 0.0)), float(profile.value("tower/position_y", 0.0)))
	tower_collision_radius = float(profile.value("tower/collision_radius", tower_collision_radius))
	enemy_bar_width = float(profile.value("visuals/enemy_bar_width", enemy_bar_width))
	enemy_bar_height = float(profile.value("visuals/enemy_bar_height", enemy_bar_height))
	world_background_color = Color(String(profile.value("visuals/world_background_color", world_background_color.to_html(false))))
	world_grid_color = Color(String(profile.value("visuals/world_grid_color", world_grid_color.to_html(false))))
	world_axis_color = Color(String(profile.value("visuals/world_axis_color", world_axis_color.to_html(false))))
	map_border_color = Color(String(profile.value("visuals/map_border_color", map_border_color.to_html(false))))
	map_border_width = float(profile.value("visuals/map_border_width", map_border_width))
	grid_spacing = float(profile.value("visuals/grid_spacing", grid_spacing))
	tower_color = Color(String(profile.value("visuals/tower_color", tower_color.to_html(false))))
	tower_fill_color = Color(String(profile.value("visuals/tower_fill_color", tower_fill_color.to_html(false))))
	inactive_device_color = Color(String(profile.value("visuals/inactive_device_color", inactive_device_color.to_html(false))))
	diagnostic_target_color = Color(String(profile.value("visuals/diagnostic_target_color", diagnostic_target_color.to_html(false))))
	low_hp_color = Color(String(profile.value("visuals/low_hp_color", low_hp_color.to_html(false))))
	healthy_hp_color = Color(String(profile.value("visuals/healthy_hp_color", healthy_hp_color.to_html(false))))
	bar_background_color = Color(String(profile.value("visuals/bar_background_color", bar_background_color.to_html(false))))
	enemy_entropy_color = Color(String(profile.value("visuals/enemy_entropy_color", enemy_entropy_color.to_html(false))))
	charge_color = Color(String(profile.value("visuals/charge_color", charge_color.to_html(false))))
	destruction_fill_color = Color(String(profile.value("visuals/destruction_fill_color", destruction_fill_color.to_html(false))))
	destruction_stroke_color = Color(String(profile.value("visuals/destruction_stroke_color", destruction_stroke_color.to_html(false))))
	destruction_fill_alpha = float(profile.value("visuals/destruction_fill_alpha", destruction_fill_alpha))
	destruction_stroke_width = float(profile.value("visuals/destruction_stroke_width", destruction_stroke_width))
	destruction_start_radius = float(profile.value("visuals/destroy_effect_start_radius", destruction_start_radius))
	destruction_end_radius = float(profile.value("visuals/destroy_effect_end_radius", destruction_end_radius))
	device_cull_margin = float(profile.value("visuals/device_cull_margin", device_cull_margin))
	selection_extra_radius = float(profile.value("visuals/selection_extra_radius", selection_extra_radius))
	selection_fill_alpha = float(profile.value("visuals/selection_fill_alpha", selection_fill_alpha))
	tower_bar_width = float(profile.value("visuals/tower_bar_width", tower_bar_width))
	tower_bar_height = float(profile.value("visuals/tower_bar_height", tower_bar_height))
	tracer_line_width = float(profile.value("visuals/tracer_line_width", tracer_line_width))
	enemy_fill_alpha = float(profile.value("visuals/enemy_fill_alpha", enemy_fill_alpha))
	device_hit_flash_color = Color(String(profile.value("visuals/device_hit_flash_color", device_hit_flash_color.to_html(false))))
	dismantle_progress_color = Color(String(profile.value("visuals/dismantle_progress_color", dismantle_progress_color.to_html(false))))
	dismantle_progress_width = float(profile.value("visuals/dismantle_progress_width", dismantle_progress_width))
	tutorial_cue_color = Color(String(profile.value("visuals/tutorial_cue_color", tutorial_cue_color.to_html(false))))
	tutorial_path_color = Color(String(profile.value("visuals/tutorial_path_color", tutorial_path_color.to_html(false))))
	tutorial_path_width = float(profile.value("visuals/tutorial_path_width", tutorial_path_width))
	tutorial_cue_pulse_seconds = float(profile.value("visuals/tutorial_cue_pulse_seconds", tutorial_cue_pulse_seconds))
	diode_teleport_pulse_color = Color(String(profile.value("visuals/diode_teleport_pulse_color", diode_teleport_pulse_color.to_html(false))))
	diode_teleport_pulse_start_radius = float(profile.value("visuals/diode_teleport_pulse_start_radius", diode_teleport_pulse_start_radius))
	diode_teleport_pulse_end_radius = float(profile.value("visuals/diode_teleport_pulse_end_radius", diode_teleport_pulse_end_radius))
	diode_teleport_pulse_width = float(profile.value("visuals/diode_teleport_pulse_width", diode_teleport_pulse_width))


func set_combat_state(
		new_enemy_records: Array[Dictionary],
		new_tracers: Array[Dictionary],
		new_tower_hp: float,
		new_tower_max_hp: float
) -> void:
	enemy_records = new_enemy_records
	combat_tracers = new_tracers
	tower_hp = new_tower_hp
	tower_max_hp = maxf(new_tower_max_hp, 0.0001)
	queue_redraw()
	_overlay.queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_projectile_instances = _create_entity_instances("ProjectileInstances")
	_wave_instances = _create_entity_instances("WavePointInstances")
	_overlay = OverlayLayer.new()
	_overlay.name = "FogAndDeviceOverlay"
	_overlay.world_view = self
	add_child(_overlay)


func set_state(
		new_render_snapshot: Dictionary,
		new_device_records: Array,
		new_selected_device_id: int,
		new_fog_texture: Texture2D,
		new_destruction_effects: Array[Dictionary] = [],
		new_selected_anchor: int = 0,
		new_dismantle_progress: float = 0.0,
		new_world_cues: Array[Dictionary] = [],
		new_teleport_effects: Array[Dictionary] = []
) -> void:
	render_snapshot = new_render_snapshot
	device_records = new_device_records
	selected_device_id = new_selected_device_id
	selected_anchor = new_selected_anchor
	dismantle_progress = clampf(new_dismantle_progress, 0.0, 1.0)
	world_cues = new_world_cues
	teleport_effects = new_teleport_effects
	fog_texture = new_fog_texture
	destruction_effects = new_destruction_effects
	_update_entity_instances(
		_projectile_instances,
		render_snapshot.get("projectile_positions", PackedVector2Array()).size(),
		render_snapshot.get("projectile_multimesh_buffer", PackedFloat32Array())
	)
	_update_entity_instances(
		_wave_instances,
		render_snapshot.get("wave_positions", PackedVector2Array()).size(),
		render_snapshot.get("wave_multimesh_buffer", PackedFloat32Array())
	)
	queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	draw_rect(map_rect, world_background_color)
	_draw_grid()
	_draw_fields()
	_draw_targets()
	_draw_enemies()
	_draw_tracers()
	_draw_energy_effects()
	_draw_teleport_effects(self)
	_draw_destruction_effects(self)


func _draw_overlay(canvas: CanvasItem) -> void:
	var started_usec := Time.get_ticks_usec()
	if fog_texture != null:
		canvas.draw_texture_rect(fog_texture, map_rect, false)
	_draw_world_cues(canvas)
	_draw_devices(canvas)
	_draw_tower(canvas)
	_draw_interaction_preview(canvas)
	canvas.draw_rect(map_rect, map_border_color, false, map_border_width)
	last_draw_milliseconds = float(Time.get_ticks_usec() - started_usec) / 1000.0


func _draw_interaction_preview(canvas: CanvasItem) -> void:
	if interaction_preview.is_empty(): return
	var preview := interaction_preview
	var point: Vector2 = preview.position
	var color := Color(tutorial_cue_color if preview.valid else low_hp_color, _input_config.preview_alpha)
	var kind := StringName(preview.kind)
	var angle := float(preview.angle)
	if kind == &"diode" and int(preview.anchor) == 1: kind = &"diode_exit"
	EnergyGlyphs.draw(canvas, kind, point, float(preview.radius), angle, color, _input_config.preview_line_width)
	if preview.mode == "placement" and kind == &"diode":
		var exit: Vector2 = preview.secondary_position
		EnergyGlyphs.draw(canvas, &"diode_exit", exit, float(preview.radius), angle, color, _input_config.preview_line_width)
		canvas.draw_line(point, exit, color, _input_config.preview_line_width, true)
		canvas.draw_string(ThemeDB.fallback_font, point + Vector2.UP * float(preview.radius), "入口", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(_input_config.preview_font_size), color)
		canvas.draw_string(ThemeDB.fallback_font, exit + Vector2.UP * float(preview.radius), "出口", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(_input_config.preview_font_size), color)
	if preview.mode == "rotation":
		var facing := angle + (PI * 0.5 if kind == &"bounce_plate" else 0.0)
		var tip := point + Vector2.RIGHT.rotated(facing) * _input_config.preview_direction_length
		EnergyGlyphs.arrow(canvas, point, tip, color, _input_config.preview_line_width)
		canvas.draw_string(ThemeDB.fallback_font, tip, "%.2f° · 松开右键固定" % rad_to_deg(facing), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(_input_config.preview_font_size), color)

func _draw_destruction_effects(canvas: CanvasItem) -> void:
	if reduced_motion or not _energy.enabled: return
	for effect in destruction_effects:
		var position: Vector2 = effect.get("position", Vector2.ZERO)
		var total := maxf(float(effect.get("total", 0.35)), 0.0001)
		var ratio := clampf(float(effect.get("remaining", 0.0)) / total, 0.0, 1.0)
		if StringName(effect.get("kind", &"device_destroyed")) == &"device_dismantled":
			var retract_radius := lerpf(destruction_start_radius, destruction_end_radius, ratio)
			canvas.draw_arc(position, retract_radius, -PI * 0.5, PI * 0.5, 14,
				Color(dismantle_progress_color, ratio), destruction_stroke_width, true)
			canvas.draw_arc(position, retract_radius, PI * 0.5, PI * 1.5, 14,
				Color(dismantle_progress_color, ratio), destruction_stroke_width, true)
			continue
		var radius := lerpf(destruction_end_radius, destruction_start_radius, ratio)
		canvas.draw_circle(position, radius, Color(destruction_fill_color, destruction_fill_alpha * ratio))
		canvas.draw_arc(position, radius, 0.0, TAU, 20, Color(destruction_stroke_color, ratio), destruction_stroke_width, true)


func _draw_teleport_effects(canvas: CanvasItem) -> void:
	if reduced_motion or not _energy.enabled: return
	for effect in teleport_effects:
		var entry: Vector2 = effect.get("entry", Vector2.ZERO)
		var exit: Vector2 = effect.get("exit", Vector2.ZERO)
		var total := maxf(float(effect.get("total", 0.32)), 0.0001)
		var remaining_ratio := clampf(float(effect.get("remaining", 0.0)) / total, 0.0, 1.0)
		var progress := 1.0 - remaining_ratio
		var radius := lerpf(diode_teleport_pulse_start_radius, diode_teleport_pulse_end_radius, progress)
		var color := Color(diode_teleport_pulse_color, remaining_ratio)
		canvas.draw_line(entry, exit, Color(diode_teleport_pulse_color, remaining_ratio * 0.65), diode_teleport_pulse_width, true)
		canvas.draw_arc(entry, radius, 0.0, TAU, 28, color, diode_teleport_pulse_width, true)
		canvas.draw_arc(exit, radius, 0.0, TAU, 28, color, diode_teleport_pulse_width, true)


func _create_entity_instances(node_name: String) -> MultiMeshInstance2D:
	var instance := MultiMeshInstance2D.new()
	instance.name = node_name
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	instance.multimesh = multimesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/energy_particle.gdshader")
	material.set_shader_parameter("wave_point", node_name == "WavePointInstances")
	instance.material = material
	add_child(instance)
	return instance


func _update_entity_instances(
		instance: MultiMeshInstance2D,
		count: int,
		buffer: PackedFloat32Array
) -> void:
	var multimesh := instance.multimesh
	if multimesh.instance_count != count:
		multimesh.instance_count = count
	if count > 0:
		multimesh.buffer = buffer


func _draw_grid() -> void:
	var spacing := maxi(1, int(round(grid_spacing)))
	for x in range(int(map_rect.position.x), int(map_rect.end.x) + 1, spacing):
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), world_grid_color, 1.0)
	for y in range(int(map_rect.position.y), int(map_rect.end.y) + 1, spacing):
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), world_grid_color, 1.0)
	draw_line(Vector2(map_rect.position.x, 0.0), Vector2(map_rect.end.x, 0.0), world_axis_color, 2.0)


func _draw_tower(canvas: CanvasItem) -> void:
	canvas.draw_circle(tower_position, tower_collision_radius, tower_fill_color)
	canvas.draw_arc(tower_position, tower_collision_radius, 0.0, TAU, 48, tower_color, 4.0, true)
	canvas.draw_line(tower_position, tower_position + Vector2(tower_collision_radius + 14.0, 0.0), tower_color, 11.0, true)
	canvas.draw_circle(tower_position, tower_collision_radius * _energy.core_ratio, tower_color)
	EnergyGlyphs.polygon(canvas, tower_position, tower_collision_radius, 6, 0.0, tower_color, _energy.line_width)
	if _energy.enabled and not reduced_motion:
		var phase := decoration_time * TAU / _energy.cycle_seconds
		canvas.draw_arc(tower_position, tower_collision_radius * (1.0 + _energy.core_ratio), phase, phase + PI, 48, Color(tower_color, _energy.halo_alpha), _energy.halo_width, true)
	canvas.draw_string(ThemeDB.fallback_font, tower_position + Vector2(-54.0, tower_collision_radius + 34.0), "奇点塔  TOWER",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, tower_color)
	if tower_hp > 0.0:
		var ratio := clampf(tower_hp / tower_max_hp, 0.0, 1.0)
		canvas.draw_rect(Rect2(tower_position + Vector2(-tower_bar_width * 0.5, tower_collision_radius + 44.0), Vector2(tower_bar_width, tower_bar_height)), bar_background_color)
		canvas.draw_rect(Rect2(tower_position + Vector2(-tower_bar_width * 0.5, tower_collision_radius + 44.0), Vector2(tower_bar_width * ratio, tower_bar_height)), low_hp_color if ratio <= low_hp_ratio else healthy_hp_color)


func _draw_enemies() -> void:
	for record in enemy_records:
		var position: Vector2 = record.get("position", Vector2.ZERO)
		var radius := float(record.get("radius", 16.0))
		var color: Color = record.get("color", Color("ff6b7a"))
		if float(record.get("hit_flash_remaining", 0.0)) > 0.0:
			color = Color(_playtest_config.enemy_hit_flash_color)
		var entropy := float(record.get("entropy", 0.0))
		EnergyGlyphs.enemy(self, position, radius, bool(record.get("ranged", false)), color, _energy.line_width)
		if bool(record.get("hit_flash_only", false)):
			continue
		if entropy > 0.0:
			draw_arc(position, radius + 5.0, 0.0, TAU, 24, enemy_entropy_color, 2.0, true)
		if bool(record.get("charging", false)):
			var charge_ratio := clampf(float(record.get("charge_ratio", 0.0)), 0.0, 1.0)
			draw_arc(position, radius + 9.0, -PI * 0.5, -PI * 0.5 + TAU * charge_ratio,
					24, charge_color, 3.0, true)
		var hp := float(record.get("hp", 0.0))
		var max_hp := maxf(float(record.get("max_hp", 1.0)), 0.0001)
		var left := -enemy_bar_width * 0.5
		draw_rect(Rect2(position + Vector2(left, radius + 8.0), Vector2(enemy_bar_width, enemy_bar_height)), bar_background_color)
		draw_rect(Rect2(position + Vector2(left, radius + 8.0), Vector2(enemy_bar_width * hp / max_hp, enemy_bar_height)), low_hp_color)


func _draw_tracers() -> void:
	for tracer in combat_tracers:
		draw_line(tracer.get("from", Vector2.ZERO), tracer.get("to", Vector2.ZERO), tracer.get("color", Color.WHITE), tracer_line_width, true)


func _draw_targets() -> void:
	for position in target_positions:
		draw_circle(position, target_radius, Color(diagnostic_target_color, 0.14))
		draw_arc(position, target_radius, 0.0, TAU, 36, diagnostic_target_color, 3.0, true)
		draw_line(position - Vector2(15.0, 0.0), position + Vector2(15.0, 0.0), diagnostic_target_color, 2.0)
		draw_line(position - Vector2(0.0, 15.0), position + Vector2(0.0, 15.0), diagnostic_target_color, 2.0)


func _draw_devices(canvas: CanvasItem) -> void:
	if hold_progress > 0.0:
		canvas.draw_arc(hold_position, _playtest_config.hold_ring_radius, -PI * 0.5,
			-PI * 0.5 + TAU * hold_progress, 36, tutorial_cue_color, _playtest_config.hold_ring_width, true)
	var visible_rect: Rect2 = render_snapshot.get("visible_rect", map_rect)
	var device_cull_rect := visible_rect.grow(device_cull_margin)
	for record: Dictionary in device_records:
		var definition := record.get("definition") as DeviceDefinition
		if definition == null:
			continue
		var position: Vector2 = record.get("position", Vector2.ZERO)
		var secondary_position: Vector2 = record.get("secondary_position", position)
		if not device_cull_rect.has_point(position) and (
				definition.kind != &"diode" or not device_cull_rect.has_point(secondary_position)
		):
			continue
		var device_id := int(record.get("id", 0))
		var angle := float(record.get("angle_radians", 0.0))
		var active := bool(record.get("active", false))
		var hp := float(record.get("hp", 0.0))
		var max_hp := maxf(float(record.get("max_hp", 1.0)), 0.0001)
		var color := definition.color if active else inactive_device_color
		if float(record.get("hit_flash_remaining", 0.0)) > 0.0:
			color = device_hit_flash_color
		if hp / max_hp <= low_hp_ratio and (reduced_motion or int(decoration_time * 1000.0 / maxi(low_hp_flash_milliseconds, 1)) % 2 == 0):
			color = low_hp_color
		if device_id == selected_device_id:
			var selection_radius := definition.activation_radius + selection_extra_radius
			var selection_position := secondary_position if definition.kind == &"diode" and selected_anchor == 1 else position
			canvas.draw_circle(selection_position, selection_radius, Color(1.0, 1.0, 1.0, selection_fill_alpha))
			canvas.draw_arc(selection_position, selection_radius, 0.0, TAU, 36, Color.WHITE, 2.0, true)
			if definition.kind == &"diode" and interaction_preview.get("mode", "") != "rotation":
				canvas.draw_string(ThemeDB.fallback_font, selection_position + Vector2(0.0, -_playtest_config.endpoint_label_offset),
					"正在操作：出口" if selected_anchor == 1 else "正在操作：入口", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					int(_playtest_config.endpoint_label_font_size), Color.WHITE)
				_draw_arrow(canvas, secondary_position, secondary_position + Vector2.RIGHT.rotated(float(record.get("secondary_angle_radians", 0.0))) * _playtest_config.exit_arrow_length, Color.WHITE)
			if dismantle_progress > 0.0:
				canvas.draw_arc(selection_position, selection_radius + 6.0, -PI * 0.5,
					-PI * 0.5 + TAU * dismantle_progress, 40, dismantle_progress_color,
					dismantle_progress_width, true)
		_draw_device_shape(canvas, definition, record, position, angle, color, active)
		_draw_bars(canvas, record, position, color)


func _draw_device_shape(
		canvas: CanvasItem, definition: DeviceDefinition, record: Dictionary,
		position: Vector2, angle: float, color: Color, active: bool
) -> void:
	var phase := decoration_time * TAU / _energy.cycle_seconds if active and not reduced_motion else 0.0
	var radius := _energy.body_radius
	if definition.kind == &"bounce_plate": radius = definition.half_length
	elif definition.kind == &"splitter": radius = definition.splitter_half_separation
	var lit: bool = not lit_query.is_valid() or lit_query.call(position)
	var display_color := color if lit else inactive_device_color
	if active and _energy.enabled and lit:
		canvas.draw_arc(position, radius, phase, phase + PI, 32, Color(color, _energy.halo_alpha), _energy.halo_width, true)
	EnergyGlyphs.draw(canvas, definition.kind, position, radius, angle, display_color, _energy.line_width, phase)
	if definition.kind == &"diode":
		var exit: Vector2 = record.get("secondary_position", position)
		var exit_angle := float(record.get("secondary_angle_radians", 0.0))
		canvas.draw_dashed_line(position, exit, Color(display_color, _energy.core_ratio), _energy.line_width, radius)
		EnergyGlyphs.draw(canvas, &"diode_exit", exit, radius, exit_angle, display_color, _energy.line_width, phase)
		_draw_bars(canvas, record, exit, display_color)
	if definition.kind == &"accumulator" and float(record.get("stored_momentum", 0.0)) > 0.0:
		canvas.draw_circle(position, radius * _energy.core_ratio, display_color)

func _draw_bars(canvas: CanvasItem, record: Dictionary, position: Vector2, color: Color) -> void:
	var hp := float(record.get("hp", 0.0))
	var max_hp := maxf(float(record.get("max_hp", 1.0)), 0.0001)
	var progress := float(record.get("activation_progress", 0.0))
	var required := maxf(float(record.get("activation_required", 1.0)), 0.0001)
	var hp_color := low_hp_color if hp / max_hp <= low_hp_ratio else healthy_hp_color
	var left := -device_bar_width * 0.5
	canvas.draw_rect(Rect2(position + Vector2(left, 43.0), Vector2(device_bar_width, hp_bar_height)), bar_background_color)
	canvas.draw_rect(Rect2(position + Vector2(left, 43.0), Vector2(device_bar_width * hp / max_hp, hp_bar_height)), hp_color)
	if not bool(record.get("active", false)):
		canvas.draw_rect(Rect2(position + Vector2(left, 52.0), Vector2(device_bar_width, activation_bar_height)), bar_background_color)
		canvas.draw_rect(Rect2(position + Vector2(left, 52.0), Vector2(device_bar_width * clampf(progress / required, 0.0, 1.0), activation_bar_height)), color)


func _draw_arrow(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	canvas.draw_line(from, to, color, 3.0, true)
	var direction := (to - from).normalized()
	canvas.draw_line(to, to - direction.rotated(0.65) * 9.0, color, 3.0, true)
	canvas.draw_line(to, to - direction.rotated(-0.65) * 9.0, color, 3.0, true)


func _draw_world_cues(canvas: CanvasItem) -> void:
	if world_cues.is_empty():
		return
	var pulse := 1.0 if reduced_motion else 0.65 + 0.35 * sin(decoration_time / tutorial_cue_pulse_seconds * TAU)
	for cue in world_cues:
		var kind := StringName(cue.get("kind", &"anchor"))
		var color: Color = cue.get("color", tutorial_cue_color)
		match kind:
			&"path":
				canvas.draw_dashed_line(cue.get("from", Vector2.ZERO), cue.get("to", Vector2.ZERO),
					Color(tutorial_path_color, pulse), tutorial_path_width, 14.0)
			&"direction":
				_draw_arrow(canvas, cue.get("from", Vector2.ZERO), cue.get("to", Vector2.ZERO), Color(color, pulse))
			_:
				var position: Vector2 = cue.get("position", Vector2.ZERO)
				var radius := float(cue.get("radius", 34.0)) * (0.92 + pulse * 0.08)
				canvas.draw_circle(position, radius, Color(color, 0.06 + pulse * 0.06))
				canvas.draw_arc(position, radius, 0.0, TAU, 36, Color(color, pulse), 3.0, true)
				var label := String(cue.get("label", ""))
				if not label.is_empty() and not _selected_at_cue(position, radius):
					canvas.draw_string(ThemeDB.fallback_font, position + Vector2(-radius, -radius - 12.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 15, color)

func _selected_at_cue(position: Vector2, radius: float) -> bool:
	for record: Dictionary in device_records:
		if record.id != selected_device_id: continue
		var selected_position: Vector2 = record.secondary_position if record.definition.kind == &"diode" and selected_anchor == 1 else record.position
		return selected_position.distance_to(position) <= radius
	return false

func _draw_energy_effects() -> void:
	if _energy == null or not _energy.enabled or reduced_motion: return
	for effect in presentation_effects:
		var ratio := clampf(float(effect.remaining) / float(effect.total), 0.0, 1.0)
		var radius := _energy.effect_radius * (ratio if effect.kind in ["dismantle", "place", "store"] else 1.0 - ratio)
		draw_arc(effect.position, radius, 0.0, TAU, 32, Color(tower_color, ratio * _energy.core_ratio), _energy.line_width, false)

func _draw_fields() -> void:
	if _energy == null: return
	for record: Dictionary in device_records:
		var definition: DeviceDefinition = record.definition
		if not bool(record.active) or definition.kind not in [&"electric_field", &"magnetic_field"]: continue
		_draw_field(definition, record.position, float(record.angle_radians))

func _draw_field(definition: DeviceDefinition, position: Vector2, angle: float) -> void:
	var canvas: CanvasItem = self
	var color := definition.color
	var phase := decoration_time * TAU / _energy.cycle_seconds if not reduced_motion else 0.0
	var field_radius := definition.field_radius
	canvas.draw_arc(position, field_radius, 0.0, TAU, 64, Color(color, _energy.core_ratio), _energy.line_width, true)
	if _energy.enabled:
		var direction := Vector2.RIGHT.rotated(angle)
		for index in _energy.field_line_count:
			var fraction := float(index + 1) / float(_energy.field_line_count + 1)
			if definition.kind == &"electric_field":
				var offset := direction.orthogonal() * field_radius * (fraction * 2.0 - 1.0)
				var extent := sqrt(maxf(field_radius * field_radius - offset.length_squared(), 0.0))
				EnergyGlyphs.arrow(canvas, position + offset - direction * extent, position + offset + direction * extent, Color(color, _energy.halo_alpha), _energy.line_width)
			else:
				canvas.draw_arc(position, field_radius * fraction, phase + fraction * TAU, phase + fraction * TAU + PI, 32, Color(color, _energy.halo_alpha), _energy.line_width, true)
