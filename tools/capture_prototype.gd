extends SceneTree

const INITIAL_OUTPUT := "res://artifacts/network-lab-initial-fog.png"
const CATALOG_OUTPUT := "res://artifacts/network-lab-nine-devices.png"
const WAVE_OUTPUT := "res://artifacts/network-lab-wave-points.png"
const PROTOTYPE_SCENE := preload("res://scenes/prototype/momentum_prototype.tscn")


func _init() -> void:
	_capture.call_deferred()


func _save_viewport(path: String) -> bool:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(error)
		return false
	return true


func _capture() -> void:
	var prototype := PROTOTYPE_SCENE.instantiate()
	root.add_child(prototype)
	prototype.runtime.set("auto_fire", false)
	for _frame in 10:
		await process_frame
	if not _save_viewport(INITIAL_OUTPUT):
		return

	var catalog: DeviceCatalog = prototype.runtime.catalog
	var construction: ConstructionController = prototype.runtime.construction
	var simulation: SimulationController = prototype.runtime.simulation
	var profile: BalanceProfile = prototype.get("_profile")
	var camera_controller: PrototypeCameraController = prototype.get("_camera_controller")
	var tower_mass := float(profile.value("tower/projectile_mass", 0.05))
	var tower_speed := float(profile.value("tower/projectile_speed", 240.0))
	var tower_momentum := tower_mass * tower_speed
	camera_controller.camera.zoom = Vector2(0.78, 0.78)
	for index in catalog.definitions.size():
		var angle := -PI * 0.5 + TAU * float(index) / float(catalog.definitions.size())
		var position := Vector2.RIGHT.rotated(angle) * 255.0
		var definition := catalog.definitions[index]
		var secondary := position + Vector2.RIGHT.rotated(angle + PI * 0.5) * 90.0
		construction.place(definition, position, angle, secondary, angle)

	for record: Dictionary in construction.view_records():
		var required := float(record.get("activation_required", 30.0))
		var shots := ceili(required / tower_momentum)
		var definition := record.get("definition") as DeviceDefinition
		var start_offset := (definition.activation_radius if definition != null else 28.0) + 8.0
		for _shot in shots:
			simulation.native.emit_projectiles([{
				"position": record.position - Vector2(start_offset, 0.0),
				"velocity": Vector2(tower_speed, 0.0),
				"mass": tower_mass,
				"tower_source": false,
			}])
			simulation.native.step(0.25)
	construction.sync(simulation.native.get_device_snapshot())
	prototype.runtime.set("lighting_dirty", true)
	prototype.runtime.input.set("_press_screen_origin", Vector2(24.0, 92.0))
	prototype.runtime.input.call("_open_radial_menu")
	for _frame in 30:
		await process_frame
	if not _save_viewport(CATALOG_OUTPUT):
		return

	var converter_position := Vector2.ZERO
	for record: Dictionary in construction.view_records():
		var definition := record.get("definition") as DeviceDefinition
		if definition != null and definition.kind == &"wave_converter":
			converter_position = record.position
			break
	prototype.runtime.input.call("_close_radial_menu")
	simulation.native.emit_projectiles([{
		"position": converter_position - Vector2(44.0, 0.0),
		"velocity": Vector2(tower_speed, 0.0),
		"mass": tower_mass,
		"tower_source": false,
	}])
	simulation.native.step(1.0 / 60.0)
	for _frame in 6:
		await process_frame
	if not _save_viewport(WAVE_OUTPUT):
		return

	print("Captured ", INITIAL_OUTPUT, ", ", CATALOG_OUTPUT, " and ", WAVE_OUTPUT)
	quit()
