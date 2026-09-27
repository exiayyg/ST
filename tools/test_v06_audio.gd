extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile := BalanceRepository.load_profile()
	var director := PresentationDirector.new()
	root.add_child(director)
	director.configure(profile, func(_position: Vector2): return true)
	print("AUDIO_DEVICE output=", AudioServer.output_device, " devices=", AudioServer.get_output_device_list())
	if not director.audio_available:
		push_error("FAIL: no actual audio output; listening not verified")
		quit(2)
		return
	director.preferences.muted = false
	director.play_ui()
	await create_timer(0.03).timeout
	var playing := false
	for child in director.get_children():
		if child is AudioStreamPlayer and child.playing: playing = true
	if not playing:
		push_error("FAIL: actual output did not start")
		quit(1)
		return
	for cue in ["place", "activate", "tower_fire", "transform", "hit", "destroy", "warning", "target", "victory", "failure"]:
		var kinds := {"place":"device_placed", "activate":"device_activated", "tower_fire":"tower_fired", "transform":"projectile_split", "hit":"enemy_hit", "destroy":"device_destroyed"}
		var view := {}
		if kinds.has(cue):
			director.ingest_event({"type":kinds[cue], "position":Vector2.ZERO, "damage":1.0})
		elif cue == "warning":
			view = {"session":{"phase":"active", "warnings":{"north":{"count":1}}}}
		elif cue == "target":
			view = {"session":{"phase":"clearing"}}
		else:
			view = {"session":{"phase":"finished", "terminal":true, "result":"success" if cue == "victory" else "failure"}}
		director.advance(0.5, view)
		await create_timer(0.5).timeout
	var limited := profile.duplicate_profile()
	limited.data.audio.world_voices = 1
	limited.data.presentation.effect_limit = 1
	director.configure(limited, func(_position: Vector2): return true)
	for index in 1000:
		director.ingest_event({"type":"enemy_hit", "position":Vector2.ZERO, "damage":1.0, "subject_id":index})
	director.ingest_event({"type":"device_destroyed", "position":Vector2.ZERO, "device_id":1})
	director.advance(0.5)
	if director.last_played != ["destroy"] or director.effects.size() != 1:
		push_error("FAIL: decoration cap must not starve high-priority audio")
		quit(1)
		return
	await create_timer(0.5).timeout
	director.ingest_event({"type":"enemy_hit", "position":Vector2.ZERO, "damage":1.0})
	director.advance(0.5)
	paused = true
	await create_timer(0.02, true).timeout
	for child in director.get_children():
		if child is AudioStreamPlayer and child.playing and not child.stream_paused:
			push_error("FAIL: world voice not paused")
			paused = false
			quit(1)
			return
	paused = false
	director.reset()
	director.free()
	print("V06_AUDIO_DEVICE passed: real output playback, no device errors, pause; subjective timbre still requires human listening")
	quit()
