class_name WaveDirector
extends RefCounted

signal target_reached
signal wave_finished(result: StringName)
signal warnings_changed(warnings: Dictionary)

const BalanceSchemaType := preload("res://scripts/config/balance_schema.gd")

enum State { IDLE, ACTIVE, TARGET_REACHED, FINISHED, FAILED }

var profile: BalanceProfile
var enemy_manager: EnemyManager
var simulation: SimulationController
var tower: TowerController
var state := State.IDLE
var wave_id: StringName
var wave: Dictionary = {}
var groups: Array[Dictionary] = []
var elapsed := 0.0
var duration := 0.0
var target_utilization := 0.0
var target_latched := false
var latest_warnings: Dictionary = {}
var result: StringName
var final_stats: Dictionary = {}
var spawn_backpressure_active := false
var spawn_backpressure_deferred := 0


func _init(
		balance_profile: BalanceProfile,
		manager: EnemyManager,
		simulation_controller: SimulationController,
		tower_controller: TowerController
) -> void:
	profile = balance_profile
	enemy_manager = manager
	simulation = simulation_controller
	tower = tower_controller


func start(configured_wave_id: StringName) -> bool:
	var configured = profile.value("waves/%s" % configured_wave_id, null)
	if configured is not Dictionary:
		return false
	return start_spec(configured_wave_id, configured)


func start_spec(configured_wave_id: StringName, configured: Dictionary) -> bool:
	if configured.is_empty() or configured.get("groups", null) is not Array:
		return false
	wave_id = configured_wave_id
	wave = configured.duplicate(true)
	duration = float(wave.get("duration", 90.0))
	target_utilization = float(wave.get("target_utilization", 0.15))
	if duration <= 0.0 or target_utilization < 0.0:
		return false
	elapsed = 0.0
	target_latched = false
	result = &""
	final_stats.clear()
	spawn_backpressure_active = false
	spawn_backpressure_deferred = 0
	groups.clear()
	for group_value in wave.get("groups", []):
		if group_value is not Dictionary:
			return false
		var group: Dictionary = (group_value as Dictionary).duplicate(true)
		group["spawned"] = 0
		group["next_time"] = float(group.get("start_time", 0.0))
		groups.append(group)
	simulation.native.reset_wave_stats()
	state = State.ACTIVE
	_refresh_warnings()
	return true


func update_before_simulation(delta: float) -> void:
	if state == State.TARGET_REACHED:
		var finish_policy := String(wave.get("finish_policy", "immediate"))
		if finish_policy == "immediate" or (finish_policy == "clear" and enemy_manager.alive_count() == 0):
			state = State.FINISHED
			result = &"success"
			wave_finished.emit(result)
		return
	if state != State.ACTIVE:
		return
	spawn_backpressure_active = false
	elapsed = minf(duration, elapsed + delta)
	_spawn_due_groups()
	_refresh_warnings()


func evaluate_after_simulation(stats: Dictionary) -> void:
	if state != State.ACTIVE and state != State.TARGET_REACHED:
		return
	if tower.is_destroyed():
		_fail(&"tower_destroyed", stats)
		return
	if state == State.TARGET_REACHED:
		return
	var utilization := float(stats.get("utilization", 0.0))
	if not target_latched and utilization >= target_utilization:
		target_latched = true
		final_stats = stats.duplicate(true)
		target_reached.emit()
		state = State.TARGET_REACHED
		latest_warnings.clear()
		warnings_changed.emit(latest_warnings)
		return
	if elapsed >= duration:
		if target_latched:
			final_stats = stats.duplicate(true)
			state = State.FINISHED
			result = &"success"
			wave_finished.emit(result)
		else:
			_fail(&"timeout", stats)


func combat_active() -> bool:
	return state == State.ACTIVE or (
		state == State.TARGET_REACHED and String(wave.get("finish_policy", "immediate")) == "clear"
	)


func is_terminal() -> bool:
	return state == State.FINISHED or state == State.FAILED


func stats_for_display(live_stats: Dictionary) -> Dictionary:
	if (state == State.TARGET_REACHED or is_terminal()) and not final_stats.is_empty():
		return final_stats
	return live_stats


func remaining_time() -> float:
	return maxf(0.0, duration - elapsed)


func display_name() -> String:
	return String(wave.get("display_name", String(wave_id)))


func debug_snapshot() -> Dictionary:
	return {
		"template_id": String(wave.get("template_id", "")),
		"threat_budget": float(wave.get("threat_budget", 0.0)),
		"spawn_backpressure_active": spawn_backpressure_active,
		"spawn_backpressure_deferred": spawn_backpressure_deferred,
	}


func _spawn_due_groups() -> void:
	var pressure := 1.0
	if not target_latched:
		pressure = BalanceSchemaType.sample_curve(
			wave.get("pressure_curve", []), elapsed / maxf(duration, 0.000001)
		)
	for group in groups:
		var count := int(group.get("count", 0))
		var spawned := int(group.get("spawned", 0))
		var start_time := float(group.get("start_time", 0.0))
		var end_time := float(group.get("end_time", start_time))
		var interval := (end_time - start_time) / float(maxi(count - 1, 1))
		while spawned < count and elapsed >= float(group.get("next_time", start_time)):
			var guard := int(wave.get("max_active_enemy_guard", 0))
			if guard > 0 and enemy_manager.alive_count() >= guard:
				spawn_backpressure_active = true
				spawn_backpressure_deferred += 1
				break
			var spawned_id := enemy_manager.spawn(
				StringName(group.get("enemy", "")),
				StringName(group.get("direction", "east")),
				group.get("enemy_modifiers", wave.get("enemy_modifiers", {}))
			)
			if spawned_id <= 0:
				break
			spawned += 1
			group["spawned"] = spawned
			group["next_time"] = float(group.get("next_time", start_time)) + interval / maxf(pressure, 0.000001)


func _refresh_warnings() -> void:
	var next_warnings: Dictionary = {}
	for group in groups:
		var spawned := int(group.get("spawned", 0))
		var count := int(group.get("count", 0))
		var warning_start := float(group.get("start_time", 0.0)) - float(group.get("warning_lead", 0.0))
		if spawned >= count or elapsed < warning_start:
			continue
		var direction := String(group.get("direction", "east"))
		var enemy_kind := String(group.get("enemy", ""))
		var entry: Dictionary = next_warnings.get(direction, {"types": {}, "pressure": 0.0})
		var remaining := count - spawned
		entry.types[enemy_kind] = int(entry.types.get(enemy_kind, 0)) + remaining
		var definition := enemy_manager.definitions.get(StringName(enemy_kind)) as EnemyDefinition
		entry.pressure = float(entry.pressure) + remaining * (definition.threat_weight if definition != null else 1.0)
		next_warnings[direction] = entry
	if next_warnings != latest_warnings:
		latest_warnings = next_warnings
		warnings_changed.emit(latest_warnings)


func _fail(reason: StringName, stats: Dictionary = {}) -> void:
	final_stats = stats.duplicate(true)
	state = State.FAILED
	result = reason
	latest_warnings.clear()
	warnings_changed.emit(latest_warnings)
	wave_finished.emit(reason)
