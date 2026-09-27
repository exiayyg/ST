extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _run() -> void:
	var service := root.get_node("_balance_service")
	for path in ["res://scenes/frontend/main_menu.tscn", "res://scenes/levels/diode_tutorial.tscn"]:
		check(change_scene_to_file(path) == OK, "test scene must load")
		await scene_changed
		var previous_id := current_scene.get_instance_id()
		var original: BalanceProfile = service.active_profile()
		var candidate := original.duplicate_profile()
		var speed := float(original.value("tower/projectile_speed")) + 10.0
		candidate.set_value("tower/projectile_speed", speed)
		check(service.active_profile() == original, "working edit must preserve active profile")
		# Applying from a paused modal must rebuild the scene and release all pause reasons.
		paused = true
		check(service.apply_and_reset(candidate).is_empty(), "valid apply must schedule reset")
		check(service.active_profile() == original, "deferred application must not partially replace profile")
		await scene_changed
		check(current_scene.get_instance_id() != previous_id and not paused, "reset must recreate scene and release pause")
		check(float(service.active_profile().runtime_config().tower.projectile_speed) == speed, "new scene must use compiled candidate")
		if current_scene is WorldScreen:
			check(current_scene.runtime.profile == service.active_profile(), "world must receive the committed active profile")
			check(current_scene.runtime.session.level != null, "tutorial binding must survive reset")
		var invalid := candidate.duplicate_profile()
		invalid.set_value("tower/fire_interval", -1.0)
		var active: BalanceProfile = service.active_profile()
		check(not service.apply_and_reset(invalid).is_empty() and service.active_profile() == active, "invalid reset must leave scene/config untouched")
	print("Balance scene reset tests ", "FAILED" if failed else "passed")
	quit(1 if failed else 0)
