extends SceneTree

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")


func _init() -> void:
	var profile := BalanceRepositoryType.load_profile()
	if profile == null:
		quit(1)
		return
	var errors := BalanceRepositoryType.save_profile(profile)
	if not errors.is_empty():
		push_error("balance.json formatting failed: %s" % ", ".join(errors))
		quit(2)
		return
	print("balance.json validated and formatted with stable field order")
	quit()
