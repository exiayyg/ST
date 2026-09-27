extends "res://tools/test_v051_ui.gd"

func _run() -> void:
	started = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/frontend/main_menu.tscn")
	await _frames(8)
	await _capture("v06-main-menu")
	await _activate("视听设置")
	var settings := _find_settings(current_scene)
	require(settings != null and settings.visible, "settings opens")
	await _capture("v06-settings")
	var checkbox: CheckBox
	for node in settings.find_children("*", "CheckBox", true, false):
		if node.text == "减少动态效果": checkbox = node
	checkbox.grab_focus()
	await _window_tap(settings, KEY_SPACE)
	require(current_scene.presentation.preferences.reduced_motion, "real input changes reduced motion")
	var time: float = current_scene.presentation.decoration_time
	await create_timer(0.15).timeout
	require(current_scene.presentation.decoration_time == time, "reduced motion clock stops")
	await _window_tap(settings, KEY_F2)
	require(not current_scene.modal.tuning.is_open(), "settings blocks F2")
	await _window_tap(settings, KEY_ESCAPE)
	require(not settings.visible, "Esc dismisses settings")
	var initial_mode := root.mode
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.mode = Window.MODE_WINDOWED
		root.size = resolution
		await _frames(8)
		await _capture("v06-menu-%s" % resolution.x)
		await _activate("视听设置")
		await _capture("v06-settings-%s" % resolution.x)
		require(settings.visible, "resized settings visible")
		await _window_tap(settings, KEY_ESCAPE)
	root.mode = initial_mode
	await _frames(8)
	await _activate("首关试玩")
	var consent := current_scene.find_child("PlaytestConsent", true, false) as ConfirmationDialog
	consent.get_ok_button().grab_focus()
	await _window_tap(consent, KEY_ENTER)
	await _frames(8)
	world = current_scene
	profile = world.runtime.profile
	require(world.presentation.preferences.reduced_motion, "preference persists scene change")
	await _tap(KEY_ESCAPE)
	await _activate("视听设置")
	settings = _find_settings(world)
	require(settings != null and settings.visible and paused, "pause settings opens with world paused")
	var tick: int = world.runtime.simulation.native.get_stats().tick
	await create_timer(0.15).timeout
	require(world.runtime.simulation.native.get_stats().tick == tick, "settings freezes world")
	await _capture("v06-pause-settings")
	await _window_tap(settings, KEY_ESCAPE)
	require(paused, "closing settings preserves prior pause")
	await _capture("v06-pause")
	await _tap(KEY_ESCAPE)
	require(not paused, "pause closes")
	await _tap(KEY_F2)
	await _capture("v06-tuning")
	await _tap(KEY_F2)
	var location := Vector2(100, 120)
	await _mouse(location, true)
	await create_timer(float(profile.value("construction_ux/radial_hold_seconds")) * 0.5).timeout
	await _capture("v06-hold")
	await create_timer(float(profile.value("construction_ux/radial_hold_seconds"))).timeout
	await _capture("v06-radial")
	await _mouse(location, false)
	await _tap(KEY_ESCAPE)
	await _capture("v06-first-level")
	print("V06_UI passed=", not ui_failed, " real settings, persistence, modal priority, pause, radial")
	quit(1 if ui_failed else 0)

func _find_settings(node: Node) -> PresentationSettings:
	for child in node.get_children():
		if child is PresentationSettings: return child
		var nested := _find_settings(child)
		if nested != null: return nested
	return null
