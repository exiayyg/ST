class_name EnergySoundBank
extends RefCounted

const CUES := ["ui_confirm", "ui_cancel", "place", "activate", "dismantle", "tower_fire", "transform", "hit", "destroy", "warning", "target", "victory", "failure", "enemy_attack"]
# PCM format / synthesis harmonic identities; not simulation parameters.
const PCM_MAX := 32767.0
const PCM_BYTES := 2

static func synthesize(config: RuntimeBalance.Audio, kind: String) -> AudioStreamWAV:
	var cue := config.cue(kind)
	var frames := int(ceil(float(cue.duration) * config.sample_rate))
	var bytes := PackedByteArray()
	bytes.resize(frames * PCM_BYTES)
	for index in frames:
		var t := float(index) / config.sample_rate
		var ratio := float(index) / maxi(frames - 1, 1)
		var envelope := minf(t / config.attack_seconds, 1.0) * pow(1.0 - ratio, 1.0 / config.release_ratio)
		# Fundamental and octave, normalized to unit peak. Fixed synthesis, no RNG.
		var phase := TAU * float(cue.frequency) * t
		var value := (sin(phase) + sin(phase * config.harmonic_multiple) * config.harmonic_ratio) / (1.0 + config.harmonic_ratio)
		bytes.encode_s16(index * PCM_BYTES, int(value * envelope * config.peak_gain * PCM_MAX))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = config.sample_rate
	stream.data = bytes
	return stream

static func load_bank(profile: BalanceProfile) -> Dictionary:
	var streams := {}
	var hash_value := JSON.stringify(profile.data.audio, "", true, true).sha256_text()
	var shipped_hash := FileAccess.get_file_as_string("res://assets/audio/bank.sha256").strip_edges() if FileAccess.file_exists("res://assets/audio/bank.sha256") else ""
	for kind in CUES:
		var path := "res://assets/audio/%s.wav" % kind
		if shipped_hash == hash_value and ResourceLoader.exists(path):
			streams[kind] = load(path)
		else:
			# Changed synthesis parameters compile once at configuration reset, never on a hit.
			streams[kind] = synthesize(profile.runtime_config().audio, kind)
	return streams
