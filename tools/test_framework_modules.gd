extends SceneTree

const Repository := preload("res://scripts/config/balance_repository.gd")
const Schema := preload("res://scripts/config/balance_schema.gd")
const EditSession := preload("res://scripts/config/balance_edit_session.gd")
const Adapter := preload("res://scripts/config/balance_edit_adapter.gd")
const Spec := preload("res://scripts/combat/session_spec.gd")
const Factory := preload("res://scripts/combat/combat_session_factory.gd")
const Runtime := preload("res://scripts/runtime/world_runtime.gd")
const TutorialConfig := preload("res://scripts/config/diode_tutorial_config.gd")
var failed := false

class MemoryAdapter extends Adapter:
	var disk: BalanceProfile
	var applied: BalanceProfile
	var editor := false
	var fail_save := false
	func load_saved(_path: String) -> BalanceProfile:
		return disk.duplicate_profile()
	func save(profile: BalanceProfile) -> Array[String]:
		if fail_save:
			return ["test write failure"]
		disk = profile.duplicate_profile()
		return []
	func apply(profile: BalanceProfile) -> Array[String]:
		applied = profile.duplicate_profile()
		if editor:
			disk = profile.duplicate_profile()
		return []
	func apply_updates_saved() -> bool:
		return editor

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _run() -> void:
	var profile := Repository.load_profile()
	check(profile != null and profile.validate().is_empty(), "v6 must load and validate")
	if profile == null:
		quit(1)
		return
	_test_migration(profile)
	_test_editing(profile)
	_test_runtime_snapshot(profile)
	_test_sessions(profile)
	_test_menu_intents(profile)
	print("Framework module tests ", "FAILED" if failed else "passed")
	quit(1 if failed else 0)

func _test_migration(profile: BalanceProfile) -> void:
	var legacy := profile.data.duplicate(true)
	preload("res://tools/input_test_driver.gd").legacy_input(legacy)
	legacy.erase("playtest")
	legacy.erase("presentation")
	legacy.erase("audio")
	legacy.schema_version = 5
	legacy.levels.diode_tutorial.erase("feedback")
	for group in legacy.waves.dev_wave_01.groups:
		group.erase("spawn_region")
	for wave in legacy.levels.diode_tutorial.waves:
		for group in wave.groups:
			group.erase("spawn_region")
	for key in ["session_kind", "route_min_north_distance", "path_hint_length", "direction_hint_length"]:
		legacy.levels.diode_tutorial.erase(key)
	legacy.levels.diode_tutorial.marker_radius = 77.0
	var before := JSON.stringify(legacy)
	var migrated := Schema.migrate(legacy)
	check(JSON.stringify(legacy) == before, "migration must never mutate its source")
	check(Schema.validate(migrated).is_empty(), "migrated v5 must validate")
	check(migrated.levels.diode_tutorial.route_min_north_distance == 77.0, "custom legacy marker must preserve gameplay distance")
	migrated.levels.diode_tutorial.marker_radius = 12.0
	var config := TutorialConfig.new(migrated.levels.diode_tutorial)
	check(config.route_min_north_distance == 77.0 and config.marker_radius == 12.0, "visual marker must not control route eligibility")
	migrated.levels.diode_tutorial.session_kind = "unknown"
	check(not Schema.validate(migrated).is_empty(), "unknown session kind must fail")
	var invalid := profile.data.duplicate(true)
	invalid.levels.diode_tutorial.route_min_north_distance = -1.0
	check(not Schema.validate(invalid).is_empty(), "negative route distance must fail")

func _test_editing(profile: BalanceProfile) -> void:
	for editor in [false, true]:
		var backend := MemoryAdapter.new()
		backend.editor = editor
		backend.disk = profile.duplicate_profile()
		var model := EditSession.new()
		model.initialize(profile, backend, not editor)
		check(model.edit_shots_per_second(7.5), "fractional firing rate must edit")
		check(is_equal_approx(float(model.working.value("tower/fire_interval")), 1.0 / 7.5), "reciprocal rate must be exact")
		check(not model.edit_shots_per_second(0.0) and not model.edit_shots_per_second(INF), "invalid rates must not modify working state")
		check(backend.applied == null and not model.snapshot().applied, "editing must not apply")
		backend.fail_save = true
		check(not model.save().is_empty() and not model.snapshot().saved, "save failure must retain saved snapshot")
		backend.fail_save = false
		check(model.save().is_empty() and model.snapshot().saved, "save must update only appropriate snapshots")
		check(bool(model.snapshot().applied) == editor, "editor save and runtime save have different undo baselines")
		check(model.apply().is_empty(), "valid working copy must apply")
		model.edit("tower/projectile_speed", 241.0)
		model.undo()
		check(model.snapshot().applied, "undo must restore last applied/loaded editor baseline")
		model.edit("tower/fire_interval", -1.0)
		var applied_before := backend.applied.data.duplicate(true)
		check(not model.apply().is_empty() and backend.applied.data == applied_before, "invalid apply must be atomic")
		check(model.reload() and model.snapshot().saved, "reload must restore disk without implicit runtime application")

func _test_runtime_snapshot(profile: BalanceProfile) -> void:
	var frozen := profile.duplicate_profile()
	check(frozen.freeze().is_empty(), "runtime compilation must succeed")
	var speed := frozen.runtime_config().tower.projectile_speed
	check(not frozen.set_value("tower/projectile_speed", speed + 1.0), "sealed profile must reject edits")
	check(frozen.data.is_read_only() and frozen.data.tower.is_read_only()
		and frozen.data.entropy.uncertainty_curve.is_read_only(), "runtime containers must be recursively read-only")
	var working := frozen.duplicate_profile()
	check(working.set_value("tower/projectile_speed", speed + 1.0), "working copy must remain writable")
	check(frozen.runtime_config().tower.projectile_speed == speed, "working edits must not affect compiled values")
	check(frozen.value("tower/projectile_speed") == speed, "compiled path cache must agree with typed tower")
	for section in ["simulation", "tower", "construction_ux", "map_camera", "entropy", "fog", "frontend", "visuals", "diagnostics"]:
		var typed = frozen.runtime_config().get(section)
		for field in frozen.data[section]:
			check(typed.get(field) == frozen.data[section][field], "typed runtime field missing or incorrect: %s/%s" % [section, field])

func _test_sessions(profile: BalanceProfile) -> void:
	var alternate := profile.duplicate_profile()
	alternate.data.levels["test_alternate"] = alternate.data.levels.diode_tutorial.duplicate(true)
	alternate.data.levels.test_alternate.observation_seconds = 9.0
	check(alternate.validate().is_empty(), "second test-only config ID must validate")
	var spec := Spec.from_launch({"kind": &"campaign", "level_id": &"test_alternate", "session_kind": &"tutorial_diode", "balance_key": "levels/test_alternate"})
	var simulation := SimulationController.new(alternate)
	check(simulation.initialize(), "test native simulation must initialize")
	var construction := ConstructionController.new(simulation, alternate)
	var tower := TowerController.new(alternate)
	var enemies := EnemyManager.new(alternate, simulation, construction, tower)
	var session := Factory.create(spec, alternate, enemies, simulation, tower, construction)
	check(session != null and session.start(), "factory must build a supplied tutorial binding")
	check(session.level.observation_seconds == 9.0, "director must use selected config, not hardcoded first level")
	var original_waves: Array = session.level.waves
	var returned_waves: Array = session.level.waves
	returned_waves.clear()
	check(session.level.waves == original_waves, "typed level must not expose mutable runtime configuration")
	check(not Factory.binding_errors(&"tutorial_diode", "waves/endless", alternate).is_empty(), "wrong config shape must fail")
	spec.balance_key = "levels/missing"
	check(Factory.create(spec, alternate, enemies, simulation, tower, construction) == null, "missing binding must not fall back")
	var missing := Spec.from_launch({"kind": &"campaign", "session_kind": &"tutorial_diode"})
	check(missing.balance_key.is_empty(), "campaign launch must explicitly carry a config key")
	var camera := Camera2D.new()
	root.add_child(camera)
	var camera_control := PrototypeCameraController.new(camera, profile.map_rect(), root, profile)
	var world := Runtime.new()
	check(world.initialize(profile, Spec.development(&"construction"), camera_control, root, false), "construction adapter must initialize without combat")
	var first := world.snapshot(camera_control.visible_world_rect())
	world.advance(0.25)
	var second := world.snapshot(camera_control.visible_world_rect())
	check(int(second.stats.tick) > int(first.stats.tick), "public world interface must advance simulation")
	check(second.enemies.is_empty() and not world.session.should_simulate_enemies(), "construction session must not simulate combat")
	world.shutdown()
	world.shutdown()
	camera.free()

func _test_menu_intents(profile: BalanceProfile) -> void:
	var modal := ScreenModalCoordinator.new()
	root.add_child(modal)
	modal.terminal_query = func(): return true
	var menu := RuntimeMenuLayer.new()
	root.add_child(menu)
	menu.configure(profile, modal)
	var observed := {"quit": 0}
	menu.quit_requested.connect(func(): observed.quit += 1)
	menu.menu.quit_requested.emit()
	check(observed.quit == 1, "menu must emit a quit intent without terminating its host")
	menu.free()
	modal.free()
