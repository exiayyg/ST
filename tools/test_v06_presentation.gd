extends SceneTree

var failures: Array[String] = []
var profile: BalanceProfile

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _run() -> void:
	profile = BalanceRepository.load_profile()
	check(profile != null, "balance loads")
	if profile == null:
		quit(1)
		return
	var old := profile.data.duplicate(true)
	preload("res://tools/input_test_driver.gd").legacy_input(old)
	old.schema_version = 8
	old.erase("presentation")
	old.erase("audio")
	var original := old.duplicate(true)
	var migrated := BalanceSchema.migrate(old)
	check(old == original and migrated.schema_version == 11 and BalanceSchema.validate(migrated).is_empty(), "v8 migration is non-mutating and complete")
	check(migrated.tower == original.tower and migrated.devices == original.devices and migrated.levels == original.levels, "migration preserves gameplay")
	for section in ["presentation", "audio"]:
		for key in profile.data[section]:
			check(not BalanceFieldCatalog.descriptor(section + "/" + key, profile.data[section][key]).is_empty(), "registered presentation field")
			check(profile.runtime_config().get(section).get(key) == profile.data[section][key], "typed field matches JSON")
	var bad := profile.duplicate_profile()
	bad.data.audio.world_voices = 0
	check(not bad.validate().is_empty(), "voice cap rejects zero")
	bad = profile.duplicate_profile()
	bad.data.audio.master_volume = NAN
	check(not bad.validate().is_empty(), "nonfinite volume rejected")
	bad = profile.duplicate_profile()
	bad.data.presentation.unknown = 0
	check(not bad.validate().is_empty(), "unknown presentation value rejected")
	var preferences := PresentationPreferences.new()
	preferences.configure(profile, "user://v06-preferences.json")
	check(preferences.update("master_volume", 0.25, "user://v06-preferences.json"), "preference saves")
	var restored := PresentationPreferences.new()
	restored.configure(profile, "user://v06-preferences.json")
	check(restored.master_volume == 0.25, "preference reload")
	check(not preferences.update("master_volume", INF, "user://v06-preferences.json"), "invalid override rejected")
	check(profile.data == BalanceRepository.load_profile().data, "preferences do not mutate project config")
	for cue in EnergySoundBank.CUES:
		var stream := EnergySoundBank.synthesize(profile.runtime_config().audio, cue)
		var peak := 0
		for index in stream.data.size() / 2:
			peak = maxi(peak, absi(stream.data.decode_s16(index * 2)))
		check(peak > 0 and peak <= int(EnergySoundBank.PCM_MAX * profile.runtime_config().audio.peak_gain), "PCM nonempty and bounded: " + cue)
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "PCM endpoints are silent: " + cue)
	var director := PresentationDirector.new()
	root.add_child(director)
	var visibility_calls := [0]
	director.configure(profile, func(position: Vector2):
		visibility_calls[0] += 1
		return position.x >= 0.0)
	director.preferences.muted = true
	for index in 500:
		director.ingest_event({"type":"enemy_hit", "damage":1.0, "position":Vector2.ONE, "subject_id":1})
	director.advance(0.01)
	check(director.effects.size() == 1, "same frame same enemy coalesces")
	check(visibility_calls[0] == 1, "500 same-enemy events perform one frame-end visibility query")
	director.ingest_event({"type":"enemy_hit", "damage":1.0, "position":Vector2(-1, 0), "subject_id":2})
	director.advance(0.01)
	check(director.effects.size() == 1, "hidden enemy produces no extra effects")
	director.ingest_event({"type":"enemy_hit", "damage":0.0, "position":Vector2.ONE, "subject_id":3})
	director.advance(0.01)
	check(director.effects.size() == 1, "zero damage ignored")
	for index in 1000:
		director.ingest_event({"type":"device_activated", "position":Vector2.ONE, "device_id":index})
	director.advance(0.01)
	check(director.effects.size() <= profile.runtime_config().presentation.effect_limit, "effect cap bounded")
	director.preferences.reduced_motion = true
	director.apply_preferences()
	var time := director.decoration_time
	director.advance(0.2)
	check(director.effects.is_empty() and director.decoration_time == time, "reduced motion retains no strong pulses")
	director.reset()
	check(director.effects.is_empty(), "reset clears transient state")
	director.free()
	check(_trace(false) == _trace(true), "presentation on/off identical ordered gameplay events, ledger, entities and result")
	if failures.is_empty(): print("V06_PRESENTATION passed: migration, preference isolation, PCM, coalescing, visibility, reduced motion and deterministic world")
	else:
		for message in failures: push_error("FAIL: " + message)
	quit(0 if failures.is_empty() else 1)

func _trace(enabled: bool) -> Dictionary:
	var camera := Camera2D.new()
	root.add_child(camera)
	var world := WorldRuntime.new()
	var controller := PrototypeCameraController.new(camera, profile.map_rect(), root, profile)
	check(world.initialize(profile, SessionSpec.development(&"single_wave"), controller, root, false), "trace initializes")
	var presentation := PresentationDirector.new()
	root.add_child(presentation)
	presentation.configure(profile, func(_position: Vector2): return true)
	presentation.preferences.muted = true
	var events: Array = []
	world.gameplay_event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	if enabled:
		world.gameplay_event.connect(presentation.ingest_event)
		world.presentation_event.connect(presentation.ingest_event)
	world.construction.place(world.catalog.get_definition(&"diode"), Vector2(180, 0), 0, Vector2(0, -180), -PI * 0.5)
	for frame in 2400:
		world.advance(1.0 / 120.0)
		if enabled: presentation.advance(1.0 / 120.0)
	var stats := world.simulation.native.get_stats()
	for key in stats.keys():
		if String(key).contains("milliseconds") or String(key).contains("microseconds"): stats.erase(key)
	var result := {"events":events, "stats":stats, "result":world.session.completion_snapshot(), "entities":world.simulation.native.get_render_snapshot(profile.map_rect(), 0.0)}
	world.shutdown()
	presentation.free()
	camera.free()
	return result
