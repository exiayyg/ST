class_name DiodeTutorialSession
extends CombatSessionDirector

const WaveDirectorType := preload("res://scripts/combat/wave_director.gd")

enum State {
	OBSERVE_SOURCE,
	PRACTICE_PLACE,
	PRACTICE_DISMANTLE,
	ROUTE_BUILD,
	WAVE_1,
	INTERMISSION,
	WAVE_2,
	FINISHED,
	FAILED,
}

var profile: BalanceProfile
var enemy_manager: EnemyManager
var simulation: SimulationController
var tower: TowerController
var construction: ConstructionController
var wave_director: WaveDirector
const TutorialConfig := preload("res://scripts/config/diode_tutorial_config.gd")
const SessionSpecType := preload("res://scripts/combat/session_spec.gd")
var level: TutorialConfig
var state := State.OBSERVE_SOURCE
var phase_remaining := 0.0
var practice_device_id := 0
var route_device_id := 0
var current_wave_index := -1
var completed_waves := 0
var result: StringName
var final_stats: Dictionary = {}
var _last_live_stats: Dictionary = {}
var _elapsed := 0.0
var _confirmation: StringName
var _confirmation_remaining := 0.0
var _no_damage_elapsed := 0.0
var _maximum_no_damage_elapsed := 0.0
var _reminder_remaining := 0.0
var _auto_fire := true
var _route_lost := false
var _route_loss_key: StringName = &"route_node_lost"
var _first_hit_time := -1.0
var _first_activation_time := -1.0
var _device_losses := 0
var _damage_total := 0.0


func _init(
		balance_profile: BalanceProfile,
		manager: EnemyManager,
		simulation_controller: SimulationController,
		tower_controller: TowerController,
		construction_controller: ConstructionController,
		configuration: TutorialConfig = null
) -> void:
	profile = balance_profile
	level = configuration
	if level == null:
		var development := SessionSpecType.development(&"tutorial_diode")
		var configured = profile.value(development.balance_key)
		if configured is Dictionary:
			level = TutorialConfig.new(configured)
	enemy_manager = manager
	simulation = simulation_controller
	tower = tower_controller
	construction = construction_controller
	wave_director = WaveDirectorType.new(profile, enemy_manager, simulation, tower) as WaveDirector
	wave_director.target_reached.connect(_on_target_reached)
	wave_director.wave_finished.connect(_on_wave_finished)


func start() -> bool:
	if level == null or level.waves.size() != 2:
		return false
	state = State.OBSERVE_SOURCE
	phase_remaining = float(level.observation_seconds)
	practice_device_id = 0
	route_device_id = 0
	current_wave_index = -1
	completed_waves = 0
	result = &""
	final_stats.clear()
	_last_live_stats.clear()
	_elapsed = 0.0
	_confirmation = &""
	_confirmation_remaining = 0.0
	_no_damage_elapsed = 0.0
	_maximum_no_damage_elapsed = 0.0
	_reminder_remaining = 0.0
	_auto_fire = true
	_route_lost = false
	_first_hit_time = -1.0
	_first_activation_time = -1.0
	_device_losses = 0
	_damage_total = 0.0
	return true


func advance(delta: float) -> void:
	if is_terminal():
		return
	if tower.is_destroyed():
		_fail(&"tower_destroyed", _last_live_stats)
		return
	_elapsed += delta
	_confirmation_remaining = maxf(0.0, _confirmation_remaining - delta)
	_reminder_remaining = maxf(0.0, _reminder_remaining - delta)
	match state:
		State.OBSERVE_SOURCE:
			phase_remaining = maxf(0.0, phase_remaining - delta)
			if phase_remaining <= 0.0:
				state = State.PRACTICE_PLACE
		State.INTERMISSION:
			phase_remaining = maxf(0.0, phase_remaining - delta)
			if phase_remaining <= 0.0:
				_start_wave(1)
		State.WAVE_1, State.WAVE_2:
			wave_director.update_before_simulation(delta)


func evaluate(stats: Dictionary) -> void:
	if is_terminal():
		return
	_last_live_stats = stats.duplicate(true)
	if tower.is_destroyed():
		_fail(&"tower_destroyed", stats)
		return
	if state == State.WAVE_1 or state == State.WAVE_2:
		wave_director.evaluate_after_simulation(stats)


func ingest_event(event: Dictionary) -> void:
	if is_terminal():
		return
	var type := StringName(event.get("type", &""))
	var device_id := int(event.get("device_id", 0))
	if type == &"device_activated" and _first_activation_time < 0.0:
		_first_activation_time = _elapsed
	if type == &"enemy_hit" and float(event.get("damage", 0.0)) > 0.0:
		_damage_total += float(event.damage)
		_no_damage_elapsed = 0.0
		if _first_hit_time < 0.0:
			_first_hit_time = _elapsed
			_confirm(&"first_effective_hit" if bool(event.get("player_visible", true)) else &"first_effective_hit_offscreen")
	if type == &"device_destroyed":
		_device_losses += 1
	if type in [&"device_destroyed", &"device_dismantled"] and device_id == route_device_id and current_wave_index >= 0:
		route_device_id = 0
		_route_lost = true
		_route_loss_key = &"route_node_lost" if type == &"device_destroyed" else &"route_node_removed"
		_confirmation_remaining = 0.0
	if type == &"projectile_teleported" and current_wave_index >= 0 and _is_active_diode(device_id):
		if _route_lost:
			route_device_id = device_id
			_route_lost = false
			_confirm(&"route_connected")
	match type:
		&"device_placed":
			if StringName(event.get("device_kind", &"")) != &"diode":
				return
			if state == State.PRACTICE_PLACE:
				practice_device_id = device_id
				state = State.PRACTICE_DISMANTLE
			elif state == State.ROUTE_BUILD:
				route_device_id = device_id
		&"device_dismantled":
			if state == State.PRACTICE_DISMANTLE and device_id == practice_device_id:
				practice_device_id = 0
				state = State.ROUTE_BUILD
			elif state == State.ROUTE_BUILD and device_id == route_device_id:
				route_device_id = 0
		&"device_destroyed":
			if state == State.PRACTICE_DISMANTLE and device_id == practice_device_id:
				practice_device_id = 0
				state = State.PRACTICE_PLACE
			elif state == State.ROUTE_BUILD and device_id == route_device_id:
				route_device_id = 0
		&"projectile_teleported":
			if state == State.ROUTE_BUILD and device_id == route_device_id \
					and _is_active_diode(device_id) and _is_valid_north_route(device_id):
				_confirm(&"route_connected")
				_start_wave(0)


func hud_snapshot(live_stats: Dictionary) -> Dictionary:
	var shown_stats := live_stats
	if state == State.WAVE_1 or state == State.WAVE_2:
		shown_stats = wave_director.stats_for_display(live_stats)
	elif not final_stats.is_empty():
		shown_stats = final_stats
	var wave_spec: Dictionary = _current_wave_spec()
	return {
		"mode": &"tutorial",
		"wave_name": String(wave_spec.get("display_name", level.display_name)),
		"wave_index": maxi(current_wave_index + 1, 0),
		"completed_waves": completed_waves,
		"phase": _phase_name(),
		"remaining": _remaining_time(),
		"stats": shown_stats,
		"target_utilization": float(wave_spec.get("target_utilization", 0.0)),
		"target_reached": (state == State.WAVE_1 or state == State.WAVE_2) and wave_director.target_latched,
		"warnings": wave_director.latest_warnings if state == State.WAVE_1 or state == State.WAVE_2 else {},
		"result": result,
		"terminal": is_terminal(),
		"alive_enemies": enemy_manager.alive_count(),
		"tutorial_phase": _tutorial_phase_name(),
		"instruction_key": _instruction_key(),
		"world_cues": _world_cues(),
		"debug": diagnostic_snapshot(),
	}


func should_simulate_enemies() -> bool:
	return (state == State.WAVE_1 or state == State.WAVE_2) and wave_director.combat_active()


func is_terminal() -> bool:
	return state == State.FINISHED or state == State.FAILED


func completion_snapshot() -> Dictionary:
	return {
		"result": result,
		"utilization": float(final_stats.get("utilization", 0.0)),
		"completed_waves": completed_waves,
		"reason": result,
	}


func _start_wave(index: int) -> void:
	var waves: Array = level.waves
	if index < 0 or index >= waves.size() or waves[index] is not Dictionary:
		_fail(&"invalid_level", _last_live_stats)
		return
	current_wave_index = index
	if not wave_director.start_spec(StringName("diode_tutorial_%d" % (index + 1)), waves[index]):
		_fail(&"invalid_level", _last_live_stats)
		return
	state = State.WAVE_1 if index == 0 else State.WAVE_2
	phase_remaining = 0.0


func _on_target_reached() -> void:
	if state != State.WAVE_1 and state != State.WAVE_2:
		return
	final_stats = wave_director.final_stats.duplicate(true)
	target_reached.emit(current_wave_index + 1)


func _on_wave_finished(wave_result: StringName) -> void:
	if wave_result != &"success":
		_fail(wave_result, wave_director.final_stats)
		return
	if state != State.WAVE_1 and state != State.WAVE_2:
		return
	completed_waves = current_wave_index + 1
	final_stats = wave_director.final_stats.duplicate(true)
	wave_finished.emit(current_wave_index + 1, wave_result)
	if state == State.WAVE_1:
		state = State.INTERMISSION
		phase_remaining = float(level.intermission_seconds)
		return
	state = State.FINISHED
	result = &"success"
	run_finished.emit(result)


func _fail(reason: StringName, stats: Dictionary) -> void:
	if is_terminal():
		return
	result = reason
	final_stats = stats.duplicate(true)
	state = State.FAILED
	run_finished.emit(reason)


func _current_wave_spec() -> Dictionary:
	var waves: Array = level.waves
	if current_wave_index >= 0 and current_wave_index < waves.size() and waves[current_wave_index] is Dictionary:
		return waves[current_wave_index]
	return {}


func _remaining_time() -> float:
	if state == State.OBSERVE_SOURCE or state == State.INTERMISSION:
		return phase_remaining
	if state == State.WAVE_1 or state == State.WAVE_2:
		return wave_director.remaining_time()
	return 0.0


func _phase_name() -> StringName:
	match state:
		State.WAVE_1, State.WAVE_2:
			match wave_director.state:
				WaveDirector.State.TARGET_REACHED: return &"clearing"
				WaveDirector.State.FAILED: return &"failed"
				_: return &"active"
		State.INTERMISSION: return &"intermission"
		State.FINISHED: return &"finished"
		State.FAILED: return &"failed"
		_: return &"tutorial"


func _tutorial_phase_name() -> StringName:
	match state:
		State.OBSERVE_SOURCE: return &"observe_source"
		State.PRACTICE_PLACE: return &"practice_place"
		State.PRACTICE_DISMANTLE: return &"practice_dismantle"
		State.ROUTE_BUILD: return &"route_build"
		State.INTERMISSION: return &"intermission"
		State.FINISHED: return &"finished"
		State.FAILED: return &"failed"
		_: return &"combat"


func _instruction_key() -> StringName:
	if not is_terminal() and current_wave_index >= 0:
		if not _auto_fire:
			return &"tower_stopped"
		if _route_lost:
			return _route_loss_key
		if _confirmation_remaining > 0.0:
			return _confirmation
		if wave_director.state == WaveDirector.State.TARGET_REACHED and should_simulate_enemies():
			return &"target_reached_clear"
	match state:
		State.OBSERVE_SOURCE: return &"observe_unique_path"
		State.PRACTICE_PLACE: return &"place_practice_diode"
		State.PRACTICE_DISMANTLE: return &"dismantle_practice_diode"
		State.ROUTE_BUILD: return &"build_north_route"
		State.INTERMISSION: return &"prepare_second_wave"
		State.FINISHED: return &"tutorial_complete"
		State.FAILED: return &"tutorial_failed"
		_: return &"defend_north"


func _world_cues() -> Array[Dictionary]:
	var radius := float(level.marker_radius)
	match state:
		State.OBSERVE_SOURCE:
			var muzzle := tower.position + Vector2(float(profile.value("tower/muzzle_offset", 34.0)), 0.0)
			return [{"kind": &"path", "from": muzzle, "to": muzzle + Vector2(level.path_hint_length, 0.0)}]
		State.PRACTICE_PLACE:
			return [
				_anchor_cue("practice_entry", "练习入口", radius),
				_anchor_cue("practice_exit", "练习出口", radius),
			]
		State.PRACTICE_DISMANTLE:
			if construction.devices.has(practice_device_id):
				var record: Dictionary = construction.devices[practice_device_id]
				return [{"kind": &"anchor", "position": record.get("position", Vector2.ZERO), "radius": radius, "label": "选中后按住拆除按钮"}]
		State.ROUTE_BUILD:
			var exit_position := _configured_position("route_exit")
			var angle := deg_to_rad(float(level.route_exit_angle_degrees))
			return [
				_anchor_cue("route_entry", "入口接入初始弹道", radius),
				{"kind": &"anchor", "position": exit_position, "radius": radius, "label": "出口移至北侧"},
				{"kind": &"direction", "from": exit_position, "to": exit_position + Vector2.RIGHT.rotated(angle) * level.direction_hint_length},
			]
	return []


func _anchor_cue(prefix: String, label: String, radius: float) -> Dictionary:
	return {"kind": &"anchor", "position": _configured_position(prefix), "radius": radius, "label": label}


func _configured_position(prefix: String) -> Vector2:
	return tower.position + level.position(prefix)


func _is_diode(device_id: int) -> bool:
	if not construction.devices.has(device_id):
		return false
	var definition := (construction.devices[device_id] as Dictionary).get("definition") as DeviceDefinition
	return definition != null and definition.kind == &"diode"


func _is_active_diode(device_id: int) -> bool:
	return _is_diode(device_id) and bool((construction.devices[device_id] as Dictionary).get("active", false))


func _is_valid_north_route(device_id: int) -> bool:
	if not _is_active_diode(device_id):
		return false
	var record: Dictionary = construction.devices[device_id]
	var exit_position: Vector2 = record.get("secondary_position", tower.position)
	var minimum_north_distance := level.route_min_north_distance
	if exit_position.y > tower.position.y - minimum_north_distance:
		return false
	var configured_angle := deg_to_rad(float(level.route_exit_angle_degrees))
	var actual_angle := float(record.get("secondary_angle_radians", 0.0))
	var tolerance := deg_to_rad(float(level.direction_tolerance_degrees))
	return absf(angle_difference(configured_angle, actual_angle)) <= tolerance

func needs_world_observation() -> bool:
	return not is_terminal()


func observe_world(delta: float, firing: bool, visible_enemies: int) -> void:
	if is_terminal():
		return
	_auto_fire = firing
	if not should_simulate_enemies() or not firing or visible_enemies <= 0:
		_no_damage_elapsed = 0.0
		if _confirmation == &"check_route_damage":
			_confirmation_remaining = 0.0
		return
	_no_damage_elapsed += delta
	_maximum_no_damage_elapsed = maxf(_maximum_no_damage_elapsed, _no_damage_elapsed)
	if _no_damage_elapsed >= level.no_damage_seconds and _reminder_remaining <= 0.0:
		_confirm(&"check_route_damage")
		_reminder_remaining = level.reminder_interval_seconds


func diagnostic_snapshot() -> Dictionary:
	return {
		"lesson_device": level.lesson_device, "elapsed": _elapsed,
		"first_activation_seconds": _first_activation_time, "first_hit_seconds": _first_hit_time,
		"damage_total": _damage_total, "no_damage_seconds": _no_damage_elapsed,
		"maximum_no_damage_seconds": _maximum_no_damage_elapsed,
		"device_losses": _device_losses, "route_device_id": route_device_id,
	}


func _confirm(key: StringName) -> void:
	_confirmation = key
	_confirmation_remaining = level.confirmation_seconds
