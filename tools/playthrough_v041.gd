extends SceneTree
## Engine-input playthrough: no HP, stage, ledger or balance mutation.
## Run in an isolated project; progress uses a separate test file.

var started := 0
var world: Node
var level: Dictionary
var profile: BalanceProfile
var _expected_exit := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	started = Time.get_ticks_msec()
	if "--exit-main" in OS.get_cmdline_user_args() or "--exit-paused" in OS.get_cmdline_user_args():
		await _test_exit()
		return
	var campaign := root.get_node("_campaign_service") as CampaignService
	campaign.configure_for_tests(load("res://resources/levels/campaign_catalog.tres"), "user://playthrough_v041.json")
	change_scene_to_file("res://scenes/frontend/main_menu.tscn")
	await _frames(4)
	await _activate("关卡模式")
	await _activate("第一关：改写路径")
	await _frames(6)
	world = current_scene
	profile = world.get("_profile")
	level = profile.value("levels/diode_tutorial")
	_log("entered tutorial from main menu")
	await create_timer(float(level.observation_seconds) + 0.2).timeout
	await _diode(Vector2(level.practice_entry_x, level.practice_entry_y), Vector2(level.practice_exit_x, level.practice_exit_y))
	_log("practice placed: " + str(world.runtime.session.state))
	await _click(Vector2(level.practice_exit_x, level.practice_exit_y))
	await _hold_action("按住拆除", float(profile.value("construction_ux/dismantle_hold_seconds")) + 0.1)
	_log("practice dismantled: " + str(world.runtime.session.state))
	await _diode(Vector2(level.route_entry_x, level.route_entry_y), Vector2(level.route_exit_x, level.route_exit_y))
	await _click(Vector2(level.route_exit_x, level.route_exit_y))
	await _rotate(Vector2(level.route_exit_x, level.route_exit_y), deg_to_rad(float(level.route_exit_angle_degrees)))
	_log("north route built using only mouse")
	var previous_phase := ""
	while float(Time.get_ticks_msec() - started) / 1000.0 < 300.0:
		var session = world.runtime.session
		var stats: Dictionary = world.runtime.simulation.native.get_stats()
		var snapshot: Dictionary = session.hud_snapshot(stats)
		var phase := "%s/%s/%s" % [snapshot.tutorial_phase, snapshot.wave_index, snapshot.phase]
		if phase != previous_phase:
			_log("phase " + phase + " utilization=" + str(stats.get("utilization", 0.0)))
			previous_phase = phase
			await _capture("v041-playthrough-" + str(session.state))
		if session.is_terminal():
			_log("RESULT " + JSON.stringify(session.completion_snapshot()))
			world.get("_combat_hud").return_requested.connect(func(): _log("return requested"))
			world.get("_combat_hud").restart_requested.connect(func(): _log("restart requested"))
			world.get("_combat_hud")._return_button.grab_focus()
			_log("focused " + str(root.gui_get_focus_owner()))
			await _tap(KEY_ENTER)
			await _frames(5)
			_log("returned to " + current_scene.scene_file_path)
			if current_scene.scene_file_path != "res://scenes/frontend/main_menu.tscn":
				push_error("Settlement return failed to reach frontend")
				quit(6)
				return
			await _capture("v041-playthrough-return")
			quit(0)
			return
		await create_timer(0.5).timeout
	_log("PLAYTHROUGH BLOCKED after 300 seconds; no synthetic victory")
	quit(2)


func _activate(fragment: String) -> void:
	for button in current_scene.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.contains(fragment):
			await _click_control(button)
			return
	push_error("Visible action not found: " + fragment)
	quit(3)


func _diode(entry: Vector2, outlet: Vector2) -> void:
	await _mouse(entry, true)
	await create_timer(float(profile.value("construction_ux/radial_hold_seconds")) + 0.2).timeout
	var index := 0
	for definition in world.runtime.catalog.definitions:
		if definition.kind == &"diode":
			break
		index += 1
	var count: int = world.runtime.catalog.definitions.size()
	var angle := -PI * 0.5 + TAU * float(index) / float(count)
	var motion := InputEventMouseMotion.new()
	motion.position = world.runtime.input.snapshot().radial_center + Vector2.from_angle(angle) * float(profile.value("construction_ux/radial_radius")) * 0.75
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await _frames(1)
	await _mouse(entry, false)
	await _drag(entry + Vector2.RIGHT * profile.runtime_config().construction_ux.diode_initial_offset, outlet)


func _click(position: Vector2) -> void:
	await _mouse(position, true)
	await _mouse(position, false)


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = root.get_canvas_transform() * position
	root.push_input(event, true)
	await _frames(1)


func _tap(code: Key) -> void:
	await _key(code, true)
	await _key(code, false)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event)
	await _frames(1)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")


func _log(message: String) -> void:
	print("PLAY %.2fs %s" % [float(Time.get_ticks_msec() - started) / 1000.0, message])


func _test_exit() -> void:
	if "--exit-main" in OS.get_cmdline_user_args():
		change_scene_to_file("res://scenes/frontend/main_menu.tscn")
		await _frames(5)
		_expected_exit = true
		await _activate("退出游戏")
	else:
		change_scene_to_file("res://scenes/prototype/momentum_prototype.tscn")
		await _frames(5)
		await _tap(KEY_ESCAPE)
		await _activate("退出游戏")
		var menu = current_scene.get("_runtime_menu")
		if not menu.confirmation.visible or not menu.confirmation.get_cancel_button().has_focus():
			push_error("Quit must confirm with cancel focused")
			quit(4)
			return
		menu.confirmation.get_ok_button().grab_focus()
		_expected_exit = true
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		menu.confirmation.push_input(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		menu.confirmation.push_input(event)
	await create_timer(1.0).timeout
	_expected_exit = false
	push_error("Exit action did not terminate the process")
	quit(5)


func _finalize() -> void:
	if _expected_exit:
		print("V041_EXIT_CONFIRMED")

func _click_control(control: Control) -> void:
	var viewport: Viewport = control.get_viewport()
	var target := control.get_global_rect().get_center()
	if viewport is Window and viewport != root and viewport.is_embedded():
		target += Vector2(viewport.position)
		viewport = root
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = target
		viewport.push_input(event, true)
		await _frames(1)

func _hold_action(fragment: String, seconds: float) -> void:
	for button in current_scene.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.contains(fragment):
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.position = button.get_global_rect().get_center()
			root.push_input(event, true)
			await create_timer(seconds).timeout
			event.pressed = false
			root.push_input(event, true)
			await _frames(2)
			return
	push_error("Hold action missing: " + fragment)

func _rotate(pivot: Vector2, angle: float) -> void:
	var start: Vector2 = root.get_canvas_transform() * pivot
	var finish: Vector2 = root.get_canvas_transform() * (pivot + Vector2.from_angle(angle) * 180.0)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = start
	root.push_input(event, true)
	await _frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion, true)
	await _frames(2)
	event.pressed = false
	event.position = finish
	root.push_input(event, true)
	await _frames(2)

func _drag(from: Vector2, to: Vector2) -> void:
	await _mouse(from, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * to
	motion.relative = root.get_canvas_transform().basis_xform(to - from)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await _frames(2)
	await _mouse(to, false)
