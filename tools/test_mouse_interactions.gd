extends SceneTree
const Driver := preload("res://tools/input_test_driver.gd")
var failures: Array[String] = []
var world: WorldScreen
var profile: BalanceProfile
var input: ConstructionInputController
var actions: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func point(value: Vector2) -> Vector2:
	return root.get_canvas_transform() * value

func _run() -> void:
	change_scene_to_file("res://scenes/prototype/momentum_prototype.tscn")
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	profile = world.runtime.profile
	input = world.runtime.input
	input.semantic_event.connect(func(e): actions.append(e.duplicate()))
	var con := world.runtime.construction
	var last_id := 0
	for definition in world.runtime.catalog.definitions:
		Driver.wheel(input, root, profile, Vector2(120, 100), world.runtime.catalog, definition.kind)
		check(con.devices.size() == 1, "wheel release creates " + String(definition.kind))
		if definition.kind == &"diode":
			var record: Dictionary = con.devices.values()[0]
			check(record.secondary_position == record.position + Vector2.RIGHT * profile.runtime_config().construction_ux.diode_initial_offset, "atomic paired default")
		last_id = con.selected_device_id
		var grab := point(Vector2(123, 100))
		Driver.mouse(input, grab, true)
		Driver.motion(input, grab + Vector2(30, 0))
		check(con.devices[last_id].position == Vector2(150, 100), "immediate offset drag for " + String(definition.kind))
		Driver.mouse(input, grab + Vector2(30, 0), false)
		con.dismantle_selected()
	actions.clear()
	Driver.wheel(input, root, profile, Vector2(330, 0), world.runtime.catalog, &"diode")
	check(con.devices.is_empty(), "invalid exit creates no partial device")
	Driver.wheel(input, root, profile, Vector2(180, 0), world.runtime.catalog, &"diode")
	var id := con.selected_device_id
	check(id == last_id + 1, "invalid pair does not consume an ID")
	var pivot := point(Vector2(276, 0))
	var desired := pivot + Vector2.from_angle(deg_to_rad(-37.25)) * 180.0
	var before_native := world.runtime.simulation.native.get_device_snapshot().duplicate(true)
	Driver.mouse(input, pivot, true, MOUSE_BUTTON_RIGHT)
	Driver.motion(input, desired)
	check(absf(rad_to_deg(float(input.snapshot().preview.angle)) + 37.25) < 0.001, "non-integer preview is exact")
	check(con.devices[id].secondary_angle_radians == 0.0 and world.runtime.simulation.native.get_device_snapshot() == before_native, "preview leaves real device unchanged")
	Driver.motion(input, pivot)
	check(absf(rad_to_deg(float(input.snapshot().preview.angle)) + 37.25) < 0.001, "center dead zone holds last angle")
	Driver.mouse(input, desired, false, MOUSE_BUTTON_RIGHT)
	check(absf(rad_to_deg(float(con.devices[id].secondary_angle_radians)) + 37.25) < 0.001, "release commits exact angle")
	check(actions.filter(func(e): return e.type == "device_rotated").size() == 1, "exactly one rotation event")
	Driver.mouse(input, pivot, true, MOUSE_BUTTON_RIGHT)
	Driver.motion(input, pivot + Vector2.UP * 180)
	Driver.mouse(input, pivot, true)
	Driver.mouse(input, pivot, false)
	Driver.mouse(input, pivot, false, MOUSE_BUTTON_RIGHT)
	check(absf(rad_to_deg(float(con.devices[id].secondary_angle_radians)) + 37.25) < 0.001, "left cancellation swallows remaining releases")
	check(actions.filter(func(e): return e.type == "device_rotated").size() == 1, "cancel is not rotation")
	Driver.mouse(input, pivot, true)
	var tolerance := profile.runtime_config().construction_ux.gesture_tolerance
	Driver.motion(input, pivot + Vector2(tolerance, 0))
	check(con.devices[id].secondary_position == Vector2(276, 0), "tolerance boundary is still a click")
	check(input.snapshot().hold_progress == 0.0, "device selection never displays a timer ring")
	Driver.motion(input, pivot + Vector2(30, 0))
	check(con.devices[id].secondary_position == Vector2(306, 0), "fast drag moves during the same input event without advance")
	check(input.snapshot().cursor_shape == Input.CURSOR_DRAG, "moving snapshot requests a closed hand")
	Driver.mouse(input, pivot + Vector2(30, 0), false)
	check(input.snapshot().cursor_shape == Input.CURSOR_ARROW, "release restores cursor")
	pivot = point(Vector2(306, 0)) + Vector2(3, 0)
	Driver.mouse(input, pivot, true)
	input.advance(profile.runtime_config().construction_ux.click_max_seconds * 2.0)
	check(con.devices[id].secondary_position == Vector2(306, 0) and input.snapshot().hold_progress == 0.0, "stationary long hold neither moves nor shows a ring")
	Driver.motion(input, pivot + Vector2(30, 0))
	check(con.devices[id].secondary_position == Vector2(336, 0), "delayed drag preserves off-center grab offset")
	check(con.devices[id].position == Vector2(180, 0), "moving outlet leaves inlet unchanged")
	input.cancel()
	check(con.devices[id].secondary_position == Vector2(336, 0), "actual movement retained on cancel")
	check(input.snapshot().cursor_shape == Input.CURSOR_ARROW, "cancel restores cursor")
	check(actions.filter(func(e): return e.type == "device_moved").size() == 2, "one event per completed or cancelled drag")
	con.dismantle_selected()
	Driver.wheel(input, root, profile, Vector2(180, 0), world.runtime.catalog, &"accumulator")
	id = con.selected_device_id
	for index in 9:
		world.runtime.simulation.native.emit_projectiles([{"position": Vector2(100, 0), "velocity": Vector2(240, 0), "mass": 0.05, "entropy": 0.0}])
	for tick in 80: world.runtime.simulation.step(1.0 / 120.0)
	con.sync(world.runtime.simulation.native.get_device_snapshot())
	check(float(con.devices[id].stored_momentum) > 0.0, "real accumulated native momentum")
	pivot = point(Vector2(180, 0))
	var count_before := int(world.runtime.simulation.native.get_stats().projectile_count)
	Driver.mouse(input, pivot, true)
	input.advance(profile.runtime_config().construction_ux.click_max_seconds)
	Driver.mouse(input, pivot, false)
	check(int(world.runtime.simulation.native.get_stats().projectile_count) == count_before, "stationary hold never releases")
	Driver.mouse(input, pivot, true, MOUSE_BUTTON_RIGHT)
	Driver.motion(input, pivot + Vector2(100, 20))
	input.cancel()
	check(int(world.runtime.simulation.native.get_stats().projectile_count) == count_before, "rotation never releases")
	Driver.mouse(input, pivot, true)
	Driver.motion(input, pivot + Vector2(30, 0))
	Driver.motion(input, pivot)
	Driver.mouse(input, pivot, false)
	check(int(world.runtime.simulation.native.get_stats().projectile_count) == count_before, "dragging out and back never releases accumulator")
	Driver.mouse(input, pivot, true)
	Driver.motion(input, pivot + Vector2(30, 0))
	world.modal.menu.open()
	Driver.mouse(input, pivot + Vector2(30, 0), false)
	check(int(world.runtime.simulation.native.get_stats().projectile_count) == count_before and not input.has_cancelable_interaction(), "modal cancels drag without release")
	world.modal.menu.close()
	pivot = point(Vector2(210, 0))
	Driver.mouse(input, pivot, true)
	Driver.motion(input, pivot + Vector2(tolerance * 0.5, 0))
	Driver.mouse(input, pivot, false)
	Driver.mouse(input, pivot, false)
	check(int(world.runtime.simulation.native.get_stats().projectile_count) == count_before + 1, "short click releases exactly one stored projectile")
	Driver.mouse(input, pivot, true, MOUSE_BUTTON_RIGHT)
	Driver.motion(input, pivot + Vector2(100, 80))
	con.damage_selected(100000.0)
	input.advance(0.0)
	check(not input.has_cancelable_interaction() and input.snapshot().preview.is_empty(), "deleted target cancels preview")
	# The cursor uses viewport logical coordinates, while rotation uses world axes.
	Driver.wheel(input, root, profile, Vector2(180, 0), world.runtime.catalog, &"bounce_plate")
	id = con.selected_device_id
	for zoom_steps in [-100.0, 100.0]:
		for step in 100:
			Driver.mouse(input, Vector2.ZERO, true, MOUSE_BUTTON_WHEEL_DOWN if zoom_steps < 0.0 else MOUSE_BUTTON_WHEEL_UP)
		world.get_node("WorldCamera").force_update_scroll()
		await process_frame
		pivot = point(con.devices[id].position)
		var ray := point(con.devices[id].position + Vector2.from_angle(0.713) * 150.0)
		Driver.mouse(input, pivot, true, MOUSE_BUTTON_RIGHT)
		Driver.motion(input, ray)
		check(absf(float(input.snapshot().preview.angle) + PI * 0.5 - 0.713) < 0.00001, "plate normal follows cursor at zoom limit")
		world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		Driver.mouse(input, ray, false, MOUSE_BUTTON_RIGHT)
		check(con.devices[id].angle_radians == 0.0 and input.snapshot().preview.is_empty(), "focus loss cancels preview at zoom limit")
		var start: Vector2 = con.devices[id].position
		var grab := point(start) + Vector2(3, 0)
		Driver.mouse(input, grab, true)
		Driver.motion(input, grab + Vector2(3, 0))
		check(con.devices[id].position == start, "screen-space tolerance independent of zoom")
		Driver.motion(input, grab + Vector2(30, 0))
		var inverse := root.get_canvas_transform().affine_inverse()
		var expected := start + (inverse * (grab + Vector2(30, 0)) - inverse * grab)
		check((con.devices[id].position as Vector2).is_equal_approx(expected), "drag offset correct at zoom limit")
		world.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		Driver.mouse(input, grab + Vector2(60, 0), false)
		check((con.devices[id].position as Vector2).is_equal_approx(expected) and input.snapshot().cursor_shape == Input.CURSOR_ARROW, "focus cancellation retains position and restores cursor")
		pivot = point(expected)
	# Modal opening cancels preview without leaking the eventual release.
	Driver.mouse(input, pivot, true, MOUSE_BUTTON_RIGHT)
	Driver.motion(input, pivot + Vector2.UP * 100.0)
	world.modal.menu.open()
	check(input.snapshot().preview.is_empty() and paused, "mouse menu cancels world gesture")
	world.modal.menu.close()
	Driver.mouse(input, pivot, false, MOUSE_BUTTON_RIGHT)
	check(con.devices[id].angle_radians == 0.0, "modal cancellation never commits rotation")
	# Release-only displacement must keep the existing map clamp and grab offset.
	var before_release: Vector2 = con.devices[id].position
	var grab_release := point(before_release) + Vector2(3, 0)
	var moves_before := actions.filter(func(e): return e.type == "device_moved").size()
	Driver.mouse(input, grab_release, true)
	Driver.motion(input, grab_release + Vector2(25, 0))
	Driver.mouse(input, point(profile.map_rect().end + Vector2(1000, 1000)), false)
	var map_max := profile.map_rect().end - Vector2.ONE * float(profile.value("map_camera/map_margin"))
	check((con.devices[id].position as Vector2).is_equal_approx(map_max), "latest release position still clamps to map")
	check(actions.filter(func(e): return e.type == "device_moved").size() == moves_before + 1, "final displacement emits only one move")
	# Deletion can arrive between motion and release without an intervening advance.
	pivot = point(con.devices[id].position)
	Driver.mouse(input, pivot, true)
	Driver.motion(input, pivot - Vector2(30, 0))
	con.damage_device(id, float(con.devices[id].hp))
	Driver.mouse(input, pivot - Vector2(90, 0), false)
	check(not con.devices.has(id) and not input.has_pointer_capture() and input.snapshot().cursor_shape == Input.CURSOR_ARROW, "deleted target rejects release before next advance")

	# Versioned defaults are only migration data; invalid edits never reach runtime.
	var old := profile.data.duplicate(true)
	Driver.legacy_input(old)
	old.schema_version = 9
	var frozen := old.duplicate(true)
	var migrated := BalanceSchema.migrate(old)
	check(old == frozen and BalanceSchema.validate(migrated).is_empty(), "v9 migration is transactional")
	check(migrated.tower == old.tower and migrated.devices == old.devices, "migration preserves balance")
	var v10 := profile.data.duplicate(true)
	v10.schema_version = 10
	v10.construction_ux.erase("click_max_seconds")
	v10.construction_ux["move_hold_seconds"] = 0.73
	var v10_original := v10.duplicate(true)
	var v11 := BalanceSchema.migrate(v10)
	check(v10 == v10_original and v11.schema_version == 11 and BalanceSchema.validate(v11).is_empty(), "v10 migration is nonmutating and valid")
	check(v11.construction_ux.click_max_seconds == 0.73 and not v11.construction_ux.has("move_hold_seconds"), "migration retains customized short click duration")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(v11, "\t", true, true))
	check(BalanceSchema.validate(roundtrip).is_empty() and is_equal_approx(float(roundtrip.construction_ux.click_max_seconds), 0.73), "v11 JSON roundtrip preserves custom click duration")
	v10.construction_ux["click_max_seconds"] = 0.5
	check(BalanceSchema.migrate(v10).is_empty(), "ambiguous old and new fields reject entire migration")
	var stale := v11.duplicate(true)
	stale.construction_ux["move_hold_seconds"] = 0.5
	check(not BalanceSchema.validate(stale).is_empty(), "v11 rejects obsolete wait parameter")
	for key in ["click_max_seconds", "gesture_tolerance", "rotation_center_dead_zone", "diode_initial_offset"]:
		var invalid := migrated.duplicate(true)
		invalid.construction_ux[key] = 0.0
		check(not BalanceSchema.validate(invalid).is_empty(), "reject zero " + key)
	for issue in failures: push_error(issue)
	print("Mouse gesture checks: ", "passed" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
