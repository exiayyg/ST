extends SceneTree

func _initialize() -> void:
	var profile := BalanceRepository.load_profile()
	if profile == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for kind in EnergySoundBank.CUES:
		var stream := EnergySoundBank.synthesize(profile.runtime_config().audio, kind)
		var error := stream.save_to_wav("res://assets/audio/%s.wav" % kind)
		if error != OK:
			push_error("Audio bake failed: %s" % kind)
			quit(1)
			return
	var file := FileAccess.open("res://assets/audio/bank.sha256", FileAccess.WRITE)
	file.store_string(JSON.stringify(profile.data.audio, "", true, true).sha256_text())
	file.close()
	print("ENERGY_AUDIO_BAKE passed: ", EnergySoundBank.CUES.size(), " original PCM resources")
	quit()
