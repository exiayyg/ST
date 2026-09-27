extends Node

const ENDLESS_SCENE := preload("res://scenes/combat/endless_sandbox.tscn")

const PREPARING_OUTPUT := "res://artifacts/endless-preparing.png"
const RADIAL_OUTPUT := "res://artifacts/endless-radial-fullscreen.png"
const BALANCE_OUTPUT := "res://artifacts/endless-balance-panel.png"
const ADJACENT_OUTPUT := "res://artifacts/endless-adjacent-warning.png"
const CLEARING_OUTPUT := "res://artifacts/endless-clearing.png"
const INTERMISSION_OUTPUT := "res://artifacts/endless-intermission.png"
const MULTIFRONT_OUTPUT := "res://artifacts/endless-wave5-multifront.png"
const DEBUG_OUTPUT := "res://artifacts/endless-f3-diagnostics.png"
const FAILED_OUTPUT := "res://artifacts/endless-run-failed.png"


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var combat := ENDLESS_SCENE.instantiate()
	add_child(combat)
	combat.runtime.set("auto_fire", false)
	for _frame in 5:
		await get_tree().process_frame
	combat.runtime.input.set("_radial_hold_seconds", 0.0)
	var press_position := get_viewport().get_visible_rect().size * 0.5 + Vector2(140.0, 120.0)
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.position = press_position
	press_event.global_position = press_position
	press_event.pressed = true
	get_viewport().push_input(press_event, true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var radial_image := get_viewport().get_texture().get_image()
	var radial_error := radial_image.save_png(RADIAL_OUTPUT)
	if radial_error != OK:
		push_error("Could not save %s: %s" % [RADIAL_OUTPUT, error_string(radial_error)])
		get_tree().quit(radial_error)
		return
	print("Fullscreen capture mode=%d viewport=%s" % [
		DisplayServer.window_get_mode(), str(radial_image.get_size())
	])
	var release_event := press_event.duplicate() as InputEventMouseButton
	release_event.pressed = false
	get_viewport().push_input(release_event, true)
	await get_tree().process_frame
	combat.set_process(false)

	var session: EndlessRunDirector = combat.runtime.session
	var manager: EnemyManager = combat.runtime.enemies
	var tower: TowerController = combat.runtime.tower
	var simulation: SimulationController = combat.runtime.simulation
	var hud: CombatHud = combat.get("_combat_hud")
	if session == null or manager == null or tower == null or hud == null:
		push_error("Endless capture fixture could not resolve the live combat modules")
		get_tree().quit(4)
		return

	await _refresh_and_save(combat, session, PREPARING_OUTPUT)
	var balance_overlay: BalanceRuntimeOverlay
	for child in combat.get_children():
		if child is BalanceRuntimeOverlay:
			balance_overlay = child
			break
	if balance_overlay == null or balance_overlay.panel == null:
		push_error("Endless capture fixture could not resolve the runtime balance panel")
		get_tree().quit(10)
		return
	var balance_panel := balance_overlay.panel
	balance_panel.visible = true
	balance_panel.get("_search").text = "waves/endless"
	balance_panel.call("_filter_rows", "waves/endless")
	var preparation_control := (balance_panel.get("_path_controls") as Dictionary).get(
		"waves/endless/opening_preparation_seconds"
	) as Control
	if preparation_control != null:
		balance_panel.get("_scroll").ensure_control_visible(preparation_control)
	await _refresh_and_save(combat, session, BALANCE_OUTPUT)
	balance_panel.visible = false

	session.wave_index = 1
	session.pending_spec = session.generator.generate(2, session.run_seed)
	session.state = EndlessRunDirector.State.INTERMISSION
	session.phase_remaining = 0.0
	session.advance(0.0)
	session.advance(12.0)
	if session.wave_index != 2 or session.wave_director.latest_warnings.size() < 2:
		push_error("Adjacent warning fixture did not expose two directions")
		get_tree().quit(5)
		return
	hud.selected_direction = String(session.wave_director.latest_warnings.keys()[0])
	await _refresh_and_save(combat, session, ADJACENT_OUTPUT)

	session.evaluate({
		"utilization": 1.0, "damage_dealt": 120.0, "tower_source_momentum": 120.0,
		"projectile_count": 48, "wave_point_count": 0, "enemy_proxy_count": manager.alive_count(),
	})
	if session.state != EndlessRunDirector.State.CLEARING or manager.alive_count() <= 0:
		push_error("Clearing fixture did not preserve living enemies after target reach")
		get_tree().quit(6)
		return
	await _refresh_and_save(combat, session, CLEARING_OUTPUT)

	for enemy in manager.enemies:
		enemy.alive = false
	manager.update(0.0, true)
	session.advance(0.001)
	if session.state != EndlessRunDirector.State.INTERMISSION:
		push_error("Intermission fixture did not follow an empty clearing state")
		get_tree().quit(7)
		return
	await _refresh_and_save(combat, session, INTERMISSION_OUTPUT)

	session.wave_index = 4
	session.pending_spec = session.generator.generate(5, session.run_seed)
	session.state = EndlessRunDirector.State.INTERMISSION
	session.phase_remaining = 0.0
	session.advance(0.0)
	session.advance(23.0)
	if session.wave_index != 5 or session.wave_director.latest_warnings.size() < 3:
		push_error("Wave-five fixture did not expose three directional warnings")
		get_tree().quit(8)
		return
	await _refresh_and_save(combat, session, MULTIFRONT_OUTPUT)
	hud.debug_visible = true
	await _refresh_and_save(combat, session, DEBUG_OUTPUT)
	hud.debug_visible = false

	tower.hp = 0.0
	session.evaluate({"utilization": 0.22, "damage_dealt": 44.0, "tower_source_momentum": 200.0})
	if not session.is_terminal() or session.result != &"tower_destroyed":
		push_error("Endless failure fixture did not enter tower-destroyed settlement")
		get_tree().quit(9)
		return
	await _refresh_and_save(combat, session, FAILED_OUTPUT)

	print("Captured fullscreen radial wheel, endless preparation, balance fields, adjacent warning, clearing, intermission, wave-five fronts, F3 diagnostics and failure settlement")
	get_tree().quit()


func _refresh_and_save(combat: Node, session: EndlessRunDirector, path: String) -> void:
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
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		get_tree().quit(error)
