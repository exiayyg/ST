extends SceneTree

var trace: Array = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/combat/endless_sandbox.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.gameplay_event.connect(func(event: Dictionary): trace.append(event.duplicate(true)))
	# The same fixture runs against the preserved pre-refactor project.
	var world = scene.get("runtime")
	var simulation: SimulationController = world.simulation if world != null else scene.get("_simulation")
	var construction: ConstructionController = world.construction if world != null else scene.get("_construction")
	var catalog: DeviceCatalog = world.catalog if world != null else scene.get("_catalog")
	for frame in 240:
		scene._process(1.0 / 120.0)
	print("WORLD_TRACE ", JSON.stringify({"events": trace, "stats": _stable_stats(simulation)}, "", true))
	var diode := construction.place(catalog.get_definition(&"diode"), Vector2(160.0, 0.0), 0.0, Vector2(160.0, -180.0), -PI * 0.5)
	construction.place(catalog.get_definition(&"accumulator"), Vector2(160.0, -320.0))
	for frame in 4800:
		scene._process(1.0 / 120.0)
		if frame == 1800:
			construction.selected_device_id = diode
			construction.selected_anchor = 1
			construction.dismantle_selected()
	var director = world.session if world != null else scene.get("_session")
	print("INTERACTION_TRACE ", JSON.stringify({"events": trace, "stats": _stable_stats(simulation),
		"devices": construction.view_records(), "lights": construction.light_sources(Vector2.ZERO, 360.0),
		"completion": director.completion_snapshot()}, "", true))
	scene.free()
	quit()

func _stable_stats(simulation: SimulationController) -> Dictionary:
	var stats: Dictionary = simulation.native.get_stats()
	var stable: Dictionary = {}
	for key in stats:
		if not String(key).contains("milliseconds") and not String(key).contains("microseconds"):
			stable[key] = stats[key]
	return stable
