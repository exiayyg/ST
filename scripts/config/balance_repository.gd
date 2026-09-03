class_name BalanceRepository
extends RefCounted

const BalanceProfileType := preload("res://scripts/config/balance_profile.gd")
const BalanceFieldCatalogType := preload("res://scripts/config/balance_field_catalog.gd")
const BalanceSchemaType := preload("res://scripts/config/balance_schema.gd")
const DEFAULT_PATH := "res://config/balance/balance.json"


static func load_profile(path := DEFAULT_PATH) -> BalanceProfile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开数值配置：%s" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("数值配置不是 JSON 对象：%s" % path)
		return null
	var migrated := BalanceSchemaType.migrate(parsed)
	if migrated.is_empty():
		push_error("数值配置版本无法迁移：%s" % path)
		return null
	var profile := BalanceProfileType.new(migrated, path) as BalanceProfile
	var errors := profile.validate()
	if not errors.is_empty():
		push_error("数值配置校验失败：\n%s" % "\n".join(errors))
		return null
	return profile


static func save_profile(profile: BalanceProfile, path := DEFAULT_PATH) -> Array[String]:
	var errors := profile.validate()
	if not errors.is_empty():
		return errors
	var text := JSON.stringify(_sort_value(profile.data, ""), "\t", false) + "\n"
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null:
		return ["无法写入临时配置：%s" % temporary_path]
	temporary.store_string(text)
	temporary.close()
	var verification := load_profile(temporary_path)
	if verification == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return ["临时配置回读校验失败，正式配置未改变"]
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return ["无法创建配置备份，正式配置未改变"]
	var replace_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return ["无法替换正式配置，已恢复备份"]
	return []


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
	if (value is int or value is float) and BalanceFieldCatalogType.is_integer_field(path):
		return int(round(float(value)))
	return value
