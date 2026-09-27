extends SceneTree
## Optimistic diagnostic only: replay the real scheduler with no damage/AI or
## target latch. Available HP / emitted source momentum is not a victory rule.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile := BalanceRepository.load_profile()
	if profile == null:
		quit(1)
		return
	var reports: Array[Dictionary] = []
	var interval := float(profile.value("tower/fire_interval"))
	var shot_momentum := float(profile.value("tower/projectile_mass")) * float(profile.value("tower/projectile_speed"))
	for wave: Dictionary in profile.value("levels/diode_tutorial/waves"):
		var simulation := SimulationController.new(profile)
		if not simulation.initialize():
			quit(1)
			return
		var construction := ConstructionController.new(simulation, profile)
		var tower := TowerController.new(profile)
		var enemies := EnemyManager.new(profile, simulation, construction, tower)
		var director := WaveDirector.new(profile, enemies, simulation, tower)
		if not director.start_spec(&"reachability", wave):
			quit(1)
			return
		var previous_id := 0
		var hp_available := 0.0
		var peak_bound := 0.0
		var spawns: Array[Dictionary] = []
		var dt := float(profile.value("simulation/fixed_step_seconds"))
		while director.elapsed < director.duration:
			director.update_before_simulation(dt)
			for enemy in enemies.enemies:
				if enemy.id > previous_id:
					hp_available += enemy.max_hp
					spawns.append({"time": director.elapsed, "id": enemy.id, "name": enemy.definition.display_name, "hp": enemy.max_hp})
					previous_id = enemy.id
			var source := floorf(director.elapsed / interval) * shot_momentum
			if source > 0.0:
				peak_bound = maxf(peak_bound, hp_available / source)
		var end_source := floorf(director.duration / interval) * shot_momentum
		reports.append({"wave": wave.display_name, "target": wave.target_utilization, "available_hp": hp_available, "deadline_source_momentum": end_source, "deadline_hp_bound": hp_available / end_source, "peak_hp_bound": peak_bound, "obviously_unreachable": peak_bound < float(wave.target_utilization), "spawn_schedule": spawns})
	var summary := {"balance_sha256": FileAccess.get_sha256("res://config/balance/balance.json"), "tower": profile.section("tower"), "waves": reports, "limitation": "Assumes all spawned HP can immediately become actual damage. Ignores travel, absorption, occlusion and device loss. Target latch would stop further spawning. Not a playability proof."}
	var file := FileAccess.open("res://artifacts/v05-reachability.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t", true))
	file.close()
	for report in reports:
		print("REACHABILITY ", report.wave, " target=", report.target, " peak_bound=", report.peak_hp_bound, " deadline_bound=", report.deadline_hp_bound)
	quit(0)
