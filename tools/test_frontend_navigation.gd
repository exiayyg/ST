extends Node

const LevelCatalogType := preload("res://scripts/campaign/level_catalog.gd")
const CampaignServiceType := preload("res://scripts/campaign/campaign_service.gd")
const CombatSessionDirectorType := preload("res://scripts/combat/combat_session_director.gd")
const FrontendControllerType := preload("res://scripts/frontend/frontend_controller.gd")

const TEST_PROGRESS_PATH := "user://frontend_navigation_v04_test.json"

class CompletionFixture extends CombatSessionDirector:
	var utilization := 0.0

	func completion_snapshot() -> Dictionary:
		return {
			"result": &"success",
			"utilization": utilization,
			"completed_waves": 2,
			"reason": &"success",
		}


var _failed := false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	_cleanup_progress()
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/frontend/main_menu.tscn",
		"the player-facing frontend must be the default scene")
	_check(FrontendControllerType.should_show_development_entries(true)
			and not FrontendControllerType.should_show_development_entries(false),
		"development entries must follow the build feature rather than campaign content")
	var service := get_tree().root.get_node_or_null("_campaign_service") as CampaignService
	var catalog = load("res://resources/levels/campaign_catalog.tres") as LevelCatalog
	_check(service != null and catalog != null, "frontend requires the campaign autoload and catalog")
	if service == null or catalog == null:
		get_tree().quit(1)
		return
	service.configure_for_tests(catalog, TEST_PROGRESS_PATH, func(_path: String): return OK)

	var frontend := (load("res://scenes/frontend/main_menu.tscn") as PackedScene).instantiate() as FrontendController
	add_child(frontend)
	await get_tree().process_frame
	var main_view := frontend.get_node("OuterMargin/CenterContainer/FrontEndContent/MainModeView") as VBoxContainer
	var level_view := frontend.get_node("OuterMargin/CenterContainer/FrontEndContent/LevelSelectView") as VBoxContainer
	_check(main_view.visible and not level_view.visible, "frontend must open on mode selection")
	var frontend_overlay = frontend.get("_balance_overlay") as BalanceRuntimeOverlay
	frontend_overlay.toggle_panel()
	_check(frontend_overlay.is_open(), "F2 balance controls must remain available on the new frontend")
	var frontend_escape := InputEventKey.new()
	frontend_escape.keycode = KEY_ESCAPE
	frontend_escape.pressed = true
	frontend._unhandled_input(frontend_escape)
	_check(not frontend_overlay.is_open() and main_view.visible,
		"frontend Esc must close F2 before changing the current menu view")
	frontend.call("_show_levels")
	_check(level_view.visible and not main_view.visible, "campaign action must open the level selector")
	var level_buttons := _buttons(level_view)
	_check(level_buttons.size() == 2, "the selector must contain one authored level and one back action")
	_check(level_buttons[0].text.contains("第一关：改写路径") and level_buttons[0].text.contains("尚未完成"),
		"the only level card must expose its unfinished state without placeholder levels")
	_check(not level_buttons[0].text.contains("敬请期待"), "the level selector must not invent unavailable content")
	frontend.free()
	await get_tree().process_frame

	_check(service.record_campaign_result(&"diode_tutorial", {
		"result": &"timeout", "utilization": 1.21,
	}) == OK, "failed attempt fixture must save")
	frontend = (load("res://scenes/frontend/main_menu.tscn") as PackedScene).instantiate() as FrontendController
	add_child(frontend)
	frontend.call("_show_levels")
	level_view = frontend.get_node("OuterMargin/CenterContainer/FrontEndContent/LevelSelectView") as VBoxContainer
	level_buttons = _buttons(level_view)
	_check(level_buttons[0].text.contains("尚未完成") and level_buttons[0].text.contains("121.0%"),
		"failed attempt best must remain visible without completing the level")
	frontend.free()

	_check(service.record_campaign_result(&"diode_tutorial", {
		"result": &"success", "utilization": 1.42, "completed_waves": 2, "reason": &"success",
	}) == OK, "frontend fixture progress must save")
	frontend = (load("res://scenes/frontend/main_menu.tscn") as PackedScene).instantiate() as FrontendController
	add_child(frontend)
	await get_tree().process_frame
	frontend.call("_show_levels")
	level_view = frontend.get_node("OuterMargin/CenterContainer/FrontEndContent/LevelSelectView") as VBoxContainer
	level_buttons = _buttons(level_view)
	_check(level_buttons[0].text.contains("已完成") and level_buttons[0].text.contains("142.0%"),
		"completed cards must show the best utilization above 100 percent")
	frontend.free()
	await get_tree().process_frame

	_test_single_result_write(service, catalog)
	await _test_pause_and_escape_priority()
	await _test_real_modal_inputs()
	await _test_save_retry_and_focus(service, catalog)
	_cleanup_progress()
	if not _failed:
		print("Frontend navigation tests passed: default menu, completion card, one-shot result and pause precedence")
	get_tree().quit(1 if _failed else 0)


func _test_single_result_write(service: CampaignService, catalog: LevelCatalog) -> void:
	_cleanup_progress()
	service.configure_for_tests(catalog, TEST_PROGRESS_PATH, func(_path: String): return OK)
	var sandbox = load("res://scripts/combat/combat_sandbox.gd").new()
	sandbox.runtime = preload("res://scripts/runtime/world_runtime.gd").new()
	var fixture := CompletionFixture.new()
	fixture.utilization = 1.1
	sandbox.set("_campaign_service", service)
	sandbox.set("_campaign_launch_active", true)
	sandbox.set("_campaign_level_id", &"diode_tutorial")
	sandbox.runtime.set("session", fixture)
	sandbox.call("_on_run_finished", &"success")
	fixture.utilization = 2.0
	sandbox.call("_on_run_finished", &"success")
	var snapshot := service.levels_snapshot()[0]
	_check(is_equal_approx(float(snapshot.best_utilization), 1.1),
		"a terminal run must write campaign progress exactly once")
	sandbox.free()


func _test_pause_and_escape_priority() -> void:
	var sandbox = (load("res://scenes/levels/diode_tutorial.tscn") as PackedScene).instantiate()
	sandbox.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sandbox)
	await get_tree().process_frame
	await get_tree().process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	sandbox.call("_handle_key", escape)
	var pause_overlay = sandbox.get("_pause_overlay")
	_check(get_tree().paused and pause_overlay != null and pause_overlay.is_open(),
		"Esc without a transient build action must pause the complete world")
	var tick_before := int(sandbox.runtime.simulation.native.get_stats().get("tick", 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var tick_after := int(sandbox.runtime.simulation.native.get_stats().get("tick", 0))
	_check(tick_after == tick_before, "native simulation must not advance while the SceneTree is paused")
	sandbox.call("_resume_run")
	_check(not get_tree().paused and not pause_overlay.is_open(), "resume must restore the tree and close the pause overlay")

	var catalog = sandbox.runtime.catalog
	preload("res://tools/input_test_driver.gd").mouse(sandbox.runtime.input, sandbox.get_viewport().get_canvas_transform() * Vector2(120, 120), true)
	sandbox.call("_handle_key", escape)
	_check(not get_tree().paused and not sandbox.runtime.input.has_cancelable_interaction(),
		"Esc must cancel pending diode placement before opening pause")
	sandbox.runtime.input.handle_command(&"dismantle_begin")
	var f2 := InputEventKey.new()
	f2.keycode = KEY_F2
	f2.pressed = true
	sandbox.call("_handle_key", f2)
	_check(sandbox.runtime.input.snapshot().dismantle_progress == 0.0, "opening F2 must cancel dismantle progress")
	var balance_overlay = sandbox.get("_balance_overlay")
	balance_overlay.panel.visible = true
	sandbox.call("_handle_key", escape)
	_check(not balance_overlay.panel.visible and not get_tree().paused, "Esc must close F2 before opening pause")
	var progress_before_exit: Dictionary = (get_tree().root.get_node("_campaign_service") as CampaignService).progress.duplicate(true)
	sandbox.call("_return_from_run")
	_check((get_tree().root.get_node("_campaign_service") as CampaignService).progress == progress_before_exit,
		"leaving an active paused-capable scene must not record campaign progress")
	sandbox.call("_pause_run")
	_check(get_tree().paused, "pause fixture must enter paused state before scene exit")
	sandbox.free()
	await get_tree().process_frame
	_check(not get_tree().paused, "leaving a combat scene must never leak the paused SceneTree state")


func _buttons(container: Container) -> Array[Button]:
	var result: Array[Button] = []
	for child in container.get_children():
		if child is Button:
			result.append(child as Button)
	return result


func _test_save_retry_and_focus(service: CampaignService, catalog: LevelCatalog) -> void:
	_cleanup_progress()
	service.configure_for_tests(catalog, "user://not_created_v041/progress.json", func(_path: String): return OK)
	var sandbox = (load("res://scenes/levels/diode_tutorial.tscn") as PackedScene).instantiate()
	add_child(sandbox)
	sandbox.set_process(false)
	var fixture := CompletionFixture.new()
	fixture.utilization = 1.7
	sandbox.runtime.set("session", fixture)
	sandbox.set("_campaign_launch_active", true)
	sandbox.set("_campaign_level_id", &"diode_tutorial")
	sandbox.call("_on_run_finished", &"success")
	var hud = sandbox.get("_combat_hud") as CombatHud
	hud.set_campaign_navigation(true)
	hud.set_snapshot({"terminal": true, "result": &"success", "phase": &"finished"}, sandbox.runtime.tower)
	_check(hud._save_button.visible and not sandbox.get("_pending_completion").is_empty(),
		"save failures must retain an immutable result and show a retry-save button")
	service.progress_path = TEST_PROGRESS_PATH
	fixture.utilization = 9.9
	hud._save_button.grab_focus()
	await _key(KEY_ENTER)
	_check(not hud._save_button.visible and sandbox.get("_pending_completion").is_empty()
		and is_equal_approx(float(service.levels_snapshot()[0].best_utilization), 1.7),
		"retry-save must commit the original result, not a changed live snapshot")
	sandbox.call("_retry_result_save")
	_check(is_equal_approx(float(service.levels_snapshot()[0].best_utilization), 1.7),
		"repeated save retries must be idempotent")
	hud._focus_default()
	_check(hud._return_button.has_focus(), "successful campaign settlement must focus return")
	await _key(KEY_LEFT)
	_check(hud._retry_button.has_focus(), "arrow keys must move settlement focus")
	await _key(KEY_TAB)
	_check(hud._return_button.has_focus(), "Tab must switch between settlement actions")
	hud.terminal = false
	hud.set_snapshot({"terminal": true, "result": &"timeout", "phase": &"failed"}, sandbox.runtime.tower)
	_check(hud._retry_button.has_focus(), "failed settlement must focus retry")
	sandbox.free()
	await get_tree().process_frame


func _key(code: Key, viewport: Viewport = null) -> void:
	var target := get_viewport() if viewport == null else viewport
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		target.push_input(event)
		await get_tree().process_frame


func _test_real_modal_inputs() -> void:
	for scene_path in ["res://scenes/prototype/momentum_prototype.tscn", "res://scenes/levels/diode_tutorial.tscn"]:
		var sandbox = (load(scene_path) as PackedScene).instantiate()
		add_child(sandbox)
		await get_tree().process_frame
		var menu = sandbox.get("_runtime_menu")
		var overlay = sandbox.get("_balance_overlay")
		await _key(KEY_F2)
		_check(overlay.is_open() and get_tree().paused, "real F2 event must show tuner and pause world")
		var before: Dictionary = sandbox.runtime.simulation.native.get_stats().duplicate(true)
		var auto_before: bool = sandbox.runtime.auto_fire
		var emission_before: float = sandbox.runtime.emit_accumulator
		await _key(KEY_SPACE)
		_check(sandbox.runtime.auto_fire == auto_before and sandbox.runtime.emit_accumulator == emission_before
			and sandbox.runtime.simulation.native.get_stats().tick == before.tick,
			"modal space input must not leak and firing accumulation must stay frozen")
		await _key(KEY_ESCAPE)
		_check(not overlay.is_open() and not menu.menu.is_open() and not get_tree().paused,
			"Esc must close F2 without opening a second modal")
		await _key(KEY_ESCAPE)
		_check(menu.menu.is_open() and get_tree().paused, "real Esc event must pause both combat and building lab")
		var paused_tick := int(sandbox.runtime.simulation.native.get_stats().tick)
		await _key(KEY_F2)
		_check(overlay.is_open() and menu.menu.is_open(), "F2 must stack above pause menu")
		await _key(KEY_ENTER)
		_check(overlay.is_open() and menu.menu.is_open() and get_tree().paused,
			"Enter in tuner must not activate the previously focused underlying pause action")
		await _key(KEY_ESCAPE)
		_check(not overlay.is_open() and menu.menu.is_open() and get_tree().paused,
			"closing tuner must retain the previously open pause menu")
		_check(int(sandbox.runtime.simulation.native.get_stats().tick) == paused_tick,
			"native tick must stay frozen through stacked modal keyboard events")
		var invoked: Array[bool] = []
		menu.request_action(func(): invoked.append(true))
		await get_tree().process_frame
		_check(menu.confirmation.visible and menu.confirmation.get_cancel_button().has_focus(),
			"abandon confirmation must initially focus cancel")
		await _key(KEY_ENTER, menu.confirmation)
		_check(invoked.is_empty() and not menu.confirmation.visible and get_tree().paused,
			"Enter on default cancel must not abandon or unpause the run")
		menu.request_action(func(): invoked.append(true))
		menu.confirmation.get_ok_button().grab_focus()
		await _key(KEY_ENTER, menu.confirmation)
		_check(invoked.size() == 1 and not get_tree().paused, "confirmed abandon must execute once and release pauses")
		sandbox.free()
		await get_tree().process_frame
		_check(not get_tree().paused, "no modal pause reason may survive scene removal")


func _cleanup_progress() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_PROGRESS_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
