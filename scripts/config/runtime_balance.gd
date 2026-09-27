class_name RuntimeBalance
extends RefCounted

# Compiled only after whole-document validation. No numeric defaults live here.

class Simulation extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var enemy_spatial_cell_size: float:
		get: return float(_values.enemy_spatial_cell_size)

	var entity_spawn_clearance: float:
		get: return float(_values.entity_spawn_clearance)

	var fixed_step_seconds: float:
		get: return float(_values.fixed_step_seconds)

	var max_interactions_per_step: int:
		get: return int(_values.max_interactions_per_step)

	var max_substeps: int:
		get: return int(_values.max_substeps)

	var momentum_zero_epsilon: float:
		get: return float(_values.momentum_zero_epsilon)

	var projectile_radius: float:
		get: return float(_values.projectile_radius)

	var random_seed: int:
		get: return int(_values.random_seed)

	var render_snapshot_margin: float:
		get: return float(_values.render_snapshot_margin)

	var spatial_cell_size: float:
		get: return float(_values.spatial_cell_size)

	var wave_point_radius: float:
		get: return float(_values.wave_point_radius)

var simulation: Simulation

class Tower extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var collision_radius: float:
		get: return float(_values.collision_radius)

	var fire_interval: float:
		get: return float(_values.fire_interval)

	var light_radius: float:
		get: return float(_values.light_radius)

	var max_hp: float:
		get: return float(_values.max_hp)

	var muzzle_offset: float:
		get: return float(_values.muzzle_offset)

	var position_x: float:
		get: return float(_values.position_x)

	var position_y: float:
		get: return float(_values.position_y)

	var projectile_mass: float:
		get: return float(_values.projectile_mass)

	var projectile_speed: float:
		get: return float(_values.projectile_speed)

var tower: Tower

class ConstructionUx extends RefCounted:
	var click_max_seconds: float:
		get: return float(_values.click_max_seconds)

	var gesture_tolerance: float:
		get: return float(_values.gesture_tolerance)

	var rotation_center_dead_zone: float:
		get: return float(_values.rotation_center_dead_zone)

	var diode_initial_offset: float:
		get: return float(_values.diode_initial_offset)

	var preview_alpha: float:
		get: return float(_values.preview_alpha)

	var preview_line_width: float:
		get: return float(_values.preview_line_width)

	var preview_direction_length: float:
		get: return float(_values.preview_direction_length)

	var preview_font_size: float:
		get: return float(_values.preview_font_size)

	var action_button_width: float:
		get: return float(_values.action_button_width)

	var action_button_height: float:
		get: return float(_values.action_button_height)

	var action_inset: float:
		get: return float(_values.action_inset)

	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var damage_debug_amount: float:
		get: return float(_values.damage_debug_amount)

	var device_pick_radius: float:
		get: return float(_values.device_pick_radius)

	var dismantle_hold_seconds: float:
		get: return float(_values.dismantle_hold_seconds)

	var radial_dead_zone: float:
		get: return float(_values.radial_dead_zone)

	var radial_hold_seconds: float:
		get: return float(_values.radial_hold_seconds)

	var radial_radius: float:
		get: return float(_values.radial_radius)

	var radial_screen_margin: float:
		get: return float(_values.radial_screen_margin)


	var radial_top_clearance: float:
		get: return float(_values.radial_top_clearance)

	var radial_bottom_clearance: float:
		get: return float(_values.radial_bottom_clearance)

var construction_ux: ConstructionUx

class MapCamera extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var map_height: float:
		get: return float(_values.map_height)

	var map_margin: float:
		get: return float(_values.map_margin)

	var map_width: float:
		get: return float(_values.map_width)

	var map_x: float:
		get: return float(_values.map_x)

	var map_y: float:
		get: return float(_values.map_y)

	var max_zoom: float:
		get: return float(_values.max_zoom)

	var min_zoom: float:
		get: return float(_values.min_zoom)

	var pan_speed: float:
		get: return float(_values.pan_speed)

	var zoom_step_base: float:
		get: return float(_values.zoom_step_base)

var map_camera: MapCamera

class Entropy extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var full_effect_entropy: float:
		get: return float(_values.full_effect_entropy)

	var interaction_acceleration: float:
		get: return float(_values.interaction_acceleration)

	var max_angle_deviation_degrees: float:
		get: return float(_values.max_angle_deviation_degrees)

	var max_diode_angle_deviation_degrees: float:
		get: return float(_values.max_diode_angle_deviation_degrees)

	var max_diode_exit_offset: float:
		get: return float(_values.max_diode_exit_offset)

	var max_enemy_shield_position_offset: float:
		get: return float(_values.max_enemy_shield_position_offset)

	var max_enemy_target_score_deviation_ratio: float:
		get: return float(_values.max_enemy_target_score_deviation_ratio)

	var max_mass_deviation_ratio: float:
		get: return float(_values.max_mass_deviation_ratio)

	var max_speed_deviation_ratio: float:
		get: return float(_values.max_speed_deviation_ratio)

	var max_split_direction_deviation_degrees: float:
		get: return float(_values.max_split_direction_deviation_degrees)

	var max_split_share_deviation_ratio: float:
		get: return float(_values.max_split_share_deviation_ratio)

	var per_interaction: float:
		get: return float(_values.per_interaction)

	var per_second: float:
		get: return float(_values.per_second)

	var start_entropy: float:
		get: return float(_values.start_entropy)

	var uncertainty_curve: Array:
		get: return _values.uncertainty_curve

	var visual_full_entropy: float:
		get: return float(_values.visual_full_entropy)

	var visual_start_entropy: float:
		get: return float(_values.visual_start_entropy)

var entropy: Entropy

class Fog extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var dark_blue: int:
		get: return int(_values.dark_blue)

	var dark_green: int:
		get: return int(_values.dark_green)

	var dark_red: int:
		get: return int(_values.dark_red)

	var edge_softness: float:
		get: return float(_values.edge_softness)

	var grid_height: int:
		get: return int(_values.grid_height)

	var grid_width: int:
		get: return int(_values.grid_width)

	var maximum_alpha: float:
		get: return float(_values.maximum_alpha)

var fog: Fog

class Frontend extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var body_font_size: int:
		get: return int(_values.body_font_size)

	var button_height: float:
		get: return float(_values.button_height)

	var card_height: float:
		get: return float(_values.card_height)

	var confirmation_width: float:
		get: return float(_values.confirmation_width)

	var content_width: float:
		get: return float(_values.content_width)

	var item_gap: float:
		get: return float(_values.item_gap)

	var outer_margin: float:
		get: return float(_values.outer_margin)

	var pause_panel_height: float:
		get: return float(_values.pause_panel_height)

	var pause_panel_width: float:
		get: return float(_values.pause_panel_width)

	var subtitle_font_size: int:
		get: return int(_values.subtitle_font_size)

	var title_font_size: int:
		get: return int(_values.title_font_size)

	var tuning_columns_breakpoint: float:
		get: return float(_values.tuning_columns_breakpoint)

	var tuning_common_gap: float:
		get: return float(_values.tuning_common_gap)

	var tuning_label_width: float:
		get: return float(_values.tuning_label_width)

	var tuning_min_height: float:
		get: return float(_values.tuning_min_height)

	var tuning_title_font_size: int:
		get: return int(_values.tuning_title_font_size)

	var tuning_field_label_width: float:
		get: return float(_values.tuning_field_label_width)

	var tuning_error_height: float:
		get: return float(_values.tuning_error_height)

	var tuning_inset_x: float:
		get: return float(_values.tuning_inset_x)

	var tuning_inset_y: float:
		get: return float(_values.tuning_inset_y)

var frontend: Frontend

class Visuals extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var bar_background_color: String:
		get: return String(_values.bar_background_color)

	var charge_color: String:
		get: return String(_values.charge_color)

	var destroy_effect_end_radius: float:
		get: return float(_values.destroy_effect_end_radius)

	var destroy_effect_seconds: float:
		get: return float(_values.destroy_effect_seconds)

	var destroy_effect_start_radius: float:
		get: return float(_values.destroy_effect_start_radius)

	var destruction_fill_alpha: float:
		get: return float(_values.destruction_fill_alpha)

	var destruction_fill_color: String:
		get: return String(_values.destruction_fill_color)

	var destruction_stroke_color: String:
		get: return String(_values.destruction_stroke_color)

	var destruction_stroke_width: float:
		get: return float(_values.destruction_stroke_width)

	var device_activation_bar_height: float:
		get: return float(_values.device_activation_bar_height)

	var device_bar_width: float:
		get: return float(_values.device_bar_width)

	var device_cull_margin: float:
		get: return float(_values.device_cull_margin)

	var device_hit_flash_color: String:
		get: return String(_values.device_hit_flash_color)

	var device_hit_flash_seconds: float:
		get: return float(_values.device_hit_flash_seconds)

	var device_hp_bar_height: float:
		get: return float(_values.device_hp_bar_height)

	var diagnostic_target_color: String:
		get: return String(_values.diagnostic_target_color)

	var diode_teleport_pulse_color: String:
		get: return String(_values.diode_teleport_pulse_color)

	var diode_teleport_pulse_end_radius: float:
		get: return float(_values.diode_teleport_pulse_end_radius)

	var diode_teleport_pulse_seconds: float:
		get: return float(_values.diode_teleport_pulse_seconds)

	var diode_teleport_pulse_start_radius: float:
		get: return float(_values.diode_teleport_pulse_start_radius)

	var diode_teleport_pulse_width: float:
		get: return float(_values.diode_teleport_pulse_width)

	var dismantle_progress_color: String:
		get: return String(_values.dismantle_progress_color)

	var dismantle_progress_width: float:
		get: return float(_values.dismantle_progress_width)

	var enemy_bar_height: float:
		get: return float(_values.enemy_bar_height)

	var enemy_bar_width: float:
		get: return float(_values.enemy_bar_width)

	var enemy_entropy_color: String:
		get: return String(_values.enemy_entropy_color)

	var enemy_fill_alpha: float:
		get: return float(_values.enemy_fill_alpha)

	var grid_spacing: float:
		get: return float(_values.grid_spacing)

	var healthy_hp_color: String:
		get: return String(_values.healthy_hp_color)

	var hud_background_color: String:
		get: return String(_values.hud_background_color)

	var hud_danger_color: String:
		get: return String(_values.hud_danger_color)

	var hud_muted_color: String:
		get: return String(_values.hud_muted_color)

	var hud_success_color: String:
		get: return String(_values.hud_success_color)

	var hud_text_color: String:
		get: return String(_values.hud_text_color)

	var hud_top_bar_height: float:
		get: return float(_values.hud_top_bar_height)

	var hud_warning_color: String:
		get: return String(_values.hud_warning_color)

	var inactive_device_color: String:
		get: return String(_values.inactive_device_color)

	var low_hp_color: String:
		get: return String(_values.low_hp_color)

	var low_hp_flash_milliseconds: int:
		get: return int(_values.low_hp_flash_milliseconds)

	var low_hp_ratio: float:
		get: return float(_values.low_hp_ratio)

	var map_border_color: String:
		get: return String(_values.map_border_color)

	var map_border_width: float:
		get: return float(_values.map_border_width)

	var projectile_base_diameter: float:
		get: return float(_values.projectile_base_diameter)

	var projectile_charge_blend_ratio: float:
		get: return float(_values.projectile_charge_blend_ratio)

	var projectile_charged_color: String:
		get: return String(_values.projectile_charged_color)

	var projectile_entropy_extra_diameter: float:
		get: return float(_values.projectile_entropy_extra_diameter)

	var projectile_high_entropy_color: String:
		get: return String(_values.projectile_high_entropy_color)

	var projectile_low_entropy_color: String:
		get: return String(_values.projectile_low_entropy_color)

	var selection_extra_radius: float:
		get: return float(_values.selection_extra_radius)

	var selection_fill_alpha: float:
		get: return float(_values.selection_fill_alpha)

	var settlement_body_font_size: int:
		get: return int(_values.settlement_body_font_size)

	var settlement_button_font_size: int:
		get: return int(_values.settlement_button_font_size)

	var settlement_button_height: float:
		get: return float(_values.settlement_button_height)

	var settlement_button_width: float:
		get: return float(_values.settlement_button_width)

	var settlement_dim_alpha: float:
		get: return float(_values.settlement_dim_alpha)

	var settlement_panel_border_width: float:
		get: return float(_values.settlement_panel_border_width)

	var settlement_panel_height: float:
		get: return float(_values.settlement_panel_height)

	var settlement_panel_width: float:
		get: return float(_values.settlement_panel_width)

	var settlement_title_font_size: int:
		get: return int(_values.settlement_title_font_size)

	var target_reached_flash_alpha: float:
		get: return float(_values.target_reached_flash_alpha)

	var target_reached_flash_seconds: float:
		get: return float(_values.target_reached_flash_seconds)

	var tower_bar_height: float:
		get: return float(_values.tower_bar_height)

	var tower_bar_width: float:
		get: return float(_values.tower_bar_width)

	var tower_color: String:
		get: return String(_values.tower_color)

	var tower_fill_color: String:
		get: return String(_values.tower_fill_color)

	var tracer_line_width: float:
		get: return float(_values.tracer_line_width)

	var tracer_seconds: float:
		get: return float(_values.tracer_seconds)

	var tutorial_cue_color: String:
		get: return String(_values.tutorial_cue_color)

	var tutorial_cue_pulse_seconds: float:
		get: return float(_values.tutorial_cue_pulse_seconds)

	var tutorial_path_color: String:
		get: return String(_values.tutorial_path_color)

	var tutorial_path_width: float:
		get: return float(_values.tutorial_path_width)

	var warning_high_threshold: int:
		get: return int(_values.warning_high_threshold)

	var warning_low_threshold: int:
		get: return int(_values.warning_low_threshold)

	var wave_point_color: String:
		get: return String(_values.wave_point_color)

	var wave_point_diameter: float:
		get: return float(_values.wave_point_diameter)

	var world_axis_color: String:
		get: return String(_values.world_axis_color)

	var world_background_color: String:
		get: return String(_values.world_background_color)

	var world_grid_color: String:
		get: return String(_values.world_grid_color)

	var tutorial_instruction_width: float:
		get: return float(_values.tutorial_instruction_width)

	var tutorial_instruction_height: float:
		get: return float(_values.tutorial_instruction_height)

	var tutorial_instruction_top_offset: float:
		get: return float(_values.tutorial_instruction_top_offset)

var visuals: Visuals

class Diagnostics extends RefCounted:
	var _values: Dictionary

	func _init(values: Dictionary) -> void:
		_values = values

	var performance_enemy_count: int:
		get: return int(_values.performance_enemy_count)

	var stress_enemy_count: int:
		get: return int(_values.stress_enemy_count)

	var target_count: int:
		get: return int(_values.target_count)

	var target_damage_per_momentum: float:
		get: return float(_values.target_damage_per_momentum)

	var target_momentum_absorption: float:
		get: return float(_values.target_momentum_absorption)

	var target_radius: float:
		get: return float(_values.target_radius)

	var target_vertical_spacing: float:
		get: return float(_values.target_vertical_spacing)

	var target_x: float:
		get: return float(_values.target_x)

var diagnostics: Diagnostics

class Playtest extends RefCounted:
	var _values: Dictionary
	func _init(values: Dictionary) -> void:
		_values = values
	var sample_interval_seconds: float:
		get: return float(_values.sample_interval_seconds)
	var flush_interval_seconds: float:
		get: return float(_values.flush_interval_seconds)
	var hold_ring_radius: float:
		get: return float(_values.hold_ring_radius)
	var hold_ring_width: float:
		get: return float(_values.hold_ring_width)
	var endpoint_label_font_size: float:
		get: return float(_values.endpoint_label_font_size)
	var endpoint_label_offset: float:
		get: return float(_values.endpoint_label_offset)
	var exit_arrow_length: float:
		get: return float(_values.exit_arrow_length)
	var enemy_hit_flash_seconds: float:
		get: return float(_values.enemy_hit_flash_seconds)
	var enemy_hit_flash_color: String:
		get: return String(_values.enemy_hit_flash_color)
	var consent_width: float:
		get: return float(_values.consent_width)
	var feedback_field_height: float:
		get: return float(_values.feedback_field_height)

var playtest: Playtest

class Presentation extends RefCounted:
	var particle_edge_ratio: float:
		get: return float(_values.particle_edge_ratio)
	var particle_core_ratio: float:
		get: return float(_values.particle_core_ratio)
	var particle_white_ratio: float:
		get: return float(_values.particle_white_ratio)
	var _values: Dictionary
	func _init(values: Dictionary) -> void:
		_values = values
	var enabled: bool:
		get: return bool(_values.enabled)
	var reduced_motion: bool:
		get: return bool(_values.reduced_motion)
	var line_width: float:
		get: return float(_values.line_width)
	var halo_width: float:
		get: return float(_values.halo_width)
	var halo_alpha: float:
		get: return float(_values.halo_alpha)
	var body_radius: float:
		get: return float(_values.body_radius)
	var core_ratio: float:
		get: return float(_values.core_ratio)
	var cycle_seconds: float:
		get: return float(_values.cycle_seconds)
	var field_line_count: int:
		get: return int(_values.field_line_count)
	var effect_limit: int:
		get: return int(_values.effect_limit)
	var effect_seconds: float:
		get: return float(_values.effect_seconds)
	var effect_radius: float:
		get: return float(_values.effect_radius)
	var icon_radius: float:
		get: return float(_values.icon_radius)
	var ui_corner_radius: float:
		get: return float(_values.ui_corner_radius)
	var ui_inset: float:
		get: return float(_values.ui_inset)
	var settings_width: float:
		get: return float(_values.settings_width)
	var context_width: float:
		get: return float(_values.context_width)

var presentation: Presentation

class Audio extends RefCounted:
	var device_check_seconds: float:
		get: return float(_values.device_check_seconds)
	var harmonic_ratio: float:
		get: return float(_values.harmonic_ratio)
	var harmonic_multiple: float:
		get: return float(_values.harmonic_multiple)
	var _values: Dictionary
	func _init(values: Dictionary) -> void:
		_values = values
	var master_volume: float:
		get: return float(_values.master_volume)
	var sfx_volume: float:
		get: return float(_values.sfx_volume)
	var muted: bool:
		get: return bool(_values.muted)
	var world_voices: int:
		get: return int(_values.world_voices)
	var ui_voices: int:
		get: return int(_values.ui_voices)
	var sample_rate: int:
		get: return int(_values.sample_rate)
	var attack_seconds: float:
		get: return float(_values.attack_seconds)
	var release_ratio: float:
		get: return float(_values.release_ratio)
	var peak_gain: float:
		get: return float(_values.peak_gain)
	var ui_confirm_frequency: float:
		get: return float(_values.ui_confirm_frequency)
	var ui_confirm_duration: float:
		get: return float(_values.ui_confirm_duration)
	var ui_confirm_gain: float:
		get: return float(_values.ui_confirm_gain)
	var ui_confirm_cooldown: float:
		get: return float(_values.ui_confirm_cooldown)
	var ui_confirm_priority: int:
		get: return int(_values.ui_confirm_priority)
	var ui_cancel_frequency: float:
		get: return float(_values.ui_cancel_frequency)
	var ui_cancel_duration: float:
		get: return float(_values.ui_cancel_duration)
	var ui_cancel_gain: float:
		get: return float(_values.ui_cancel_gain)
	var ui_cancel_cooldown: float:
		get: return float(_values.ui_cancel_cooldown)
	var ui_cancel_priority: int:
		get: return int(_values.ui_cancel_priority)
	var place_frequency: float:
		get: return float(_values.place_frequency)
	var place_duration: float:
		get: return float(_values.place_duration)
	var place_gain: float:
		get: return float(_values.place_gain)
	var place_cooldown: float:
		get: return float(_values.place_cooldown)
	var place_priority: int:
		get: return int(_values.place_priority)
	var activate_frequency: float:
		get: return float(_values.activate_frequency)
	var activate_duration: float:
		get: return float(_values.activate_duration)
	var activate_gain: float:
		get: return float(_values.activate_gain)
	var activate_cooldown: float:
		get: return float(_values.activate_cooldown)
	var activate_priority: int:
		get: return int(_values.activate_priority)
	var dismantle_frequency: float:
		get: return float(_values.dismantle_frequency)
	var dismantle_duration: float:
		get: return float(_values.dismantle_duration)
	var dismantle_gain: float:
		get: return float(_values.dismantle_gain)
	var dismantle_cooldown: float:
		get: return float(_values.dismantle_cooldown)
	var dismantle_priority: int:
		get: return int(_values.dismantle_priority)
	var tower_fire_frequency: float:
		get: return float(_values.tower_fire_frequency)
	var tower_fire_duration: float:
		get: return float(_values.tower_fire_duration)
	var tower_fire_gain: float:
		get: return float(_values.tower_fire_gain)
	var tower_fire_cooldown: float:
		get: return float(_values.tower_fire_cooldown)
	var tower_fire_priority: int:
		get: return int(_values.tower_fire_priority)
	var transform_frequency: float:
		get: return float(_values.transform_frequency)
	var transform_duration: float:
		get: return float(_values.transform_duration)
	var transform_gain: float:
		get: return float(_values.transform_gain)
	var transform_cooldown: float:
		get: return float(_values.transform_cooldown)
	var transform_priority: int:
		get: return int(_values.transform_priority)
	var hit_frequency: float:
		get: return float(_values.hit_frequency)
	var hit_duration: float:
		get: return float(_values.hit_duration)
	var hit_gain: float:
		get: return float(_values.hit_gain)
	var hit_cooldown: float:
		get: return float(_values.hit_cooldown)
	var hit_priority: int:
		get: return int(_values.hit_priority)
	var destroy_frequency: float:
		get: return float(_values.destroy_frequency)
	var destroy_duration: float:
		get: return float(_values.destroy_duration)
	var destroy_gain: float:
		get: return float(_values.destroy_gain)
	var destroy_cooldown: float:
		get: return float(_values.destroy_cooldown)
	var destroy_priority: int:
		get: return int(_values.destroy_priority)
	var warning_frequency: float:
		get: return float(_values.warning_frequency)
	var warning_duration: float:
		get: return float(_values.warning_duration)
	var warning_gain: float:
		get: return float(_values.warning_gain)
	var warning_cooldown: float:
		get: return float(_values.warning_cooldown)
	var warning_priority: int:
		get: return int(_values.warning_priority)
	var target_frequency: float:
		get: return float(_values.target_frequency)
	var target_duration: float:
		get: return float(_values.target_duration)
	var target_gain: float:
		get: return float(_values.target_gain)
	var target_cooldown: float:
		get: return float(_values.target_cooldown)
	var target_priority: int:
		get: return int(_values.target_priority)
	var victory_frequency: float:
		get: return float(_values.victory_frequency)
	var victory_duration: float:
		get: return float(_values.victory_duration)
	var victory_gain: float:
		get: return float(_values.victory_gain)
	var victory_cooldown: float:
		get: return float(_values.victory_cooldown)
	var victory_priority: int:
		get: return int(_values.victory_priority)
	var failure_frequency: float:
		get: return float(_values.failure_frequency)
	var failure_duration: float:
		get: return float(_values.failure_duration)
	var failure_gain: float:
		get: return float(_values.failure_gain)
	var failure_cooldown: float:
		get: return float(_values.failure_cooldown)
	var failure_priority: int:
		get: return int(_values.failure_priority)
	var enemy_attack_frequency: float:
		get: return float(_values.enemy_attack_frequency)
	var enemy_attack_duration: float:
		get: return float(_values.enemy_attack_duration)
	var enemy_attack_gain: float:
		get: return float(_values.enemy_attack_gain)
	var enemy_attack_cooldown: float:
		get: return float(_values.enemy_attack_cooldown)
	var enemy_attack_priority: int:
		get: return int(_values.enemy_attack_priority)
	func cue(kind: String) -> Dictionary:
		return {"frequency":_values[kind + "_frequency"], "duration":_values[kind + "_duration"], "gain":_values[kind + "_gain"], "cooldown":_values[kind + "_cooldown"], "priority":_values[kind + "_priority"]}

var audio: Audio

func _init(document: Dictionary) -> void:
	presentation = Presentation.new(document.presentation)
	audio = Audio.new(document.audio)
	playtest = Playtest.new(document.playtest)
	simulation = Simulation.new(document.simulation)
	tower = Tower.new(document.tower)
	construction_ux = ConstructionUx.new(document.construction_ux)
	map_camera = MapCamera.new(document.map_camera)
	entropy = Entropy.new(document.entropy)
	fog = Fog.new(document.fog)
	frontend = Frontend.new(document.frontend)
	visuals = Visuals.new(document.visuals)
	diagnostics = Diagnostics.new(document.diagnostics)
