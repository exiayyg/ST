class_name LevelCatalog
extends Resource

const SessionFactory := preload("res://scripts/combat/combat_session_factory.gd")

@export var levels: Array[LevelDefinition] = []


func validation_errors(profile: BalanceProfile = null) -> Array[String]:
	var errors: Array[String] = []
	var by_id: Dictionary = {}
	for index in levels.size():
		var definition := levels[index]
		if definition == null:
			errors.append("levels/%d 不能为空" % index)
			continue
		var level_id := String(definition.id)
		if level_id.is_empty():
			errors.append("levels/%d 缺少稳定 ID" % index)
			continue
		if by_id.has(definition.id):
			errors.append("关卡 ID 重复：%s" % level_id)
			continue
		by_id[definition.id] = definition
		if definition.display_name.strip_edges().is_empty():
			errors.append("关卡 %s 缺少显示名称" % level_id)
		if definition.scene_path.is_empty() or not ResourceLoader.exists(definition.scene_path, "PackedScene"):
			errors.append("关卡 %s 场景不存在：%s" % [level_id, definition.scene_path])
		if not SessionFactory.supported(StringName(definition.session_kind)):
			errors.append("关卡 %s 使用未知会话：%s" % [level_id, definition.session_kind])
		if definition.balance_key.is_empty():
			errors.append("关卡 %s 缺少 balance_key" % level_id)
		elif profile != null:
			errors.append_array(SessionFactory.binding_errors(StringName(definition.session_kind), definition.balance_key, profile))

	for definition in levels:
		if definition == null or String(definition.id).is_empty():
			continue
		var seen_prerequisites: Dictionary = {}
		for prerequisite in definition.prerequisites:
			if prerequisite == definition.id:
				errors.append("关卡 %s 不能依赖自身" % definition.id)
			elif seen_prerequisites.has(prerequisite):
				errors.append("关卡 %s 重复依赖 %s" % [definition.id, prerequisite])
			elif not by_id.has(prerequisite):
				errors.append("关卡 %s 的前置关卡不存在：%s" % [definition.id, prerequisite])
			seen_prerequisites[prerequisite] = true

	var visit_state: Dictionary = {}
	for level_id in by_id.keys():
		_detect_cycle(level_id, by_id, visit_state, [], errors)
	return errors


func ordered_levels(release_only := true) -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	for definition in levels:
		if definition != null and (not release_only or definition.release_visible):
			result.append(definition)
	result.sort_custom(func(a: LevelDefinition, b: LevelDefinition):
		if a.sort_order == b.sort_order:
			return String(a.id) < String(b.id)
		return a.sort_order < b.sort_order
	)
	return result


func get_level(level_id: StringName) -> LevelDefinition:
	for definition in levels:
		if definition != null and definition.id == level_id:
			return definition
	return null


func is_unlocked(level_id: StringName, completed_ids: Dictionary) -> bool:
	var definition := get_level(level_id)
	if definition == null:
		return false
	for prerequisite in definition.prerequisites:
		if not bool(completed_ids.get(prerequisite, false)):
			return false
	return true


func _detect_cycle(
		level_id: StringName,
		by_id: Dictionary,
		visit_state: Dictionary,
		stack: Array[StringName],
		errors: Array[String]
) -> void:
	var state := int(visit_state.get(level_id, 0))
	if state == 2:
		return
	if state == 1:
		var chain: Array[String] = []
		for item in stack:
			chain.append(String(item))
		chain.append(String(level_id))
		var message := "关卡前置存在循环：%s" % " -> ".join(chain)
		if not errors.has(message):
			errors.append(message)
		return
	visit_state[level_id] = 1
	stack.append(level_id)
	var definition := by_id.get(level_id) as LevelDefinition
	if definition != null:
		for prerequisite in definition.prerequisites:
			if by_id.has(prerequisite):
				_detect_cycle(prerequisite, by_id, visit_state, stack, errors)
	stack.pop_back()
	visit_state[level_id] = 2
