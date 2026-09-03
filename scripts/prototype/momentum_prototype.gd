extends Node2D

const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")
const ConstructionControllerType := preload("res://scripts/prototype/construction_controller.gd")
const DeviceCatalogType := preload("res://scripts/prototype/device_catalog.gd")
const FogOfWarType := preload("res://scripts/prototype/fog_of_war.gd")
const CameraControllerType := preload("res://scripts/prototype/prototype_camera_controller.gd")
const WorldViewType := preload("res://scripts/prototype/network_world_view.gd")
const HudType := preload("res://scripts/prototype/prototype_hud.gd")
const BalanceOverlayType := preload("res://scripts/config/balance_runtime_overlay.gd")

var _simulation: SimulationController
var _construction: ConstructionController
var _catalog: DeviceCatalog
var _fog: FogOfWar
var _camera_controller: PrototypeCameraController
var _world_view: NetworkWorldView
var _hud: PrototypeHud

var _emit_accumulator := 0.0
var _emitted_count := 0
var _auto_fire := true
var _lighting_dirty := true

var _left_press_active := false
var _press_started_msec := 0
var _press_world_origin := Vector2.ZERO
var _press_screen_origin := Vector2.ZERO
var _dragging_device := false
var _middle_dragging := false

var _radial_open := false
var _radial_center := Vector2.ZERO
var _radial_hover := -1

var _pending_diode_definition: DeviceDefinition
var _pending_diode_entrance := Vector2.ZERO
var _profile: BalanceProfile
var _map_rect := Rect2(-2304.0, -1296.0, 4608.0, 2592.0)
var _tower_position := Vector2.ZERO
var _tower_light_radius := 360.0
var _emit_interval := 0.08
var _radial_hold_seconds := 0.35
var _radial_radius := 112.0
var _radial_dead_zone := 34.0
var _map_margin := 48.0
@export var enable_diagnostic_targets := true


func _ready() -> void:
	var balance_service := get_node_or_null("/root/_balance_service")
	_profile = balance_service.active_profile() if balance_service != null else null
	if _profile == null:
		push_error("BalanceProfile 初始化失败")
		return
	_map_rect = _profile.map_rect()
	_tower_position = Vector2(float(_profile.value("tower/position_x", 0.0)), float(_profile.value("tower/position_y", 0.0)))
	_tower_light_radius = float(_profile.value("tower/light_radius", 360.0))
	_emit_interval = float(_profile.value("tower/fire_interval", 0.08))
	_radial_hold_seconds = float(_profile.value("construction_ux/radial_hold_seconds", 0.35))
	_radial_radius = float(_profile.value("construction_ux/radial_radius", 112.0))
	_radial_dead_zone = float(_profile.value("construction_ux/radial_dead_zone", 34.0))
	_map_margin = float(_profile.value("map_camera/map_margin", 48.0))
	_simulation = SimulationControllerType.new(_profile) as SimulationController
	if not _simulation.initialize():
		push_error("MomentumSimulation initialization failed")
		set_process(false)
		set_process_unhandled_input(false)
		return
	_catalog = DeviceCatalogType.new(_profile) as DeviceCatalog
	_construction = ConstructionControllerType.new(_simulation, _profile) as ConstructionController
	_fog = FogOfWarType.new(_simulation.native, _profile) as FogOfWar

	_world_view = WorldViewType.new() as NetworkWorldView
	_world_view.name = "NetworkWorldView"
	add_child(_world_view)
	_world_view.configure(_profile)

	var camera := Camera2D.new()
	camera.name = "WorldCamera"
	camera.position = Vector2.ZERO
	camera.enabled = true
	add_child(camera)
	_camera_controller = CameraControllerType.new(camera, _map_rect, get_viewport(), _profile) as PrototypeCameraController

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "HudLayer"
	add_child(canvas_layer)
	_hud = HudType.new() as PrototypeHud
	_hud.name = "PrototypeHud"
	_hud.catalog = _catalog
	_hud.configure(_profile)
	canvas_layer.add_child(_hud)
	var balance_overlay := BalanceOverlayType.new() as BalanceRuntimeOverlay
	add_child(balance_overlay)

	if enable_diagnostic_targets:
		var target_count := int(_profile.value("diagnostics/target_count", 3))
		var target_x := float(_profile.value("diagnostics/target_x", 1800.0))
		var target_spacing := float(_profile.value("diagnostics/target_vertical_spacing", 480.0))
		for index in target_count:
			_world_view.target_positions.append(Vector2(target_x, (float(index) - float(target_count - 1) * 0.5) * target_spacing))
		for target_position in _world_view.target_positions:
			_simulation.add_diagnostic_target(target_position)
	_rebuild_fog()
	_refresh_views()


func _process(delta: float) -> void:
	_construction.advance_effects(delta)
	_camera_controller.update(delta)
	if _left_press_active and not _radial_open and not _dragging_device:
		var held_seconds := float(Time.get_ticks_msec() - _press_started_msec) / 1000.0
		if held_seconds >= _radial_hold_seconds:
			_open_radial_menu()

	if _auto_fire:
		_emit_accumulator += delta
		while _emit_accumulator >= _emit_interval:
			_emit_accumulator -= _emit_interval
			_emit_initial_projectile()
	_simulation.step(delta)
	_collect_events(_simulation.native.consume_events())
	if _construction.sync(_simulation.native.get_device_snapshot()):
		_lighting_dirty = true
	if _lighting_dirty:
		_rebuild_fog()
	_refresh_views()


func _emit_initial_projectile() -> void:
	var lane_count := maxi(1, int(_profile.value("tower/lane_count", 3)))
	var lane_spacing := float(_profile.value("tower/lane_spacing", 5.0))
	var lane_offset := (float(_emitted_count % lane_count) - float(lane_count - 1) * 0.5) * lane_spacing
	_simulation.emit_tower_projectile(_tower_position, lane_offset)
	_emitted_count += 1


func _collect_events(events: Array) -> void:
	for event: Dictionary in events:
		match StringName(event.get("type", "")):
			&"device_activated":
				_hud.push_message("装置永久激活 · 新照明已接入网络")
				_lighting_dirty = true
			&"projectile_accelerated":
				_hud.push_message("加速器：速度提升，质量不变")
			&"projectile_mass_increased":
				_hud.push_message("质量器：质量提升，速度不变")
			&"projectile_split":
				_hud.push_message("分流器：P → P/2 + P/2，同向平行")
			&"projectile_teleported":
				_hud.push_message("二极管：空间拓扑跳转")
			&"wave_emitted":
				_hud.push_message("波粒转换：离散扇形波点已发射")
			&"wave_reconstructed":
				_hud.push_message("波动量达到阈值：自动重构标准弹丸")
			&"accumulator_released":
				_hud.push_message("蓄积器：全部质量与动量一次释放")
			&"interaction_guard_triggered":
				_hud.push_message("诊断：单步交互保护已触发，实体未被删除")


func _refresh_views() -> void:
	var visible_rect := _camera_controller.visible_world_rect()
	var render_snapshot := _simulation.native.get_render_snapshot(
		visible_rect, float(_profile.value("simulation/render_snapshot_margin", 96.0))
	)
	var stats := _simulation.native.get_stats()
	stats["fog_rebuild_milliseconds"] = _fog.last_rebuild_milliseconds
	_world_view.set_state(
		render_snapshot,
		_construction.view_records(),
		_construction.selected_device_id,
		_fog.texture,
		_construction.destruction_effects
	)
	_hud.set_state(
		stats,
		_radial_open,
		_radial_center,
		_radial_hover,
		_auto_fire,
		_pending_diode_definition != null
	)


func _rebuild_fog() -> void:
	_fog.rebuild(_construction.light_sources(_tower_position, _tower_light_radius))
	_lighting_dirty = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle_dragging = event.pressed
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera_controller.zoom_by_steps(1.0)
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera_controller.zoom_by_steps(-1.0)
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_build_action()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_on_left_pressed(event.position)
	else:
		_on_left_released()


func _on_left_pressed(screen_position: Vector2) -> void:
	var world_position := _clamp_world_position(_screen_to_world(screen_position))
	if _pending_diode_definition != null:
		if _fog.is_lit(world_position):
			_construction.place(
				_pending_diode_definition,
				_pending_diode_entrance,
				0.0,
				world_position,
				0.0
			)
			_pending_diode_definition = null
			_lighting_dirty = true
		else:
			_hud.push_message("二极管出口必须初次放置在当前亮区")
		return

	var picked := _construction.pick(world_position, float(_profile.value("construction_ux/device_pick_radius", 38.0)))
	if int(picked.id) > 0:
		_construction.selected_device_id = int(picked.id)
		_construction.selected_anchor = int(picked.anchor)
		_dragging_device = true
		_left_press_active = true
		return

	_construction.selected_device_id = 0
	_construction.selected_anchor = 0
	if not _fog.is_lit(world_position):
		_hud.push_message("初次建造只能从亮区开始")
		return
	_left_press_active = true
	_press_started_msec = Time.get_ticks_msec()
	_press_world_origin = world_position
	_press_screen_origin = screen_position


func _on_left_released() -> void:
	if _dragging_device:
		_dragging_device = false
		_left_press_active = false
		return
	if _radial_open:
		if _radial_hover >= 0 and _radial_hover < _catalog.definitions.size():
			var definition := _catalog.definitions[_radial_hover]
			if definition.kind == &"diode":
				_pending_diode_definition = definition
				_pending_diode_entrance = _press_world_origin
			else:
				_construction.place(definition, _press_world_origin)
				_lighting_dirty = true
		_close_radial_menu()
	_left_press_active = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _middle_dragging:
		_camera_controller.pan_by_screen_delta(event.relative)
		return
	if _dragging_device:
		var position := _clamp_world_position(_screen_to_world(event.position))
		if _construction.move_selected(position):
			var record: Dictionary = _construction.devices.get(_construction.selected_device_id, {})
			if bool(record.get("active", false)):
				_lighting_dirty = true
		return
	if _radial_open:
		var offset := event.position - _radial_center
		if offset.length() < _radial_dead_zone:
			_radial_hover = -1
			return
		var sector_size := TAU / float(_catalog.definitions.size())
		var normalized_angle := fposmod(offset.angle() + PI * 0.5 + sector_size * 0.5, TAU)
		_radial_hover = int(floor(normalized_angle / sector_size)) % _catalog.definitions.size()


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			_cancel_build_action()
		KEY_Q:
			if _construction.rotate_selected(deg_to_rad(-float(_profile.value("construction_ux/rotation_step_degrees", 15.0)))):
				_mark_light_dirty_if_selected_active()
		KEY_E:
			if _construction.rotate_selected(deg_to_rad(float(_profile.value("construction_ux/rotation_step_degrees", 15.0)))):
				_mark_light_dirty_if_selected_active()
		KEY_R:
			if not _construction.release_selected():
				_hud.push_message("选中的蓄积器尚未激活或没有存量")
		KEY_SPACE:
			_auto_fire = not _auto_fire
		KEY_DELETE:
			if event.shift_pressed and _construction.damage_selected(float(_profile.value("construction_ux/damage_debug_amount", 25.0))):
				_hud.push_message("装置被摧毁：只移除它自己的照明覆盖")
				_lighting_dirty = true


func _open_radial_menu() -> void:
	_radial_open = true
	var viewport_size := get_viewport_rect().size
	var margin := _radial_radius + float(_profile.value("construction_ux/radial_screen_margin", 14.0))
	_radial_center = Vector2(
		clampf(_press_screen_origin.x, margin, viewport_size.x - margin),
		clampf(_press_screen_origin.y, margin + 68.0, viewport_size.y - margin - 42.0)
	)
	_radial_hover = -1


func _close_radial_menu() -> void:
	_radial_open = false
	_radial_hover = -1


func _cancel_build_action() -> void:
	_left_press_active = false
	_dragging_device = false
	_pending_diode_definition = null
	_close_radial_menu()


func _mark_light_dirty_if_selected_active() -> void:
	var record: Dictionary = _construction.devices.get(_construction.selected_device_id, {})
	if bool(record.get("active", false)):
		_lighting_dirty = true


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _clamp_world_position(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, _map_rect.position.x + _map_margin, _map_rect.end.x - _map_margin),
		clampf(position.y, _map_rect.position.y + _map_margin, _map_rect.end.y - _map_margin)
	)
