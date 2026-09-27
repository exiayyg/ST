extends SceneTree
## Accelerated diagnostic trial through public world commands. Not UI acceptance.
## No HP, ledger, enemy state, autofire, or director-state writes.

var trace: Array[Dictionary] = []
var elapsed := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/levels/diode_tutorial.tscn") as PackedScene
	if scene == null:
		quit(2)
		return
	var host := scene.instantiate()
	root.add_child(host)
	host.set_process(false)
	var runtime: WorldRuntime = host.runtime
	var lesson := runtime.session as DiodeTutorialSession
	var config := lesson.level
	var phase := ""
	var last_log := -1
	var acted: Dictionary = {}
	var second_wave_started := -1.0
	var totals := {"activation": -1.0, "hit": -1.0, "losses": 0, "operations": 0}
	runtime.gameplay_event.connect(func(event: Dictionary):
		match String(event.type):
			"device_activated":
				if totals.activation < 0.0: totals.activation = elapsed
			"enemy_hit":
				if float(event.get("damage", 0.0)) > 0.0 and totals.hit < 0.0: totals.hit = elapsed
			"device_destroyed": totals.losses += 1
	)
	while elapsed < 360.0 and not lesson.is_terminal():
		var next := String(lesson.hud_snapshot({}).tutorial_phase)
		if phase != next:
			phase = next
			print("TRIAL_PHASE ", elapsed, " ", phase)
		if phase == "practice_place" and not acted.has(phase):
			runtime.construction.place(runtime.catalog.get_definition(&"diode"), config.position("practice_entry"), 0, config.position("practice_exit"))
			acted[phase] = true
		elif phase == "practice_dismantle" and not acted.has(phase):
			runtime.construction.dismantle_selected()
			acted[phase] = true
		elif phase == "route_build" and not acted.has(phase):
			runtime.construction.place(runtime.catalog.get_definition(&"diode"), config.position("route_entry"), 0, config.position("route_exit"), deg_to_rad(config.route_exit_angle_degrees))
			acted[phase] = true
		if lesson.current_wave_index == 1 and second_wave_started < 0.0:
			second_wave_started = elapsed
		if "--adjust" in OS.get_cmdline_user_args() and second_wave_started >= 0.0 and elapsed - second_wave_started >= 24.0 and not acted.has("redirect"):
			runtime.construction.selected_anchor = 1
			runtime.construction.move_selected(Vector2(80, -340))
			acted["redirect"] = true
			totals.operations += 1
		runtime.advance(1.0 / 120.0)
		elapsed += 1.0 / 120.0
		if int(elapsed) != last_log:
			last_log = int(elapsed)
			var enemies: Array = []
			for enemy in runtime.enemies.enemies:
				if enemy.alive: enemies.append({"id": enemy.id, "position": enemy.position, "hp": enemy.hp, "target_id": enemy.target_id, "anchor": enemy.target_anchor})
			var devices: Array = []
			for device: Dictionary in runtime.construction.devices.values():
				devices.append({"id": device.id, "hp": device.hp, "exit": device.secondary_position})
			var record := {"time": elapsed, "phase": phase, "wave": lesson.current_wave_index + 1, "tower_hp": runtime.tower.hp, "enemies": enemies, "devices": devices, "stats": runtime.simulation.native.get_stats(), "feedback": lesson.diagnostic_snapshot()}
			trace.append(record)
	print("TRIAL_RESULT ", JSON.stringify({"result": lesson.completion_snapshot(), "totals": totals, "elapsed": elapsed}))
	var file := FileAccess.open("res://artifacts/v05-route-trial.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(trace, "\t", true))
	file.close()
	host.free()
	quit(0)
