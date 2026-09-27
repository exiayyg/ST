extends Node

const Driver := preload("res://tools/input_test_driver.gd")
const PROTOTYPE_SCENE := preload("res://scenes/prototype/momentum_prototype.tscn")
const FogOfWarType := preload("res://scripts/prototype/fog_of_war.gd")


func _ready() -> void:
	print("Prototype logic test starting")
	_run.call_deferred()


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false


func _finish_at(stage: String) -> bool:
	if OS.get_environment("ST_TEST_STAGE") != stage:
		return false
	print("Prototype logic partial stage passed: ", stage)
	get_tree().quit()
	return true


func _run() -> void:
	var prototype := PROTOTYPE_SCENE.instantiate()
	add_child(prototype)
	prototype.runtime.set("auto_fire", false)
	await get_tree().process_frame
	await get_tree().process_frame

	var catalog: DeviceCatalog = prototype.runtime.catalog
	if not _require(catalog != null and catalog.definitions.size() == 9,
			"Radial catalog must expose all nine devices"):
		return

	var fog: FogOfWar = prototype.runtime.fog
	if not _require(fog.is_lit(Vector2.ZERO) and not fog.is_lit(Vector2(900.0, 0.0)),
			"Initial fog should reveal only the tower region"):
		return
	if _finish_at("init"):
		return

	var construction: ConstructionController = prototype.runtime.construction
	var outside_screen := prototype.get_viewport().get_canvas_transform() * Vector2(900.0, 0.0)
	Driver.mouse(prototype.runtime.input, outside_screen, true)
	if not _require(not prototype.runtime.input.has_cancelable_interaction() and construction.devices.is_empty(),
			"Initial placement must reject unlit empty ground"):
		return

	var center_screen := prototype.get_viewport().get_canvas_transform() * Vector2(80.0, 0.0)
	Driver.mouse(prototype.runtime.input, center_screen, true)
	Driver.mouse(prototype.runtime.input, center_screen, false)
	if not _require(not bool(prototype.runtime.input.snapshot().radial_open) and construction.devices.is_empty(),
			"A short empty-ground click should cancel selection without opening construction"):
		return
	if _finish_at("clicks"):
		return

	var overlap_fog := FogOfWarType.new() as FogOfWar
	overlap_fog.rebuild([
		{"position": Vector2.ZERO, "radius": 200.0},
		{"position": Vector2(200.0, 0.0), "radius": 200.0},
	])
	if not _require(overlap_fog.is_lit(Vector2(100.0, 0.0)),
			"Overlapping active lights should reveal their shared area"):
		return
	overlap_fog.rebuild([{"position": Vector2(200.0, 0.0), "radius": 200.0}])
	if not _require(overlap_fog.is_lit(Vector2(100.0, 0.0)) and not overlap_fog.is_lit(Vector2(-150.0, 0.0)),
			"Removing one light should preserve overlap and refog only uncovered space"):
		return
	if _finish_at("fog"):
		return

	# Edge fit is exercised through real input in the dedicated mouse suite.
	var diode_exit := Vector2(126.0, 20.0)
	Driver.wheel(prototype.runtime.input, prototype.get_viewport(), prototype.runtime.profile, Vector2(30.0, 20.0), catalog, &"diode")
	if not _require(construction.devices.size() == 1, "diode pair must be created on wheel release"):
		return
	var diode_record: Dictionary = construction.devices.values()[0]
	if not _require(diode_record.position.distance_to(Vector2(30.0, 20.0)) < 0.01 and diode_record.secondary_position.distance_to(diode_exit) < 0.01,
			"both initial anchors must use the configured pair offset"):
		return
	construction.selected_device_id = int(diode_record.id)
	construction.selected_anchor = 1
	if not _require(construction.move_selected(Vector2(150.0, 60.0)) and
			construction.rotate_selected(deg_to_rad(15.0)),
			"Completed diode anchors should remain independently movable and rotatable"):
		return
	if _finish_at("diode"):
		return

	var speed := catalog.get_definition(&"speed_increaser")
	var device_id := construction.place(speed, Vector2(180.0, 0.0))
	for index in 12:
		construction.place(speed, Vector2(180.0 + float(index) * 8.0, 80.0))
	if not _require(device_id > 0 and construction.devices.size() == 14,
			"Construction registry should place unlimited free devices through the native seam"):
		return
	if _finish_at("many_devices"):
		return
	construction.selected_device_id = device_id
	if not _require(construction.move_selected(Vector2(900.0, 700.0)),
			"Placed devices should remain movable outside current light"):
		return
	for _hit in 4:
		construction.damage_selected(25.0)
	if not _require(not construction.devices.has(device_id) and construction.devices.size() == 13,
			"Four debug damage steps should destroy a 100 HP device"):
		return
	if _finish_at("damage"):
		return

	var camera_controller: PrototypeCameraController = prototype.get("_camera_controller")
	camera_controller.camera.position = Vector2(99999.0, 99999.0)
	camera_controller.zoom_by_steps(-100.0)
	var half_view: Vector2 = prototype.get_viewport_rect().size * 0.5 / camera_controller.camera.zoom.x
	var configured_map_rect: Rect2 = prototype.runtime.input.get("_map_rect") as Rect2
	var expected_max_x := configured_map_rect.get_center().x if half_view.x > configured_map_rect.size.x * 0.5 else configured_map_rect.end.x - half_view.x
	var expected_max_y := configured_map_rect.get_center().y if half_view.y > configured_map_rect.size.y * 0.5 else configured_map_rect.end.y - half_view.y
	if not _require(is_equal_approx(camera_controller.camera.zoom.x, 0.5) and
			camera_controller.camera.position.x <= expected_max_x + 0.01 and
			camera_controller.camera.position.y <= expected_max_y + 0.01,
			"Camera zoom and position should clamp to the map at the minimum zoom"):
		return
	camera_controller.zoom_by_steps(100.0)
	if not _require(is_equal_approx(camera_controller.camera.zoom.x, 1.5),
			"Camera zoom should clamp to the configured maximum"):
		return

	print("Prototype logic tests passed: lit placement, short/long radial behavior, diode anchors, " +
			"free construction, movement/rotation, camera bounds, fog overlap, HP destruction")
	overlap_fog.texture = null
	overlap_fog = null
	await get_tree().process_frame
	get_tree().quit()
