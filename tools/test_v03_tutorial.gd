extends Node

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")
const ConstructionControllerType := preload("res://scripts/prototype/construction_controller.gd")
const DeviceCatalogType := preload("res://scripts/prototype/device_catalog.gd")
const TowerControllerType := preload("res://scripts/combat/tower_controller.gd")
const EnemyManagerType := preload("res://scripts/combat/enemy_manager.gd")
const TutorialSessionType := preload("res://scripts/combat/diode_tutorial_session.gd")
const PrototypeScene := preload("res://scenes/prototype/momentum_prototype.tscn")

var _failed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	var profile := BalanceRepositoryType.load_profile()
	_check(profile != null and profile.validate().is_empty(), "schema v3 profile must load for v0.3 tests")
	if profile == null:
		get_tree().quit(1)
		return
	_test_unique_tower_path(profile)
	_test_tower_source_uses_device_entropy(profile)
	_test_dismantle_contract(profile)
	_test_accumulator_dismantle_discards_native_store(profile)
	_test_diode_teleport_effect(profile)
	await _test_dismantle_hold(profile)
	_test_tutorial_flow(profile)
	_test_tutorial_failures(profile)
	if not _failed:
		print("v0.3 tests passed: unique source path, deliberate dismantle and diode tutorial flow")
	get_tree().quit(1 if _failed else 0)


func _test_unique_tower_path(profile: BalanceProfile) -> void:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "tower path simulation must initialize")
	var tower_position := Vector2(11.0, 23.0)
	for _index in 4:
		simulation.emit_tower_projectile(tower_position)
	var before: Dictionary = simulation.native.get_projectile_snapshot()
	var positions: PackedVector2Array = before.positions
	var velocities: PackedVector2Array = before.velocities
	var expected := tower_position + Vector2(float(profile.value("tower/muzzle_offset", 34.0)), 0.0)
	_check(positions.size() == 4 and velocities.size() == 4, "repeated tower fire must create every requested projectile")
	for index in positions.size():
		_check(positions[index].distance_to(expected) < 0.000001,
				"every tower projectile must start at the same fixed muzzle point")
		_check(velocities[index].distance_to(Vector2(float(profile.value("tower/projectile_speed", 240.0)), 0.0)) < 0.000001,
				"every tower projectile must start with the same fixed direction")
	simulation.step(1.0 / 30.0)
	var after_positions: PackedVector2Array = simulation.native.get_projectile_snapshot().positions
	for index in range(1, after_positions.size()):
		_check(after_positions[index].distance_to(after_positions[0]) < 0.000001,
				"tower projectiles must remain on one coincident path before device interaction")

	var entropy_simulation := MomentumSimulation.new()
	_check(entropy_simulation.configure({
		"fixed_step_seconds": 1.0 / 120.0,
		"max_substeps": 120,
		"entropy_per_second": 100.0,
		"entropy_start": 50.0,
		"entropy_full_effect": 100.0,
		"entropy_curve": [{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
	}), "entropy free-flight simulation must initialize")
	entropy_simulation.emit_projectiles([
		{"position": Vector2.ZERO, "velocity": Vector2(240.0, 0.0), "mass": 0.05, "entropy": 0.0},
		{"position": Vector2.ZERO, "velocity": Vector2(240.0, 0.0), "mass": 0.05, "entropy": 100.0},
	])
	entropy_simulation.step(0.5)
	var entropy_snapshot: Dictionary = entropy_simulation.get_projectile_snapshot()
	_check((entropy_snapshot.positions as PackedVector2Array)[0].distance_to((entropy_snapshot.positions as PackedVector2Array)[1]) < 0.000001
			and (entropy_snapshot.velocities as PackedVector2Array)[0].distance_to((entropy_snapshot.velocities as PackedVector2Array)[1]) < 0.000001,
			"entropy must not create free-flight drift before a device interaction")


func _test_tower_source_uses_device_entropy(profile: BalanceProfile) -> void:
	var simulation := MomentumSimulation.new()
	_check(simulation.configure({
		"fixed_step_seconds": 1.0 / 120.0,
		"max_substeps": 240,
		"projectile_radius": 1.0,
		"entity_spawn_clearance": 1.0,
		"entropy_per_second": 0.0,
		"entropy_per_interaction": 0.0,
		"entropy_start": 50.0,
		"entropy_full_effect": 100.0,
		"entropy_curve": [{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
		"max_diode_exit_offset": float(profile.value("entropy/max_diode_exit_offset", 8.0)),
		"max_diode_angle_deviation_radians": deg_to_rad(float(profile.value(
			"entropy/max_diode_angle_deviation_degrees", 5.7295779513
		))),
		"random_seed": 20260903,
	}), "tower-source device entropy simulation must initialize")
	var diode_id := simulation.add_device({
		"type": "diode",
		"position": Vector2(10.0, 0.0),
		"secondary_position": Vector2(20.0, 20.0),
		"secondary_angle_radians": PI * 0.5,
		"activation_radius": 1.0,
		"activation_required": 13.0,
		"entropy_sensitivity": 1.0,
	})
	_check(diode_id > 0, "tower-source entropy test must add its diode")
	simulation.emit_projectiles([{
		"position": Vector2.ZERO, "velocity": Vector2(20.0, 0.0), "mass": 1.0,
		"tower_source": true, "entropy": 0.0,
	}])
	simulation.step(1.0)
	simulation.consume_events()
	simulation.emit_projectiles([{
		"position": Vector2.ZERO, "velocity": Vector2(20.0, 0.0), "mass": 1.0,
		"tower_source": true, "entropy": 100.0,
	}])
	simulation.step(1.0)
	var teleport_position := Vector2.INF
	for event: Dictionary in simulation.consume_events():
		if StringName(event.get("type", &"")) == &"projectile_teleported":
			teleport_position = event.get("position", Vector2.INF)
	var projectile_snapshot: Dictionary = simulation.get_projectile_snapshot()
	var velocities: PackedVector2Array = projectile_snapshot.velocities
	var angle_deviation := 0.0
	if not velocities.is_empty():
		angle_deviation = absf(angle_difference(PI * 0.5, velocities[0].angle()))
	_check(teleport_position.is_finite() and velocities.size() == 1,
			"an activated diode must preserve the high-entropy tower-source projectile")
	_check(absf(teleport_position.x - 20.0) > 0.000001 or angle_deviation > 0.000001,
			"tower-source identity must not bypass configured entropy deviation after a diode interaction")


func _test_dismantle_contract(profile: BalanceProfile) -> void:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "dismantle simulation must initialize")
	var construction := ConstructionControllerType.new(simulation, profile) as ConstructionController
	var catalog := DeviceCatalogType.new(profile) as DeviceCatalog
	var diode := catalog.get_definition(&"diode")
	var device_id := construction.place(diode, Vector2(100.0, 0.0), 0.0, Vector2(100.0, -120.0), -PI * 0.5)
	var record: Dictionary = construction.devices[device_id]
	record.active = true
	record.activation_progress = diode.activation_required
	record.stored_mass = 3.0
	record.stored_momentum = 90.0
	record.stored_wave_momentum = 7.0
	construction.devices[device_id] = record
	var emitted_events: Array[Dictionary] = []
	construction.gameplay_event.connect(func(event: Dictionary):
		if StringName(event.get("type", &"")) == &"device_dismantled":
			emitted_events.append(event)
	)
	construction.selected_device_id = device_id
	construction.selected_anchor = 1
	var event := construction.dismantle_selected()
	_check(not event.is_empty() and emitted_events.size() == 1 and event == emitted_events[0],
			"dismantling must return and emit one structured gameplay event")
	_check(not construction.devices.has(device_id) and simulation.native.get_device_snapshot().is_empty(),
			"dismantling either diode anchor must atomically remove the native pair")
	_check(construction.destruction_effects.size() == 2,
			"dismantling a diode must create feedback at both anchors")
	_check(StringName(construction.destruction_effects[0].get("kind", &"")) == &"device_dismantled"
			and StringName(construction.destruction_effects[1].get("kind", &"")) == &"device_dismantled",
			"dismantling feedback must remain visually distinguishable from enemy destruction")
	_check(is_equal_approx(float(event.discarded_activation_progress), diode.activation_required)
			and is_equal_approx(float(event.discarded_mass), 3.0)
			and is_equal_approx(float(event.discarded_momentum), 90.0)
			and is_equal_approx(float(event.discarded_wave_momentum), 7.0),
			"dismantling must report every discarded store without reconstructing momentum")
	_check(construction.light_sources(Vector2.ZERO, 360.0).size() == 1,
			"dismantling an active diode must remove both lighting sources")
	var destroyed_id := construction.place(catalog.get_definition(&"speed_increaser"), Vector2(180.0, 80.0))
	construction.damage_device(destroyed_id, 1000.0)
	_check(StringName(construction.destruction_effects.back().get("kind", &"")) == &"device_destroyed",
			"enemy/debug destruction must retain destruction feedback rather than dismantle feedback")


func _test_accumulator_dismantle_discards_native_store(profile: BalanceProfile) -> void:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "accumulator dismantle simulation must initialize")
	var construction := ConstructionControllerType.new(simulation, profile) as ConstructionController
	var catalog := DeviceCatalogType.new(profile) as DeviceCatalog
	var accumulator := catalog.get_definition(&"accumulator")
	var position := Vector2(40.0, 0.0)
	var device_id := construction.place(accumulator, position)
	var spawn_position := position - Vector2(accumulator.activation_radius + 8.0, 0.0)
	var tower_mass := float(profile.value("tower/projectile_mass", 0.05))
	var tower_speed := float(profile.value("tower/projectile_speed", 240.0))
	var activation_shots := ceili(accumulator.activation_required / (tower_mass * tower_speed))
	var activation_commands: Array[Dictionary] = []
	for _index in activation_shots:
		activation_commands.append({
			"position": spawn_position, "velocity": Vector2(tower_speed, 0.0),
			"mass": tower_mass, "tower_source": true, "entropy": 0.0,
		})
	simulation.native.emit_projectiles(activation_commands)
	_step_simulation(simulation, 6, 0.05)
	construction.sync(simulation.native.get_device_snapshot())
	_check(bool((construction.devices[device_id] as Dictionary).get("active", false)),
			"accumulator dismantle test must activate the real native device")
	simulation.native.emit_projectiles([{
		"position": spawn_position, "velocity": Vector2(tower_speed, 0.0),
		"mass": tower_mass, "tower_source": true, "entropy": 0.0,
	}])
	_step_simulation(simulation, 6, 0.05)
	construction.sync(simulation.native.get_device_snapshot())
	var stored: Dictionary = construction.devices[device_id]
	_check(float(stored.get("stored_mass", 0.0)) > 0.0 and float(stored.get("stored_momentum", 0.0)) > 0.0,
			"the real native accumulator must contain mass and momentum before dismantling")
	construction.selected_device_id = device_id
	var event := construction.dismantle_selected()
	var projectiles: PackedVector2Array = simulation.native.get_projectile_snapshot().positions
	_check(projectiles.is_empty(), "dismantling a stored accumulator must not release or refund a projectile")
	_check(float(event.get("discarded_mass", 0.0)) > 0.0 and float(event.get("discarded_momentum", 0.0)) > 0.0,
			"dismantling must report the real accumulator store that was permanently discarded")


func _test_diode_teleport_effect(profile: BalanceProfile) -> void:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "teleport effect simulation must initialize")
	var construction := ConstructionControllerType.new(simulation, profile) as ConstructionController
	var catalog := DeviceCatalogType.new(profile) as DeviceCatalog
	var entry := Vector2(80.0, 10.0)
	var exit := Vector2(160.0, -120.0)
	var diode_id := construction.place(catalog.get_definition(&"diode"), entry, 0.0, exit, -PI * 0.5)
	_check(construction.record_diode_teleport(diode_id) and construction.teleport_effects.size() == 1,
			"a real diode teleport notification must create one paired transient effect")
	var effect: Dictionary = construction.teleport_effects[0]
	_check((effect.get("entry", Vector2.INF) as Vector2) == entry and (effect.get("exit", Vector2.INF) as Vector2) == exit,
			"the teleport effect must preserve both diode endpoints")
	construction.advance_effects(float(profile.value("visuals/diode_teleport_pulse_seconds", 0.32)) * 0.5)
	construction.record_diode_teleport(diode_id)
	_check(construction.teleport_effects.size() == 1 and is_equal_approx(
		float(construction.teleport_effects[0].get("remaining", 0.0)),
		float(profile.value("visuals/diode_teleport_pulse_seconds", 0.32))
	), "repeated high-frequency teleports must refresh one effect per stable diode ID")
	construction.advance_effects(float(profile.value("visuals/diode_teleport_pulse_seconds", 0.32)) + 0.01)
	_check(construction.teleport_effects.is_empty(), "teleport effects must expire without changing device state")
	var ordinary_id := construction.place(catalog.get_definition(&"speed_increaser"), Vector2(220.0, 0.0))
	_check(not construction.record_diode_teleport(ordinary_id), "non-diode devices must reject teleport effects")


func _step_simulation(simulation: SimulationController, count: int, delta: float) -> void:
	for _index in count:
		simulation.step(delta)


func _test_tutorial_flow(profile: BalanceProfile) -> void:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "tutorial simulation must initialize")
	var construction := ConstructionControllerType.new(simulation, profile) as ConstructionController
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var tutorial := TutorialSessionType.new(profile, manager, simulation, tower, construction) as DiodeTutorialSession
	var target_events := [0]
	var wave_events := [0]
	var run_events := [0]
	tutorial.target_reached.connect(func(_wave_index: int): target_events[0] += 1)
	tutorial.wave_finished.connect(func(_wave_index: int, _result: StringName): wave_events[0] += 1)
	tutorial.run_finished.connect(func(_result: StringName): run_events[0] += 1)
	construction.gameplay_event.connect(tutorial.ingest_event)
	_check(tutorial.start(), "diode tutorial must start from the schema v3 level definition")
	_check(tutorial.state == DiodeTutorialSession.State.OBSERVE_SOURCE
			and tutorial.hud_snapshot({}).world_cues.size() == 1,
			"tutorial must begin by showing the unique source path")
	tutorial.advance(float(profile.value("levels/diode_tutorial/observation_seconds", 3.0)) + 0.01)
	_check(tutorial.state == DiodeTutorialSession.State.PRACTICE_PLACE,
			"observation must advance to diode placement practice")
	var catalog := DeviceCatalogType.new(profile) as DeviceCatalog
	var diode := catalog.get_definition(&"diode")
	var practice_id := construction.place(diode, Vector2(120.0, 120.0), 0.0, Vector2(240.0, 120.0), 0.0)
	_check(tutorial.state == DiodeTutorialSession.State.PRACTICE_DISMANTLE,
			"placing a diode must advance to dismantle practice")
	construction.damage_device(practice_id, 1000.0)
	_check(tutorial.state == DiodeTutorialSession.State.PRACTICE_PLACE,
			"destroying the tracked practice diode must return to placement instead of soft-locking")
	practice_id = construction.place(diode, Vector2(120.0, 120.0), 0.0, Vector2(240.0, 120.0), 0.0)
	var other_id := construction.place(diode, Vector2(80.0, 150.0), 0.0, Vector2(200.0, 150.0), 0.0)
	construction.selected_device_id = other_id
	construction.dismantle_selected()
	_check(tutorial.state == DiodeTutorialSession.State.PRACTICE_DISMANTLE,
			"dismantling a different device must not skip the tracked practice diode")
	construction.selected_device_id = practice_id
	construction.dismantle_selected()
	_check(tutorial.state == DiodeTutorialSession.State.ROUTE_BUILD,
			"dismantling the tracked pair must advance to route construction")
	var route_id := construction.place(diode, Vector2(180.0, 0.0), 0.0, Vector2(180.0, -180.0), -PI * 0.5)
	construction.damage_device(route_id, 1000.0)
	_check(tutorial.state == DiodeTutorialSession.State.ROUTE_BUILD and tutorial.route_device_id == 0,
			"destroying the tracked route diode must allow a replacement without leaving stale stable IDs")
	route_id = construction.place(diode, Vector2(180.0, 0.0), 0.0, Vector2(180.0, -180.0), -PI * 0.5)
	var route_record: Dictionary = construction.devices[route_id]
	route_record.active = true
	construction.devices[route_id] = route_record
	tutorial.ingest_event({"type": &"device_activated", "device_id": route_id})
	route_record.secondary_angle_radians = 0.0
	construction.devices[route_id] = route_record
	tutorial.ingest_event({"type": &"projectile_teleported", "device_id": route_id})
	_check(tutorial.state == DiodeTutorialSession.State.ROUTE_BUILD,
			"a real teleport with the exit facing outside the configured north tolerance must remain in route practice")
	route_record.secondary_angle_radians = -PI * 0.5
	construction.devices[route_id] = route_record
	tutorial.ingest_event({"type": &"projectile_teleported", "device_id": route_id})
	_check(tutorial.state == DiodeTutorialSession.State.WAVE_1,
			"only a real active-diode teleport may start the first encounter")
	tutorial.evaluate({"utilization": 1.0})
	tutorial.advance(0.01)
	_check(tutorial.state == DiodeTutorialSession.State.INTERMISSION and tutorial.completed_waves == 1,
			"the first target and clear must enter real-time adjustment")
	_check(target_events[0] == 1 and wave_events[0] == 1 and run_events[0] == 0,
			"wave one target and finish events must each fire once without ending the run")
	tutorial.advance(float(profile.value("levels/diode_tutorial/intermission_seconds", 20.0)) + 0.01)
	_check(tutorial.state == DiodeTutorialSession.State.WAVE_2,
			"intermission must start the configured second encounter")
	tutorial.evaluate({"utilization": 1.0})
	tutorial.advance(0.01)
	_check(tutorial.state == DiodeTutorialSession.State.FINISHED and tutorial.is_terminal()
			and tutorial.completed_waves == 2 and tutorial.result == &"success",
			"clearing the second target must complete the tutorial exactly once")
	tutorial.evaluate({"utilization": 1.0})
	tutorial.advance(10.0)
	_check(target_events[0] == 2 and wave_events[0] == 2 and run_events[0] == 1,
			"terminal tutorial calls must not duplicate target, wave-finished or run-finished events")
	var completion := tutorial.completion_snapshot()
	_check(completion.result == &"success" and completion.reason == &"success"
			and int(completion.completed_waves) == 2
			and is_equal_approx(float(completion.utilization), 1.0),
			"completed tutorial must expose a stable campaign completion snapshot")


func _test_tutorial_failures(profile: BalanceProfile) -> void:
	var timeout_fixture := _create_tutorial_fixture(profile)
	var timeout_tutorial: DiodeTutorialSession = timeout_fixture.tutorial
	var timeout_runs := [0]
	timeout_tutorial.run_finished.connect(func(_result: StringName): timeout_runs[0] += 1)
	_check(timeout_tutorial.start(), "timeout tutorial fixture must start")
	timeout_tutorial.call("_start_wave", 0)
	var duration := float(timeout_tutorial.level.waves[0].duration)
	timeout_tutorial.advance(duration + 0.01)
	timeout_tutorial.evaluate({"utilization": 0.0})
	timeout_tutorial.advance(1.0)
	_check(timeout_tutorial.state == DiodeTutorialSession.State.FAILED
			and timeout_tutorial.result == &"timeout" and timeout_runs[0] == 1,
			"tutorial timeout must fail once and remain terminal")
	var timeout_completion := timeout_tutorial.completion_snapshot()
	_check(timeout_completion.result == &"timeout" and timeout_completion.reason == &"timeout"
			and int(timeout_completion.completed_waves) == 0,
			"failed tutorial must expose its terminal reason without granting completion")

	var tower_fixture := _create_tutorial_fixture(profile)
	var tower_tutorial: DiodeTutorialSession = tower_fixture.tutorial
	var tower: TowerController = tower_fixture.tower
	var tower_targets := [0]
	var tower_runs := [0]
	tower_tutorial.target_reached.connect(func(_wave_index: int): tower_targets[0] += 1)
	tower_tutorial.run_finished.connect(func(_result: StringName): tower_runs[0] += 1)
	_check(tower_tutorial.start(), "tower-destroyed tutorial fixture must start")
	tower_tutorial.call("_start_wave", 0)
	tower.hp = 0.0
	tower_tutorial.evaluate({"utilization": 1.0})
	tower_tutorial.evaluate({"utilization": 1.0})
	_check(tower_tutorial.state == DiodeTutorialSession.State.FAILED
			and tower_tutorial.result == &"tower_destroyed" and tower_targets[0] == 0 and tower_runs[0] == 1,
			"tower destruction must beat same-frame target reach and emit one terminal event")


func _create_tutorial_fixture(profile: BalanceProfile) -> Dictionary:
	var simulation := SimulationControllerType.new(profile) as SimulationController
	_check(simulation.initialize(), "tutorial failure simulation must initialize")
	var construction := ConstructionControllerType.new(simulation, profile) as ConstructionController
	var tower := TowerControllerType.new(profile) as TowerController
	var manager := EnemyManagerType.new(profile, simulation, construction, tower) as EnemyManager
	var tutorial := TutorialSessionType.new(profile, manager, simulation, tower, construction) as DiodeTutorialSession
	construction.gameplay_event.connect(tutorial.ingest_event)
	return {"simulation": simulation, "construction": construction, "tower": tower,
		"manager": manager, "tutorial": tutorial}


func _test_dismantle_hold(profile: BalanceProfile) -> void:
	var prototype := PrototypeScene.instantiate()
	add_child(prototype)
	await get_tree().process_frame
	await get_tree().process_frame
	prototype.runtime.set("auto_fire", false)
	var construction: ConstructionController = prototype.runtime.construction
	var catalog: DeviceCatalog = prototype.runtime.catalog
	var device_id := construction.place(catalog.get_definition(&"speed_increaser"), Vector2(100.0, 100.0))
	construction.selected_device_id = device_id
	var hp_before := float((construction.devices[device_id] as Dictionary).get("hp", 0.0))
	var debug_damage := float(profile.value("construction_ux/damage_debug_amount", 25.0))
	var shift_delete := InputEventKey.new()
	shift_delete.keycode = KEY_DELETE
	shift_delete.pressed = true
	shift_delete.shift_pressed = true
	prototype.call("_handle_key", shift_delete)
	_check(construction.devices.has(device_id)
			and is_equal_approx(float((construction.devices[device_id] as Dictionary).get("hp", 0.0)), hp_before - debug_damage)
			and prototype.runtime.input.snapshot().dismantle_progress == 0.0,
			"Shift+Delete must apply only configured development damage and never begin dismantling")

	var diode_id := construction.place(catalog.get_definition(&"diode"), Vector2(140.0, 0.0), 0.0, Vector2(140.0, -120.0), -PI * 0.5)
	prototype.runtime.call("_collect_events", [{"type": &"projectile_teleported", "device_id": diode_id}])
	_check(construction.teleport_effects.size() == 1,
			"the prototype event bridge must translate a native diode teleport into visual pulse state")
	construction.selected_device_id = device_id

	prototype.runtime.input.handle_command(&"dismantle_begin")
	prototype.runtime.input.advance( float(profile.value("construction_ux/dismantle_hold_seconds", 0.6)) * 0.5)
	_check(construction.devices.has(device_id), "a partial Delete hold must not dismantle the selected device")
	prototype.runtime.input.handle_command(&"dismantle_end")
	prototype.runtime.input.advance( 10.0)
	_check(construction.devices.has(device_id), "releasing Delete must cancel dismantle progress")
	prototype.runtime.input.handle_command(&"dismantle_begin")
	construction.selected_device_id = 0
	prototype.runtime.input.advance( 0.01)
	_check(prototype.runtime.input.snapshot().dismantle_progress == 0.0 and construction.devices.has(device_id),
			"switching selection must cancel dismantle progress without deleting the old selection")
	construction.selected_device_id = device_id
	prototype.runtime.input.handle_command(&"dismantle_begin")
	var f2_event := InputEventKey.new()
	f2_event.keycode = KEY_F2
	f2_event.pressed = true
	prototype.call("_handle_key", f2_event)
	_check(prototype.runtime.input.snapshot().dismantle_progress == 0.0 and construction.devices.has(device_id),
			"opening the F2 modal must cancel pending dismantle progress")
	prototype.runtime.input.handle_command(&"dismantle_begin")
	prototype.runtime.input.advance( float(profile.value("construction_ux/dismantle_hold_seconds", 0.6)) + 0.01)
	_check(not construction.devices.has(device_id), "holding Delete through the configured threshold must dismantle")
	prototype.queue_free()
	await get_tree().process_frame
