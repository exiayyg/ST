extends Node

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const LevelDefinitionType := preload("res://scripts/campaign/level_definition.gd")
const LevelCatalogType := preload("res://scripts/campaign/level_catalog.gd")
const ProgressRepositoryType := preload("res://scripts/campaign/campaign_progress_repository.gd")
const CampaignServiceType := preload("res://scripts/campaign/campaign_service.gd")

const TEST_PROGRESS_PATH := "user://campaign_progress_v04_test.json"

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
	var profile := BalanceRepositoryType.load_profile()
	_check(profile != null, "balance profile must load for campaign tests")
	var project_catalog = load("res://resources/levels/campaign_catalog.tres") as LevelCatalog
	_check(project_catalog != null, "project campaign catalog must load")
	if project_catalog != null:
		_check(project_catalog.validation_errors(profile).is_empty(), "project campaign catalog must validate")
		_check(project_catalog.ordered_levels().size() == 1, "only the authored diode tutorial must be player-visible")

	_test_catalog_rejection(profile)
	_test_progress_repository()
	await _test_campaign_service(profile)
	_cleanup_progress()
	if not _failed:
		print("Campaign framework tests passed: catalog validation, atomic progress, sequential unlocks and scene routing")
	get_tree().quit(1 if _failed else 0)


func _test_catalog_rejection(profile: BalanceProfile) -> void:
	var duplicate := LevelCatalogType.new() as LevelCatalog
	duplicate.levels.append(_definition(&"same"))
	duplicate.levels.append(_definition(&"same"))
	_check(not duplicate.validation_errors(profile).is_empty(), "duplicate level IDs must be rejected")

	var invalid := LevelCatalogType.new() as LevelCatalog
	var missing_scene := _definition(&"missing_scene")
	missing_scene.scene_path = "res://scenes/levels/not_present.tscn"
	invalid.levels.append(missing_scene)
	var unknown_session := _definition(&"unknown_session")
	unknown_session.session_kind = "unsupported"
	invalid.levels.append(unknown_session)
	var missing_prerequisite := _definition(&"missing_prerequisite")
	missing_prerequisite.prerequisites.append(&"absent")
	invalid.levels.append(missing_prerequisite)
	var invalid_errors := invalid.validation_errors(profile)
	_check(invalid_errors.size() >= 3, "missing scenes, unknown sessions and unknown prerequisites must all be rejected")

	var cyclic := LevelCatalogType.new() as LevelCatalog
	var first := _definition(&"first")
	var second := _definition(&"second")
	first.prerequisites.append(second.id)
	second.prerequisites.append(first.id)
	cyclic.levels.append(first)
	cyclic.levels.append(second)
	var cycle_errors := cyclic.validation_errors(profile)
	_check(_contains_text(cycle_errors, "循环"), "cyclic prerequisites must be rejected")


func _test_progress_repository() -> void:
	var missing := ProgressRepositoryType.load_progress(TEST_PROGRESS_PATH)
	_check(bool(missing.get("ok", false)), "missing progress must load as an empty profile")
	_check((missing.get("data", {}) as Dictionary) == ProgressRepositoryType.empty_progress(),
		"missing progress must use the versioned empty schema")

	_write_text(TEST_PROGRESS_PATH, "{ broken")
	var broken := ProgressRepositoryType.load_progress(TEST_PROGRESS_PATH)
	_check(not bool(broken.get("ok", true)), "malformed progress JSON must be rejected atomically")
	var valid := ProgressRepositoryType.empty_progress()
	valid.levels["diode_tutorial"] = {"completed": true, "best_utilization": 1.35}
	_check(ProgressRepositoryType.save_progress(valid, TEST_PROGRESS_PATH).is_empty(),
		"valid progress must replace a corrupt file transactionally")
	var corrupt_files := _corrupt_files()
	_check(corrupt_files.size() == 1 and _read_text(corrupt_files[0]) == "{ broken",
		"corrupt bytes must be preserved independently from the last valid backup")
	var first_text := _read_text(TEST_PROGRESS_PATH)
	var loaded := ProgressRepositoryType.load_progress(TEST_PROGRESS_PATH)
	_check(bool(loaded.get("ok", false)) and is_equal_approx(
		float(((loaded.get("data", {}) as Dictionary).levels.diode_tutorial as Dictionary).best_utilization), 1.35
	), "progress roundtrip must preserve utilization above 100 percent")
	_check(ProgressRepositoryType.save_progress(loaded.data, TEST_PROGRESS_PATH).is_empty(),
		"reloaded progress must save again")
	_check(_read_text(TEST_PROGRESS_PATH) == first_text, "progress JSON ordering must remain stable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROGRESS_PATH))
	var restored := ProgressRepositoryType.load_progress(TEST_PROGRESS_PATH)
	_check(bool(restored.ok) and _read_text(TEST_PROGRESS_PATH) == first_text and FileAccess.file_exists(TEST_PROGRESS_PATH),
		"interrupted replacement with missing primary must recover the valid backup")
	_write_text(TEST_PROGRESS_PATH, "{ new corruption")
	var repaired := ProgressRepositoryType.load_progress(TEST_PROGRESS_PATH)
	_check(bool(repaired.ok) and _read_text(TEST_PROGRESS_PATH) == first_text and _read_text(TEST_PROGRESS_PATH + ".bak") == first_text,
		"corrupt primary must not overwrite the last valid backup")
	_check(_corrupt_files().size() == 2, "each damaged primary must be preserved independently")
	var unknown_field: Dictionary = (loaded.data as Dictionary).duplicate(true)
	unknown_field["unexpected"] = true
	_check(not ProgressRepositoryType.save_progress(unknown_field, TEST_PROGRESS_PATH).is_empty()
			and _read_text(TEST_PROGRESS_PATH) == first_text,
		"unknown progress fields must reject the entire save without replacing valid bytes")
	var missing_field: Dictionary = (loaded.data as Dictionary).duplicate(true)
	missing_field.levels.diode_tutorial.erase("best_utilization")
	_check(not ProgressRepositoryType.save_progress(missing_field, TEST_PROGRESS_PATH).is_empty()
			and _read_text(TEST_PROGRESS_PATH) == first_text,
		"missing progress fields must reject the entire save")
	var wrong_type: Dictionary = (loaded.data as Dictionary).duplicate(true)
	wrong_type.levels.diode_tutorial.completed = "yes"
	_check(not ProgressRepositoryType.save_progress(wrong_type, TEST_PROGRESS_PATH).is_empty()
			and _read_text(TEST_PROGRESS_PATH) == first_text,
		"wrong progress field types must reject the entire save")


func _test_campaign_service(profile: BalanceProfile) -> void:
	_cleanup_progress()
	var catalog := LevelCatalogType.new() as LevelCatalog
	var first := _definition(&"diode_tutorial")
	first.sort_order = 10
	var second := _definition(&"future_test_level")
	second.sort_order = 20
	second.prerequisites.append(first.id)
	catalog.levels.append(first)
	catalog.levels.append(second)
	var changed_paths: Array[String] = []
	var service := CampaignServiceType.new() as CampaignService
	add_child(service)
	service.configure_for_tests(catalog, TEST_PROGRESS_PATH, func(path: String):
		changed_paths.append(path)
		return OK
	)
	var snapshots := service.levels_snapshot()
	_check(snapshots.size() == 2 and not bool(snapshots[0].locked) and bool(snapshots[1].locked),
		"only the first sequential level may start unlocked")
	_check(service.launch_level(second.id) == ERR_UNAUTHORIZED, "locked levels must reject launch requests")

	_check(service.record_campaign_result(first.id, {
		"result": &"timeout", "utilization": 1.2, "completed_waves": 0, "reason": &"timeout",
	}) == OK, "failed attempts must still record their best utilization")
	snapshots = service.levels_snapshot()
	_check(not bool(snapshots[0].completed) and is_equal_approx(float(snapshots[0].best_utilization), 1.2),
		"failure must update best utilization without completing the level")
	_check(bool(snapshots[1].locked), "failure must not unlock the next level")

	_check(service.record_campaign_result(first.id, {
		"result": &"success", "utilization": 0.8, "completed_waves": 2, "reason": &"success",
	}) == OK, "success must be persisted")
	snapshots = service.levels_snapshot()
	_check(bool(snapshots[0].completed) and is_equal_approx(float(snapshots[0].best_utilization), 1.2),
		"success must complete the level without lowering its best utilization")
	_check(not bool(snapshots[1].locked), "completing prerequisites must unlock the next level")

	_check(service.launch_level(first.id) == OK and changed_paths.back() == first.scene_path,
		"campaign launch must route through the authored scene")
	_check(StringName(service.current_launch_snapshot().kind) == &"campaign", "campaign launch context must be retained for retry")
	_check(service.retry_current() == OK and changed_paths.back() == first.scene_path,
		"retry must reload the retained launch scene")
	_check(service.return_to_frontend(true) == OK and changed_paths.back() == service.FRONTEND_SCENE,
		"campaign return must route to the frontend")
	_check(service.current_launch_snapshot().is_empty(), "returning to the frontend must clear launch context")
	_check(service.consume_frontend_level_target() and not service.consume_frontend_level_target(),
		"level-select return target must be consumed exactly once")
	_check(service.launch_endless() == OK and changed_paths.back() == service.ENDLESS_SCENE,
		"endless launch must use its existing scene")
	_check(StringName(service.current_launch_snapshot().kind) == &"endless", "endless launch must not masquerade as campaign progress")
	service.free()
	await get_tree().process_frame


func _definition(level_id: StringName) -> LevelDefinition:
	var definition := LevelDefinitionType.new() as LevelDefinition
	definition.id = level_id
	definition.display_name = String(level_id)
	definition.description = "test"
	definition.scene_path = "res://scenes/levels/diode_tutorial.tscn"
	definition.session_kind = "tutorial_diode"
	definition.balance_key = "levels/diode_tutorial"
	return definition


func _contains_text(messages: Array[String], fragment: String) -> bool:
	for message in messages:
		if message.contains(fragment):
			return true
	return false


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _cleanup_progress() -> void:
	for path in _corrupt_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_PROGRESS_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _corrupt_files() -> Array[String]:
	var found: Array[String] = []
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(TEST_PROGRESS_PATH.get_file() + ".corrupt."):
			found.append("user://" + filename)
	return found
