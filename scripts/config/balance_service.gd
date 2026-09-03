extends Node

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")

var profile: BalanceProfile
var disk_profile: BalanceProfile


func _ready() -> void:
	reload_from_disk()


func reload_from_disk() -> bool:
	var loaded := BalanceRepositoryType.load_profile()
	if loaded == null:
		return false
	disk_profile = loaded
	profile = loaded.duplicate_profile()
	return true


func apply_and_reset(new_profile: BalanceProfile) -> Array[String]:
	var errors := new_profile.validate()
	if not errors.is_empty():
		return errors
	profile = new_profile.duplicate_profile()
	get_tree().call_deferred("reload_current_scene")
	return []


func save(new_profile: BalanceProfile) -> Array[String]:
	var errors := BalanceRepositoryType.save_profile(new_profile)
	if errors.is_empty():
		disk_profile = new_profile.duplicate_profile()
	return errors


func active_profile() -> BalanceProfile:
	if profile == null:
		reload_from_disk()
	return profile
