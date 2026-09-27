extends Node

const FRONTEND_SCENE := preload("res://scenes/frontend/main_menu.tscn")
const TUTORIAL_SCENE := preload("res://scenes/levels/diode_tutorial.tscn")
const PROGRESS_PATH := "user://frontend_capture_v04.json"

const MAIN_OUTPUT := "res://artifacts/v041-main-menu.png"
const UNFINISHED_OUTPUT := "res://artifacts/v041-level-failed-best.png"
const COMPLETED_OUTPUT := "res://artifacts/v041-level-completed.png"
const PAUSE_OUTPUT := "res://artifacts/v041-pause.png"
const SETTLEMENT_OUTPUT := "res://artifacts/v041-settlement.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture.call_deferred()


func _capture() -> void:
	_cleanup_progress()
	var service := get_node("/root/_campaign_service") as CampaignService
	var catalog = load("res://resources/levels/campaign_catalog.tres") as LevelCatalog
	service.configure_for_tests(catalog, PROGRESS_PATH, func(_path: String): return OK)
	var frontend := FRONTEND_SCENE.instantiate() as FrontendController
	add_child(frontend)
	await _settle_frames(3)
	if not await _save(MAIN_OUTPUT):
		return
	frontend.call("_show_help")
	await _settle_frames(2)
	await _save("res://artifacts/v041-help.png")
	frontend.get("_help").hide()
	service.record_campaign_result(&"diode_tutorial", {"result": &"timeout", "utilization": 1.21})
	frontend.free()
	frontend = FRONTEND_SCENE.instantiate() as FrontendController
	add_child(frontend)
	await _settle_frames(2)
	frontend.call("_show_levels")
	await _settle_frames(2)
	if not await _save(UNFINISHED_OUTPUT):
		return
	frontend.free()
	service.record_campaign_result(&"diode_tutorial", {
		"result": &"success", "utilization": 1.42, "completed_waves": 2, "reason": &"success",
	})
	frontend = FRONTEND_SCENE.instantiate() as FrontendController
	add_child(frontend)
	await _settle_frames(2)
	frontend.call("_show_levels")
	await _settle_frames(2)
	if not await _save(COMPLETED_OUTPUT):
		return
	frontend.free()

	var launch_error := service.launch_level(&"diode_tutorial")
	if launch_error != OK:
		push_error("Could not establish campaign launch context: %s" % error_string(launch_error))
		get_tree().quit(launch_error)
		return
	var combat := TUTORIAL_SCENE.instantiate()
	add_child(combat)
	await _settle_frames(5)
	combat.call("_pause_run")
	await _settle_frames(2)
	if not await _save(PAUSE_OUTPUT):
		return
	combat.get("_balance_overlay").toggle_panel()
	await _settle_frames(4)
	await _save("res://artifacts/v041-tuning-wide.png")
	combat.get("_balance_overlay").close_panel()
	combat.get("_runtime_menu").request_action(func(): pass)
	await _settle_frames(3)
	await _save("res://artifacts/v041-abandon-confirmation.png")
	combat.get("_runtime_menu")._cancel_confirmation()
	combat.call("_resume_run")
	combat.set_process(false)
	var session := combat.runtime.session as DiodeTutorialSession
	var simulation := combat.runtime.simulation as SimulationController
	var tower := combat.runtime.tower as TowerController
	var hud := combat.get("_combat_hud") as CombatHud
	session.state = DiodeTutorialSession.State.FINISHED
	session.result = &"success"
	session.completed_waves = 2
	session.current_wave_index = 1
	session.final_stats = simulation.native.get_stats()
	session.final_stats["utilization"] = 1.42
	hud.set_campaign_navigation(true)
	hud.set_snapshot(session.hud_snapshot(session.final_stats), tower)
	await _settle_frames(2)
	if not await _save(SETTLEMENT_OUTPUT):
		return
	hud.set_save_failed(true)
	await _settle_frames(2)
	await _save("res://artifacts/v041-save-retry.png")
	combat.free()
	_cleanup_progress()
	print("Captured v0.4 main menu, level states, pause and settlement navigation")
	get_tree().quit(0)


func _settle_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		return true
	push_error("Could not save %s: %s" % [path, error_string(error)])
	get_tree().paused = false
	get_tree().quit(error)
	return false


func _cleanup_progress() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = PROGRESS_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
