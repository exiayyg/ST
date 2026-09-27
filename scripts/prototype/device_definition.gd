class_name DeviceDefinition
extends Resource

@export var kind: StringName
@export var display_name: String
@export var short_name: String
@export var color: Color = Color.WHITE
@export var activation_required := 30.0
@export var max_hp := 100.0
@export var light_radius := 260.0
@export var activation_radius := 28.0
@export var half_length := 48.0
@export var speed_multiplier := 1.55
@export var mass_multiplier := 1.55
@export var splitter_half_separation := 36.0
@export var field_radius := 120.0
@export var electric_acceleration := 90.0
@export var magnetic_angular_speed := 1.2
@export var shockwave_radius := 36.0
@export var wave_point_count := 48
@export var wave_fan_radians := PI * 0.5
@export var wave_speed := 360.0
@export var reconstruction_mass := 0.05
@export var reconstruction_speed := 240.0


@export var entropy_sensitivity := 1.0


func to_native_spec(
		position: Vector2,
		angle_radians: float,
		secondary_position: Vector2 = Vector2.ZERO,
		secondary_angle_radians: float = 0.0
) -> Dictionary:
	return {
		"type": String(kind),
		"position": position,
		"angle_radians": angle_radians,
		"secondary_position": secondary_position,
		"secondary_angle_radians": secondary_angle_radians,
		"activation_radius": activation_radius,
		"activation_required": activation_required,
		"half_length": half_length,
		"speed_multiplier": speed_multiplier,
		"mass_multiplier": mass_multiplier,
		"splitter_half_separation": splitter_half_separation,
		"field_radius": field_radius,
		"electric_acceleration": electric_acceleration,
		"magnetic_angular_speed": magnetic_angular_speed,
		"shockwave_radius": shockwave_radius,
		"wave_point_count": wave_point_count,
		"wave_fan_radians": wave_fan_radians,
		"wave_speed": wave_speed,
		"reconstruction_mass": reconstruction_mass,
		"reconstruction_speed": reconstruction_speed,
		"entropy_sensitivity": entropy_sensitivity,
	}
