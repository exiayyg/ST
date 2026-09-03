class_name EndlessWaveGenerator
extends RefCounted

const DIRECTIONS := [&"east", &"south", &"west", &"north"]

var profile: BalanceProfile
var config: Dictionary


func _init(balance_profile: BalanceProfile) -> void:
	profile = balance_profile
	config = profile.value("waves/endless", {}).duplicate(true)


func generate(wave_index: int, run_seed: int) -> Dictionary:
	var index := maxi(1, wave_index)
	var random := RandomNumberGenerator.new()
	random.seed = _wave_seed(index, run_seed)
	var template := _select_template(index, random)
	if template.is_empty():
		return {}

	var duration := float(config.get("wave_duration_seconds", 90.0))
	var budget := float(config.get("base_threat_budget", 18.0)) \
		+ float(config.get("threat_budget_growth_per_wave", 4.0)) * float(index - 1)
	var target := minf(
		float(config.get("target_utilization_cap", 0.6)),
		float(config.get("base_target_utilization", 0.15))
			+ float(config.get("target_growth_per_wave", 0.015)) * float(index - 1)
	)
	var ranged_share := 0.0 if index == 1 else minf(
		float(config.get("ranged_share_cap", 0.45)),
		float(config.get("ranged_share_growth_per_wave", 0.08)) * float(index - 1)
	)
	var modifiers := {
		"hp_multiplier": _growth_multiplier(index, "hp_growth_per_wave", "hp_multiplier_cap"),
		"damage_multiplier": _growth_multiplier(index, "damage_growth_per_wave", "damage_multiplier_cap"),
		"speed_multiplier": _growth_multiplier(index, "speed_growth_per_wave", "speed_multiplier_cap"),
	}
	var groups := _build_groups(template, index, random, duration, budget, ranged_share, modifiers)
	return {
		"display_name": "DEV 无尽 · 第 %d 波" % index,
		"duration": duration,
		"target_utilization": target,
		"finish_policy": "clear",
		"pressure_curve": (config.get("pressure_curve", []) as Array).duplicate(true),
		"groups": groups,
		"wave_index": index,
		"template_id": String(template.get("id", "")),
		"template_name": String(template.get("display_name", template.get("id", ""))),
		"threat_budget": budget,
		"ranged_share": ranged_share,
		"enemy_modifiers": modifiers,
		"max_active_enemy_guard": int(config.get("max_active_enemy_guard", 1000)),
	}


func _select_template(wave_index: int, random: RandomNumberGenerator) -> Dictionary:
	var templates: Array = config.get("templates", [])
	for value in templates:
		var candidate: Dictionary = value
		if int(candidate.get("force_wave", 0)) == wave_index:
			return candidate.duplicate(true)
	var eligible: Array[Dictionary] = []
	var total_weight := 0.0
	for value in templates:
		var candidate: Dictionary = value
		if wave_index < int(candidate.get("min_wave", 1)):
			continue
		var weight := maxf(0.0, float(candidate.get("weight", 0.0)))
		if weight <= 0.0:
			continue
		eligible.append(candidate)
		total_weight += weight
	if eligible.is_empty() or total_weight <= 0.0:
		return {}
	var sample := random.randf() * total_weight
	for candidate in eligible:
		sample -= float(candidate.get("weight", 0.0))
		if sample <= 0.0:
			return candidate.duplicate(true)
	return eligible[-1].duplicate(true)


func _build_groups(
		template: Dictionary,
		_wave_index: int,
		random: RandomNumberGenerator,
		duration: float,
		budget: float,
		ranged_share: float,
		modifiers: Dictionary
) -> Array[Dictionary]:
	var offsets: Array = template.get("direction_offsets", [])
	var shares: Array = template.get("budget_shares", [])
	var delays: Array = template.get("start_delay_ratios", [])
	var groups: Array[Dictionary] = []
	var primary := random.randi_range(0, DIRECTIONS.size() - 1)
	var total_share := 0.0
	for value in shares:
		total_share += maxf(0.0, float(value))
	var spawn_start := float(config.get("spawn_start_ratio", 0.1))
	var spawn_end := float(config.get("spawn_end_ratio", 0.75))
	var warning_lead := float(config.get("warning_lead_seconds", 8.0))
	var melee_threat := maxf(0.000001, float(profile.value("enemies/dev_melee/threat_weight", 1.0)))
	var ranged_threat := maxf(0.000001, float(profile.value("enemies/dev_ranged/threat_weight", 1.4)))
	for lane_index in offsets.size():
		var direction_index := posmod(primary + int(offsets[lane_index]), DIRECTIONS.size())
		var direction: StringName = DIRECTIONS[direction_index]
		var share := maxf(0.0, float(shares[lane_index])) / maxf(total_share, 0.000001)
		var lane_budget := budget * share
		var ranged_count := int(floor(lane_budget * ranged_share / ranged_threat))
		var melee_budget := maxf(0.0, lane_budget - float(ranged_count) * ranged_threat)
		var melee_count := int(floor(melee_budget / melee_threat))
		if melee_count + ranged_count <= 0:
			melee_count = 1
		var delay := float(delays[lane_index]) if lane_index < delays.size() else 0.0
		var start_time := duration * clampf(spawn_start + delay, 0.0, spawn_end)
		var end_time := maxf(start_time, duration * spawn_end)
		if melee_count > 0:
			groups.append(_group(direction, &"dev_melee", melee_count, start_time, end_time, warning_lead, modifiers))
		if ranged_count > 0:
			groups.append(_group(direction, &"dev_ranged", ranged_count, start_time, end_time, warning_lead, modifiers))
	return groups


func _group(
		direction: StringName,
		enemy_kind: StringName,
		count: int,
		start_time: float,
		end_time: float,
		warning_lead: float,
		modifiers: Dictionary
) -> Dictionary:
	return {
		"direction": String(direction),
		"enemy": String(enemy_kind),
		"count": count,
		"start_time": start_time,
		"end_time": end_time,
		"warning_lead": warning_lead,
		"enemy_modifiers": modifiers.duplicate(true),
	}


func _growth_multiplier(wave_index: int, growth_key: String, cap_key: String) -> float:
	return minf(
		float(config.get(cap_key, 1.0)),
		1.0 + float(config.get(growth_key, 0.0)) * float(wave_index - 1)
	)


func _wave_seed(wave_index: int, run_seed: int) -> int:
	return posmod(run_seed * 1664525 + wave_index * 1013904223, 2147483647)
