extends SceneTree

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")
const ConstructionControllerType := preload("res://scripts/prototype/construction_controller.gd")
const DeviceCatalogType := preload("res://scripts/prototype/device_catalog.gd")
const TowerControllerType := preload("res://scripts/combat/tower_controller.gd")
const EnemyManagerType := preload("res://scripts/combat/enemy_manager.gd")
const EndlessWaveGeneratorType := preload("res://scripts/combat/endless_wave_generator.gd")
const EndlessRunDirectorType := preload("res://scripts/combat/endless_run_director.gd")

var _failed := false


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	var profile := BalanceRepositoryType.load_profile()
	_check(profile != null, "endless tests require a valid balance profile")
	if profile == null:
		quit(1)
		return

	_test_generator(profile)
	_test_enemy_modifiers(profile)
	_test_spawn_backpressure(profile)
	_test_session_and_cross_wave_accounting(profile)
	_test_failure_precedence(profile)
	_test_twenty_wave_soak(profile)

	if not _failed:
		print("Endless mode tests passed: deterministic templates, capped growth, backpressure, session phases, cross-wave ledger, failure precedence and 20-wave soak")
	quit(1 if _failed else 0)


func _test_generator(profile: BalanceProfile) -> void:
	var generator := EndlessWaveGeneratorType.new(profile) as EndlessWaveGenerator
	var seed := int(profile.value("waves/endless/run_seed", 1))
	var expected := {1: "single_front", 2: "adjacent_split", 3: "opposite_pincer", 5: "three_front_staggered", 8: "four_front_pressure"}
	for wave_index in expected.keys():
		var spec := generator.generate(wave_index, seed)
		_check(String(spec.get("template_id", "")) == String(expected[wave_index]),
			"forced endless template must appear at wave %d" % wave_index)
		_check(spec == generator.generate(wave_index, seed),
			"same endless seed and wave index must generate identical specs")
	var wave_one := generator.generate(1, seed)
	var wave_twenty := generator.generate(20, seed)
	var wave_hundred := generator.generate(100, seed)
	_check(is_equal_approx(float(wave_one.target_utilization), 0.15)
			and float(wave_twenty.target_utilization) >= float(wave_one.target_utilization)
			and float(wave_hundred.target_utilization) <= 0.6,
			"endless utilization targets must grow monotonically and respect the cap")
	var modifiers: Dictionary = wave_hundred.enemy_modifiers
	_check(float(modifiers.hp_multiplier) <= 2.5 and float(modifiers.damage_multiplier) <= 2.0
			and float(modifiers.speed_multiplier) <= 1.25,
			"endless enemy growth must respect every configured cap")
	_check(_unique_directions(generator.generate(2, seed)).size() == 2
			and _unique_directions(generator.generate(3, seed)).size() == 2
			and _unique_directions(generator.generate(5, seed)).size() == 3
			and _unique_directions(generator.generate(8, seed)).size() == 4,
			"forced direction templates must expose their intended number of fronts")


func _test_enemy_modifiers(profile: BalanceProfile) -> void:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "enemy modifier simulation must initialize")
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var definition: EnemyDefinition = manager.definitions[&"dev_melee"]
	var definition_hp := definition.max_hp
	var enemy := manager.find_enemy(manager.spawn(&"dev_melee", &"east", {
		"hp_multiplier": 1.5, "damage_multiplier": 1.25, "speed_multiplier": 1.1,
	}))
	_check(is_equal_approx(enemy.max_hp, definition_hp * 1.5)
			and is_equal_approx(enemy.attack_damage, definition.attack_damage * 1.25)
			and is_equal_approx(enemy.move_speed, definition.move_speed * 1.1),
			"wave multipliers must live on each enemy runtime")
	_check(is_equal_approx(definition.max_hp, definition_hp),
			"wave multipliers must not mutate shared enemy definitions")


func _test_spawn_backpressure(source_profile: BalanceProfile) -> void:
	var profile := _fast_profile(source_profile)
	profile.set_value("waves/endless/max_active_enemy_guard", 1)
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "spawn backpressure simulation must initialize")
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var session := EndlessRunDirectorType.new(profile, manager, simulation, tower) as EndlessRunDirector
	session.start()
	manager.spawn(&"dev_melee", &"east")
	session.advance(0.02)
	session.advance(0.01)
	var debug: Dictionary = session.hud_snapshot({}).debug
	_check(manager.alive_count() == 1 and bool(debug.spawn_backpressure_active)
			and int(debug.spawn_backpressure_deferred) > 0,
			"the active-enemy engineering guard must defer spawns and expose F3 diagnostics without deletion")


func _test_session_and_cross_wave_accounting(source_profile: BalanceProfile) -> void:
	var profile := _fast_profile(source_profile)
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "endless session simulation must initialize")
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var catalog := DeviceCatalogType.new(profile) as DeviceCatalog
	var device_id := construction.place(catalog.get_definition(&"bounce_plate"), Vector2(500.0, 500.0))
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var session := EndlessRunDirectorType.new(profile, manager, simulation, tower) as EndlessRunDirector
	_check(session.start() and session.state == EndlessRunDirector.State.PREPARING
			and not session.should_simulate_enemies(),
			"endless run must begin in a real-time enemy-free preparation phase")
	session.advance(0.02)
	_check(session.state == EndlessRunDirector.State.ACTIVE and session.wave_index == 1,
			"preparation expiry must begin wave one without rebuilding the world")
	session.advance(0.01)
	_check(manager.alive_count() > 0, "active endless wave must spawn its generated groups")
	session.evaluate({"utilization": 1.0, "damage_dealt": 24.0, "tower_source_momentum": 24.0})
	_check(session.state == EndlessRunDirector.State.CLEARING and session.should_simulate_enemies(),
			"target reach must stop spawning while living enemies keep acting")
	session.advance(0.001)
	_check(session.state == EndlessRunDirector.State.CLEARING,
			"clearing must not finish while any spawned enemy remains alive")
	for enemy in manager.enemies:
		enemy.alive = false
	manager.update(0.0, true)
	session.advance(0.001)
	_check(session.state == EndlessRunDirector.State.INTERMISSION and session.completed_waves == 1,
			"an empty battlefield after target reach must enter real-time intermission")

	simulation.native.emit_projectiles([{
		"position": Vector2.ZERO, "velocity": Vector2(1000.0, 0.0), "mass": 0.02,
		"entropy": 0.0, "tower_source": false,
	}, {
		"position": Vector2(0.0, 1000.0), "velocity": Vector2(240.0, 0.0), "mass": 0.05,
		"entropy": 0.0, "tower_source": true,
	}])
	var entities_before := int(simulation.native.get_stats().projectile_count)
	_check(float(simulation.native.get_stats().tower_source_momentum) > 0.0,
			"intermission tower emissions must exist before the next ledger reset")
	session.advance(0.02)
	var reset_stats: Dictionary = simulation.native.get_stats()
	_check(session.wave_index == 2 and session.state == EndlessRunDirector.State.ACTIVE
			and is_zero_approx(float(reset_stats.tower_source_momentum))
			and int(reset_stats.projectile_count) == entities_before
			and construction.devices.has(device_id),
			"next wave must reset only its ledger while preserving devices and nonzero entities")

	var enemy := manager.find_enemy(manager.spawn(&"dev_melee", &"east"))
	enemy.position = Vector2(30.0, 0.0)
	manager.sync_native_proxies()
	for _step in 5:
		simulation.native.step(1.0 / 120.0)
	var carry_stats: Dictionary = simulation.native.get_stats()
	_check(float(carry_stats.damage_dealt) > 0.0 and is_zero_approx(float(carry_stats.tower_source_momentum)),
			"carry-over projectile damage must enter the new numerator without historical source momentum")


func _test_failure_precedence(source_profile: BalanceProfile) -> void:
	var profile := _fast_profile(source_profile)
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "failure precedence simulation must initialize")
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var session := EndlessRunDirectorType.new(profile, manager, simulation, tower) as EndlessRunDirector
	session.start()
	session.advance(0.02)
	tower.hp = 0.0
	session.evaluate({"utilization": 1.0, "damage_dealt": 10.0, "tower_source_momentum": 10.0})
	_check(session.state == EndlessRunDirector.State.FAILED and session.result == &"tower_destroyed",
			"tower destruction must beat target reach on the same endless frame")

	var timeout_tower := TowerControllerType.new(profile) as TowerController
	var timeout_manager := EnemyManagerType.new(profile, simulation, construction, timeout_tower) as EnemyManager
	var timeout_session := EndlessRunDirectorType.new(profile, timeout_manager, simulation, timeout_tower) as EndlessRunDirector
	timeout_session.start()
	timeout_session.advance(0.02)
	timeout_session.advance(1.0)
	timeout_session.evaluate({"utilization": 0.0})
	_check(timeout_session.state == EndlessRunDirector.State.FAILED and timeout_session.result == &"timeout",
			"missing the utilization target by the deadline must end the endless run")


func _test_twenty_wave_soak(source_profile: BalanceProfile) -> void:
	var profile := _fast_profile(source_profile)
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "20-wave soak simulation must initialize")
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var session := EndlessRunDirectorType.new(profile, manager, simulation, tower) as EndlessRunDirector
	session.start()
	session.advance(0.02)
	for expected_wave in range(1, 21):
		_check(session.wave_index == expected_wave and session.state == EndlessRunDirector.State.ACTIVE,
			"accelerated soak must begin expected wave %d" % expected_wave)
		session.evaluate({"utilization": 10.0, "damage_dealt": 120.0, "tower_source_momentum": 12.0})
		for enemy in manager.enemies:
			enemy.alive = false
		manager.update(0.0, true)
		session.advance(0.001)
		_check(session.state == EndlessRunDirector.State.INTERMISSION,
			"accelerated soak must enter intermission after wave %d" % expected_wave)
		if expected_wave < 20:
			session.advance(0.02)
	_check(session.completed_waves == 20 and not session.is_terminal(),
			"20-wave accelerated soak must preserve the run without failure")


func _fast_profile(source: BalanceProfile) -> BalanceProfile:
	var profile := source.duplicate_profile()
	profile.set_value("waves/endless/opening_preparation_seconds", 0.01)
	profile.set_value("waves/endless/intermission_seconds", 0.01)
	profile.set_value("waves/endless/wave_duration_seconds", 0.05)
	profile.set_value("waves/endless/spawn_start_ratio", 0.0)
	profile.set_value("waves/endless/spawn_end_ratio", 0.5)
	return profile


func _unique_directions(spec: Dictionary) -> Dictionary:
	var directions := {}
	for group: Dictionary in spec.get("groups", []):
		directions[String(group.get("direction", ""))] = true
	return directions
