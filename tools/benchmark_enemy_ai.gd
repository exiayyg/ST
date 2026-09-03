extends SceneTree

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")
const ConstructionControllerType := preload("res://scripts/prototype/construction_controller.gd")
const DeviceCatalogType := preload("res://scripts/prototype/device_catalog.gd")
const TowerControllerType := preload("res://scripts/combat/tower_controller.gd")
const EnemyManagerType := preload("res://scripts/combat/enemy_manager.gd")

const PERFORMANCE_ENEMIES := 300
const STRESS_ENEMIES := 1000
const DEVICE_COUNT := 100
const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 180


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile := BalanceRepositoryType.load_profile()
	if profile == null:
		quit(1)
		return
	var result := _measure(profile, PERFORMANCE_ENEMIES, SAMPLE_FRAMES)
	var stress := _measure(profile, STRESS_ENEMIES, 30)
	print("enemy_ai enemies=%d devices=%d samples=%d p50_ms=%.3f p95_ms=%.3f max_ms=%.3f stress_enemies=%d stress_max_ms=%.3f" % [
		PERFORMANCE_ENEMIES, DEVICE_COUNT, SAMPLE_FRAMES, result.p50, result.p95, result.maximum,
		STRESS_ENEMIES, stress.maximum,
	])
	if float(result.p95) > 2.0:
		push_error("300-enemy GDScript AI p95 exceeded the 2 ms budget")
		quit(2)
		return
	quit()


func _measure(profile: BalanceProfile, enemy_count: int, samples: int) -> Dictionary:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	if not simulation.initialize():
		return {"p50": INF, "p95": INF, "maximum": INF}
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var catalog := DeviceCatalogType.new(profile) as DeviceCatalog
	var definition := catalog.get_definition(&"bounce_plate")
	for index in DEVICE_COUNT:
		var column := index % 10
		var row := index / 10
		construction.place(definition, Vector2(-900.0 + column * 200.0, -700.0 + row * 150.0))
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var directions := [&"east", &"south", &"west", &"north"]
	for index in enemy_count:
		manager.spawn(&"dev_melee" if index % 3 != 0 else &"dev_ranged", directions[index % directions.size()])
	for _frame in WARMUP_FRAMES:
		manager.update(1.0 / 60.0, true)
	var timings: Array[float] = []
	for _frame in samples:
		var started := Time.get_ticks_usec()
		manager.update(1.0 / 60.0, true)
		timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
	timings.sort()
	return {
		"p50": timings[int(floor(float(timings.size() - 1) * 0.50))],
		"p95": timings[int(floor(float(timings.size() - 1) * 0.95))],
		"maximum": timings[-1],
	}
