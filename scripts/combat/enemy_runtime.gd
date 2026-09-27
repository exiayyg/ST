class_name EnemyRuntime
extends RefCounted

var id := 0
var definition: EnemyDefinition
var position := Vector2.ZERO
var hp := 0.0
var max_hp := 0.0
var move_speed := 0.0
var attack_damage := 0.0
var entropy := 0.0
var attack_cooldown := 0.0
var charge_remaining := -1.0
var target_refresh_remaining := 0.0
var target_kind: StringName = &"tower"
var target_id := 0
var target_anchor := 0
var alive := true
var hit_flash_remaining := 0.0


func _init(
		runtime_id: int,
		enemy_definition: EnemyDefinition,
		spawn_position: Vector2,
		modifiers: Dictionary = {},
		initial_target_refresh := 0.0
) -> void:
	id = runtime_id
	definition = enemy_definition
	position = spawn_position
	max_hp = enemy_definition.max_hp * maxf(0.0, float(modifiers.get("hp_multiplier", 1.0)))
	move_speed = enemy_definition.move_speed * maxf(0.0, float(modifiers.get("speed_multiplier", 1.0)))
	attack_damage = enemy_definition.attack_damage * maxf(0.0, float(modifiers.get("damage_multiplier", 1.0)))
	hp = max_hp
	attack_cooldown = enemy_definition.attack_interval
	target_refresh_remaining = maxf(0.0, initial_target_refresh)


func view_record() -> Dictionary:
	return {
		"id": id,
		"hit_flash_remaining": hit_flash_remaining,
		"position": position,
		"hp": hp,
		"max_hp": max_hp,
		"entropy": entropy,
		"radius": definition.radius,
		"color": definition.color,
		"display_name": definition.display_name,
		"ranged": definition.ranged,
		"charging": charge_remaining >= 0.0,
		"charge_ratio": clampf(1.0 - charge_remaining / maxf(definition.ranged_charge_seconds, 0.000001), 0.0, 1.0) if charge_remaining >= 0.0 else 0.0,
	}
