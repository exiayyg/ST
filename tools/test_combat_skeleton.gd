extends SceneTree

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")
const ConstructionControllerType := preload("res://scripts/prototype/construction_controller.gd")
const DeviceCatalogType := preload("res://scripts/prototype/device_catalog.gd")
const TowerControllerType := preload("res://scripts/combat/tower_controller.gd")
const EnemyManagerType := preload("res://scripts/combat/enemy_manager.gd")
const WaveDirectorType := preload("res://scripts/combat/wave_director.gd")
const CombatHudType := preload("res://scripts/combat/combat_hud.gd")

var _failed := false
var _reached_count := 0
var _finished_count := 0
var _failure_result: StringName
var _restart_count := 0
var _return_count := 0


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	var profile := BalanceRepositoryType.load_profile()
	_check(profile != null, "combat test requires a valid balance profile")
	if profile == null:
		quit(1)
		return

	var proxy_profile := profile.duplicate_profile()
	proxy_profile.set_value("enemies/dev_melee/radius", 4.0)
	proxy_profile.set_value("enemies/dev_melee/momentum_absorption", 0.5)
	proxy_profile.set_value("enemies/dev_melee/damage_per_momentum", 1.0)
	proxy_profile.set_value("enemies/dev_melee/entropy_transfer_ratio", 0.25)
	var simulation := SimulationControllerType.new(proxy_profile) as SimulationController
	_check(simulation.initialize(), "native simulation must initialize from BalanceProfile")
	var construction := ConstructionControllerType.new(simulation) as ConstructionController
	var tower := TowerControllerType.new(proxy_profile) as TowerController
	var manager := EnemyManagerType.new(proxy_profile, simulation, construction, tower) as EnemyManager
	var enemy_id := manager.spawn(&"dev_melee", &"east")
	var enemy := manager.find_enemy(enemy_id)
	enemy.position = Vector2(30.0, 0.0)
	_check(manager.sync_native_proxies(), "enemy proxy batch must synchronize")
	simulation.native.emit_projectiles([{
		"position": Vector2.ZERO, "velocity": Vector2(1000.0, 0.0),
		"mass": 0.02, "entropy": 60.0,
	}])
	for _step in 5:
		simulation.native.step(1.0 / 120.0)
	var events: Array = simulation.native.consume_events()
	var hit_events := events.filter(func(event: Dictionary): return event.get("type") == "enemy_hit")
	for event in events:
		manager.apply_native_event(event)
	_check(hit_events.size() == 1, "swept enemy proxy collision must emit one enemy_hit")
	if hit_events.size() == 1:
		_check(is_equal_approx(float(hit_events[0].damage), 10.0), "actual enemy damage must use transferred momentum")
		_check(is_equal_approx(float(hit_events[0].entropy_transferred), float(hit_events[0].source_entropy) * 0.25), "enemy entropy transfer must be independent of damage")
	_check(is_equal_approx(enemy.hp, 50.0) and enemy.entropy > 15.0,
			"GDScript enemy HP and entropy must consume native events")
	var projectile_snapshot: Dictionary = simulation.native.get_projectile_snapshot()
	_check(projectile_snapshot.masses.size() == 1 and
			is_equal_approx(float(projectile_snapshot.masses[0]) * (projectile_snapshot.velocities[0] as Vector2).length(), 10.0),
			"enemy hit must preserve untransferred projectile momentum")
	manager.clear_native_proxies()
	_check(int(simulation.native.get_stats().enemy_proxy_count) == 0,
			"suspending combat must remove every native enemy collision proxy")

	var attack_profile := profile.duplicate_profile()
	attack_profile.set_value("enemies/dev_melee/move_speed", 0.0)
	attack_profile.set_value("enemies/dev_melee/attack_range", 100.0)
	attack_profile.set_value("enemies/dev_melee/attack_interval", 0.1)
	attack_profile.set_value("enemies/dev_melee/attack_damage", 25.0)
	var attack_simulation := SimulationControllerType.new(attack_profile) as SimulationController
	_check(attack_simulation.initialize(), "device attack simulation must initialize")
	var attack_construction := ConstructionControllerType.new(attack_simulation) as ConstructionController
	var attack_catalog := DeviceCatalogType.new(attack_profile) as DeviceCatalog
	var device_id := attack_construction.place(attack_catalog.get_definition(&"speed_increaser"), Vector2(50.0, 0.0))
	var attack_tower := TowerControllerType.new(attack_profile) as TowerController
	var attack_manager := EnemyManagerType.new(attack_profile, attack_simulation, attack_construction, attack_tower) as EnemyManager
	var attacker := attack_manager.find_enemy(attack_manager.spawn(&"dev_melee", &"east"))
	attacker.position = Vector2(100.0, 0.0)
	var lighting_changed := false
	for _attack in 5:
		lighting_changed = attack_manager.update(0.1, true) or lighting_changed
	_check(lighting_changed and not attack_construction.devices.has(device_id),
			"enemy melee attacks must remove a depleted device from native mechanics and lighting registry")
	var diode_id := attack_construction.place(
		attack_catalog.get_definition(&"diode"), Vector2(20.0, 20.0), 0.0, Vector2(80.0, 20.0), 0.0
	)
	attack_construction.damage_device(diode_id, 1000.0)
	_check(not attack_construction.devices.has(diode_id) and attack_construction.destruction_effects.size() == 3,
			"destroying a diode must remove the paired device and show destruction at both anchors")
	var flash_id := attack_construction.place(
		attack_catalog.get_definition(&"bounce_plate"), Vector2(20.0, 80.0)
	)
	attack_construction.damage_device(flash_id, 1.0)
	_check(float((attack_construction.devices[flash_id] as Dictionary).hit_flash_remaining) > 0.0,
			"a surviving device hit must produce configurable world-space hit feedback")
	attack_construction.advance_effects(1.0)
	_check(is_zero_approx(float((attack_construction.devices[flash_id] as Dictionary).hit_flash_remaining)),
			"device hit feedback must expire without changing HP or mechanics")

	var ranged_profile := profile.duplicate_profile()
	ranged_profile.set_value("enemies/dev_ranged/move_speed", 0.0)
	ranged_profile.set_value("enemies/dev_ranged/attack_interval", 0.1)
	ranged_profile.set_value("enemies/dev_ranged/ranged_charge_seconds", 0.1)
	var ranged_simulation := SimulationControllerType.new(ranged_profile) as SimulationController
	_check(ranged_simulation.initialize(), "ranged attack simulation must initialize")
	var ranged_construction := ConstructionControllerType.new(ranged_simulation) as ConstructionController
	var ranged_tower := TowerControllerType.new(ranged_profile) as TowerController
	var ranged_manager := EnemyManagerType.new(ranged_profile, ranged_simulation, ranged_construction, ranged_tower) as EnemyManager
	var ranged_enemy := ranged_manager.find_enemy(ranged_manager.spawn(&"dev_ranged", &"east"))
	ranged_enemy.position = Vector2(200.0, 0.0)
	var tower_hp_before := ranged_tower.hp
	ranged_manager.update(0.1, true)
	_check(ranged_enemy.charge_remaining > 0.0 and ranged_tower.hp == tower_hp_before,
			"ranged enemy must enter a visible charge state before ray damage")
	ranged_manager.update(0.05, true)
	_check(ranged_tower.hp == tower_hp_before, "ranged charge must not deal early damage")
	ranged_manager.update(0.051, true)
	_check(ranged_tower.hp < tower_hp_before and not ranged_manager.tracers.is_empty(),
			"completed ranged charge must perform ray hit and create a presentation-only tracer")

	ranged_manager.tracers.clear()
	ranged_enemy.entropy = 49.999
	ranged_manager.call("_ranged_attack", ranged_enemy, ranged_tower.position)
	var below_endpoint: Vector2 = ranged_manager.tracers[-1].to
	ranged_manager.tracers.clear()
	ranged_enemy.entropy = 50.0
	ranged_manager.call("_ranged_attack", ranged_enemy, ranged_tower.position)
	var threshold_endpoint: Vector2 = ranged_manager.tracers[-1].to
	_check(absf(below_endpoint.y) <= 0.00001 and absf(threshold_endpoint.y) <= 0.00001,
			"enemy aim must remain completely accurate at and below the shared entropy threshold")

	var wave_tower := TowerControllerType.new(profile) as TowerController
	var wave_director := WaveDirectorType.new(profile, manager, simulation, wave_tower) as WaveDirector
	_reached_count = 0
	_finished_count = 0
	wave_director.target_reached.connect(func(): _reached_count += 1)
	wave_director.wave_finished.connect(func(_result): _finished_count += 1)
	_check(wave_director.start(&"dev_wave_01"), "development wave must start")
	_check(wave_director.latest_warnings.has("east") and
			int(wave_director.latest_warnings.east.types.dev_melee) == 8,
			"direction warning must expose exact development enemy name and remaining count")
	var warning_hud := CombatHudType.new() as CombatHud
	root.add_child(warning_hud)
	warning_hud.configure(profile, manager.definitions)
	warning_hud.set_state(wave_director, {"utilization": 0.0}, wave_tower)
	var warning_event := InputEventMouseButton.new()
	warning_event.button_index = MOUSE_BUTTON_LEFT
	warning_event.pressed = true
	var warning_rect: Rect2 = warning_hud.call("_warning_rect", "east")
	warning_event.position = warning_rect.get_center()
	warning_hud._gui_input(warning_event)
	_check(warning_hud.selected_direction == "east",
			"clicking a direction warning must open its exact enemy roster")
	warning_hud.free()
	var reached_stats := {"utilization": 1.0, "damage_dealt": 24.0, "tower_source_momentum": 24.0}
	wave_director.evaluate_after_simulation(reached_stats)
	_check(wave_director.state == WaveDirector.State.TARGET_REACHED and _reached_count == 1 and _finished_count == 0,
			"TargetReached must be distinct and precede WaveFinished")
	_check(float(wave_director.stats_for_display({"utilization": 9.0}).utilization) == 1.0,
			"target reach must freeze the wave ledger before residual projectiles can change settlement values")
	wave_director.update_before_simulation(0.016)
	_check(wave_director.state == WaveDirector.State.FINISHED and _finished_count == 1,
			"immediate finish policy must emit WaveFinished on the next frame")

	var hud := CombatHudType.new() as CombatHud
	root.add_child(hud)
	hud.configure(profile, manager.definitions)
	hud.set_state(wave_director, wave_director.stats_for_display({"utilization": 9.0}), wave_tower)
	_restart_count = 0
	hud.restart_requested.connect(func(): _restart_count += 1)
	hud.return_requested.connect(func(): _return_count += 1)
	var restart_event := InputEventMouseButton.new()
	restart_event.button_index = MOUSE_BUTTON_LEFT
	restart_event.pressed = true
	var restart_rect: Rect2 = hud.call("_settlement_button_rect", hud.get_viewport_rect().size)
	restart_event.position = restart_rect.get_center()
	hud._gui_input(restart_event)
	_check(hud.terminal and _restart_count == 1,
			"terminal settlement must expose a clickable restart action")
	hud.set_campaign_navigation(true)
	var return_event := InputEventMouseButton.new()
	return_event.button_index = MOUSE_BUTTON_LEFT
	return_event.pressed = true
	var return_rect: Rect2 = hud.call("_settlement_return_button_rect", hud.get_viewport_rect().size)
	return_event.position = return_rect.get_center()
	hud._gui_input(return_event)
	_check(_return_count == 1, "campaign settlement must expose a separate return-to-level-select action")
	hud.request_default_terminal_action()
	_check(_return_count == 2 and _restart_count == 1,
			"successful campaign settlement must default Enter to return rather than replay")
	hud.free()

	var failed_tower := TowerControllerType.new(profile) as TowerController
	var failed_director := WaveDirectorType.new(profile, manager, simulation, failed_tower) as WaveDirector
	_failure_result = &""
	failed_director.wave_finished.connect(func(value): _failure_result = value)
	failed_director.start(&"dev_wave_01")
	failed_tower.hp = 0.0
	failed_director.evaluate_after_simulation({"utilization": 1.0, "damage_dealt": 5.0, "tower_source_momentum": 10.0})
	_check(failed_director.state == WaveDirector.State.FAILED and _failure_result == &"tower_destroyed",
			"tower destruction must win over target utilization on the same frame")
	_check(is_equal_approx(float(failed_director.final_stats.utilization), 1.0),
			"failure settlement must preserve the final ledger from the decisive frame")

	if not _failed:
		print("Combat vertical-slice tests passed: ledger freeze, proxy suspension, paired destruction, hit feedback, settlement navigation and wave ordering")
	quit(1 if _failed else 0)
