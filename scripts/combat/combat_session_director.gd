class_name CombatSessionDirector
extends RefCounted

signal target_reached(wave_index: int)
signal wave_finished(wave_index: int, result: StringName)
signal run_finished(result: StringName)


func start() -> bool:
	return false


func advance(_delta: float) -> void:
	pass


func evaluate(_stats: Dictionary) -> void:
	pass


func hud_snapshot(_live_stats: Dictionary) -> Dictionary:
	return {}


func should_simulate_enemies() -> bool:
	return false


func is_terminal() -> bool:
	return false
