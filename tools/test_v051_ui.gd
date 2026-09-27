extends "res://tools/playthrough_v05.gd"
## Real UI smoke test in an isolated user directory. No native/state/HP writes.

var ui_failed := false

func require(condition: bool, label: String) -> void:
	if not condition:
		ui_failed = true
		push_error(label)

func _run() -> void:
	started = Time.get_ticks_msec()
	var campaign := root.get_node("_campaign_service") as CampaignService
	campaign.configure_for_tests(load("res://resources/levels/campaign_catalog.tres"), "user://ui_progress.json")
	change_scene_to_file("res://scenes/frontend/main_menu.tscn")
	await _frames(5)
	await _activate("首关试玩")
	var dialog := current_scene.find_child("PlaytestConsent", true, false) as ConfirmationDialog
	var consent := current_scene.find_child("RecordConsent", true, false) as CheckBox
	require(not consent.button_pressed and dialog.get_cancel_button().has_focus(), "unchecked consent and cancel focus")
	await _window_tap(dialog, KEY_F2)
	require(not current_scene.modal.tuning.is_open(), "F2 cannot open through consent")
	consent.grab_focus()
	await _window_tap(dialog, KEY_SPACE)
	require(consent.button_pressed, "real keyboard toggles consent")
	dialog.get_cancel_button().grab_focus()
	await _window_tap(dialog, KEY_ENTER)
	await _activate("首关试玩")
	require(not consent.button_pressed, "cancelled authorization does not carry into next launch")
	dialog.get_ok_button().grab_focus()
	await _window_tap(dialog, KEY_ENTER)
	await _frames(5)
	world = current_scene
	profile = world.runtime.profile
	level = profile.value("levels/diode_tutorial")
	require(campaign.current_launch_snapshot().kind == &"playtest" and not campaign.current_launch_snapshot().record_enabled, "unrecorded playtest launch")
	var location := Vector2(100, 120)
	await _mouse(location, true)
	await create_timer(float(profile.value("construction_ux/radial_hold_seconds")) * 0.4).timeout
	require(world.runtime.input.hold_progress() > 0.0 and not world.runtime.input.snapshot().radial_open, "legal hold ring precedes radial menu")
	await _capture("v051-hold-progress")
	await _mouse(location, false)
	require(world.runtime.input.hold_progress() == 0.0, "short release removes hold feedback")
	await _mouse(location, true)
	await _tap(KEY_F2)
	require(paused and world.runtime.input.hold_progress() == 0.0, "F2 cancels long hold and pauses")
	var before: Dictionary = world.runtime.simulation.native.get_stats()
	var elapsed_before: float = world.runtime.session.diagnostic_snapshot().elapsed
	await create_timer(0.3).timeout
	require(world.runtime.simulation.native.get_stats().tick == before.tick and world.runtime.session.diagnostic_snapshot().elapsed == elapsed_before, "F2 freezes native and tutorial time")
	await _tap(KEY_F2)
	await _mouse(location, false)
	require(not paused, "F2 restores playing state")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_F2)
	await _tap(KEY_F2)
	require(paused and world.modal.menu.menu.is_open(), "F2 opened from pause returns to pause")
	await _tap(KEY_ESCAPE)
	require(not paused, "Esc resumes pause")
	await _diode(Vector2(level.practice_entry_x, level.practice_entry_y), Vector2(level.practice_exit_x, level.practice_exit_y))
	await _click(Vector2(level.practice_exit_x, level.practice_exit_y))
	await _capture("v051-selected-exit")
	await _click(Vector2(level.practice_entry_x, level.practice_entry_y))
	await _capture("v051-selected-entry")
	await _tap(KEY_ESCAPE)
	await _activate("重新开始")
	var confirmation: ConfirmationDialog = world.modal.menu.confirmation
	require(confirmation.visible and confirmation.get_cancel_button().has_focus(), "retry warns and defaults to cancel")
	confirmation.get_cancel_button().grab_focus()
	await _window_tap(confirmation, KEY_ENTER)
	await _activate("返回主菜单")
	confirmation.get_ok_button().grab_focus()
	await _window_tap(confirmation, KEY_ENTER)
	await _frames(5)
	require(current_scene is FrontendController and campaign.current_launch_snapshot().is_empty(), "return clears playtest authorization")
	require(not DirAccess.dir_exists_absolute("user://playtests") and not FileAccess.file_exists("user://ui_progress.json"), "unconsented input run writes neither reports nor progress")
	print("V051_REAL_UI ", "FAILED" if ui_failed else "passed")
	quit(1 if ui_failed else 0)
