class_name SimulationController
extends RefCounted

var native: MomentumSimulation
var profile: BalanceProfile
const RuntimeBalanceType := preload("res://scripts/config/runtime_balance.gd")
var _tower_config: RuntimeBalanceType.Tower


func _init(balance_profile: BalanceProfile = null) -> void:
	profile = balance_profile


func initialize() -> bool:
	if profile == null:
		push_error("SimulationController 需要 BalanceProfile")
		return false
	if not profile.validate().is_empty():
		return false
	native = MomentumSimulation.new()
	_tower_config = profile.runtime_config().tower
	var tower := profile.section("tower")
	var simulation := profile.section("simulation")
	var entropy := profile.section("entropy")
	return native.configure({
		"fixed_step_seconds": float(simulation.fixed_step_seconds),
		"max_substeps": int(simulation.max_substeps),
		"initial_projectile_momentum": profile.tower_momentum(),
		"initial_projectile_mass": float(tower.projectile_mass),
		"initial_projectile_speed": float(tower.projectile_speed),
		"momentum_zero_epsilon": float(simulation.momentum_zero_epsilon),
		"projectile_radius": float(simulation.projectile_radius),
		"wave_point_radius": float(simulation.wave_point_radius),
		"entropy_per_second": float(entropy.per_second),
		"entropy_per_interaction": float(entropy.per_interaction),
		"entropy_interaction_acceleration": float(entropy.interaction_acceleration),
		"entropy_start": float(entropy.start_entropy),
		"entropy_full_effect": float(entropy.full_effect_entropy),
		"entropy_curve": entropy.uncertainty_curve,
		"max_angle_deviation_radians": deg_to_rad(float(entropy.max_angle_deviation_degrees)),
		"max_speed_deviation_ratio": float(entropy.max_speed_deviation_ratio),
		"max_mass_deviation_ratio": float(entropy.max_mass_deviation_ratio),
		"max_diode_exit_offset": float(entropy.max_diode_exit_offset),
		"max_diode_angle_deviation_radians": deg_to_rad(float(entropy.max_diode_angle_deviation_degrees)),
		"max_split_direction_deviation_radians": deg_to_rad(float(entropy.max_split_direction_deviation_degrees)),
		"max_split_share_deviation_ratio": float(entropy.max_split_share_deviation_ratio),
		"entropy_visual_start": float(entropy.visual_start_entropy),
		"entropy_visual_full": float(entropy.visual_full_entropy),
		"spatial_cell_size": float(simulation.spatial_cell_size),
		"enemy_spatial_cell_size": float(simulation.enemy_spatial_cell_size),
		"entity_spawn_clearance": float(simulation.entity_spawn_clearance),
		"max_interactions_per_step": int(simulation.max_interactions_per_step),
		"random_seed": int(simulation.random_seed),
		"projectile_base_diameter": float(profile.value("visuals/projectile_base_diameter", 8.0)),
		"projectile_entropy_extra_diameter": float(profile.value("visuals/projectile_entropy_extra_diameter", 8.0)),
		"wave_point_diameter": float(profile.value("visuals/wave_point_diameter", 5.0)),
		"projectile_low_entropy_color": Color(String(profile.value("visuals/projectile_low_entropy_color", "79d7ff"))),
		"projectile_high_entropy_color": Color(String(profile.value("visuals/projectile_high_entropy_color", "ff765f"))),
		"projectile_charged_color": Color(String(profile.value("visuals/projectile_charged_color", "ffe36b"))),
		"projectile_charge_blend_ratio": float(profile.value("visuals/projectile_charge_blend_ratio", 0.45)),
		"wave_point_color": Color(String(profile.value("visuals/wave_point_color", "65f4ff"))),
	})


func emit_tower_projectile(position: Vector2) -> void:
	var speed := _tower_config.projectile_speed
	var mass := _tower_config.projectile_mass
	var muzzle_offset := _tower_config.muzzle_offset
	native.emit_projectiles([{
		"position": position + Vector2(muzzle_offset, 0.0),
		"velocity": Vector2(speed, 0.0),
		"mass": mass,
		"tower_source": true,
		"entropy": 0.0,
		"charge": 0.0,
	}])


func add_device(
		definition: DeviceDefinition,
		position: Vector2,
		angle: float,
		secondary_position: Vector2 = Vector2.ZERO,
		secondary_angle: float = 0.0
) -> int:
	return native.add_device(definition.to_native_spec(position, angle, secondary_position, secondary_angle))


func add_diagnostic_target(position: Vector2) -> int:
	return native.add_diagnostic_target({
		"position": position,
		"radius": float(profile.value("diagnostics/target_radius", 34.0)),
		"damage_per_momentum": float(profile.value("diagnostics/target_damage_per_momentum", 1.0)),
		"momentum_absorption_fraction": float(profile.value("diagnostics/target_momentum_absorption", 1.0)),
	})


func step(delta: float) -> void:
	native.step(delta)
