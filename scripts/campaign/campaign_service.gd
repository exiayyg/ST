class_name CampaignService
extends Node

const ProgressRepositoryType := preload("res://scripts/campaign/campaign_progress_repository.gd")
const CATALOG_PATH := "res://resources/levels/campaign_catalog.tres"
const FRONTEND_SCENE := "res://scenes/frontend/main_menu.tscn"
const ENDLESS_SCENE := "res://scenes/combat/endless_sandbox.tscn"

var catalog: LevelCatalog
var progress: Dictionary = {}
var progress_path := ProgressRepositoryType.DEFAULT_PATH
var current_launch: Dictionary = {}
var show_levels_on_frontend := false
var errors: Array[String] = []
var scene_change_override: Callable
var _catalog_valid := false
var progress_notice := ""
var last_save_errors: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build():
		# Finalize only previously authorized, abandoned reports; never creates a run.
		PlaytestRecorder.recover_interrupted("user://playtests")
	var loaded = load(CATALOG_PATH)
	if loaded is LevelCatalog:
		catalog = loaded as LevelCatalog
	else:
		errors.append("无法加载关卡目录：%s" % CATALOG_PATH)
	_load_state()


func configure_for_tests(
		level_catalog: LevelCatalog,
		path: String,
		change_callback := Callable()
) -> void:
	catalog = level_catalog
	progress_path = path
	scene_change_override = change_callback
	errors.clear()
	current_launch.clear()
	show_levels_on_frontend = false
	_load_state()


func levels_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if catalog == null or not _catalog_valid:
		return result
	var completed := _completed_ids()
	for definition in catalog.ordered_levels(true):
		var record: Dictionary = (progress.get("levels", {}) as Dictionary).get(String(definition.id), {})
		var snapshot := definition.snapshot()
		snapshot.merge({
			"locked": not catalog.is_unlocked(definition.id, completed),
			"completed": bool(record.get("completed", false)),
			"best_utilization": float(record.get("best_utilization", 0.0)),
		}, true)
		result.append(snapshot)
	return result


func launch_level(level_id: StringName) -> Error:
	if catalog == null:
		return ERR_UNCONFIGURED
	if not _catalog_valid:
		return ERR_INVALID_DATA
	var definition := catalog.get_level(level_id)
	if definition == null or not definition.release_visible:
		return ERR_DOES_NOT_EXIST
	if not catalog.is_unlocked(level_id, _completed_ids()):
		return ERR_UNAUTHORIZED
	var request := {
		"kind": &"campaign",
		"level_id": level_id,
		"scene_path": definition.scene_path,
		"session_kind": StringName(definition.session_kind),
		"balance_key": definition.balance_key,
	}
	return _launch(request)


func launch_playtest(level_id: StringName, record_enabled: bool) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAUTHORIZED
	if catalog == null or not _catalog_valid:
		return ERR_UNCONFIGURED
	var definition := catalog.get_level(level_id)
	if definition == null or not definition.release_visible:
		return ERR_DOES_NOT_EXIST
	return _launch({
		"kind": &"playtest", "level_id": level_id, "scene_path": definition.scene_path,
		"session_kind": StringName(definition.session_kind), "balance_key": definition.balance_key,
		"record_enabled": record_enabled,
	})


func launch_endless() -> Error:
	return _launch({
		"kind": &"endless",
		"level_id": &"",
		"scene_path": ENDLESS_SCENE,
		"session_kind": &"endless",
		"balance_key": "waves/endless",
	})


func launch_development_scene(scene_path: String, session_kind: StringName = &"") -> Error:
	if not OS.is_debug_build():
		return ERR_UNAUTHORIZED
	return _launch({
		"kind": &"development",
		"level_id": &"",
		"scene_path": scene_path,
		"session_kind": session_kind,
	})


func retry_current() -> Error:
	if current_launch.is_empty():
		return ERR_UNCONFIGURED
	return _change_scene(String(current_launch.get("scene_path", "")))


func return_to_frontend(show_levels := false) -> Error:
	var previous_launch := current_launch.duplicate(true)
	var previous_target := show_levels_on_frontend
	show_levels_on_frontend = show_levels
	current_launch.clear()
	var result := _change_scene(FRONTEND_SCENE)
	if result != OK:
		current_launch = previous_launch
		show_levels_on_frontend = previous_target
	return result


func record_campaign_result(level_id: StringName, summary: Dictionary) -> Error:
	if StringName(current_launch.get("kind", &"")) == &"playtest":
		return ERR_UNAUTHORIZED
	if catalog == null:
		return ERR_UNCONFIGURED
	if not _catalog_valid:
		return ERR_INVALID_DATA
	if catalog.get_level(level_id) == null:
		return ERR_DOES_NOT_EXIST
	var utilization_value = summary.get("utilization", null)
	if utilization_value is not int and utilization_value is not float:
		return ERR_INVALID_DATA
	var utilization := float(utilization_value)
	if not is_finite(utilization) or utilization < 0.0:
		return ERR_INVALID_DATA
	var result_name := StringName(summary.get("result", &""))
	if result_name == &"":
		return ERR_INVALID_DATA
	var next_progress := progress.duplicate(true)
	var levels: Dictionary = next_progress.get("levels", {})
	var existing: Dictionary = levels.get(String(level_id), {
		"completed": false,
		"best_utilization": 0.0,
	})
	var next_record := {
		"completed": bool(existing.get("completed", false)) or result_name == &"success",
		"best_utilization": maxf(float(existing.get("best_utilization", 0.0)), utilization),
	}
	if existing == next_record:
		return OK
	levels[String(level_id)] = next_record
	next_progress["levels"] = levels
	var save_errors := ProgressRepositoryType.save_progress(next_progress, progress_path)
	last_save_errors = save_errors
	if not save_errors.is_empty():
		return ERR_CANT_CREATE
	progress = next_progress
	return OK


func current_launch_snapshot() -> Dictionary:
	return current_launch.duplicate(true)


func consume_frontend_level_target() -> bool:
	var result := show_levels_on_frontend
	show_levels_on_frontend = false
	return result


func _load_state() -> void:
	progress_notice = ""
	last_save_errors.clear()
	progress = ProgressRepositoryType.empty_progress()
	_catalog_valid = false
	if catalog != null:
		var catalog_errors := catalog.validation_errors(_balance_profile())
		errors.append_array(catalog_errors)
		_catalog_valid = catalog_errors.is_empty()
	var loaded := ProgressRepositoryType.load_progress(progress_path)
	if bool(loaded.get("ok", false)):
		progress = (loaded.get("data", {}) as Dictionary).duplicate(true)
		progress_notice = String(loaded.get("notice", ""))
	else:
		progress_notice = "本地进度无法读取，已保留损坏数据并以空白进度继续。"
		for message in loaded.get("errors", []):
			errors.append(String(message))
	for message in errors:
		push_warning(message)


func _completed_ids() -> Dictionary:
	var completed := {}
	for raw_id in (progress.get("levels", {}) as Dictionary).keys():
		var record: Dictionary = (progress.get("levels", {}) as Dictionary)[raw_id]
		completed[StringName(raw_id)] = bool(record.get("completed", false))
	return completed


func _launch(request: Dictionary) -> Error:
	var previous_launch := current_launch.duplicate(true)
	current_launch = request.duplicate(true)
	var result := _change_scene(String(request.get("scene_path", "")))
	if result != OK:
		current_launch = previous_launch
	return result


func _change_scene(scene_path: String) -> Error:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	preload("res://scripts/combat/runtime_pause_state.gd").reset(get_tree())
	if scene_change_override.is_valid():
		var value = scene_change_override.call(scene_path)
		return int(value)
	return get_tree().change_scene_to_file(scene_path)


func _balance_profile() -> BalanceProfile:
	var balance_service := get_node_or_null("/root/_balance_service")
	if balance_service != null and balance_service.has_method("active_profile"):
		return balance_service.active_profile() as BalanceProfile
	return null
