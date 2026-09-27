class_name EndlessRunDirector
extends CombatSessionDirector

const WaveDirectorType := preload("res://scripts/combat/wave_director.gd")
const EndlessWaveGeneratorType := preload("res://scripts/combat/endless_wave_generator.gd")

enum State { PREPARING, ACTIVE, CLEARING, INTERMISSION, FAILED }

var profile: BalanceProfile
var enemy_manager: EnemyManager
var simulation: SimulationController
var tower: TowerController
var generator: EndlessWaveGenerator
var wave_director: WaveDirector
var state := State.PREPARING
var wave_index := 0
var completed_waves := 0
var run_seed := 0
var phase_remaining := 0.0
var result: StringName
var pending_spec: Dictionary = {}
var final_stats: Dictionary = {}
var _last_live_stats: Dictionary = {}


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
	generator = EndlessWaveGeneratorType.new(profile) as EndlessWaveGenerator
	wave_director = WaveDirectorType.new(profile, enemy_manager, simulation, tower) as WaveDirector
	wave_director.target_reached.connect(_on_target_reached)
	wave_director.wave_finished.connect(_on_wave_finished)


func start() -> bool:
	result = &""
	wave_index = 0
	completed_waves = 0
	final_stats.clear()
	_last_live_stats.clear()
	run_seed = _resolve_run_seed()
	pending_spec = generator.generate(1, run_seed)
	if pending_spec.is_empty():
		return false
	state = State.PREPARING
	phase_remaining = float(profile.value("waves/endless/opening_preparation_seconds", 20.0))
	return true


func advance(delta: float) -> void:
	if state == State.FAILED:
		return
	if tower.is_destroyed():
		_fail(&"tower_destroyed", _last_live_stats)
		return
	match state:
		State.PREPARING, State.INTERMISSION:
			phase_remaining = maxf(0.0, phase_remaining - delta)
			if phase_remaining <= 0.0:
				_start_next_wave()
		State.ACTIVE, State.CLEARING:
			wave_director.update_before_simulation(delta)


func evaluate(stats: Dictionary) -> void:
	if state == State.FAILED:
		return
	_last_live_stats = stats.duplicate(true)
	if tower.is_destroyed():
		_fail(&"tower_destroyed", stats)
		return
	if state == State.ACTIVE or state == State.CLEARING:
		wave_director.evaluate_after_simulation(stats)


func hud_snapshot(live_stats: Dictionary) -> Dictionary:
	var spec := wave_director.wave if wave_index > 0 else pending_spec
	var shown_stats := live_stats
	if state == State.ACTIVE or state == State.CLEARING:
		shown_stats = wave_director.stats_for_display(live_stats)
	elif not final_stats.is_empty():
		shown_stats = final_stats
	var debug := wave_director.debug_snapshot() if wave_index > 0 else {}
	debug.merge({
		"run_seed": run_seed,
		"template_id": String(spec.get("template_id", "")),
		"threat_budget": float(spec.get("threat_budget", 0.0)),
		"hp_multiplier": float((spec.get("enemy_modifiers", {}) as Dictionary).get("hp_multiplier", 1.0)),
		"damage_multiplier": float((spec.get("enemy_modifiers", {}) as Dictionary).get("damage_multiplier", 1.0)),
		"speed_multiplier": float((spec.get("enemy_modifiers", {}) as Dictionary).get("speed_multiplier", 1.0)),
	}, true)
	return {
		"mode": &"endless",
		"wave_name": String(spec.get("display_name", "DEV 无尽模式")),
		"wave_index": maxi(1, wave_index),
		"completed_waves": completed_waves,
		"phase": _phase_name(),
		"remaining": _remaining_time(),
		"stats": shown_stats,
		"target_utilization": float(spec.get("target_utilization", 0.0)),
		"target_reached": state == State.CLEARING or state == State.INTERMISSION,
		"warnings": wave_director.latest_warnings if state == State.ACTIVE else {},
		"result": result,
		"terminal": state == State.FAILED,
		"alive_enemies": enemy_manager.alive_count(),
		"debug": debug,
	}


func should_simulate_enemies() -> bool:
	return state == State.ACTIVE or state == State.CLEARING


func is_terminal() -> bool:
	return state == State.FAILED


func completion_snapshot() -> Dictionary:
	return {
		"result": result,
		"utilization": float(final_stats.get("utilization", 0.0)),
		"completed_waves": completed_waves,
		"reason": result,
	}


func _start_next_wave() -> void:
	wave_index += 1
	var spec := pending_spec.duplicate(true) if int(pending_spec.get("wave_index", 0)) == wave_index else generator.generate(wave_index, run_seed)
	pending_spec.clear()
	if spec.is_empty() or not wave_director.start_spec(StringName("endless_%04d" % wave_index), spec):
		_fail(&"invalid_wave", _last_live_stats)
		return
	state = State.ACTIVE
	phase_remaining = 0.0


func _on_target_reached() -> void:
	if state != State.ACTIVE:
		return
	state = State.CLEARING
	final_stats = wave_director.final_stats.duplicate(true)
	target_reached.emit(wave_index)


func _on_wave_finished(wave_result: StringName) -> void:
	if wave_result != &"success":
		_fail(wave_result, wave_director.final_stats)
		return
	if state != State.CLEARING:
		return
	completed_waves = wave_index
	final_stats = wave_director.final_stats.duplicate(true)
	wave_finished.emit(wave_index, wave_result)
	pending_spec = generator.generate(wave_index + 1, run_seed)
	state = State.INTERMISSION
	phase_remaining = float(profile.value("waves/endless/intermission_seconds", 15.0))


func _fail(reason: StringName, stats: Dictionary) -> void:
	if state == State.FAILED:
		return
	result = reason
	final_stats = stats.duplicate(true)
	state = State.FAILED
	run_finished.emit(reason)


func _remaining_time() -> float:
	if state == State.PREPARING or state == State.INTERMISSION:
		return phase_remaining
	if state == State.ACTIVE:
		return wave_director.remaining_time()
	return 0.0


func _phase_name() -> StringName:
	match state:
		State.PREPARING: return &"preparing"
		State.ACTIVE: return &"active"
		State.CLEARING: return &"clearing"
		State.INTERMISSION: return &"intermission"
		_: return &"failed"


func _resolve_run_seed() -> int:
	var configured := int(profile.value("waves/endless/run_seed", 20260901))
	if String(profile.value("waves/endless/seed_mode", "fixed")) == "random_each_run":
		return int(Time.get_ticks_usec() % 2147483647)
	return configured
