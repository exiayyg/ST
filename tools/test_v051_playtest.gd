extends SceneTree

var failed := false
var profile: BalanceProfile
var config: RuntimeBalance.Playtest

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _run() -> void:
	profile = BalanceRepository.load_profile()
	config = profile.runtime_config().playtest
	test_migration()
	test_recorder()
	test_campaign()
	test_observer_determinism()
	test_input_and_hits()
	await test_lifecycle()
	print("V051_PLAYTEST ", "FAILED" if failed else "passed")
	quit(1 if failed else 0)

func test_migration() -> void:
	var old := profile.data.duplicate(true)
	preload("res://tools/input_test_driver.gd").legacy_input(old)
	old.erase("playtest")
	old.erase("presentation")
	old.erase("audio")
	old.schema_version = 7
	old.tower.fire_interval = 0.37
	var before := JSON.stringify(old)
	var migrated := BalanceSchema.migrate(old)
	check(BalanceSchema.validate(migrated).is_empty(), "v7 -> v8 validates")
	check(JSON.stringify(old) == before and migrated.tower.fire_interval == 0.37, "migration preserves source and existing tuning")
	check(BalanceSchema.migrate(profile.data) == profile.data, "v8 idempotent migration")
	for field in ["sample_interval_seconds", "flush_interval_seconds", "enemy_hit_flash_seconds"]:
		var bad := profile.duplicate_profile()
		bad.set_value("playtest/" + field, 0.0)
		check(not bad.validate().is_empty(), "zero timing rejects entire config: " + field)

func test_recorder() -> void:
	var disabled := PlaytestRecorder.new()
	check(disabled.begin(false, {}, config, "user://no_consent"), "no consent still permits play")
	disabled.ingest_event({"type": "device_placed"})
	disabled.observe_frame(10.0, {"wave_index": 1})
	disabled.finish("quit")
	check(disabled.snapshot().is_empty() and not DirAccess.dir_exists_absolute("user://no_consent"), "no consent produces no files or samples")
	var recorder := PlaytestRecorder.new()
	check(recorder.begin(true, {"config_hash": "test"}, config, "user://recorder_unit"), "recorder begins")
	recorder.ingest_event({"type": "enemy_hit", "damage": 0})
	check(not recorder.snapshot().first_events.has("enemy_hit"), "zero damage not a first hit")
	recorder.ingest_event({"type": "enemy_hit", "damage": 12, "entity_id": 1234, "position": Vector2(4, 5)})
	recorder.ingest_event({"type": "device_moved", "device_id": 8, "anchor_index": 1})
	recorder.observe_frame(1.0, {"wave_index": 1, "tutorial_phase": "wave_1", "tower_hp": 1000, "real_frame_time": 0.013479116666666667})
	recorder.observe_frame(2.0, {}, true)
	recorder.observe_frame(0.0, {"wave_index": 1, "phase": "clearing", "actual_damage": 24.0, "enemy_count": 3, "no_damage_seconds": 2.0})
	recorder.observe_frame(0.0, {"wave_index": 1, "phase": "intermission", "actual_damage": 24.0, "live_source_momentum": 999})
	check(recorder.snapshot().waves["1"].phase == "clearing" and recorder.snapshot().waves["1"].actual_damage == 24.0, "intermission cannot overwrite completed wave with later source momentum")
	var directory := recorder.report_directory()
	recorder.finish("retry")
	var summary := recorder.snapshot()
	check(summary.elapsed_seconds == 1.0 and summary.paused_seconds == 2.0, "paused time separate from simulation")
	check(summary.actions.device_moved == 1 and summary.reason == "retry", "semantic actions counted")
	var saved := FileAccess.get_file_as_string(directory.path_join("summary.json"))
	recorder.finish("quit")
	check(saved == FileAccess.get_file_as_string(directory.path_join("summary.json")), "finish writes exactly once")
	check(not FileAccess.get_file_as_string(directory.path_join("events.jsonl")).contains("entity_id"), "no projectile identifiers or trajectories in journal")
	check(recorder.submit_feedback({"stuck": "测试意见", "unclear": "", "other": ""}), "optional feedback saves")
	check(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("summary.json"))).feedback.stuck == "测试意见", "feedback round trip")
	var interrupted := PlaytestRecorder.new()
	check(interrupted.begin(true, {}, config, "user://interrupted"), "interruption fixture begins")
	var interrupted_dir := interrupted.report_directory()
	interrupted = null
	PlaytestRecorder.recover_interrupted("user://interrupted")
	check(JSON.parse_string(FileAccess.get_file_as_string(interrupted_dir.path_join("summary.json"))).reason == "interrupted", "unfinished consented journal is preserved and marked interrupted")
	var blocker := FileAccess.open("user://blocked_path", FileAccess.WRITE)
	blocker.close()
	var failing := PlaytestRecorder.new()
	var notices: Array[String] = []
	failing.recording_failed.connect(func(message: String): notices.append(message))
	check(not failing.begin(true, {}, config, "user://blocked_path/child"), "write failure is nonfatal return")
	check(notices.size() == 1 and not notices[0].contains("成绩未保存"), "recording error distinct from progress error")

func test_campaign() -> void:
	var service := CampaignService.new()
	root.add_child(service)
	service.configure_for_tests(load("res://resources/levels/campaign_catalog.tres"), "user://playtest_progress.json", func(_path: String): return OK)
	check(service.record_campaign_result(&"diode_tutorial", {"result": "timeout", "utilization": 1.23}) == OK, "fixture formal failed best saved")
	var original := FileAccess.get_file_as_bytes("user://playtest_progress.json")
	for consent in [false, true]:
		check(service.launch_playtest(&"diode_tutorial", consent) == OK, "playtest launches")
		var spec := SessionSpec.from_launch(service.current_launch_snapshot())
		check(spec.source == &"playtest" and spec.record_enabled == consent and spec.balance_key == "levels/diode_tutorial", "launch binding and authorization propagated")
		for result in ["success", "timeout"]:
			check(service.record_campaign_result(&"diode_tutorial", {"result": result, "utilization": 2.0}) == ERR_UNAUTHORIZED, "playtest cannot submit formal result")
		check(service.retry_current() == OK and service.current_launch_snapshot().record_enabled == consent, "retry retains consent")
		check(service.return_to_frontend() == OK and service.current_launch_snapshot().is_empty(), "return clears consent")
		check(FileAccess.get_file_as_bytes("user://playtest_progress.json") == original, "all playtest navigation preserves formal progress bytes")
	service.free()

func run_trace(record_enabled: bool) -> Dictionary:
	var camera := Camera2D.new()
	root.add_child(camera)
	var runtime := WorldRuntime.new()
	var controller := PrototypeCameraController.new(camera, profile.map_rect(), root, profile)
	check(runtime.initialize(profile, SessionSpec.development(&"single_wave"), controller, root, false), "world initializes")
	var recorder := PlaytestRecorder.new()
	recorder.begin(record_enabled, {}, config, "user://determinism")
	var events: Array = []
	runtime.gameplay_event.connect(func(event: Dictionary):
		events.append(event.duplicate(true))
		recorder.ingest_event(event))
	runtime.construction.place(runtime.catalog.get_definition(&"diode"), Vector2(180, 0), 0, Vector2(0, -180), -PI * 0.5)
	for frame in 2400:
		runtime.advance(1.0 / 120.0)
		recorder.observe_frame(1.0 / 120.0, {"wave_index": 1})
	var stats := runtime.simulation.native.get_stats()
	for key in stats.keys():
		if String(key).contains("milliseconds") or String(key).contains("microseconds"):
			stats.erase(key)
	var result := {"stats": stats, "events": events, "completion": runtime.session.completion_snapshot(),
		"entities": runtime.simulation.native.get_render_snapshot(profile.map_rect(), 0.0)}
	recorder.finish("test")
	runtime.shutdown()
	camera.free()
	return result

func test_observer_determinism() -> void:
	check(run_trace(false) == run_trace(true), "recording on/off identical ordered events, ledger, entity snapshot and outcome")

func test_input_and_hits() -> void:
	var scene := load("res://scenes/levels/diode_tutorial.tscn").instantiate() as WorldScreen
	root.add_child(scene)
	scene.set_process(false)
	var runtime := scene.runtime
	var actions: Array = []
	runtime.input.semantic_event.connect(func(event: Dictionary): actions.append(event.duplicate()))
	var id := runtime.construction.place(runtime.catalog.get_definition(&"diode"), Vector2(180, 0), 0, Vector2(0, -180))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = root.get_canvas_transform() * Vector2(0, -180)
	press.pressed = true
	runtime.input.handle_input(press)
	press.pressed = false
	runtime.input.handle_input(press)
	check(actions.is_empty(), "selection click is not a movement")
	press.pressed = true
	runtime.input.handle_input(press)
	runtime.input.advance(0.0)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * Vector2(40, -180)
	runtime.input.handle_input(motion)
	runtime.input.advance(0.0)
	runtime.input.cancel()
	check(actions.filter(func(e): return e.type == "device_moved").size() == 1, "cancel after actual dragging still records one movement")
	actions.clear()
	var driver := preload("res://tools/input_test_driver.gd")
	var pivot := root.get_canvas_transform() * Vector2(40, -180)
	driver.mouse(runtime.input, pivot, true, MOUSE_BUTTON_RIGHT)
	driver.motion(runtime.input, pivot + Vector2(100, -30))
	check(actions.is_empty(), "rotation preview records no committed action")
	driver.mouse(runtime.input, pivot + Vector2(100, -30), false, MOUSE_BUTTON_RIGHT)
	check(actions.filter(func(e): return e.type == "device_rotated").size() == 1, "one completed gesture records one rotation")
	driver.mouse(runtime.input, pivot, true, MOUSE_BUTTON_RIGHT)
	driver.motion(runtime.input, pivot + Vector2(0, -100))
	runtime.input.cancel()
	check(actions.filter(func(e): return e.type == "device_rotated").size() == 1, "cancelled preview never records rotation")
	check(runtime.input.hold_progress() == 0.0, "cancellation clears hold ring")
	var enemy_id := runtime.enemies.spawn(&"tutorial_breaker", &"north")
	var enemy := runtime.enemies.find_enemy(enemy_id)
	runtime.enemies.apply_native_event({"type": "enemy_hit", "subject_id": enemy_id, "damage": 1.0})
	runtime.enemies.apply_native_event({"type": "enemy_hit", "subject_id": enemy_id, "damage": 1.0})
	check(enemy.hit_flash_remaining == config.enemy_hit_flash_seconds, "same-frame positive hits merge without stacking duration")
	var rendered: Array = runtime.snapshot(profile.map_rect()).enemies
	check(rendered.size() == 1 and rendered[0].hit_flash_remaining == 0.0, "unlit enemies never expose hit flashes through fog")
	enemy.position = Vector2(80, 0)
	rendered = runtime.snapshot(profile.map_rect()).enemies
	check(rendered[0].hit_flash_remaining > 0.0, "same enemy retains actual flash when within lighting")
	runtime.enemies.apply_native_event({"type": "enemy_hit", "subject_id": enemy_id, "damage": enemy.hp})
	check(runtime.enemies.alive_count() == 0, "killing hit immediately removes AI/combat participation")
	rendered = runtime.snapshot(profile.map_rect()).enemies
	check(rendered.size() == 1 and rendered[0].get("hit_flash_only", false), "killing hit retains only one transient presentation record")
	runtime.enemies.update(config.enemy_hit_flash_seconds, false)
	check(runtime.snapshot(profile.map_rect()).enemies.is_empty(), "death flash expires without resurrecting enemy")
	check(runtime.construction.devices.has(id), "semantic observation never removes device")
	scene.free()

func test_lifecycle() -> void:
	var campaign := root.get_node("_campaign_service") as CampaignService
	campaign.configure_for_tests(load("res://resources/levels/campaign_catalog.tres"), "user://lifecycle_progress.json")
	check(campaign.launch_playtest(&"diode_tutorial", true) == OK, "recording lifecycle launch")
	await scene_changed
	var reports := get_reports()
	check(reports.size() == 1, "consented launch creates one report")
	var old_dir: String = reports[0]
	var balance := root.get_node("_balance_service")
	var candidate: BalanceProfile = balance.active_profile().duplicate_profile()
	candidate.set_value("playtest/hold_ring_width", config.hold_ring_width + 1.0)
	check(balance.apply_and_reset(candidate).is_empty(), "valid apply accepted")
	await scene_changed
	check(get_reports().size() == 2, "apply reset starts new consented run")
	var old = JSON.parse_string(FileAccess.get_file_as_string(old_dir.path_join("summary.json")))
	check(old.finished and old.reason == "balance_reset", "successful reset finishes old report as reset")
	var newer_dir := get_reports().filter(func(path): return path != old_dir)[0] as String
	var newer = JSON.parse_string(FileAccess.get_file_as_string(newer_dir.path_join("summary.json")))
	check(newer.metadata.config_hash != old.metadata.config_hash, "config hashes separate reset worlds")
	var invalid := candidate.duplicate_profile()
	invalid.set_value("tower/fire_interval", -1.0)
	check(not balance.apply_and_reset(invalid).is_empty(), "invalid reset rejected")
	await process_frame
	check(get_reports().size() == 2 and not JSON.parse_string(FileAccess.get_file_as_string(newer_dir.path_join("summary.json"))).finished, "failed reset continues original recording")
	check(campaign.return_to_frontend() == OK, "return after playtest")
	await scene_changed
	check(not FileAccess.file_exists("user://lifecycle_progress.json"), "playtest lifecycle never writes formal progress")
	check(JSON.parse_string(FileAccess.get_file_as_string(newer_dir.path_join("summary.json"))).finished, "scene exit closes recording")

func get_reports() -> Array[String]:
	var paths: Array[String] = []
	for name in DirAccess.get_directories_at("user://playtests"):
		paths.append("user://playtests".path_join(name))
	return paths
