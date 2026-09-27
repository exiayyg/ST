extends SceneTree

const SCENE_PATH := "res://scenes/levels/diode_tutorial.tscn"
const CAPTURE_SCENE_PATH := "res://scenes/tests/capture_diode_tutorial_stage.tscn"
const COMBAT_SCRIPT := preload("res://scripts/combat/combat_sandbox.gd")
const CAPTURE_SCRIPT := preload("res://tools/capture_diode_tutorial_stage.gd")


func _init() -> void:
	var root := Node2D.new()
	root.name = "DiodeTutorial"
	root.set_script(COMBAT_SCRIPT)
	root.set("session_mode", "tutorial_diode")
	root.set("enable_diagnostic_targets", false)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack diode tutorial scene: %s" % error_string(pack_error))
		quit(pack_error)
		return
	var save_error := ResourceSaver.save(packed_scene, SCENE_PATH)
	if save_error != OK:
		push_error("Could not save diode tutorial scene: %s" % error_string(save_error))
		quit(save_error)
		return
	root.free()

	var capture_root := Node.new()
	capture_root.name = "CaptureDiodeTutorialStage"
	capture_root.set_script(CAPTURE_SCRIPT)
	var capture_scene := PackedScene.new()
	var capture_pack_error := capture_scene.pack(capture_root)
	if capture_pack_error != OK:
		push_error("Could not pack diode tutorial capture scene: %s" % error_string(capture_pack_error))
		quit(capture_pack_error)
		return
	var capture_save_error := ResourceSaver.save(capture_scene, CAPTURE_SCENE_PATH)
	if capture_save_error != OK:
		push_error("Could not save diode tutorial capture scene: %s" % error_string(capture_save_error))
		quit(capture_save_error)
		return
	capture_root.free()

	ProjectSettings.set_setting("application/run/main_scene", SCENE_PATH)
	var settings_error := ProjectSettings.save()
	if settings_error != OK:
		push_error("Could not select diode tutorial main scene: %s" % error_string(settings_error))
		quit(settings_error)
		return
	print("Created and selected ", SCENE_PATH, "; created ", CAPTURE_SCENE_PATH)
	quit()
