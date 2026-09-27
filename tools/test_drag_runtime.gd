extends SceneTree
# Real viewport input and rendered captures; no native/HP/session fixture writes.
const MouseDemo := preload("res://tools/capture_mouse_interactions.gd")
var failures: Array[String] = []
var world: WorldScreen
var demo := MouseDemo.new()
var actions: Array[Dictionary] = []
var events: Array[Dictionary] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _run() -> void:
	change_scene_to_file("res://scenes/prototype/momentum_prototype.tscn")
	await process_frame
	await process_frame
	world = current_scene
	world.runtime.input.semantic_event.connect(func(e: Dictionary): actions.append(e.duplicate(true)))
	world.gameplay_event.connect(func(e: Dictionary): events.append(e.duplicate(true)))
	DirAccess.make_dir_recursive_absolute("res://artifacts/drag-distance")
	await _nine_devices()
	await _accumulator()
	await demo.mouse(self, Vector2(100, 120), true)
	await create_timer(world.runtime.profile.runtime_config().construction_ux.radial_hold_seconds + 0.1).timeout
	var index := 0
	for definition in world.runtime.catalog.definitions:
		if definition.kind == &"diode": break
		index += 1
	var angle := -PI * 0.5 + TAU * float(index) / float(world.runtime.catalog.definitions.size())
	var cursor: Vector2 = world.runtime.input.snapshot().radial_center + Vector2.from_angle(angle) * world.runtime.profile.runtime_config().construction_ux.radial_radius
	demo.motion(self, cursor)
	await demo.mouse(self, root.get_canvas_transform().affine_inverse() * cursor, false)
	world = current_scene
	check(world.runtime.construction.devices.size() == 1, "wheel creates pair via viewport events")
	if world.runtime.construction.devices.is_empty():
		quit(1)
		return
	var id: int = world.runtime.construction.selected_device_id
	DirAccess.make_dir_recursive_absolute("res://artifacts/drag-distance")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i.ZERO]:
		root.mode = Window.MODE_FULLSCREEN if dimensions == Vector2i.ZERO else Window.MODE_WINDOWED
		if dimensions != Vector2i.ZERO: root.size = dimensions
		await create_timer(0.2).timeout
		world = current_scene
		var before: Vector2 = world.runtime.construction.devices[id].secondary_position
		var inlet: Vector2 = world.runtime.construction.devices[id].position
		var grab: Vector2 = before + Vector2(3, 0)
		await demo.mouse(self, grab, true)
		var screen_grab: Vector2 = root.get_canvas_transform() * grab
		demo.motion(self, screen_grab + Vector2(3, 0))
		check(world.runtime.construction.devices[id].secondary_position == before, "jitter stays still at " + str(dimensions))
		var destination: Vector2 = root.get_canvas_transform() * (grab + Vector2(30, 0))
		# Deliberately assert before any frame/advance: no time gate can satisfy this.
		demo.motion(self, destination)
		check((world.runtime.construction.devices[id].secondary_position as Vector2).is_equal_approx(before + Vector2(30, 0)), "same-event move at " + str(dimensions))
		check(world.runtime.construction.devices[id].position == inlet, "only selected endpoint moves")
		check(world.runtime.input.snapshot().cursor_shape == Input.CURSOR_DRAG and world.runtime.input.snapshot().hold_progress == 0.0, "grab feedback without progress ring")
		await process_frame
		await RenderingServer.frame_post_draw
		print("DRAG ", dimensions, " cursor=", Input.get_current_cursor_shape(), " position=", world.runtime.construction.devices[id].secondary_position)
		check(Input.get_current_cursor_shape() == Input.CURSOR_DRAG, "host applies drag cursor")
		root.get_texture().get_image().save_png("res://artifacts/drag-distance/moving-%d.png" % dimensions.x)
		await demo.mouse(self, grab + Vector2(35, 0), false)
		check((world.runtime.construction.devices[id].secondary_position as Vector2).is_equal_approx(before + Vector2(35, 0)), "release uses its newest coordinate with grab offset")
		check(Input.get_current_cursor_shape() == Input.CURSOR_ARROW, "release restores OS cursor")
		# Begin another drag, then use the actual focus-loss cleanup path.
		var released: Vector2 = world.runtime.construction.devices[id].secondary_position
		await demo.mouse(self, released, true)
		demo.motion(self, root.get_canvas_transform() * (before + Vector2(40, 0)))
		world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await demo.mouse(self, before + Vector2(60, 0), false)
		check((world.runtime.construction.devices[id].secondary_position as Vector2).is_equal_approx(before + Vector2(40, 0)), "cancel retains actual movement only")
		check(Input.get_current_cursor_shape() == Input.CURSOR_ARROW, "focus loss restores cursor")
	await demo.button(self, "暂停")
	check(paused, "mouse pause remains reachable")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/drag-distance/paused.png")
	await demo.button(self, "继续")
	check(not paused, "mouse resume works")
	await _diode_anchors(id)
	await _interruptions(id)
	await _zoom_and_edges()
	preload("res://assets/ui/closed_grab.svg").get_image().save_png("res://artifacts/drag-distance/closed-grab.png")
	for failure in failures: push_error(failure)
	print("Drag runtime checks: ", "passed" if failures.is_empty() else "FAILED", " (", checks, " assertions)")
	quit(0 if failures.is_empty() else 1)

func _place(kind: StringName, position: Vector2) -> int:
	var count := world.runtime.construction.devices.size()
	await demo.mouse(self, position, true)
	await create_timer(world.runtime.profile.runtime_config().construction_ux.radial_hold_seconds + 0.1).timeout
	var snapshot := world.runtime.input.snapshot()
	check(snapshot.radial_open, "wheel opens for " + String(kind))
	if not snapshot.radial_open: return 0
	var definitions := world.runtime.catalog.definitions
	for index in definitions.size():
		if definitions[index].kind != kind: continue
		var angle := -PI * 0.5 + TAU * float(index) / float(definitions.size())
		var cursor: Vector2 = snapshot.radial_center + Vector2.from_angle(angle) * world.runtime.profile.runtime_config().construction_ux.radial_radius
		demo.motion(self, cursor)
		await _screen_mouse(cursor, false)
		break
	check(world.runtime.construction.devices.size() == count + 1, "atomic wheel release " + String(kind))
	return world.runtime.construction.selected_device_id

func _screen_mouse(position: Vector2, down: bool, which := MOUSE_BUTTON_LEFT) -> void:
	# Keep exact logical pixel boundaries: a world roundtrip can turn 4 into 4.00006.
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = which
	event.pressed = down
	root.push_input(event, true)
	await process_frame

func _button(text: String) -> Button:
	for control in current_scene.find_children("*", "Button", true, false):
		if control.is_visible_in_tree() and control.text == text: return control
	return null

func _dismantle() -> void:
	await process_frame
	var control := _button("按住拆除")
	check(control != null, "mouse dismantle button available")
	if control == null: return
	var cursor := control.get_global_rect().get_center()
	await _screen_mouse(cursor, true)
	await create_timer(world.runtime.profile.runtime_config().construction_ux.dismantle_hold_seconds + 0.1).timeout
	await _screen_mouse(cursor, false)

func _action_count(type: String) -> int:
	return actions.filter(func(e: Dictionary): return String(e.type) == type).size()

func _event_count(type: String) -> int:
	return events.filter(func(e: Dictionary): return String(e.type) == type).size()

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/drag-distance/" + name + ".png")

func _nine_devices() -> void:
	for definition in world.runtime.catalog.definitions:
		var id := await _place(definition.kind, Vector2(100, 120))
		if not world.runtime.construction.devices.has(id): return
		var record: Dictionary = world.runtime.construction.devices[id]
		await demo.mouse(self, record.position, true)
		await demo.mouse(self, record.position, false)
		check(world.runtime.construction.selected_device_id == id, "short select " + String(definition.kind))
		var moved := _action_count("device_moved")
		for repetition in 3:
			var before: Vector2 = record.position
			var grab: Vector2 = root.get_canvas_transform() * before + Vector2(3, 2)
			await _screen_mouse(grab, true)
			demo.motion(self, grab + Vector2(30, 0))
			check(record.position != before, "immediate viewport move " + String(definition.kind))
			var inverse := root.get_canvas_transform().affine_inverse()
			var expected: Vector2 = before + inverse * (grab + Vector2(35, 0)) - inverse * grab
			await _screen_mouse(grab + Vector2(35, 0), false)
			check((record.position as Vector2).is_equal_approx(expected), "off-center newest release " + String(definition.kind))
			check(_action_count("device_moved") == moved + repetition + 1, "one semantic move per grab")
			check(not world.runtime.input.has_pointer_capture(), "release clears pointer capture")
		await _dismantle()
		check(not world.runtime.construction.devices.has(id), "mouse removes whole " + String(definition.kind))
	print("VIEWPORT nine devices: placement, selection, three offset grabs and dismantling")

func _accumulator() -> void:
	var id := await _place(&"accumulator", Vector2(180, 0))
	if not world.runtime.construction.devices.has(id): return
	var record: Dictionary = world.runtime.construction.devices[id]
	# Charge only from the real tower; no native fixtures or state writes in this suite.
	for attempt in 120:
		if float(record.stored_momentum) > 0.0: break
		await create_timer(0.1).timeout
	check(float(record.stored_momentum) > 0.0, "tower really charges accumulator")
	await demo.button(self, "发射中 · 点击停火")
	await create_timer(1.0).timeout
	var stored := float(record.stored_momentum)
	var released := _event_count("accumulator_released")
	await demo.mouse(self, record.position, true)
	await create_timer(world.runtime.profile.runtime_config().construction_ux.click_max_seconds + 0.1).timeout
	await demo.mouse(self, record.position, false)
	var pivot: Vector2 = root.get_canvas_transform() * record.position
	await _screen_mouse(pivot, true)
	demo.motion(self, pivot + Vector2(40, 0))
	demo.motion(self, pivot)
	await _screen_mouse(pivot, false)
	await _screen_mouse(pivot, true, MOUSE_BUTTON_RIGHT)
	demo.motion(self, pivot + Vector2(100, 60))
	await _screen_mouse(pivot, true) # cancels preview, not an accumulator click
	await _screen_mouse(pivot, false)
	await _screen_mouse(pivot, false, MOUSE_BUTTON_RIGHT)
	await _screen_mouse(pivot, true)
	await _key(KEY_ESCAPE)
	await _screen_mouse(pivot, false)
	await demo.button(self, "暂停")
	check(paused, "accumulator UI pauses without releasing")
	await demo.button(self, "数值编辑")
	await demo.button(self, "关闭数值编辑")
	check(paused, "tuning close retains prior pause")
	await demo.button(self, "继续")
	check(_event_count("accumulator_released") == released and is_equal_approx(float(record.stored_momentum), stored), "long hold, roundtrip, rotation, cancellation and UI do not release")
	await demo.mouse(self, record.position, true)
	await demo.mouse(self, record.position, false)
	await demo.mouse(self, record.position, false)
	await process_frame
	check(_event_count("accumulator_released") == released + 1 and float(record.stored_momentum) == 0.0, "short click releases once despite duplicate up")
	await _capture("accumulator-released")
	await _dismantle()
	await demo.button(self, "已停火 · 点击发射")
	print("VIEWPORT accumulator: real stored momentum, no accidental releases")

func _diode_anchors(id: int) -> void:
	var record: Dictionary = world.runtime.construction.devices[id]
	for anchor in 2:
		var position_key := "position" if anchor == 0 else "secondary_position"
		var angle_key := "angle_radians" if anchor == 0 else "secondary_angle_radians"
		var other_position_key := "secondary_position" if anchor == 0 else "position"
		var other_angle_key := "secondary_angle_radians" if anchor == 0 else "angle_radians"
		var other_position: Vector2 = record[other_position_key]
		var other_angle: float = record[other_angle_key]
		var pivot: Vector2 = record[position_key]
		await demo.mouse(self, pivot, true)
		demo.motion(self, root.get_canvas_transform() * (pivot + Vector2(0, -25)))
		await demo.mouse(self, pivot + Vector2(0, -30), false)
		check(world.runtime.construction.selected_anchor == anchor, "locked diode anchor selection")
		pivot = record[position_key]
		var original_angle: float = record[angle_key]
		var rotated := _action_count("device_rotated")
		var ray := pivot + Vector2.from_angle(0.713 + anchor) * 100.0
		await demo.mouse(self, pivot, true, MOUSE_BUTTON_RIGHT)
		demo.motion(self, root.get_canvas_transform() * ray)
		check(record[angle_key] == original_angle, "preview never changes real anchor angle")
		await _capture("diode-anchor-%d-preview" % anchor)
		await demo.mouse(self, ray, false, MOUSE_BUTTON_RIGHT)
		check(is_equal_approx(float(record[angle_key]), 0.713 + anchor), "non-integer angle committed")
		check(_action_count("device_rotated") == rotated + 1, "one rotation per commit")
		check(record[other_position_key] == other_position and record[other_angle_key] == other_angle, "other diode anchor unchanged")

func _interruptions(id: int) -> void:
	var record: Dictionary = world.runtime.construction.devices[id]
	# A captured release over a real HUD button finishes the move, not the UI click.
	var pivot: Vector2 = record.position
	var grab: Vector2 = root.get_canvas_transform() * pivot + Vector2(3, 0)
	await _screen_mouse(grab, true)
	demo.motion(self, grab + Vector2(25, 0))
	var button := _button("暂停")
	var hud_position := button.get_global_rect().get_center()
	var inverse := root.get_canvas_transform().affine_inverse()
	var expected := inverse * hud_position + pivot - inverse * grab
	var profile := world.runtime.profile
	expected = expected.clamp(profile.map_rect().position + Vector2.ONE * float(profile.value("map_camera/map_margin")), profile.map_rect().end - Vector2.ONE * float(profile.value("map_camera/map_margin")))
	await _screen_mouse(hud_position, false)
	check((record.position as Vector2).is_equal_approx(expected) and not paused, "release over HUD moves to latest coordinate without pressing pause")
	# Continue on the outlet, which remains in clear space.
	for interrupt in [KEY_ESCAPE, KEY_F2]:
		pivot = record.secondary_position
		await demo.mouse(self, pivot, true)
		demo.motion(self, root.get_canvas_transform() * (pivot + Vector2(20, 0)))
		var position_before_interrupt: Vector2 = record.secondary_position
		await _key(interrupt)
		check(not world.runtime.input.has_pointer_capture() and world.runtime.input.snapshot().cursor_shape == Input.CURSOR_ARROW, "keyboard modal cancels drag")
		await demo.mouse(self, pivot + Vector2(80, 0), false)
		if interrupt == KEY_F2:
			check(paused and world.modal.tuning.is_open(), "F2 pauses and opens")
			await _key(KEY_F2)
		await demo.mouse(self, pivot + Vector2(100, 0), false)
		check(record.secondary_position == position_before_interrupt, "late release after interruption does not move")
		check(not paused, "interruption leaves pause state correct")
	# External pause is a public modal entry; no private scene method is invoked.
	pivot = record.secondary_position
	await demo.mouse(self, pivot, true)
	demo.motion(self, root.get_canvas_transform() * (pivot + Vector2(20, 0)))
	var actual: Vector2 = record.secondary_position
	world.modal.menu.open()
	await demo.mouse(self, pivot + Vector2(90, 0), false)
	await demo.button(self, "继续")
	await demo.mouse(self, pivot + Vector2(100, 0), false)
	check(record.secondary_position == actual and not world.runtime.input.has_pointer_capture(), "pause entry cancels capture and stale release")
	# Real developer damage removes the selected pair before its release arrives.
	pivot = record.secondary_position
	await demo.mouse(self, pivot, true)
	demo.motion(self, root.get_canvas_transform() * (pivot + Vector2(20, 0)))
	for hit in 4:
		var event := InputEventKey.new()
		event.keycode = KEY_DELETE
		event.shift_pressed = true
		event.pressed = true
		root.push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
		await process_frame
	await demo.mouse(self, pivot + Vector2(100, 0), false)
	check(not world.runtime.construction.devices.has(id) and not world.runtime.input.has_pointer_capture(), "destroyed pair cannot receive late release")
	check(Input.get_current_cursor_shape() == Input.CURSOR_ARROW, "destruction clears grab cursor")
	print("VIEWPORT boundaries: HUD release, Esc, F2, pause and destruction")

func _zoom_and_edges() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await create_timer(0.2).timeout
	var id := await _place(&"bounce_plate", Vector2(120, 100))
	if not world.runtime.construction.devices.has(id): return
	var record: Dictionary = world.runtime.construction.devices[id]
	for wheel in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
		for step in 50:
			await _screen_mouse(Vector2(500, 300), true, wheel)
		await process_frame
		var camera := world.get_node("WorldCamera") as Camera2D
		var expected_zoom := float(world.runtime.profile.value("map_camera/min_zoom" if wheel == MOUSE_BUTTON_WHEEL_DOWN else "map_camera/max_zoom"))
		check(is_equal_approx(camera.zoom.x, expected_zoom), "actual wheel reaches zoom limit")
		var before: Vector2 = record.position
		var grab: Vector2 = root.get_canvas_transform() * before + Vector2(3, 0)
		await _screen_mouse(grab, true)
		demo.motion(self, grab + Vector2(4, 0))
		check((record.position as Vector2).is_equal_approx(before) and world.runtime.input.snapshot().state == ConstructionInputController.Gesture.LEFT_PENDING, "four logical pixels do not drag at zoom limit")
		demo.motion(self, grab + Vector2(25, 0))
		var inverse := root.get_canvas_transform().affine_inverse()
		var expected := before + inverse * (grab + Vector2(35, 0)) - inverse * grab
		await _screen_mouse(grab + Vector2(35, 0), false)
		check((record.position as Vector2).is_equal_approx(expected), "final grab offset at zoom limit")
		var original := float(record.angle_radians)
		var ray: Vector2 = record.position + Vector2.from_angle(0.3713) * 120
		await demo.mouse(self, record.position, true, MOUSE_BUTTON_RIGHT)
		demo.motion(self, root.get_canvas_transform() * ray)
		check(is_equal_approx(float(world.runtime.input.snapshot().preview.get("angle", INF)), 0.3713 - PI * 0.5), "plate normal exact at zoom limit")
		demo.motion(self, root.get_canvas_transform() * record.position)
		check(is_equal_approx(float(world.runtime.input.snapshot().preview.get("angle", INF)), 0.3713 - PI * 0.5), "center dead zone preserves last angle")
		world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await demo.mouse(self, ray, false, MOUSE_BUTTON_RIGHT)
		check(record.angle_radians == original and world.runtime.input.snapshot().preview.is_empty(), "focus loss cancels rotation")
	await _dismantle()
	# Pan via actual middle-button motion so lit ground sits near the screen corner.
	var origin := Vector2(10, 40)
	await _screen_mouse(Vector2(500, 300), true, MOUSE_BUTTON_MIDDLE)
	var pan := InputEventMouseMotion.new()
	pan.position = Vector2(80, 110)
	pan.relative = Vector2(70, 130) - root.get_canvas_transform() * origin
	root.push_input(pan, true)
	await _screen_mouse(pan.position, false, MOUSE_BUTTON_MIDDLE)
	await process_frame
	var screen_origin: Vector2 = root.get_canvas_transform() * origin
	await demo.mouse(self, origin, true)
	await create_timer(world.runtime.profile.runtime_config().construction_ux.radial_hold_seconds + 0.1).timeout
	var snapshot := world.runtime.input.snapshot()
	print("EDGE origin=", screen_origin, " center=", snapshot.radial_center, " open=", snapshot.radial_open, " camera=", world.get_node("WorldCamera").position)
	var radius := world.runtime.profile.runtime_config().construction_ux.radial_radius
	check(snapshot.radial_open and snapshot.radial_center != screen_origin, "edge wheel shifts visual center")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(Rect2(snapshot.radial_center - Vector2.ONE * radius, Vector2.ONE * radius * 2)), "edge wheel stays on screen")
	check((snapshot.hold_position as Vector2).is_equal_approx(origin), "edge adjustment never moves construction origin")
	await _capture("edge-wheel")
	await _key(KEY_ESCAPE)
	await demo.mouse(self, origin, false)
	check(world.runtime.construction.devices.is_empty(), "cancelled edge wheel creates nothing")
	# Scene exit clears the old controller and global cursor, then ignores late release.
	# Reload restores the normal camera through the existing scene lifecycle.
	reload_current_scene()
	await process_frame
	await process_frame
	world = current_scene
	id = await _place(&"diode", Vector2(100, 120))
	await demo.mouse(self, Vector2(100, 120), true)
	demo.motion(self, root.get_canvas_transform() * Vector2(140, 120))
	var old_input := world.runtime.input
	check(old_input.has_pointer_capture(), "scene exit begins with active drag")
	change_scene_to_file("res://scenes/frontend/main_menu.tscn")
	await process_frame
	await process_frame
	await _screen_mouse(Vector2(500, 300), false)
	check(not old_input.has_pointer_capture() and Input.get_current_cursor_shape() == Input.CURSOR_ARROW and not paused, "scene exit clears gesture, cursor and pause")
	print("VIEWPORT space: zoom limits, edge wheel, focus and scene exit")
