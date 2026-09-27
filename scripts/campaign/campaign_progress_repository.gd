class_name CampaignProgressRepository
extends RefCounted

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://campaign_progress.json"


static func empty_progress() -> Dictionary:
	return {"schema_version": CURRENT_VERSION, "levels": {}}


static func load_progress(path := DEFAULT_PATH) -> Dictionary:
	var present := FileAccess.file_exists(path)
	var primary := _read_progress(path)
	if bool(primary.ok):
		return primary
	var backup := _read_progress(path + ".bak")
	if present:
		var preserved := _preserve_corrupt(path)
		if preserved != OK:
			return _failure("无法保留损坏进度，原文件未修改")
	if bool(backup.ok):
		var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(path + ".bak"), ProjectSettings.globalize_path(path + ".tmp"))
		if copy_error == OK:
			copy_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
		backup["notice"] = "已从上次有效备份恢复关卡进度。" if copy_error == OK else "备份进度已载入，暂时无法恢复正式文件。"
		return backup
	if not present and not FileAccess.file_exists(path + ".bak"):
		return {"ok": true, "data": empty_progress(), "errors": []}
	return _failure("本地进度无法读取，已保留损坏数据并以空白进度继续。")


static func _read_progress(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("进度文件不存在")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("无法打开关卡进度：%s" % path)
	var parser := JSON.new()
	var content := file.get_as_text()
	file.close()
	var parse_error := parser.parse(content)
	if parse_error != OK:
		return _failure("关卡进度 JSON 无效（第 %d 行）：%s" % [parser.get_error_line(), parser.get_error_message()])
	var parsed = parser.data
	if parsed is not Dictionary:
		return _failure("关卡进度不是 JSON 对象：%s" % path)
	var errors := validate(parsed)
	if not errors.is_empty():
		return {"ok": false, "data": empty_progress(), "errors": errors}
	return {"ok": true, "data": (parsed as Dictionary).duplicate(true), "errors": []}


static func save_progress(data: Dictionary, path := DEFAULT_PATH) -> Array[String]:
	var errors := validate(data)
	if not errors.is_empty():
		return errors
	var text := JSON.stringify(_sort_value(data, ""), "\t", false) + "\n"
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null:
		return ["无法写入临时进度：%s" % temporary_path]
	temporary.store_string(text)
	temporary.close()
	var verification := _read_progress(temporary_path)
	if not bool(verification.get("ok", false)) or JSON.stringify(_sort_value(verification.data, ""), "\t", false) + "\n" != text:
		_remove_if_exists(temporary_path)
		return ["临时进度回读校验失败，正式进度未改变"]
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(path):
		var backup_error: Error
		if bool(_read_progress(path).ok):
			_remove_if_exists(backup_path)
			backup_error = DirAccess.rename_absolute(absolute_path, absolute_backup)
		else:
			backup_error = _preserve_corrupt(path)
		if backup_error != OK:
			_remove_if_exists(temporary_path)
			return ["无法创建进度备份，正式进度未改变"]
	var replace_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return ["无法替换正式进度，已恢复备份"]
	return []


static func _preserve_corrupt(path: String) -> Error:
	var preserved_path := "%s.corrupt.%d" % [path, Time.get_ticks_usec()]
	while FileAccess.file_exists(preserved_path):
		preserved_path += "_"
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(preserved_path))


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var expected := ["schema_version", "levels"]
	for key in expected:
		if not data.has(key):
			errors.append("关卡进度缺少字段：%s" % key)
	for key in data.keys():
		if not expected.has(String(key)):
			errors.append("关卡进度包含未知字段：%s" % key)
	var version = data.get("schema_version", null)
	if (version is not int and version is not float) or not is_finite(float(version)) \
			or int(version) != CURRENT_VERSION or not is_equal_approx(float(version), float(CURRENT_VERSION)):
		errors.append("关卡进度 schema_version 必须为 %d" % CURRENT_VERSION)
	var levels_value = data.get("levels", null)
	if levels_value is not Dictionary:
		errors.append("关卡进度 levels 必须为对象")
		return errors
	for raw_id in (levels_value as Dictionary).keys():
		var level_id := String(raw_id)
		if level_id.strip_edges().is_empty():
			errors.append("关卡进度不能包含空 ID")
			continue
		var record = levels_value[raw_id]
		if record is not Dictionary:
			errors.append("关卡进度 %s 必须为对象" % level_id)
			continue
		for key in ["completed", "best_utilization"]:
			if not record.has(key):
				errors.append("关卡进度 %s 缺少字段：%s" % [level_id, key])
		for key in record.keys():
			if not ["completed", "best_utilization"].has(String(key)):
				errors.append("关卡进度 %s 包含未知字段：%s" % [level_id, key])
		if record.get("completed", null) is not bool:
			errors.append("关卡进度 %s/completed 必须为布尔值" % level_id)
		var best = record.get("best_utilization", null)
		if best is not int and best is not float:
			errors.append("关卡进度 %s/best_utilization 必须为数值" % level_id)
		elif not is_finite(float(best)) or float(best) < 0.0:
			errors.append("关卡进度 %s/best_utilization 必须为有限非负数" % level_id)
	return errors


static func _sort_value(value, path: String):
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys:
			var child_path := String(key) if path.is_empty() else "%s/%s" % [path, key]
			result[key] = _sort_value(value[key], child_path)
		return result
	if value is Array:
		var result: Array = []
		for index in value.size():
			result.append(_sort_value(value[index], "%s/%d" % [path, index]))
		return result
	if path == "schema_version" and (value is int or value is float):
		return int(value)
	return value


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "data": empty_progress(), "errors": [message]}


static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
