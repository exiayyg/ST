extends Node

const COMBAT_SCENE := preload("res://scenes/combat/combat_sandbox.tscn")

const COMBAT_OUTPUT := "res://artifacts/combat-skeleton-overview.png"
const DESTROY_OUTPUT := "res://artifacts/combat-device-destruction.png"
const ENTROPY_THRESHOLD_OUTPUT := "res://artifacts/balance-panel-entropy-threshold.png"
const ENTROPY_ABOVE_OUTPUT := "res://artifacts/balance-panel-entropy-above.png"
const WAVE_FINISHED_OUTPUT := "res://artifacts/combat-wave-finished.png"
const WAVE_FAILED_OUTPUT := "res://artifacts/combat-wave-failed.png"


func _ready() -> void:
	_capture.call_deferred()


func _save(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		get_tree().quit(error)
		return false
	return true


func _capture() -> void:
	var combat := COMBAT_SCENE.instantiate()
	add_child(combat)
	combat.runtime.set("auto_fire", false)
	for _frame in 6:
		await get_tree().process_frame

	var construction: ConstructionController = combat.runtime.construction
	var catalog: DeviceCatalog = combat.runtime.catalog
	var simulation: SimulationController = combat.runtime.simulation
	var world_view: NetworkWorldView = combat.get("_world_view")
	var manager: EnemyManager = combat.runtime.enemies
	var session := combat.runtime.session as SingleWaveSession
	var director: WaveDirector = session.wave_director if session != null else null
	var combat_hud: CombatHud = combat.get("_combat_hud")
	if director == null:
		push_error("Single-wave capture fixture could not resolve its session adapter")
		get_tree().quit(3)
		return

	var speed_id := construction.place(catalog.get_definition(&"speed_increaser"), Vector2(175.0, 40.0))
	var bounce_id := construction.place(catalog.get_definition(&"bounce_plate"), Vector2(315.0, 40.0), PI * 0.5)
	for target in [Vector2(175.0, 40.0), Vector2(315.0, 40.0)]:
		var commands: Array[Dictionary] = []
		for _shot in 4:
			commands.append({
				"position": target - Vector2(44.0, 0.0), "velocity": Vector2(240.0, 0.0),
				"mass": 0.05, "tower_source": false,
			})
		simulation.native.emit_projectiles(commands)
		simulation.native.step(0.15)
	construction.sync(simulation.native.get_device_snapshot())
	var low_hp_record: Dictionary = construction.devices.get(speed_id, {})
	low_hp_record.hp = 24.0
	construction.devices[speed_id] = low_hp_record

	var melee := manager.find_enemy(manager.spawn(&"dev_melee", &"east"))
	melee.position = Vector2(270.0, 130.0)
	var ranged := manager.find_enemy(manager.spawn(&"dev_ranged", &"north"))
	ranged.position = Vector2(300.0, -130.0)
	ranged.entropy = 75.0
	manager.call("_ranged_attack", ranged, Vector2.ZERO)
	combat.runtime.set("lighting_dirty", true)
	combat.runtime.call("rebuild_fog")
	combat.call("_refresh_views")
	world_view.set_combat_state(manager.view_records(), manager.tracers, float(combat.runtime.tower.hp), float(combat.runtime.tower.max_hp))
	combat_hud.set_state(director, simulation.native.get_stats(), combat.runtime.tower)
	for _frame in 5:
		await get_tree().process_frame
	if not _save(COMBAT_OUTPUT):
		return

	construction.damage_device(bounce_id, 1000.0)
	combat.runtime.set("lighting_dirty", true)
	combat.runtime.call("rebuild_fog")
	combat.call("_refresh_views")
	await get_tree().process_frame
	if not _save(DESTROY_OUTPUT):
		return

	var balance_overlay: BalanceRuntimeOverlay
	for child in combat.get_children():
		if child is BalanceRuntimeOverlay:
			balance_overlay = child
			break
	if balance_overlay == null or balance_overlay.panel == null:
		push_error("Runtime balance panel was not created in the development build")
		get_tree().quit(4)
		return
	var panel := balance_overlay.panel
	panel.visible = true
	panel.get("_search").text = "uncertainty_curve"
	panel.call("_filter_rows", "uncertainty_curve")
	await get_tree().process_frame
	var curve_control := (panel.get("_path_controls") as Dictionary).get("entropy/uncertainty_curve") as Control
	if curve_control != null:
		panel.get("_scroll").ensure_control_visible(curve_control)
	panel.get("_preview_entropy").value = 50.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not _save(ENTROPY_THRESHOLD_OUTPUT):
		return
	panel.get("_preview_entropy").value = 75.0
	await get_tree().process_frame
	if not _save(ENTROPY_ABOVE_OUTPUT):
		return

	panel.visible = false
	var success_stats := {"utilization": 1.0, "damage_dealt": 120.0, "tower_source_momentum": 120.0,
		"last_step_milliseconds": 0.0, "projectile_count": 0, "wave_point_count": 0,
		"enemy_proxy_count": 0}
	director.evaluate_after_simulation(success_stats)
	director.update_before_simulation(0.016)
	combat_hud.set_state(director, director.stats_for_display(success_stats), combat.runtime.tower)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var settlement_rect: Rect2 = combat_hud.call("_settlement_panel_rect", get_viewport().get_visible_rect().size)
	var settlement_region := Rect2i(settlement_rect)
	var success_panel := get_viewport().get_texture().get_image().get_region(settlement_region).get_data()
	if not _save(WAVE_FINISHED_OUTPUT):
		return

	combat.set_process(false)
	var tower: TowerController = combat.runtime.tower
	var failed_director := WaveDirector.new(combat.get("_profile"), manager, simulation, tower)
	failed_director.start(&"dev_wave_01")
	tower.hp = 0.0
	var failure_stats := {"utilization": 0.07, "damage_dealt": 14.0, "tower_source_momentum": 200.0}
	failed_director.evaluate_after_simulation(failure_stats)
	combat_hud.set_state(failed_director, failed_director.stats_for_display(failure_stats), tower)
	if failed_director.state != WaveDirector.State.FAILED or failed_director.result != &"tower_destroyed" or not combat_hud.terminal:
		push_error("Failure settlement fixture did not enter the expected tower-destroyed state")
		get_tree().quit(5)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var failure_panel := get_viewport().get_texture().get_image().get_region(settlement_region).get_data()
	if failure_panel == success_panel:
		push_error("Failure settlement capture must differ from success settlement capture")
		get_tree().quit(5)
		return
	if not _save(WAVE_FAILED_OUTPUT):
		return

	print("Captured combat skeleton, destruction, entropy panel threshold/above, success and failure settlement screenshots")
	get_tree().quit()
