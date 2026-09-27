extends Node

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")

var profile: BalanceProfile
var disk_profile: BalanceProfile
signal apply_failed(errors: Array[String])
var _reset_pending := false


func _ready() -> void:
	reload_from_disk()


func reload_from_disk() -> bool:
	var loaded := BalanceRepositoryType.load_profile()
	if loaded == null:
		return false
	disk_profile = loaded
	profile = loaded.duplicate_profile()
	return profile.freeze().is_empty()


func apply_and_reset(new_profile: BalanceProfile) -> Array[String]:
	var errors := new_profile.validate()
	if not errors.is_empty():
		return errors
	if _reset_pending:
		return ["已有配置重置正在进行"]
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path.is_empty():
		return ["当前场景没有可重载的来源，配置未应用"]
	var packed := load(get_tree().current_scene.scene_file_path) as PackedScene
	if packed == null or not packed.can_instantiate():
		return ["当前场景无法实例化，配置未应用"]
	var candidate := new_profile.duplicate_profile()
	errors = candidate.freeze()
	if not errors.is_empty():
		return errors
	_reset_pending = true
	_reload_scene.call_deferred(candidate)
	return []


func _reload_scene(candidate: BalanceProfile) -> void:
	var previous := profile
	profile = candidate
	var error := get_tree().reload_current_scene()
	_reset_pending = false
	if error != OK:
		profile = previous
		var errors: Array[String] = ["场景重载失败（%s），已保留此前配置" % error_string(error)]
		apply_failed.emit(errors)
		push_error(errors[0])
	else:
		preload("res://scripts/combat/runtime_pause_state.gd").reset(get_tree())


func save(new_profile: BalanceProfile) -> Array[String]:
	var errors := BalanceRepositoryType.save_profile(new_profile)
	if errors.is_empty():
		disk_profile = new_profile.duplicate_profile()
	return errors


func active_profile() -> BalanceProfile:
	if profile == null:
		reload_from_disk()
	return profile

func is_reset_pending() -> bool:
	return _reset_pending
