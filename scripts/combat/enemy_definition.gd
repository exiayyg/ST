class_name EnemyDefinition
extends Resource

@export var kind: StringName
@export var display_name: String
@export var color := Color("ff6b7a")
@export var max_hp := 60.0
@export var radius := 18.0
@export var move_speed := 70.0
@export var sense_radius := 220.0
@export var attack_range := 38.0
@export var attack_interval := 1.0
@export var attack_damage := 12.0
@export var ranged_charge_seconds := 0.0
@export var momentum_absorption := 0.35
@export var damage_per_momentum := 1.0
@export var entropy_transfer_ratio := 0.5
@export var entropy_decay_per_second := 0.0
@export var aim_max_deviation_degrees := 0.0
@export var threat_weight := 1.0
@export var ranged := false


static func from_config(enemy_kind: StringName, values: Dictionary) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.kind = enemy_kind
	definition.display_name = String(values.get("display_name", String(enemy_kind)))
	definition.color = Color(String(values.get("color", "ff6b7a")))
	definition.max_hp = float(values.get("max_hp", definition.max_hp))
	definition.radius = float(values.get("radius", definition.radius))
	definition.move_speed = float(values.get("move_speed", definition.move_speed))
	definition.sense_radius = float(values.get("sense_radius", definition.sense_radius))
	definition.attack_range = float(values.get("attack_range", definition.attack_range))
	definition.attack_interval = float(values.get("attack_interval", definition.attack_interval))
	definition.attack_damage = float(values.get("attack_damage", definition.attack_damage))
	definition.ranged_charge_seconds = float(values.get("ranged_charge_seconds", definition.ranged_charge_seconds))
	definition.momentum_absorption = float(values.get("momentum_absorption", definition.momentum_absorption))
	definition.damage_per_momentum = float(values.get("damage_per_momentum", definition.damage_per_momentum))
	definition.entropy_transfer_ratio = float(values.get("entropy_transfer_ratio", definition.entropy_transfer_ratio))
	definition.entropy_decay_per_second = float(values.get("entropy_decay_per_second", definition.entropy_decay_per_second))
	definition.aim_max_deviation_degrees = float(values.get("aim_max_deviation_degrees", definition.aim_max_deviation_degrees))
	definition.threat_weight = float(values.get("threat_weight", definition.threat_weight))
	definition.ranged = bool(values.get("ranged", definition.ranged))
	return definition
