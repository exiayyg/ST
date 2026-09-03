extends SceneTree


func _init() -> void:
	ProjectSettings.set_setting("application/config/name", "Singular Tower / 一炮千径")
	ProjectSettings.set_setting(
		"application/run/main_scene",
		"res://scenes/combat/endless_sandbox.tscn"
	)
	ProjectSettings.set_setting("display/window/size/viewport_width", 1920)
	ProjectSettings.set_setting("display/window/size/viewport_height", 1080)
	ProjectSettings.set_setting("display/window/size/mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
	ProjectSettings.clear("display/window/size/window_width_override")
	ProjectSettings.clear("display/window/size/window_height_override")
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	var error := ProjectSettings.save()
	if error != OK:
		push_error("Could not save project settings: %s" % error_string(error))
		quit(error)
		return
	print("Configured the endless main scene with a 1920x1080 logical viewport and native fullscreen launch.")
	quit()
