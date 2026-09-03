class_name TowerController
extends RefCounted

signal damaged(amount: float)
signal destroyed

var position := Vector2.ZERO
var radius := 42.0
var max_hp := 1000.0
var hp := 1000.0


func _init(profile: BalanceProfile) -> void:
	position = Vector2(float(profile.value("tower/position_x", 0.0)), float(profile.value("tower/position_y", 0.0)))
	radius = float(profile.value("tower/collision_radius", 42.0))
	max_hp = float(profile.value("tower/max_hp", 1000.0))
	hp = max_hp


func apply_damage(amount: float) -> bool:
	if amount <= 0.0 or hp <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount)
	if hp <= 0.0:
		destroyed.emit()
		return true
	return false


func is_destroyed() -> bool:
	return hp <= 0.0
