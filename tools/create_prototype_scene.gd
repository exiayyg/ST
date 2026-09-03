extends SceneTree

const SCENE_PATH := "res://scenes/prototype/momentum_prototype.tscn"
const PROTOTYPE_SCRIPT := preload("res://scripts/prototype/momentum_prototype.gd")


func _init() -> void:
	var root := Node2D.new()
	root.name = "MomentumPrototype"
	root.set_script(PROTOTYPE_SCRIPT)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack prototype scene: %s" % error_string(pack_error))
		quit(pack_error)
		return

	var save_error := ResourceSaver.save(packed_scene, SCENE_PATH)
	if save_error != OK:
		push_error("Could not save prototype scene: %s" % error_string(save_error))
		quit(save_error)
		return

	print("Created ", SCENE_PATH)
	quit()
