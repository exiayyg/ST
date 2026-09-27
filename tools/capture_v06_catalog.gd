extends SceneTree

class Catalog extends Node2D:
	var profile: BalanceProfile
	var definitions: Array[DeviceDefinition]
	var view: NetworkWorldView
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(60, 60), "九装置视觉目录 · 展示夹具，不是自动通关", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		for index in definitions.size():
			var center := Vector2(250 + (index % 3) * 470, 210 + (index / 3) * 240)
			draw_string(font, center + Vector2(-110, 95), definitions[index].display_name, HORIZONTAL_ALIGNMENT_CENTER, 220, 22, Color.WHITE)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile := BalanceRepository.load_profile()
	var catalog := Catalog.new()
	catalog.profile = profile
	catalog.definitions.assign(DeviceCatalog.new(profile).definitions)
	root.add_child(catalog)
	var view := NetworkWorldView.new()
	view.show_behind_parent = true
	catalog.add_child(view)
	view.configure(profile)
	view.map_rect = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	view.tower_position = Vector2(-1000, -1000)
	view.decoration_time = 0.5
	var records: Array = []
	for index in catalog.definitions.size():
		var definition := catalog.definitions[index]
		var center := Vector2(250 + (index % 3) * 470, 210 + (index / 3) * 240)
		records.append({"id":index + 1, "definition":definition, "position":center, "angle_radians":0.0, "secondary_position":center + Vector2(110, 0), "secondary_angle_radians":-PI * 0.5,
			"active":true, "hp":100.0, "max_hp":100.0, "activation_progress":definition.activation_required, "activation_required":definition.activation_required, "stored_momentum":12.0})
	view.set_state({}, records, 0, null)
	# Labels stay above the actual production drawing.
	catalog.move_child(view, 0)
	catalog.show_behind_parent = false
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/v06-device-catalog.png")
	print("V06_CATALOG captured production glyphs; diagnostic fixture only")
	quit()
