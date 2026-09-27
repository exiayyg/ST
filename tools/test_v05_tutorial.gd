extends SceneTree
## Focused rule fixtures; NOT a playability pass. Actual input acceptance is separate.

var failed := false
var profile: BalanceProfile

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)

func _run() -> void:
	profile = BalanceRepository.load_profile()
	if profile == null:
		quit(1)
		return
	_test_migration()
	_test_spawn()
	_test_anchors()
	_test_feedback()
	_test_feedback(false)
	print("V05_RULES ", "FAILED" if failed else "passed")
	quit(1 if failed else 0)

func fixture() -> Dictionary:
	var simulation := SimulationController.new(profile)
	check(simulation.initialize(), "native fixture initializes")
	var construction := ConstructionController.new(simulation, profile)
	var tower := TowerController.new(profile)
	var enemies := EnemyManager.new(profile, simulation, construction, tower)
	return {"simulation": simulation, "construction": construction, "tower": tower, "enemies": enemies, "catalog": DeviceCatalog.new(profile)}

func _test_migration() -> void:
	var legacy := profile.data.duplicate(true)
	preload("res://tools/input_test_driver.gd").legacy_input(legacy)
	legacy.erase("playtest")
	legacy.erase("presentation")
	legacy.erase("audio")
	legacy.schema_version = 6
	legacy.levels.diode_tutorial.erase("feedback")
	legacy.tower.fire_interval = 0.37
	legacy.levels.diode_tutorial.route_exit_x = 207.0
	var configured: Array = [legacy.waves.dev_wave_01]
	configured.append_array(legacy.levels.diode_tutorial.waves)
	for wave in configured:
		for group in wave.groups:
			group.erase("spawn_region")
	var original := JSON.stringify(legacy)
	var migrated := BalanceSchema.migrate(legacy)
	check(JSON.stringify(legacy) == original, "migration is in-memory and transactional")
	check(BalanceSchema.validate(migrated).is_empty(), "v6 migrates to valid v7")
	check(migrated.tower.fire_interval == 0.37 and migrated.levels.diode_tutorial.route_exit_x == 207.0, "migration preserves player tuning, including old lesson layout")
	for wave in migrated.levels.diode_tutorial.waves:
		for group in wave.groups:
			check(group.spawn_region.mode == "full_edge", "migration never silently narrows old spawns")
	check(BalanceSchema.validate(JSON.parse_string(JSON.stringify(migrated, "\t", true))).is_empty(), "v7 stable JSON round trip")
	for invalid in [{"mode": "road", "center_ratio": 0.5, "half_width": 24.0}, {"mode": "segment", "center_ratio": 0.0, "half_width": 24.0}, {"mode": "segment", "center_ratio": 0.5, "half_width": -1.0}, {"mode": "segment", "center_ratio": "0.5", "half_width": 24.0}]:
		var data := profile.data.duplicate(true)
		data.levels.diode_tutorial.waves[0].groups[0].spawn_region = invalid
		check(not BalanceSchema.validate(data).is_empty(), "invalid region rejects entire profile")

func _test_spawn() -> void:
	var f := fixture()
	var manager := f.enemies as EnemyManager
	var rect := profile.map_rect()
	var inset := float(profile.value("enemies/settings/spawn_edge_inset"))
	var distribution := float(profile.value("enemies/settings/spawn_distribution_step"))
	for direction in [&"north", &"south", &"east", &"west"]:
		for _index in 25:
			var id := manager.next_enemy_id
			var ratio := fposmod(float(id) * distribution, 1.0)
			var expected: Vector2
			match direction:
				&"north": expected = Vector2(lerpf(rect.position.x + inset, rect.end.x - inset, ratio), rect.position.y + inset)
				&"south": expected = Vector2(lerpf(rect.position.x + inset, rect.end.x - inset, ratio), rect.end.y - inset)
				&"east": expected = Vector2(rect.end.x - inset, lerpf(rect.position.y + inset, rect.end.y - inset, ratio))
				_: expected = Vector2(rect.position.x + inset, lerpf(rect.position.y + inset, rect.end.y - inset, ratio))
			check(manager.find_enemy(manager.spawn(&"dev_melee", direction)).position == expected, "full-edge exact legacy spawn sequence")
	var region := SpawnRegion.from_spec({"mode": "segment", "center_ratio": 0.5, "half_width": 24.0})
	for _index in 100:
		var enemy := manager.find_enemy(manager.spawn(&"tutorial_breaker", &"north", {}, region))
		check(absf(enemy.position.x) <= 24.0 and enemy.position.y == rect.position.y + inset, "segment stays on configured edge")
	var before := manager.next_enemy_id
	var invalid := SpawnRegion.from_spec({"mode": "segment", "center_ratio": 0.0, "half_width": 24.0})
	check(manager.spawn(&"dev_melee", &"north", {}, invalid) == 0 and manager.next_enemy_id == before, "invalid segment consumes no ID")
	check(manager.spawn(&"dev_melee", &"diagonal") == 0 and manager.next_enemy_id == before, "invalid direction consumes no ID")
	var director := WaveDirector.new(profile, manager, f.simulation, f.tower)
	check(director.start(&"dev_wave_01"), "legacy wave starts")
	var current := director.wave_id
	var bad: Dictionary = profile.value("levels/diode_tutorial/waves/0").duplicate(true)
	bad.groups[0].spawn_region.center_ratio = 0.0
	check(not director.start_spec(&"bad", bad) and director.wave_id == current, "bad region cannot partially replace active wave")

func _test_anchors() -> void:
	for ranged in [false, true]:
		for anchor in [0, 1]:
			var f := fixture()
			var manager := f.enemies as EnemyManager
			var construction := f.construction as ConstructionController
			var diode := construction.place(f.catalog.get_definition(&"diode"), Vector2(180, 0), 0, Vector2(0, -180), -PI / 2)
			var enemy := manager.find_enemy(manager.spawn(&"tutorial_suppressor" if ranged else &"tutorial_breaker", &"north"))
			enemy.position = construction.get_device_position(diode, anchor) + Vector2.UP * (100.0 if ranged else 30.0)
			manager.update(0.0, true)
			# Public advancement respects target refresh; force no target state.
			manager.update(float(profile.value("enemies/settings/target_refresh_seconds")), true)
			check(enemy.target_id == diode and enemy.target_anchor == anchor, "enemy acquires correct diode endpoint")
			var hp := float(construction.devices[diode].hp)
			var guard := 0
			while construction.devices.has(diode) and float(construction.devices[diode].hp) == hp and guard < 600:
				manager.update(1.0 / 120.0, true)
				guard += 1
			check(construction.devices.has(diode) and is_equal_approx(float(construction.devices[diode].hp), hp - enemy.attack_damage), "one attack damages shared HP exactly once")
			construction.selected_anchor = anchor
			check(construction.move_selected(Vector2(900, 900)), "target endpoint moves")
			manager.update(float(profile.value("enemies/settings/target_refresh_seconds")), true)
			check(enemy.target_id != diode or enemy.target_anchor != anchor, "moved endpoint leaves perception index")
			construction.dismantle_selected()
			manager.update(0.0, true)
			check(construction.target_anchors().is_empty() and enemy.target_id == 0, "pair removal invalidates both anchors immediately")

func _test_feedback(player_visible := true) -> void:
	var f := fixture()
	var lesson := DiodeTutorialSession.new(profile, f.enemies, f.simulation, f.tower, f.construction)
	f.construction.gameplay_event.connect(lesson.ingest_event)
	check(lesson.start(), "lesson starts")
	lesson.advance(lesson.level.observation_seconds)
	f.construction.place(f.catalog.get_definition(&"diode"), Vector2(-100, -100), 0, Vector2(-100, 100))
	f.construction.dismantle_selected()
	var diode: int = f.construction.place(f.catalog.get_definition(&"diode"), Vector2(180, 0), 0, Vector2(0, -180), -PI / 2)
	for _shot in 7:
		f.simulation.emit_tower_projectile(Vector2.ZERO)
		for _step in 120:
			f.simulation.step(1.0 / 120.0)
			f.construction.sync(f.simulation.native.get_device_snapshot())
			for event: Dictionary in f.simulation.native.consume_events():
				lesson.ingest_event(event)
	check(lesson.current_wave_index == 0, "real activation and teleport start lesson wave")
	check(lesson.hud_snapshot({}).instruction_key == &"route_connected", "real teleport confirms route")
	lesson.observe_world(20, true, 0)
	check(lesson.diagnostic_snapshot().no_damage_seconds == 0, "unseen enemies do not trigger damage timer")
	lesson.observe_world(20, false, 1)
	check(lesson.hud_snapshot({}).instruction_key == &"tower_stopped", "stopped firing is not diagnosed as network failure")
	lesson.observe_world(lesson.level.no_damage_seconds, true, 1)
	check(lesson.hud_snapshot({}).instruction_key == &"check_route_damage", "visible enemies without effective damage trigger reminder")
	lesson.advance(lesson.level.confirmation_seconds)
	lesson.observe_world(0, true, 1)
	check(lesson.hud_snapshot({}).instruction_key != &"check_route_damage", "same reminder cannot restart within cooldown")
	lesson.advance(lesson.level.reminder_interval_seconds - lesson.level.confirmation_seconds)
	lesson.observe_world(0, true, 1)
	check(lesson.hud_snapshot({}).instruction_key == &"check_route_damage", "reminder can recur after configured cooldown")
	lesson.observe_world(0, true, 0)
	check(lesson.hud_snapshot({}).instruction_key != &"check_route_damage", "losing enemy visibility dismisses stale reminder")
	lesson.ingest_event({"type": "enemy_hit", "damage": 0.0})
	check(lesson.diagnostic_snapshot().first_hit_seconds < 0, "zero damage never claims effective hit")
	lesson.ingest_event({"type": "enemy_hit", "damage": 4.2, "player_visible": player_visible})
	var expected := &"first_effective_hit" if player_visible else &"first_effective_hit_offscreen"
	check(lesson.hud_snapshot({}).instruction_key == expected, "actual positive damage confirms first hit with visibility-safe text")
	var wave_before := lesson.current_wave_index
	f.construction.damage_device(diode, 1000)
	check(lesson.hud_snapshot({}).instruction_key == &"route_node_lost" and lesson.current_wave_index == wave_before, "route loss changes feedback, not wave")
	var before_ledger := float(f.simulation.native.get_stats().tower_source_momentum)
	var replacement: int = f.construction.place(f.catalog.get_definition(&"diode"), Vector2(180, 0), 0, Vector2(0, -180), -PI / 2)
	for _shot in 7:
		f.simulation.emit_tower_projectile(Vector2.ZERO)
		for _step in 120:
			f.simulation.step(1.0 / 120.0)
			f.construction.sync(f.simulation.native.get_device_snapshot())
			for event: Dictionary in f.simulation.native.consume_events():
				lesson.ingest_event(event)
	check(lesson.route_device_id == replacement and lesson.current_wave_index == wave_before, "real repair restores guidance without restarting wave")
	check(float(f.simulation.native.get_stats().tower_source_momentum) >= before_ledger, "repair cannot reset ledger")
	check(lesson.hud_snapshot({}).instruction_key == &"route_connected", "real repaired route confirms reconnection")
	f.tower.apply_damage(10000)
	lesson.evaluate({})
	var end := lesson.diagnostic_snapshot()
	lesson.advance(100)
	lesson.observe_world(100, true, 1)
	lesson.ingest_event({"type": "enemy_hit", "damage": 10.0})
	check(lesson.diagnostic_snapshot() == end, "terminal lesson stops feedback timers and events")
