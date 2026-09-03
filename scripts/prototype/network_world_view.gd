class_name NetworkWorldView
extends Node2D

class OverlayLayer:
	extends Node2D
	var world_view

	func _draw() -> void:
		world_view._draw_overlay(self)

var render_snapshot: Dictionary = {}
var device_records: Array = []
var selected_device_id := 0
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


func configure(profile: BalanceProfile) -> void:
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
		new_destruction_effects: Array[Dictionary] = []
) -> void:
	render_snapshot = new_render_snapshot
	device_records = new_device_records
	selected_device_id = new_selected_device_id
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
	_draw_targets()
	_draw_enemies()
	_draw_tracers()


func _draw_overlay(canvas: CanvasItem) -> void:
	var started_usec := Time.get_ticks_usec()
	if fog_texture != null:
		canvas.draw_texture_rect(fog_texture, map_rect, false)
	_draw_devices(canvas)
	_draw_destruction_effects(canvas)
	_draw_tower(canvas)
	canvas.draw_rect(map_rect, map_border_color, false, map_border_width)
	last_draw_milliseconds = float(Time.get_ticks_usec() - started_usec) / 1000.0


func _draw_destruction_effects(canvas: CanvasItem) -> void:
	for effect in destruction_effects:
		var position: Vector2 = effect.get("position", Vector2.ZERO)
		var total := maxf(float(effect.get("total", 0.35)), 0.0001)
		var ratio := clampf(float(effect.get("remaining", 0.0)) / total, 0.0, 1.0)
		var radius := lerpf(destruction_end_radius, destruction_start_radius, ratio)
		canvas.draw_circle(position, radius, Color(destruction_fill_color, destruction_fill_alpha * ratio))
		canvas.draw_arc(position, radius, 0.0, TAU, 20, Color(destruction_stroke_color, ratio), destruction_stroke_width, true)


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
	canvas.draw_circle(tower_position, 12.0, tower_color)
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
		var entropy := float(record.get("entropy", 0.0))
		draw_circle(position, radius, Color(color, enemy_fill_alpha))
		draw_arc(position, radius, 0.0, TAU, 24, color, 3.0, true)
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
		if hp / max_hp <= low_hp_ratio and int(Time.get_ticks_msec() / maxi(low_hp_flash_milliseconds, 1)) % 2 == 0:
			color = low_hp_color
		if device_id == selected_device_id:
			var selection_radius := definition.activation_radius + selection_extra_radius
			canvas.draw_circle(position, selection_radius, Color(1.0, 1.0, 1.0, selection_fill_alpha))
			canvas.draw_arc(position, selection_radius, 0.0, TAU, 36, Color.WHITE, 2.0, true)
		_draw_device_shape(canvas, definition, record, position, angle, color, active)
		_draw_bars(canvas, record, position, color)


func _draw_device_shape(
		canvas: CanvasItem,
		definition: DeviceDefinition,
		record: Dictionary,
		position: Vector2,
		angle: float,
		color: Color,
		active: bool
) -> void:
	var direction := Vector2.RIGHT.rotated(angle)
	match definition.kind:
		&"bounce_plate":
			var tangent := direction
			canvas.draw_line(position - tangent * definition.half_length,
				position + tangent * definition.half_length, Color(color, 0.25), 12.0, true)
			canvas.draw_line(position - tangent * definition.half_length,
				position + tangent * definition.half_length, color, 4.0, true)
		&"speed_increaser":
			canvas.draw_arc(position, 27.0, 0.0, TAU, 32, color, 4.0, true)
			_draw_arrow(canvas, position - direction * 13.0, position + direction * 17.0, color)
		&"mass_increaser":
			canvas.draw_rect(Rect2(position - Vector2(23.0, 23.0), Vector2(46.0, 46.0)), Color(color, 0.16), true)
			canvas.draw_rect(Rect2(position - Vector2(23.0, 23.0), Vector2(46.0, 46.0)), color, false, 4.0)
			canvas.draw_circle(position, 9.0, color)
		&"splitter":
			var normal := direction.orthogonal()
			canvas.draw_line(position - direction * 22.0, position + direction * 9.0, color, 4.0, true)
			for side in [-1.0, 1.0]:
				var endpoint: Vector2 = position + normal * definition.splitter_half_separation * side
				canvas.draw_line(position + direction * 9.0, endpoint, color, 3.0, true)
				_draw_arrow(canvas, endpoint, endpoint + direction * 20.0, color)
		&"diode":
			var exit: Vector2 = record.get("secondary_position", Vector2.ZERO)
			var exit_angle := float(record.get("secondary_angle_radians", 0.0))
			canvas.draw_dashed_line(position, exit, Color(color, 0.58), 3.0, 12.0)
			canvas.draw_circle(position, 23.0, Color(color, 0.12))
			canvas.draw_arc(position, 23.0, 0.0, TAU, 28, color, 4.0, true)
			canvas.draw_circle(exit, 23.0, Color(color, 0.12))
			canvas.draw_arc(exit, 23.0, 0.0, TAU, 28, color, 4.0, true)
			_draw_arrow(canvas, exit, exit + Vector2.RIGHT.rotated(exit_angle) * 30.0, color)
		&"electric_field", &"magnetic_field":
			if active:
				canvas.draw_circle(position, definition.field_radius, Color(color, 0.055))
				canvas.draw_arc(position, definition.field_radius, 0.0, TAU, 64, Color(color, 0.32), 2.0, true)
			canvas.draw_circle(position, 27.0, Color(color, 0.16))
			canvas.draw_arc(position, 27.0, 0.0, TAU, 32, color, 4.0, true)
			canvas.draw_string(ThemeDB.fallback_font, position + Vector2(-9.0, 8.0),
				"E" if definition.kind == &"electric_field" else "B",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, color)
		&"wave_converter":
			canvas.draw_arc(position, 28.0, -PI * 0.75, PI * 0.75, 28, color, 4.0, true)
			for offset in [-0.35, 0.0, 0.35]:
				canvas.draw_line(position, position + direction.rotated(offset) * 35.0, Color(color, 0.75), 2.0)
		&"accumulator":
			canvas.draw_circle(position, 28.0, Color(color, 0.13))
			canvas.draw_arc(position, 28.0, 0.0, TAU, 32, color, 4.0, true)
			var stored := float(record.get("stored_momentum", 0.0))
			canvas.draw_arc(position, 18.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(stored / maxf(definition.activation_required, 0.0001), 0.0, 1.0),
				24, color, 6.0, true)


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
