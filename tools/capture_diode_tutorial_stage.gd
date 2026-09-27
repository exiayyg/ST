extends Node

const TUTORIAL_SCENE := preload("res://scenes/levels/diode_tutorial.tscn")

const UNIQUE_PATH_OUTPUT := "res://artifacts/tutorial-unique-path.png"
const DISMANTLE_OUTPUT := "res://artifacts/tutorial-dismantle-practice.png"
const ROUTE_OUTPUT := "res://artifacts/tutorial-diode-route.png"
const ENEMIES_OUTPUT := "res://artifacts/tutorial-two-enemies.png"
const FINISHED_OUTPUT := "res://artifacts/tutorial-finished.png"


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var combat := TUTORIAL_SCENE.instantiate()
	add_child(combat)
	for _frame in 6:
		await get_tree().process_frame
	combat.set_process(false)

	var construction: ConstructionController = combat.runtime.construction
	var catalog: DeviceCatalog = combat.runtime.catalog
	var simulation: SimulationController = combat.runtime.simulation
	var manager: EnemyManager = combat.runtime.enemies
	var tower: TowerController = combat.runtime.tower
	var session: DiodeTutorialSession = combat.runtime.session
	if construction == null or catalog == null or simulation == null or manager == null \
			or tower == null or session == null:
		push_error("Tutorial capture fixture could not resolve the live gameplay modules")
		get_tree().quit(3)
		return

	combat.runtime.set("auto_fire", true)
	for _step in 18:
		combat.call("_process", 0.08)
	if not await _refresh_and_save(combat, session, UNIQUE_PATH_OUTPUT):
		return

	session.state = DiodeTutorialSession.State.PRACTICE_PLACE
	var diode := catalog.get_definition(&"diode")
	var practice_id := construction.place(
		diode,
		tower.position + _configured_offset(session.level, "practice_entry"),
		0.0,
		tower.position + _configured_offset(session.level, "practice_exit"),
		0.0
	)
	construction.selected_device_id = practice_id
	construction.selected_anchor = 1
	combat.runtime.input.set("_dismantle_active", true)
	combat.runtime.input.set("_dismantle_device_id", practice_id)
	combat.runtime.input.set("_dismantle_elapsed", float(combat.runtime.input.get("_dismantle_hold_seconds")) * 0.68)
	if not await _refresh_and_save(combat, session, DISMANTLE_OUTPUT):
		return

	combat.runtime.input.call("_cancel_dismantle")
	construction.selected_device_id = practice_id
	construction.dismantle_selected()
	var route_id := construction.place(
		diode,
		tower.position + _configured_offset(session.level, "route_entry"),
		0.0,
		tower.position + _configured_offset(session.level, "route_exit"),
		deg_to_rad(session.level.route_exit_angle_degrees)
	)
	construction.selected_device_id = route_id
	construction.selected_anchor = 1
	for _step in 38:
		combat.call("_process", 0.08)
	if session.state != DiodeTutorialSession.State.WAVE_1:
		push_error("Tutorial capture did not activate and route through the configured diode")
		get_tree().quit(4)
		return
	if construction.teleport_effects.is_empty():
		push_error("Tutorial route capture did not observe a real diode teleport pulse")
		get_tree().quit(7)
		return
	if not await _refresh_and_save(combat, session, ROUTE_OUTPUT):
		return

	for enemy in manager.enemies:
		enemy.alive = false
	manager.update(0.0, false)
	session.call("_start_wave", 1)
	session.wave_director.update_before_simulation(100.0)
	var visible_enemy_index := 0
	for enemy in manager.enemies:
		if not enemy.alive:
			continue
		enemy.position = tower.position + Vector2(
			(float(visible_enemy_index) - 5.0) * 62.0,
			-330.0 - float(visible_enemy_index % 2) * 44.0
		)
		visible_enemy_index += 1
	if manager.alive_count() != 11:
		push_error("Tutorial wave-two capture expected both configured enemy groups")
		get_tree().quit(5)
		return
	if not await _refresh_and_save(combat, session, ENEMIES_OUTPUT):
		return

	for enemy in manager.enemies:
		enemy.alive = false
	manager.update(0.0, false)
	var success_stats := simulation.native.get_stats()
	success_stats["utilization"] = 1.0
	success_stats["damage_dealt"] = 120.0
	success_stats["tower_source_momentum"] = 120.0
	session.evaluate(success_stats)
	session.advance(0.01)
	if not session.is_terminal() or session.result != &"success":
		push_error("Tutorial capture could not reach the success settlement")
		get_tree().quit(6)
		return
	if not await _refresh_and_save(combat, session, FINISHED_OUTPUT):
		return

	print("Captured unique path, dismantle practice, diode route, both tutorial enemies and completion settlement")
	get_tree().quit()


func _configured_offset(level: Resource, prefix: String) -> Vector2:
	return level.position(prefix)


func _refresh_and_save(combat: Node, session: DiodeTutorialSession, path: String) -> bool:
	var manager: EnemyManager = combat.runtime.enemies
	var tower: TowerController = combat.runtime.tower
	var simulation: SimulationController = combat.runtime.simulation
	var world_view: NetworkWorldView = combat.get("_world_view")
	var hud: CombatHud = combat.get("_combat_hud")
	combat.call("_refresh_views")
	world_view.set_combat_state(manager.view_records(), manager.tracers, tower.hp, tower.max_hp)
	hud.set_snapshot(session.hud_snapshot(simulation.native.get_stats()), tower)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		return true
	push_error("Could not save %s: %s" % [path, error_string(error)])
	get_tree().quit(error)
	return false
