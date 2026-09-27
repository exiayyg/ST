class_name RuntimePauseState
extends RefCounted

const META := &"singular_pause_reasons"


static func acquire(tree: SceneTree, owner_id: int, reason: StringName) -> void:
	var state: Dictionary = tree.get_meta(META, {"previous": tree.paused, "reasons": {}})
	state.reasons["%d:%s" % [owner_id, reason]] = true
	tree.set_meta(META, state)
	tree.paused = true


static func release(tree: SceneTree, owner_id: int, reason: StringName) -> void:
	if not tree.has_meta(META):
		return
	var state: Dictionary = tree.get_meta(META)
	state.reasons.erase("%d:%s" % [owner_id, reason])
	if state.reasons.is_empty():
		tree.remove_meta(META)
		tree.paused = bool(state.previous)
	else:
		tree.set_meta(META, state)
		tree.paused = true


static func reset(tree: SceneTree) -> void:
	tree.remove_meta(META)
	tree.paused = false
