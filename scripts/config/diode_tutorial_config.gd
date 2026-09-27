class_name DiodeTutorialConfig
extends Resource

var _values: Dictionary

var no_damage_seconds: float:
	get: return float(_values.feedback.no_damage_seconds)

var confirmation_seconds: float:
	get: return float(_values.feedback.confirmation_seconds)

var reminder_interval_seconds: float:
	get: return float(_values.feedback.reminder_interval_seconds)

func _init(values: Dictionary) -> void:
	_values = values.duplicate(true)

var direction_tolerance_degrees: float:
	get: return float(_values.direction_tolerance_degrees)

var display_name: String:
	get: return String(_values.display_name)

var intermission_seconds: float:
	get: return float(_values.intermission_seconds)

var lesson_device: String:
	get: return String(_values.lesson_device)

var marker_radius: float:
	get: return float(_values.marker_radius)

var observation_seconds: float:
	get: return float(_values.observation_seconds)

var practice_entry_x: float:
	get: return float(_values.practice_entry_x)

var practice_entry_y: float:
	get: return float(_values.practice_entry_y)

var practice_exit_x: float:
	get: return float(_values.practice_exit_x)

var practice_exit_y: float:
	get: return float(_values.practice_exit_y)

var route_entry_x: float:
	get: return float(_values.route_entry_x)

var route_entry_y: float:
	get: return float(_values.route_entry_y)

var route_exit_angle_degrees: float:
	get: return float(_values.route_exit_angle_degrees)

var route_exit_x: float:
	get: return float(_values.route_exit_x)

var route_exit_y: float:
	get: return float(_values.route_exit_y)

var waves: Array:
	get: return _values.waves.duplicate(true)

var session_kind: String:
	get: return String(_values.session_kind)

var route_min_north_distance: float:
	get: return float(_values.route_min_north_distance)

var path_hint_length: float:
	get: return float(_values.path_hint_length)

var direction_hint_length: float:
	get: return float(_values.direction_hint_length)

func position(prefix: String) -> Vector2:
	return Vector2(float(_values[prefix + "_x"]), float(_values[prefix + "_y"]))
