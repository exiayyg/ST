class_name BalanceProfile
extends Resource

const BalanceSchemaType := preload("res://scripts/config/balance_schema.gd")
const RuntimeBalanceType := preload("res://scripts/config/runtime_balance.gd")

var _data: Dictionary = {}
var data: Dictionary:
	get: return _data
	set(value):
		if not _sealed:
			_data = value.duplicate(true)
var _sealed := false
var _path_cache: Dictionary = {}
var _compiled: RuntimeBalanceType
var source_path := "res://config/balance/balance.json"


func _init(initial_data: Dictionary = {}, path := "res://config/balance/balance.json") -> void:
	data = initial_data.duplicate(true)
	source_path = path


func duplicate_profile() -> BalanceProfile:
	return BalanceProfile.new(data, source_path)


func section(name: String) -> Dictionary:
	return (data.get(name, {}) as Dictionary).duplicate(true)


func value(path: String, fallback = null):
	if _sealed:
		return _path_cache.get(path, fallback)
	var cursor = data
	for part in path.split("/"):
		if cursor is Dictionary:
			if not cursor.has(part):
				return fallback
			cursor = cursor[part]
		elif cursor is Array and part.is_valid_int():
			var index := part.to_int()
			if index < 0 or index >= cursor.size():
				return fallback
			cursor = cursor[index]
		else:
			return fallback
	return cursor


func set_value(path: String, new_value) -> bool:
	if _sealed:
		return false
	var parts := path.split("/")
	if parts.is_empty():
		return false
	var cursor = data
	for index in range(parts.size() - 1):
		var part := parts[index]
		if cursor is Dictionary and cursor.has(part):
			cursor = cursor[part]
		elif cursor is Array and part.is_valid_int() and part.to_int() >= 0 and part.to_int() < cursor.size():
			cursor = cursor[part.to_int()]
		else:
			return false
	var last := parts[-1]
	if cursor is Dictionary:
		cursor[last] = new_value
	elif cursor is Array and last.is_valid_int() and last.to_int() >= 0 and last.to_int() < cursor.size():
		cursor[last.to_int()] = new_value
	else:
		return false
	return true


func validate() -> Array[String]:
	return BalanceSchemaType.validate(data)


func freeze() -> Array[String]:
	if _sealed:
		return []
	var errors := validate()
	if not errors.is_empty():
		return errors
	_freeze_value(_data, "")
	_compiled = RuntimeBalanceType.new(_data)
	_sealed = true
	return []


func runtime_config() -> RuntimeBalanceType:
	if _sealed:
		return _compiled
	var copy := duplicate_profile()
	return copy._compiled if copy.freeze().is_empty() else null


func _freeze_value(value, path: String) -> void:
	_path_cache[path] = value
	if value is Dictionary:
		for key in value:
			_freeze_value(value[key], String(key) if path.is_empty() else path + "/" + String(key))
		value.make_read_only()
	elif value is Array:
		for index in value.size():
			_freeze_value(value[index], path + "/" + str(index))
		value.make_read_only()


func entropy_weight(entropy_value: float) -> float:
	var entropy_section: Dictionary = data.get("entropy", {})
	var start := float(entropy_section.get("start_entropy", 50.0))
	var full := float(entropy_section.get("full_effect_entropy", 100.0))
	if entropy_value <= start:
		return 0.0
	if entropy_value >= full:
		return 1.0
	var normalized := (entropy_value - start) / maxf(full - start, 0.000001)
	return BalanceSchemaType.sample_curve(entropy_section.get("uncertainty_curve", []), normalized)


func tower_momentum() -> float:
	return float(value("tower/projectile_mass", 0.05)) * float(value("tower/projectile_speed", 240.0))


func map_rect() -> Rect2:
	return Rect2(
		float(value("map_camera/map_x", -2304.0)),
		float(value("map_camera/map_y", -1296.0)),
		float(value("map_camera/map_width", 4608.0)),
		float(value("map_camera/map_height", 2592.0))
	)
