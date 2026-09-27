@tool
class_name BalanceEditAdapter
extends RefCounted

const Repository := preload("res://scripts/config/balance_repository.gd")
var target: Object

func save(profile: BalanceProfile) -> Array[String]:
	return target.save(profile) if target != null else Repository.save_profile(profile, profile.source_path)

func apply(profile: BalanceProfile) -> Array[String]:
	return ["没有可用的应用目标"] if target == null else target.apply_and_reset(profile)

func load_saved(path: String) -> BalanceProfile:
	return Repository.load_profile(path)

func apply_updates_saved() -> bool:
	return false

class Runtime extends BalanceEditAdapter:
	pass

class Editor extends BalanceEditAdapter:
	func apply_updates_saved() -> bool:
		return true
