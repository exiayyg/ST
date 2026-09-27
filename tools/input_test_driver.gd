extends RefCounted
# Shared test driver crosses the same input seam as WorldScreen.
static func mouse(input: ConstructionInputController, position: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = pressed
	input.handle_input(event)

static func motion(input: ConstructionInputController, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	input.handle_input(event)

static func wheel(input: ConstructionInputController, viewport: Viewport, profile: BalanceProfile, point: Vector2, catalog: DeviceCatalog, kind: StringName) -> void:
	mouse(input, viewport.get_canvas_transform() * point, true)
	input.advance(profile.runtime_config().construction_ux.radial_hold_seconds)
	var index := 0
	for definition in catalog.definitions:
		if definition.kind == kind: break
		index += 1
	var angle := -PI * 0.5 + TAU * float(index) / float(catalog.definitions.size())
	var position: Vector2 = input.snapshot().radial_center + Vector2.from_angle(angle) * profile.runtime_config().construction_ux.radial_radius
	motion(input, position)
	mouse(input, position, false)

static func legacy_input(data: Dictionary) -> void:
	for key in ["move_hold_seconds", "click_max_seconds", "gesture_tolerance", "rotation_center_dead_zone", "diode_initial_offset", "preview_alpha", "preview_line_width", "preview_direction_length", "preview_font_size", "action_button_width", "action_button_height", "action_inset"]:
		data.construction_ux.erase(key)
	data.construction_ux["rotation_step_degrees"] = 15.0
	if data.has("playtest"): data.playtest["rotation_group_seconds"] = 0.5
