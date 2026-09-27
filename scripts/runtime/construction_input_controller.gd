class_name ConstructionInputController
extends RefCounted

signal semantic_event(event: Dictionary)
signal message(text: String)
signal lighting_changed
signal command_requested(command: StringName)

enum Gesture { IDLE, LEFT_PENDING, WHEEL, MOVE, ROTATE, DISMANTLE, PAN }

var _state := Gesture.IDLE
var _construction: ConstructionController
var _catalog: DeviceCatalog
var _fog: FogOfWar
var _camera_controller: PrototypeCameraController
var _viewport: Viewport
var _config: RuntimeBalance.ConstructionUx
var _map_rect: Rect2
var _map_margin: float
var _elapsed := 0.0
var _press_screen := Vector2.ZERO
var _cursor := Vector2.ZERO
var _origin := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _target: Dictionary = {}
var _exceeded_tolerance := false
var _changed := false
var _preview_angle := 0.0
var _original_angle := 0.0
var _radial_center := Vector2.ZERO
var _radial_hover := -1
var _held_keys: Dictionary = {}

func initialize(construction: ConstructionController, catalog: DeviceCatalog, fog: FogOfWar, camera: PrototypeCameraController, viewport: Viewport, profile: BalanceProfile) -> void:
	_construction = construction
	_catalog = catalog
	_fog = fog
	_camera_controller = camera
	_viewport = viewport
	_config = profile.runtime_config().construction_ux
	_map_rect = profile.map_rect()
	_map_margin = float(profile.value("map_camera/map_margin"))

func advance(delta: float) -> void:
	if not _target.is_empty() and not _target_valid():
		cancel()
	_elapsed += delta
	if _state == Gesture.LEFT_PENDING and _target.is_empty() and _elapsed >= _config.radial_hold_seconds:
		_open_wheel()
	elif _state == Gesture.DISMANTLE and _elapsed >= _config.dismantle_hold_seconds:
		var removed := _construction.dismantle_selected()
		_reset_gesture()
		if not removed.is_empty():
			lighting_changed.emit()
			message.emit("装置已拆除：激活与蓄积状态不会返还")
	if _state == Gesture.IDLE:
		var direction := Vector2(float(_held_keys.has(KEY_D)) - float(_held_keys.has(KEY_A)), float(_held_keys.has(KEY_S)) - float(_held_keys.has(KEY_W)))
		_camera_controller.update(delta, direction)

func snapshot() -> Dictionary:
	var preview: Dictionary = {}
	if _state == Gesture.WHEEL and _radial_hover >= 0:
		preview = _placement_preview()
	elif _state == Gesture.ROTATE and _changed and _target_valid():
		var definition := _construction.devices[_target.device_id].definition as DeviceDefinition
		preview = {"mode": "rotation", "kind": String(definition.kind), "position": _origin,
			"angle": _preview_angle, "anchor": _target.anchor_index, "valid": true,
			"radius": definition.half_length if definition.kind == &"bounce_plate" else definition.activation_radius}
	return {"state": _state, "hold_progress": hold_progress(), "hold_position": _origin,
		"cursor_shape": Input.CURSOR_DRAG if _state == Gesture.MOVE else Input.CURSOR_ARROW,
		"radial_open": _state == Gesture.WHEEL, "radial_center": _radial_center,
		"radial_hover": _radial_hover, "pending_diode": false, "preview": preview,
		"dismantle_progress": clampf(_elapsed / _config.dismantle_hold_seconds, 0.0, 1.0) if _state == Gesture.DISMANTLE else 0.0}

# The screen routes only unconsumed world input here. Modal/UI actions share this seam.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and not event.echo:
		if event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
			if event.pressed and _state == Gesture.IDLE:
				_held_keys[event.keycode] = true
			else:
				_held_keys.erase(event.keycode)
			return true
		if event.keycode == KEY_DELETE:
			if event.pressed:
				handle_command(&"debug_damage" if event.shift_pressed else &"dismantle_begin")
			else:
				handle_command(&"dismantle_end")
			return true
		if not event.pressed:
			return false
		match event.keycode:
			KEY_ESCAPE: handle_command(&"escape")
			KEY_R: handle_command(&"release")
			KEY_SPACE: handle_command(&"toggle_auto_fire")
			_: return false
		return true
	if event is InputEventMouseMotion:
		_cursor = event.position
		if _state == Gesture.IDLE:
			return false
		_exceeded_tolerance = _exceeded_tolerance or _cursor.distance_to(_press_screen) > _config.gesture_tolerance
		match _state:
			Gesture.LEFT_PENDING:
				if not _target.is_empty() and _exceeded_tolerance:
					_state = Gesture.MOVE
					_move()
			Gesture.PAN: _camera_controller.pan_by_screen_delta(event.relative)
			Gesture.WHEEL: _update_sector()
			Gesture.MOVE: _move()
			Gesture.ROTATE: _rotate_preview()
		return true
	if event is not InputEventMouseButton:
		return false
	_cursor = event.position
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if _state != Gesture.IDLE:
				cancel()
			else:
				_begin_pointer(true)
		elif _state == Gesture.ROTATE:
			_rotate_preview()
			if _changed and _target_valid() and _preview_angle != _original_angle:
				if _construction.set_anchor_rotation(_target.device_id, _target.anchor_index, _preview_angle):
					_emit_adjustment(&"device_rotated")
			_reset_gesture()
		return true
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _state != Gesture.IDLE:
				cancel()
			else:
				_begin_pointer(false)
		else:
			_finish_left()
		return true
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed and _state == Gesture.IDLE:
			_state = Gesture.PAN
		elif not event.pressed and _state == Gesture.PAN:
			_reset_gesture()
		return true
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and _state == Gesture.IDLE:
			_camera_controller.zoom_by_steps(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		return true
	return false

func handle_command(command: StringName) -> void:
	match command:
		&"dismantle_begin":
			cancel()
			if _construction.devices.has(_construction.selected_device_id):
				_target = {"device_id": _construction.selected_device_id, "anchor_index": _construction.selected_anchor}
				_state = Gesture.DISMANTLE
		&"dismantle_end":
			if _state == Gesture.DISMANTLE: cancel()
		&"release":
			if _state == Gesture.IDLE and not _construction.release_selected():
				message.emit("蓄积器尚未激活或没有存量")
		&"debug_damage":
			if OS.is_debug_build():
				cancel()
				if _construction.damage_selected(_config.damage_debug_amount):
					lighting_changed.emit()
		&"escape":
			if not cancel(): command_requested.emit(&"pause")
		&"pause", &"toggle_auto_fire":
			cancel()
			command_requested.emit(command)

func _begin_pointer(rotation: bool) -> void:
	_press_screen = _cursor
	_elapsed = 0.0
	_exceeded_tolerance = false
	_origin = _screen_to_world(_cursor)
	var picked := _construction.pick(_origin, _config.device_pick_radius)
	if int(picked.id) > 0:
		_construction.selected_device_id = int(picked.id)
		_construction.selected_anchor = int(picked.anchor)
		_target = {"device_id": int(picked.id), "anchor_index": int(picked.anchor)}
		var point := _construction.get_device_position(_target.device_id, _target.anchor_index)
		_grab_offset = point - _origin
		_origin = point
		_state = Gesture.ROTATE if rotation else Gesture.LEFT_PENDING
		var key := "secondary_angle_radians" if _target.anchor_index == 1 else "angle_radians"
		_original_angle = float(_construction.devices[_target.device_id][key])
		_preview_angle = _original_angle
	elif not rotation:
		_construction.selected_device_id = 0
		_construction.selected_anchor = 0
		if _legal_initial(_origin):
			_state = Gesture.LEFT_PENDING
		else:
			_invalid_placement()

func _finish_left() -> void:
	if _state == Gesture.MOVE:
		# Release can carry a newer position than the last motion. Only a live
		# drag owns that final displacement; cancelled gestures remain idle.
		_move()
	elif _state == Gesture.WHEEL:
		var draft := _placement_preview()
		if not draft.is_empty():
			if draft.valid:
				var definition := _catalog.definitions[_radial_hover]
				var id := _construction.place(definition, draft.position, 0.0, draft.secondary_position, 0.0)
				if id > 0: lighting_changed.emit()
			else:
				_invalid_placement()
		else:
			semantic_event.emit({"type": "interaction_cancelled"})
	elif _state == Gesture.LEFT_PENDING and not _target.is_empty():
		var clicked := _construction.pick(_screen_to_world(_cursor), _config.device_pick_radius)
		if _elapsed < _config.click_max_seconds and not _exceeded_tolerance and _cursor.distance_to(_press_screen) <= _config.gesture_tolerance \
				and _target_valid() and int(clicked.id) == int(_target.device_id) and int(clicked.anchor) == int(_target.anchor_index):
			var definition := _construction.devices[_target.device_id].definition as DeviceDefinition
			if definition.kind == &"accumulator" and not _construction.release_selected():
				message.emit("蓄积器尚未激活或没有存量")
	if _state in [Gesture.LEFT_PENDING, Gesture.WHEEL, Gesture.MOVE]:
		_finish_move()
		_reset_gesture()

func _move() -> void:
	if not _target_valid():
		cancel()
		return
	var position := _screen_to_world(_cursor) + _grab_offset
	position = position.clamp(_map_rect.position + Vector2.ONE * _map_margin, _map_rect.end - Vector2.ONE * _map_margin)
	var previous := _construction.get_device_position(_target.device_id, _target.anchor_index)
	if position != previous and _construction.move_selected(position):
		_changed = true
		if bool(_construction.devices[_target.device_id].active):
			lighting_changed.emit()

func _rotate_preview() -> void:
	if not _target_valid():
		cancel()
		return
	if not _exceeded_tolerance:
		return
	var pivot_screen: Vector2 = _viewport.get_canvas_transform() * _origin
	if _cursor.distance_to(pivot_screen) < _config.rotation_center_dead_zone:
		return
	var direction := _screen_to_world(_cursor) - _origin
	var definition := _construction.devices[_target.device_id].definition as DeviceDefinition
	_preview_angle = wrapf(direction.angle() - (PI * 0.5 if definition.kind == &"bounce_plate" else 0.0), -PI, PI)
	_changed = true

func _open_wheel() -> void:
	_state = Gesture.WHEEL
	var viewport_size := _viewport.get_visible_rect().size
	var margin := _config.radial_radius + _config.radial_screen_margin
	_radial_center = Vector2(clampf(_press_screen.x, margin, viewport_size.x - margin),
		clampf(_press_screen.y, margin + _config.radial_top_clearance, viewport_size.y - margin - _config.radial_bottom_clearance))
	_radial_hover = -1

func _update_sector() -> void:
	var offset := _cursor - _radial_center
	if offset.length() < _config.radial_dead_zone:
		_radial_hover = -1
		return
	var sector_size := TAU / float(_catalog.definitions.size())
	_radial_hover = int(floor(fposmod(offset.angle() + PI * 0.5 + sector_size * 0.5, TAU) / sector_size)) % _catalog.definitions.size()

func _placement_preview() -> Dictionary:
	if _radial_hover < 0: return {}
	var definition := _catalog.definitions[_radial_hover]
	var secondary := _origin + Vector2.RIGHT * _config.diode_initial_offset if definition.kind == &"diode" else _origin
	return {"mode": "placement", "kind": String(definition.kind), "position": _origin,
		"secondary_position": secondary, "angle": 0.0, "anchor": 0,
		"radius": definition.half_length if definition.kind == &"bounce_plate" else definition.activation_radius,
		"valid": _legal_initial(_origin) and _legal_initial(secondary)}

func _legal_initial(position: Vector2) -> bool:
	return _map_rect.grow(-_map_margin).has_point(position) and _fog.is_lit(position)

func _invalid_placement() -> void:
	semantic_event.emit({"type": "invalid_placement"})
	message.emit("全部端点必须位于地图内的当前亮区；未放置任何装置")

func _target_valid() -> bool:
	return _construction.devices.has(_target.device_id) and _construction.selected_device_id == int(_target.device_id) \
		and _construction.selected_anchor == int(_target.anchor_index)

func _emit_adjustment(type: StringName) -> void:
	var event := _target.duplicate()
	event["type"] = type
	semantic_event.emit(event)

func _finish_move() -> void:
	if _state == Gesture.MOVE and _changed:
		_emit_adjustment(&"device_moved")

func _reset_gesture() -> void:
	_state = Gesture.IDLE
	_target.clear()
	_elapsed = 0.0
	_changed = false
	_exceeded_tolerance = false
	_radial_hover = -1

func has_cancelable_interaction() -> bool:
	return _state != Gesture.IDLE

func has_pointer_capture() -> bool:
	return _state not in [Gesture.IDLE, Gesture.DISMANTLE]

func cancel() -> bool:
	var had_interaction := has_cancelable_interaction()
	if had_interaction:
		_finish_move()
		semantic_event.emit({"type": "interaction_cancelled"})
	_reset_gesture()
	_held_keys.clear()
	return had_interaction

func cancel_transient_interaction() -> bool:
	return cancel()

func hold_progress() -> float:
	if _state != Gesture.LEFT_PENDING or not _target.is_empty(): return 0.0
	return clampf(_elapsed / _config.radial_hold_seconds, 0.0, 1.0)

func _screen_to_world(position: Vector2) -> Vector2:
	return _viewport.get_canvas_transform().affine_inverse() * position
