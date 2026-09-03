class_name SingleWaveSession
extends CombatSessionDirector

const WaveDirectorType := preload("res://scripts/combat/wave_director.gd")

var wave_director: WaveDirector
var configured_wave_id: StringName


func _init(
		profile: BalanceProfile,
		manager: EnemyManager,
		simulation: SimulationController,
		tower: TowerController,
		wave_id: StringName = &"dev_wave_01"
) -> void:
	configured_wave_id = wave_id
	wave_director = WaveDirectorType.new(profile, manager, simulation, tower) as WaveDirector
	wave_director.target_reached.connect(func(): target_reached.emit(1))
	wave_director.wave_finished.connect(func(result: StringName):
		wave_finished.emit(1, result)
		if result != &"success":
			run_finished.emit(result)
	)


func start() -> bool:
	return wave_director.start(configured_wave_id)


func advance(delta: float) -> void:
	wave_director.update_before_simulation(delta)


func evaluate(stats: Dictionary) -> void:
	wave_director.evaluate_after_simulation(stats)


func hud_snapshot(live_stats: Dictionary) -> Dictionary:
	return {
		"mode": &"single_wave",
		"wave_name": wave_director.display_name(),
		"wave_index": 1,
		"completed_waves": 1 if wave_director.result == &"success" else 0,
		"phase": _phase_name(),
		"remaining": wave_director.remaining_time(),
		"stats": wave_director.stats_for_display(live_stats),
		"target_utilization": wave_director.target_utilization,
		"target_reached": wave_director.target_latched,
		"warnings": wave_director.latest_warnings,
		"result": wave_director.result,
		"terminal": wave_director.is_terminal(),
		"alive_enemies": wave_director.enemy_manager.alive_count(),
		"debug": wave_director.debug_snapshot(),
	}


func should_simulate_enemies() -> bool:
	return wave_director.combat_active()


func is_terminal() -> bool:
	return wave_director.is_terminal()


func _phase_name() -> StringName:
	match wave_director.state:
		WaveDirector.State.ACTIVE: return &"active"
		WaveDirector.State.TARGET_REACHED: return &"clearing"
		WaveDirector.State.FINISHED: return &"finished"
		WaveDirector.State.FAILED: return &"failed"
		_: return &"idle"
