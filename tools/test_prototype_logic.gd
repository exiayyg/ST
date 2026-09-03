extends Node

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
	prototype.set("_auto_fire", false)
	await get_tree().process_frame
	await get_tree().process_frame

	var catalog: DeviceCatalog = prototype.get("_catalog")
	if not _require(catalog != null and catalog.definitions.size() == 9,
			"Radial catalog must expose all nine devices"):
		return

	var fog: FogOfWar = prototype.get("_fog")
	if not _require(fog.is_lit(Vector2.ZERO) and not fog.is_lit(Vector2(900.0, 0.0)),
			"Initial fog should reveal only the tower region"):
		return
	if _finish_at("init"):
		return

	var construction: ConstructionController = prototype.get("_construction")
	var outside_screen := prototype.get_viewport().get_canvas_transform() * Vector2(900.0, 0.0)
	prototype.call("_on_left_pressed", outside_screen)
	if not _require(not bool(prototype.get("_left_press_active")) and construction.devices.is_empty(),
			"Initial placement must reject unlit empty ground"):
		return

	var center_screen := prototype.get_viewport().get_canvas_transform() * Vector2(80.0, 0.0)
	prototype.call("_on_left_pressed", center_screen)
	prototype.call("_on_left_released")
	if not _require(not bool(prototype.get("_radial_open")) and construction.devices.is_empty(),
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

	prototype.set("_press_screen_origin", Vector2(1.0, 1.0))
	prototype.call("_open_radial_menu")
	var menu_center: Vector2 = prototype.get("_radial_center")
	if not _require(menu_center.x >= 126.0 and menu_center.y >= 194.0,
			"Radial menu should shift inside the viewport near corners"):
		return
	prototype.call("_close_radial_menu")
	if _finish_at("radial"):
		return

	var diode := catalog.get_definition(&"diode")
	prototype.set("_pending_diode_definition", diode)
	prototype.set("_pending_diode_entrance", Vector2(30.0, 20.0))
	var diode_exit := Vector2(110.0, 40.0)
	var diode_exit_screen := prototype.get_viewport().get_canvas_transform() * diode_exit
	prototype.call("_on_left_pressed", diode_exit_screen)
	if not _require(construction.devices.size() == 1 and prototype.get("_pending_diode_definition") == null,
			"Diode construction should complete only after its lit exit anchor is placed"):
		return
	var diode_record: Dictionary = construction.devices.values()[0]
	if not _require(diode_record.position == Vector2(30.0, 20.0) and
			diode_record.secondary_position.distance_to(diode_exit) < 0.01,
			"Diode two-stage construction must preserve both anchor positions"):
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
	var configured_map_rect: Rect2 = prototype.get("_map_rect") as Rect2
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
