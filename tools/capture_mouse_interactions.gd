extends RefCounted
# Fennara actual-input observation, no HP/ledger/native state changes.
func run(ctx: Variant) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var world: WorldScreen = tree.current_scene
	var entry := Vector2(100, 120)
	await mouse(tree, entry, true)
	await ctx.wait(world.runtime.profile.runtime_config().construction_ux.radial_hold_seconds + 0.1)
	var index := 0
	for definition in world.runtime.catalog.definitions:
		if definition.kind == &"diode": break
		index += 1
	var angle := -PI * 0.5 + TAU * float(index) / float(world.runtime.catalog.definitions.size())
	var cursor: Vector2 = world.runtime.input.snapshot().radial_center + Vector2.from_angle(angle) * world.runtime.profile.runtime_config().construction_ux.radial_radius
	motion(tree, cursor)
	await ctx.wait(0.1)
	await ctx.capture("mouse-pair-preview", 0)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = cursor
	event.pressed = false
	tree.root.push_input(event, true)
	await ctx.wait(0.1)
	ctx.log("pair created on release", {"count": world.runtime.construction.devices.size()})
	if world.runtime.construction.devices.size() != 1:
		ctx.error("Pair was not created")
		return
	var id: int = world.runtime.construction.selected_device_id
	var record: Dictionary = world.runtime.construction.devices[id]
	var outlet: Vector2 = record.secondary_position
	await ctx.capture("mouse-pair-placed", 0)
	for dimensions in [Vector2i.ZERO, Vector2i(1280, 720), Vector2i(1920, 1080)]:
		if dimensions == Vector2i.ZERO:
			tree.root.mode = Window.MODE_FULLSCREEN
		else:
			tree.root.mode = Window.MODE_WINDOWED
			tree.root.size = dimensions
		await ctx.wait(0.3)
		var before: float = record.secondary_angle_radians
		await mouse(tree, outlet, true, MOUSE_BUTTON_RIGHT)
		var destination: Vector2 = tree.root.get_canvas_transform() * (outlet + Vector2.from_angle(deg_to_rad(-37.25)) * 180.0)
		motion(tree, destination)
		await ctx.wait(0.1)
		ctx.log("rotation preview", {"window": str(dimensions), "unchanged": record.secondary_angle_radians == before, "preview": world.runtime.input.snapshot().preview})
		await ctx.capture("mouse-rotation-" + str(dimensions.x), 0)
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.position = destination
		event.pressed = false
		tree.root.push_input(event, true)
		await ctx.wait(0.1)
		if absf(rad_to_deg(float(record.secondary_angle_radians)) + 37.25) > 0.001:
			ctx.error("Rotation commit mismatch")
	tree.root.mode = Window.MODE_FULLSCREEN
	await ctx.wait(0.2)
	await button(tree, "暂停")
	var tick: int = world.runtime.simulation.native.get_stats().tick
	await ctx.wait(0.2)
	ctx.log("mouse pause", {"paused": tree.paused, "tick_unchanged": tick == int(world.runtime.simulation.native.get_stats().tick)})
	await ctx.capture("mouse-pause", 0)
	await button(tree, "数值编辑")
	await ctx.capture("mouse-tuning", 0)
	await button(tree, "关闭数值编辑")
	ctx.log("mouse tuning close", {"paused": tree.paused, "tuning": world.modal.tuning.is_open()})
	await button(tree, "继续")
	await ctx.wait(0.1)
	ctx.log("mouse resume", {"paused": tree.paused})

func motion(tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	tree.root.push_input(event, true)

func mouse(tree: SceneTree, position: Vector2, down: bool, which := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = tree.root.get_canvas_transform() * position
	event.button_index = which
	event.pressed = down
	tree.root.push_input(event, true)
	await tree.process_frame

func button(tree: SceneTree, text: String) -> void:
	for control in tree.current_scene.find_children("*", "Button", true, false):
		if not control.is_visible_in_tree() or control.text != text: continue
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = control.get_global_rect().get_center()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			tree.root.push_input(event, true)
			await tree.process_frame
		await tree.create_timer(0.1).timeout
		return
	push_error("Mouse action missing: " + text)
