class_name DeviceCatalog
extends RefCounted

const DeviceDefinitionType := preload("res://scripts/prototype/device_definition.gd")

var definitions: Array[DeviceDefinition] = []
var by_kind: Dictionary = {}


func _init(profile: BalanceProfile = null) -> void:
	if profile == null:
		push_error("DeviceCatalog 需要 BalanceProfile")
		return
	var configured: Dictionary = profile.data.get("devices", {})
	var ordered_kinds: Array[StringName] = [
		&"bounce_plate", &"speed_increaser", &"mass_increaser", &"splitter",
		&"accumulator", &"wave_converter", &"magnetic_field", &"electric_field", &"diode"
	]
	for kind in ordered_kinds:
		if configured.has(String(kind)):
			definitions.append(_make(kind, configured[String(kind)]))
	for definition in definitions:
		by_kind[definition.kind] = definition


func get_definition(kind: StringName) -> DeviceDefinition:
	return by_kind.get(kind) as DeviceDefinition


func _make(kind: StringName, values: Dictionary) -> DeviceDefinition:
	var definition := DeviceDefinitionType.new() as DeviceDefinition
	definition.kind = kind
	definition.display_name = String(values.get("display_name", String(kind)))
	definition.short_name = String(values.get("short_name", definition.display_name))
	definition.color = Color(String(values.get("color", "ffffff")))
	definition.activation_required = float(values.get("activation_required", definition.activation_required))
	definition.max_hp = float(values.get("max_hp", definition.max_hp))
	definition.light_radius = float(values.get("light_radius", definition.light_radius))
	definition.activation_radius = float(values.get("activation_radius", definition.activation_radius))
	definition.half_length = float(values.get("half_length", definition.half_length))
	definition.speed_multiplier = float(values.get("speed_multiplier", definition.speed_multiplier))
	definition.mass_multiplier = float(values.get("mass_multiplier", definition.mass_multiplier))
	definition.splitter_half_separation = float(values.get("splitter_half_separation", definition.splitter_half_separation))
	definition.field_radius = float(values.get("field_radius", definition.field_radius))
	definition.electric_acceleration = float(values.get("electric_acceleration", definition.electric_acceleration))
	definition.magnetic_angular_speed = float(values.get("magnetic_angular_speed", definition.magnetic_angular_speed))
	definition.shockwave_radius = float(values.get("shockwave_radius", definition.shockwave_radius))
	definition.wave_point_count = int(values.get("wave_point_count", definition.wave_point_count))
	definition.wave_fan_radians = deg_to_rad(float(values.get("wave_fan_degrees", rad_to_deg(definition.wave_fan_radians))))
	definition.wave_speed = float(values.get("wave_speed", definition.wave_speed))
	definition.reconstruction_mass = float(values.get("reconstruction_mass", definition.reconstruction_mass))
	definition.reconstruction_speed = float(values.get("reconstruction_speed", definition.reconstruction_speed))
	definition.entropy_sensitivity = float(values.get("entropy_sensitivity", definition.entropy_sensitivity))
	return definition
