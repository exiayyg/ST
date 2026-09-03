extends SceneTree

const ENDLESS_SCENE := preload("res://scenes/combat/endless_sandbox.tscn")

var _failed := false


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	var combat := ENDLESS_SCENE.instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	combat.set("_auto_fire", false)
	combat.set("_radial_hold_seconds", 0.0)
	var viewport_size := root.get_visible_rect().size
	var press_position := viewport_size * 0.5 + Vector2(140.0, 120.0)
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.position = press_position
	press_event.global_position = press_position
	press_event.pressed = true
	root.push_input(press_event, true)
	await process_frame
	var construction_hud := combat.get("_hud") as PrototypeHud
	_check(bool(combat.get("_radial_open")),
		"a long press on lit empty ground must open the radial state in the endless scene")
	_check(construction_hud != null and construction_hud.visible and construction_hud.radial_open,
		"the endless scene must visibly render the construction radial wheel")
	var release_event := press_event.duplicate() as InputEventMouseButton
	release_event.pressed = false
	root.push_input(release_event, true)
	await process_frame
	combat.set_process(false)
	var combat_hud := combat.get("_combat_hud") as CombatHud
	combat_hud.warnings = {"east": {"types": {"dev_melee": 2}, "pressure": 2.0}}
	var warning_rect: Rect2 = combat_hud.call("_warning_rect", "east")
	_check(not bool(combat_hud.call("_has_point", press_position))
			and bool(combat_hud.call("_has_point", warning_rect.get_center())),
		"the combat HUD must only capture its interactive warning region during play")
	var warning_press := InputEventMouseButton.new()
	warning_press.button_index = MOUSE_BUTTON_LEFT
	warning_press.position = warning_rect.get_center()
	warning_press.global_position = warning_press.position
	warning_press.pressed = true
	root.push_input(warning_press, true)
	await process_frame
	_check(combat_hud.selected_direction == "east" and not bool(combat.get("_left_press_active")),
		"narrowing the combat HUD hit area must preserve warning clicks without starting construction")

	var configured_mode := int(ProjectSettings.get_setting("display/window/size/mode", -1))
	_check(configured_mode == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"the project must launch in fullscreen mode by default")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) >= 1920
			and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) >= 1080,
		"the default logical viewport must be at least 1920x1080")
	_check(int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)) <= 0
			and int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)) <= 0,
		"low-resolution desktop window overrides must not force a 1152x648 launch")

	if not _failed:
		print("Runtime UX regressions passed: radial input, warning hit regions and native fullscreen defaults")
	quit(1 if _failed else 0)
