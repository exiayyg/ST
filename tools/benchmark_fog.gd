extends SceneTree

const FogOfWarType := preload("res://scripts/prototype/fog_of_war.gd")


func _init() -> void:
	var native := MomentumSimulation.new()
	var fog := FogOfWarType.new(native) as FogOfWar
	var sources: Array[Dictionary] = []
	for index in 100:
		sources.append({
			"position": Vector2(
				-2070.0 + float(index % 10) * 460.0,
				-1050.0 + float(index / 10) * 230.0
			),
			"radius": 260.0,
		})
	var samples: Array[float] = []
	for _sample in 10:
		fog.rebuild(sources)
		samples.append(fog.last_rebuild_milliseconds)
	samples.sort()
	print("fog_native sources=100 grid=256x144 samples=10 p50_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [
		samples[4], samples[8], samples[9],
	])
	quit()
