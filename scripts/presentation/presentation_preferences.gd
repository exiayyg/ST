class_name PresentationPreferences
extends RefCounted

const PATH := "user://presentation_settings.json"
var master_volume: float
var sfx_volume: float
var muted: bool
var reduced_motion: bool
var notice := ""
var _overrides: Dictionary = {}

func configure(profile: BalanceProfile, path := PATH) -> void:
	notice = ""
	master_volume = profile.runtime_config().audio.master_volume
	sfx_volume = profile.runtime_config().audio.sfx_volume
	muted = profile.runtime_config().audio.muted
	reduced_motion = profile.runtime_config().presentation.reduced_motion
	_overrides.clear()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _valid(parsed):
		notice = "视听偏好无法读取，已使用项目默认值。"
		return
	_overrides = parsed.duplicate(true)
	_apply(_overrides)

func snapshot() -> Dictionary:
	return {"master_volume":master_volume, "sfx_volume":sfx_volume, "muted":muted, "reduced_motion":reduced_motion}

func update(key: String, value, path := PATH) -> bool:
	var candidate := _overrides.duplicate(true)
	candidate[key] = value
	if not _valid(candidate):
		return false
	_overrides = candidate
	_apply(candidate)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		notice = "视听设置本次已生效，但未能保存。"
		return false
	file.store_string(JSON.stringify(candidate, "\t", true, true))
	file.close()
	if not _valid(JSON.parse_string(FileAccess.get_file_as_string(temporary))) or DirAccess.rename_absolute(temporary, path) != OK:
		notice = "视听设置本次已生效，但未能保存。"
		return false
	notice = ""
	return true

func _apply(data: Dictionary) -> void:
	for key in data:
		set(key, data[key])

func _valid(value) -> bool:
	if value is not Dictionary:
		return false
	for key in value:
		if key in ["muted", "reduced_motion"]:
			if value[key] is not bool: return false
		elif key in ["master_volume", "sfx_volume"]:
			if value[key] is not float and value[key] is not int: return false
			if not is_finite(float(value[key])) or float(value[key]) < 0.0 or float(value[key]) > 1.0: return false
		else:
			return false
	return true
