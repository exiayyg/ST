extends "res://tools/playthrough_v041.gd"
## Real engine-input acceptance. Fixed reference actions, no target tracking,
## no HP/ledger/state/config writes. Progress is isolated by the runner.

var report: Dictionary = {"events": [], "samples": [], "adjustments": [], "captures": []}
var _run_time := 0.0
var _wave_two_time := -1.0
var _wave_one_first_hit := -1.0
var _wave_one_last_hit := -1.0
var _last_sample := -1
var _first_hit_captured := false
var _hit_flash_captured := false
var _reminder_captured := false
var _connection_captured := false
var _visible_hit_captured := false

func _run() -> void:
	started = Time.get_ticks_msec()
	var campaign := root.get_node("_campaign_service") as CampaignService
	campaign.configure_for_tests(load("res://resources/levels/campaign_catalog.tres"), "user://playthrough_v05.json")
	change_scene_to_file("res://scenes/frontend/main_menu.tscn")
	await _frames(4)
	if "--playtest" in OS.get_cmdline_user_args():
		await _activate("首关试玩")
		await _capture_v05("consent-unchecked")
		var consent := current_scene.find_child("RecordConsent", true, false) as CheckBox
		if consent == null or consent.button_pressed:
			push_error("Consent must initially be unchecked")
			quit(1)
			return
		# Real button activation, not a context/consent flag write.
		var dialog := current_scene.find_child("PlaytestConsent", true, false) as ConfirmationDialog
		await _click_control(consent)
		if not consent.button_pressed:
			push_error("Mouse did not enable consent")
			quit(1)
			return
		await _click_control(dialog.get_ok_button())
	else:
		await _activate("关卡模式")
		await _activate("第一关：改写路径")
	await _frames(6)
	world = current_scene
	profile = world.runtime.profile
	level = profile.value("levels/diode_tutorial")
	report["balance_sha256"] = FileAccess.get_sha256("res://config/balance/balance.json")
	report["tower"] = profile.section("tower")
	world.runtime.gameplay_event.connect(_record_event)
	process_frame.connect(_record_frame)
	await create_timer(float(level.observation_seconds) + 0.2).timeout
	await _diode(Vector2(level.practice_entry_x, level.practice_entry_y), Vector2(level.practice_exit_x, level.practice_exit_y))
	await _click(Vector2(level.practice_exit_x, level.practice_exit_y))
	await _hold_action("按住拆除", float(profile.value("construction_ux/dismantle_hold_seconds")) + 0.1)
	await _diode(Vector2(level.route_entry_x, level.route_entry_y), Vector2(level.route_exit_x, level.route_exit_y))
	await _click(Vector2(level.route_exit_x, level.route_exit_y))
	await _rotate(Vector2(level.route_exit_x, level.route_exit_y), deg_to_rad(float(level.route_exit_angle_degrees)))
	await _capture_v05("north-route-placement")
	var phase := ""
	while _run_time < 240.0:
		var lesson := world.runtime.session as DiodeTutorialSession
		var snapshot := lesson.hud_snapshot(world.runtime.simulation.native.get_stats())
		var next := "%s/%s/%s" % [snapshot.tutorial_phase, snapshot.wave_index, snapshot.phase]
		if next != phase:
			phase = next
			_log("PHASE " + phase)
			await _capture_v05("phase-" + phase.replace("/", "-"))
		if lesson.current_wave_index == 1 and _wave_two_time < 0.0:
			_wave_two_time = _run_time
		if _wave_one_first_hit >= 0.0 and not _first_hit_captured:
			_first_hit_captured = true
			await _capture_v05("first-hit-feedback")
		if snapshot.instruction_key == &"route_connected" and not _connection_captured:
			_connection_captured = true
			await _capture_v05("route-connected")
		if _wave_two_time >= 0.0 and _run_time - _wave_two_time >= 24.0 and report.adjustments.is_empty():
			# Fixed reference correction; never follows enemy IDs or positions.
			await _pan_up()
			var destination := Vector2(180, -340) if "--feedback-probe" in OS.get_cmdline_user_args() else Vector2(80, -340)
			await _drag(Vector2(0, -180), destination)
			report.adjustments.append({"time": _run_time, "kind": "drag", "to": destination})
			await _capture_v05("second-wave-redirect")
		for device: Dictionary in world.runtime.construction.devices.values():
			if float(device.hp) < float(device.max_hp) and not _hit_flash_captured:
				_hit_flash_captured = true
				await _capture_v05("dual-anchor-damage")
		if snapshot.instruction_key == &"check_route_damage" and not _reminder_captured:
			_reminder_captured = true
			await _capture_v05("no-damage-feedback")
			if "--feedback-probe" in OS.get_cmdline_user_args():
				await _drag(Vector2(180, -340), Vector2(80, -340))
				report.adjustments.append({"time": _run_time, "kind": "drag", "to": Vector2(80, -340)})
		if lesson.is_terminal():
			report["completion"] = lesson.completion_snapshot()
			report["diagnostics"] = lesson.diagnostic_snapshot()
			report["wave_one_unedited_damage_window"] = _wave_one_last_hit - _wave_one_first_hit
			report["autofire_always_on"] = not report.get("autofire_violation", false)
			process_frame.disconnect(_record_frame)
			if "--playtest" in OS.get_cmdline_user_args():
				await _frames(3)
				await _capture_v05("report-actions")
				await _activate("填写试玩意见")
				await _capture_v05("optional-feedback")
				for dialog in get_nodes_in_group("screen_modal_dialog"):
					if dialog is ConfirmationDialog and dialog.visible:
						await _click_control(dialog.get_cancel_button())
			await _activate("返回主菜单" if "--playtest" in OS.get_cmdline_user_args() else "返回关卡选择")
			await _frames(6)
			report["returned_to_frontend"] = current_scene.scene_file_path == "res://scenes/frontend/main_menu.tscn"
			report["progress"] = campaign.levels_snapshot()
			if "--playtest" in OS.get_cmdline_user_args():
				var directories := DirAccess.get_directories_at("user://playtests")
				var valid_recording := false
				if directories.size() == 1:
					var summary = JSON.parse_string(FileAccess.get_file_as_string("user://playtests".path_join(directories[0]).path_join("summary.json")))
					valid_recording = summary is Dictionary and summary.finished and summary.completion.result == "success"
					report["playtest_summary"] = summary
				report["saved_progress_valid"] = not FileAccess.file_exists("user://playthrough_v05.json") and valid_recording
			else:
				var saved = JSON.parse_string(FileAccess.get_file_as_string("user://playthrough_v05.json"))
				report["saved_progress_valid"] = saved is Dictionary and saved.get("levels", {}).get("diode_tutorial", {}).get("completed", false)
			await _capture_v05("saved-result-return")
			var success: bool = report.completion.result == &"success" and report.returned_to_frontend and report.saved_progress_valid and report.autofire_always_on and report.wave_one_unedited_damage_window >= 10.0 and report.adjustments.size() <= 3
			_write_report()
			print("V05_INPUT_ACCEPTANCE ", success, " ", JSON.stringify(report.completion), " unedited_damage_window=", report.wave_one_unedited_damage_window)
			quit(0 if success else 1)
			return
		await create_timer(0.1).timeout
	report["blocked"] = "240 seconds; no synthetic victory"
	_write_report()
	quit(2)

func _record_frame() -> void:
	if not is_instance_valid(world) or world.runtime == null:
		return
	var lesson := world.runtime.session as DiodeTutorialSession
	_run_time = float(lesson.diagnostic_snapshot().elapsed)
	if not lesson.is_terminal() and not world.runtime.auto_fire:
		report["autofire_violation"] = true
	if int(_run_time) == _last_sample:
		return
	_last_sample = int(_run_time)
	report.samples.append({"time": _run_time, "tower_hp": world.runtime.tower.hp, "session": lesson.hud_snapshot(world.runtime.simulation.native.get_stats()), "devices": world.runtime.construction.view_records()})

func _record_event(event: Dictionary) -> void:
	var kind := String(event.type)
	# Capture after the reference camera pan: early hits can be behind the HUD.
	if kind == "enemy_hit" and float(event.get("damage", 0.0)) > 0.0 and bool(event.get("player_visible", false)) and not _visible_hit_captured and not report.adjustments.is_empty():
		_visible_hit_captured = true
		_capture_visible_hit.call_deferred()
	if kind in ["device_placed", "device_dismantled", "device_destroyed", "device_activated", "enemy_hit", "enemy_depleted"]:
		var record := event.duplicate(true)
		record["time"] = _run_time
		report.events.append(record)
	if kind == "enemy_hit" and float(event.get("damage", 0.0)) > 0.0 and world.runtime.session.current_wave_index == 0:
		if _wave_one_first_hit < 0.0: _wave_one_first_hit = _run_time
		_wave_one_last_hit = _run_time

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

func _pan_up() -> void:
	var button := InputEventMouseButton.new()
	button.position = root.get_visible_rect().get_center()
	button.button_index = MOUSE_BUTTON_MIDDLE
	button.pressed = true
	root.push_input(button, true)
	var motion := InputEventMouseMotion.new()
	motion.position = button.position + Vector2(0, 260)
	motion.relative = Vector2(0, 260)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(motion, true)
	await _frames(2)
	button.pressed = false
	root.push_input(button, true)
	await _frames(2)

func _capture_v05(label: String) -> void:
	await _capture(("v051-" if "--playtest" in OS.get_cmdline_user_args() else "v05-probe-" if "--feedback-probe" in OS.get_cmdline_user_args() else "v05-") + label)
	report.captures.append(label)

func _write_report() -> void:
	var path := "res://artifacts/v051-input-report.json" if "--playtest" in OS.get_cmdline_user_args() else "res://artifacts/v05-feedback-report.json" if "--feedback-probe" in OS.get_cmdline_user_args() else "res://artifacts/v05-input-report.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true))
	file.close()

func _window_tap(window: Window, key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		if is_instance_valid(window) and window.is_inside_tree():
			window.push_input(event)
		else:
			root.push_input(event)
		await _frames(1)

func _capture_visible_hit() -> void:
	await _capture_v05("visible-hit-flash")
	if "--capture-visible-hit-only" in OS.get_cmdline_user_args():
		print("V051_VISIBLE_HIT_CAPTURE passed; observation only, not a victory claim")
		quit()
