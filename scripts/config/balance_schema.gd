class_name BalanceSchema
extends RefCounted

const BalanceFieldCatalogType := preload("res://scripts/config/balance_field_catalog.gd")

const PresentationSchemaType := preload("res://scripts/config/presentation_schema.gd")
const CURRENT_VERSION := 11

const TOP_LEVEL_KEYS := [
	"schema_version", "simulation", "map_camera", "construction_ux", "tower",
	"entropy", "fog", "frontend", "visuals", "devices", "enemies", "waves", "levels", "diagnostics", "playtest", "presentation", "audio"
]

const SECTION_FIELDS := {
	"playtest": ["sample_interval_seconds","flush_interval_seconds","hold_ring_radius","hold_ring_width","endpoint_label_font_size","endpoint_label_offset","exit_arrow_length","enemy_hit_flash_seconds","enemy_hit_flash_color","consent_width","feedback_field_height"],
	"simulation": ["fixed_step_seconds", "max_substeps", "momentum_zero_epsilon", "projectile_radius", "wave_point_radius", "spatial_cell_size", "enemy_spatial_cell_size", "entity_spawn_clearance", "max_interactions_per_step", "random_seed", "render_snapshot_margin"],
	"map_camera": ["map_x", "map_y", "map_width", "map_height", "map_margin", "pan_speed", "min_zoom", "max_zoom", "zoom_step_base"],
	"construction_ux": ["radial_top_clearance", "radial_bottom_clearance", "radial_hold_seconds", "radial_radius", "radial_dead_zone", "radial_screen_margin", "device_pick_radius", "click_max_seconds", "gesture_tolerance", "rotation_center_dead_zone", "diode_initial_offset", "preview_alpha", "preview_line_width", "preview_direction_length", "preview_font_size", "action_button_width", "action_button_height", "action_inset", "damage_debug_amount", "dismantle_hold_seconds"],
	"tower": ["position_x", "position_y", "max_hp", "collision_radius", "light_radius", "fire_interval", "projectile_mass", "projectile_speed", "muzzle_offset"],
	"entropy": ["per_second", "per_interaction", "interaction_acceleration", "start_entropy", "full_effect_entropy", "uncertainty_curve", "max_angle_deviation_degrees", "max_speed_deviation_ratio", "max_mass_deviation_ratio", "max_diode_exit_offset", "max_diode_angle_deviation_degrees", "max_split_direction_deviation_degrees", "max_split_share_deviation_ratio", "max_enemy_target_score_deviation_ratio", "max_enemy_shield_position_offset", "visual_start_entropy", "visual_full_entropy"],
	"fog": ["grid_width", "grid_height", "edge_softness", "dark_red", "dark_green", "dark_blue", "maximum_alpha"],
	"frontend": ["tuning_min_height", "tuning_title_font_size", "tuning_field_label_width", "tuning_error_height", "tuning_inset_x", "tuning_inset_y", "content_width", "outer_margin", "title_font_size", "subtitle_font_size", "body_font_size", "card_height", "button_height", "item_gap", "pause_panel_width", "pause_panel_height", "tuning_columns_breakpoint", "tuning_label_width", "tuning_common_gap", "confirmation_width"],
	"visuals": ["tutorial_instruction_width", "tutorial_instruction_height", "tutorial_instruction_top_offset", "bar_background_color", "charge_color", "destruction_fill_alpha", "destruction_fill_color", "destruction_stroke_color", "destruction_stroke_width", "destroy_effect_end_radius", "destroy_effect_seconds", "destroy_effect_start_radius", "device_activation_bar_height", "device_bar_width", "device_cull_margin", "device_hit_flash_color", "device_hit_flash_seconds", "device_hp_bar_height", "diagnostic_target_color", "diode_teleport_pulse_color", "diode_teleport_pulse_end_radius", "diode_teleport_pulse_seconds", "diode_teleport_pulse_start_radius", "diode_teleport_pulse_width", "dismantle_progress_color", "dismantle_progress_width", "enemy_bar_height", "enemy_bar_width", "enemy_entropy_color", "enemy_fill_alpha", "grid_spacing", "healthy_hp_color", "hud_background_color", "hud_danger_color", "hud_muted_color", "hud_success_color", "hud_text_color", "hud_top_bar_height", "hud_warning_color", "inactive_device_color", "low_hp_color", "low_hp_flash_milliseconds", "low_hp_ratio", "map_border_color", "map_border_width", "projectile_base_diameter", "projectile_charge_blend_ratio", "projectile_charged_color", "projectile_entropy_extra_diameter", "projectile_high_entropy_color", "projectile_low_entropy_color", "selection_extra_radius", "selection_fill_alpha", "settlement_body_font_size", "settlement_button_font_size", "settlement_button_height", "settlement_button_width", "settlement_dim_alpha", "settlement_panel_border_width", "settlement_panel_height", "settlement_panel_width", "settlement_title_font_size", "target_reached_flash_alpha", "target_reached_flash_seconds", "tower_bar_height", "tower_bar_width", "tower_color", "tower_fill_color", "tracer_line_width", "tracer_seconds", "tutorial_cue_color", "tutorial_cue_pulse_seconds", "tutorial_path_color", "tutorial_path_width", "warning_high_threshold", "warning_low_threshold", "wave_point_color", "wave_point_diameter", "world_axis_color", "world_background_color", "world_grid_color"],
	"diagnostics": ["target_radius", "target_damage_per_momentum", "target_momentum_absorption", "target_x", "target_vertical_spacing", "target_count", "performance_enemy_count", "stress_enemy_count"],
}

const DEVICE_KINDS := ["bounce_plate", "speed_increaser", "mass_increaser", "splitter", "accumulator", "wave_converter", "magnetic_field", "electric_field", "diode"]
const DEVICE_COMMON_FIELDS := ["display_name", "short_name", "color", "activation_required", "max_hp", "light_radius", "activation_radius", "entropy_sensitivity"]
const DEVICE_EXTRA_FIELDS := {
	"bounce_plate": ["half_length"], "speed_increaser": ["speed_multiplier"],
	"mass_increaser": ["mass_multiplier"], "splitter": ["splitter_half_separation"],
	"accumulator": [], "wave_converter": ["wave_point_count", "wave_fan_degrees", "wave_speed", "reconstruction_mass", "reconstruction_speed"],
	"magnetic_field": ["field_radius", "magnetic_angular_speed", "shockwave_radius"],
	"electric_field": ["field_radius", "electric_acceleration"], "diode": [],
}
const ENEMY_KINDS := ["dev_melee", "dev_ranged", "tutorial_breaker", "tutorial_suppressor", "settings"]
const ENEMY_FIELDS := ["display_name", "color", "max_hp", "radius", "move_speed", "sense_radius", "attack_range", "attack_interval", "attack_damage", "ranged_charge_seconds", "momentum_absorption", "damage_per_momentum", "entropy_transfer_ratio", "entropy_decay_per_second", "aim_max_deviation_degrees", "threat_weight", "ranged"]
const ENEMY_SETTINGS_FIELDS := ["ranged_ray_extra_distance", "spawn_distribution_step", "spawn_edge_inset", "target_forward_dot_min", "target_refresh_seconds", "target_spatial_cell_size"]
const WAVE_FIELDS := ["display_name", "duration", "target_utilization", "finish_policy", "pressure_curve", "groups"]
const WAVE_GROUP_FIELDS := ["direction", "enemy", "count", "start_time", "end_time", "warning_lead", "spawn_region"]
const ENDLESS_FIELDS := [
	"base_target_utilization", "base_threat_budget", "damage_growth_per_wave", "damage_multiplier_cap",
	"display_name", "hp_growth_per_wave", "hp_multiplier_cap", "intermission_seconds",
	"max_active_enemy_guard", "opening_preparation_seconds", "pressure_curve", "ranged_share_cap",
	"ranged_share_growth_per_wave", "run_seed", "seed_mode", "spawn_end_ratio", "spawn_start_ratio",
	"speed_growth_per_wave", "speed_multiplier_cap", "target_growth_per_wave", "target_utilization_cap",
	"templates", "threat_budget_growth_per_wave", "warning_lead_seconds", "wave_duration_seconds",
]
const ENDLESS_TEMPLATE_FIELDS := [
	"budget_shares", "direction_offsets", "display_name", "force_wave", "id", "min_wave",
	"start_delay_ratios", "weight",
]
const DIODE_TUTORIAL_FIELDS := [
	"session_kind", "route_min_north_distance", "path_hint_length", "direction_hint_length",
	"display_name", "lesson_device", "observation_seconds", "marker_radius",
	"direction_tolerance_degrees", "practice_entry_x", "practice_entry_y",
	"practice_exit_x", "practice_exit_y", "route_entry_x", "route_entry_y",
	"route_exit_x", "route_exit_y", "route_exit_angle_degrees",
	"intermission_seconds", "waves", "feedback",
]


static func migrate(data: Dictionary) -> Dictionary:
	var raw_version = data.get("schema_version")
	if raw_version is not int and raw_version is not float:
		return {}
	if not is_finite(float(raw_version)) or float(raw_version) != floorf(float(raw_version)):
		return {}
	for section in TOP_LEVEL_KEYS:
		if section != "schema_version" and data.has(section) and data[section] is not Dictionary:
			return {}
	var migrated := data.duplicate(true)
	var version := int(migrated.get("schema_version", 0))
	if version == CURRENT_VERSION:
		return migrated
	if version == 1:
		migrated = _migrate_v1_to_v2(migrated)
		version = 2
	if version == 2:
		migrated = _migrate_v2_to_v3(migrated)
		version = 3
	if version == 3:
		migrated = _migrate_v3_to_v4(migrated)
		version = 4
	if version == 4:
		var frontend = migrated.get("frontend", null)
		if frontend is not Dictionary:
			return {}
		frontend["tuning_columns_breakpoint"] = 1100.0
		frontend["tuning_label_width"] = 200.0
		frontend["tuning_common_gap"] = 12.0
		frontend["confirmation_width"] = 520.0
		migrated["schema_version"] = 5
		version = 5
	if version == 5:
		if migrated.get("frontend") is not Dictionary:
			return {}
		migrated.frontend["tuning_min_height"] = 540.0
		migrated.frontend["tuning_title_font_size"] = 22.0
		migrated.frontend["tuning_field_label_width"] = 330.0
		migrated.frontend["tuning_error_height"] = 70.0
		migrated.frontend["tuning_inset_x"] = 80.0
		migrated.frontend["tuning_inset_y"] = 50.0
		if migrated.get("construction_ux") is not Dictionary:
			return {}
		migrated.construction_ux["radial_top_clearance"] = 68.0
		migrated.construction_ux["radial_bottom_clearance"] = 42.0
		if migrated.get("visuals") is not Dictionary:
			return {}
		migrated.visuals["tutorial_instruction_width"] = 660.0
		migrated.visuals["tutorial_instruction_height"] = 52.0
		migrated.visuals["tutorial_instruction_top_offset"] = 104.0
		if migrated.get("levels") is not Dictionary:
			return {}
		for level_id in migrated.levels:
			var level_config = migrated.levels[level_id]
			if level_config is not Dictionary or not level_config.has("marker_radius"):
				return {}
			level_config["session_kind"] = "tutorial_diode"
			level_config["route_min_north_distance"] = level_config.marker_radius
			level_config["path_hint_length"] = 900.0
			level_config["direction_hint_length"] = 90.0
		migrated["schema_version"] = 6
		version = 6
	if version == 6:
		if migrated.get("waves") is not Dictionary or migrated.get("levels") is not Dictionary:
			return {}
		var configured_waves: Array = [migrated.waves.get("dev_wave_01")]
		for level_config in migrated.levels.values():
			if level_config is not Dictionary or level_config.get("waves") is not Array:
				return {}
			if level_config.has("feedback"):
				return {}
			level_config["feedback"] = {"no_damage_seconds": 8.0, "confirmation_seconds": 3.0, "reminder_interval_seconds": 12.0}
			configured_waves.append_array(level_config.waves)
		for configured_wave in configured_waves:
			if configured_wave is not Dictionary or configured_wave.get("groups") is not Array:
				return {}
			for group in configured_wave.groups:
				if group is not Dictionary or group.has("spawn_region"):
					return {}
				group["spawn_region"] = {"mode": "full_edge", "center_ratio": 0.5, "half_width": 0.0}
		migrated["schema_version"] = 7
		version = 7
	if version == 7:
		if migrated.has("playtest"):
			return {}
		migrated["playtest"] = {"sample_interval_seconds":1,"flush_interval_seconds":5,"rotation_group_seconds":0.5,"hold_ring_radius":22,"hold_ring_width":3,"endpoint_label_font_size":16,"endpoint_label_offset":48,"exit_arrow_length":70,"enemy_hit_flash_seconds":0.14,"enemy_hit_flash_color":"fff4c2","consent_width":620,"feedback_field_height":72}
		migrated["schema_version"] = 8
		version = 8
	if version == 8:
		if migrated.has("presentation") or migrated.has("audio"):
			return {}
		migrated["presentation"] = PresentationSchemaType.defaults("presentation")
		migrated["audio"] = PresentationSchemaType.defaults("audio")
		migrated["schema_version"] = 9
		version = 9
	if version == 9:
		if migrated.get("construction_ux") is not Dictionary or migrated.get("playtest") is not Dictionary:
			return {}
		var input_defaults := {"move_hold_seconds":0.2,"gesture_tolerance":4,"rotation_center_dead_zone":12,"diode_initial_offset":96,"preview_alpha":0.65,"preview_line_width":2,"preview_direction_length":90,"preview_font_size":16,"action_button_width":112,"action_button_height":36,"action_inset":14}
		for key in input_defaults:
			if migrated.construction_ux.has(key):
				return {}
			migrated.construction_ux[key] = input_defaults[key]
		migrated.construction_ux.erase("rotation_step_degrees")
		migrated.playtest.erase("rotation_group_seconds")
		migrated["schema_version"] = 10
		version = 10
	if version == 10:
		var construction = migrated.get("construction_ux")
		if construction is not Dictionary or not construction.has("move_hold_seconds") or construction.has("click_max_seconds"):
			return {}
		construction["click_max_seconds"] = construction.move_hold_seconds
		construction.erase("move_hold_seconds")
		migrated["schema_version"] = 11
		version = 11
	if version != CURRENT_VERSION:
		return {}
	return migrated


static func _migrate_v1_to_v2(migrated: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = migrated.get("diagnostics", {})
	var refresh_seconds := float(diagnostics.get("enemy_ai_profile_interval", 0.2))
	diagnostics.erase("enemy_ai_profile_interval")
	migrated["diagnostics"] = diagnostics
	var enemies: Dictionary = migrated.get("enemies", {})
	var settings: Dictionary = enemies.get("settings", {})
	settings["target_refresh_seconds"] = refresh_seconds
	settings["target_spatial_cell_size"] = 256.0
	enemies["settings"] = settings
	migrated["enemies"] = enemies
	var waves: Dictionary = migrated.get("waves", {})
	waves["endless"] = _default_endless_config()
	migrated["waves"] = waves
	migrated["schema_version"] = 2
	return migrated


static func _migrate_v2_to_v3(migrated: Dictionary) -> Dictionary:
	var tower: Dictionary = migrated.get("tower", {})
	tower.erase("lane_count")
	tower.erase("lane_spacing")
	migrated["tower"] = tower
	var construction: Dictionary = migrated.get("construction_ux", {})
	construction["dismantle_hold_seconds"] = 0.6
	migrated["construction_ux"] = construction
	var enemies: Dictionary = migrated.get("enemies", {})
	enemies["tutorial_breaker"] = _default_tutorial_enemy("教学·破线者", "ff6078", false)
	enemies["tutorial_suppressor"] = _default_tutorial_enemy("教学·压制者", "ffb15d", true)
	migrated["enemies"] = enemies
	var visuals: Dictionary = migrated.get("visuals", {})
	visuals["dismantle_progress_color"] = "ffcf5c"
	visuals["dismantle_progress_width"] = 5.0
	visuals["diode_teleport_pulse_color"] = "65f4ff"
	visuals["diode_teleport_pulse_end_radius"] = 42.0
	visuals["diode_teleport_pulse_seconds"] = 0.32
	visuals["diode_teleport_pulse_start_radius"] = 14.0
	visuals["diode_teleport_pulse_width"] = 3.0
	visuals["tutorial_cue_color"] = "5ee6a8"
	visuals["tutorial_cue_pulse_seconds"] = 1.2
	visuals["tutorial_path_color"] = "79d7ff"
	visuals["tutorial_path_width"] = 2.0
	migrated["visuals"] = visuals
	migrated["levels"] = {"diode_tutorial": _default_diode_tutorial()}
	migrated["schema_version"] = 3
	return migrated


static func _migrate_v3_to_v4(migrated: Dictionary) -> Dictionary:
	migrated["frontend"] = _default_frontend_config()
	migrated["schema_version"] = 4
	return migrated


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in TOP_LEVEL_KEYS:
		if not data.has(key):
			errors.append("缺少字段：%s" % key)
	for key in data.keys():
		if not TOP_LEVEL_KEYS.has(String(key)):
			errors.append("未知顶层字段：%s" % key)
	if int(data.get("schema_version", 0)) != CURRENT_VERSION:
		errors.append("schema_version 必须为 %d" % CURRENT_VERSION)
	_validate_structure(data, errors)
	_validate_value(data, "", errors)
	_validate_leaf_types(data, "", errors)
	# Cross-field validators may assume typed, structurally complete containers.
	if not errors.is_empty():
		return errors
	_validate_catalog_ranges(data, "", errors)
	for field in data.audio:
		if not String(field).ends_with("_frequency"): continue
		var cue := String(field).trim_suffix("_frequency")
		var audio: Dictionary = data.audio
		if float(audio[cue + "_frequency"]) * float(audio.harmonic_multiple) >= float(audio.sample_rate) * 0.5:
			errors.append("audio/%s_frequency：泛音频率必须低于采样率一半" % cue)
		if float(audio.attack_seconds) >= float(audio[cue + "_duration"]):
			errors.append("audio/attack_seconds 必须短于 %s_duration" % cue)
	for path in BalanceFieldCatalogType.unregistered_leaf_paths(data):
		errors.append("字段未登记到数值面板 schema：%s" % path)
	for field in SECTION_FIELDS.playtest:
		if not String(field).ends_with("_color"):
			_require_positive(data, "playtest/%s" % field, errors)
	_require_positive(data, "simulation/fixed_step_seconds", errors)
	_require_positive(data, "simulation/max_substeps", errors)
	_require_positive(data, "simulation/projectile_radius", errors)
	_require_positive(data, "simulation/wave_point_radius", errors)
	_require_positive(data, "simulation/spatial_cell_size", errors)
	_require_positive(data, "simulation/enemy_spatial_cell_size", errors)
	_require_positive(data, "simulation/max_interactions_per_step", errors)
	_require_positive(data, "map_camera/map_width", errors)
	_require_positive(data, "map_camera/map_height", errors)
	_require_positive(data, "tower/max_hp", errors)
	_require_positive(data, "tower/collision_radius", errors)
	_require_positive(data, "tower/light_radius", errors)
	_require_positive(data, "tower/fire_interval", errors)
	_require_positive(data, "tower/projectile_mass", errors)
	_require_positive(data, "tower/projectile_speed", errors)
	_require_positive(data, "construction_ux/dismantle_hold_seconds", errors)
	for field in SECTION_FIELDS["frontend"]:
		_require_positive(data, "frontend/%s" % field, errors)
	_require_positive(data, "visuals/grid_spacing", errors)
	_require_positive(data, "visuals/map_border_width", errors)
	_require_positive(data, "visuals/destroy_effect_seconds", errors)
	_require_positive(data, "visuals/destruction_stroke_width", errors)
	_require_positive(data, "visuals/tower_bar_width", errors)
	_require_positive(data, "visuals/tower_bar_height", errors)
	_require_positive(data, "visuals/tracer_line_width", errors)
	_require_positive(data, "visuals/dismantle_progress_width", errors)
	_require_positive(data, "visuals/diode_teleport_pulse_end_radius", errors)
	_require_positive(data, "visuals/diode_teleport_pulse_seconds", errors)
	_require_positive(data, "visuals/diode_teleport_pulse_start_radius", errors)
	_require_positive(data, "visuals/diode_teleport_pulse_width", errors)
	if float(_path_value(data, "visuals/diode_teleport_pulse_start_radius", 0.0)) > float(_path_value(
			data, "visuals/diode_teleport_pulse_end_radius", 0.0
	)):
		errors.append("visuals/diode_teleport_pulse_start_radius 不能大于 end_radius")
	_require_positive(data, "visuals/tutorial_cue_pulse_seconds", errors)
	_require_positive(data, "visuals/tutorial_path_width", errors)
	_require_positive(data, "visuals/device_hit_flash_seconds", errors)
	_require_positive(data, "visuals/hud_top_bar_height", errors)
	_require_positive(data, "visuals/target_reached_flash_seconds", errors)
	_require_positive(data, "visuals/settlement_panel_width", errors)
	_require_positive(data, "visuals/settlement_panel_height", errors)
	_require_positive(data, "visuals/settlement_panel_border_width", errors)
	_require_positive(data, "visuals/settlement_button_width", errors)
	_require_positive(data, "visuals/settlement_button_height", errors)
	_require_positive(data, "visuals/settlement_title_font_size", errors)
	_require_positive(data, "visuals/settlement_body_font_size", errors)
	_require_positive(data, "visuals/settlement_button_font_size", errors)
	_require_positive(data, "fog/grid_width", errors)
	_require_positive(data, "fog/grid_height", errors)
	_require_positive(data, "construction_ux/radial_radius", errors)
	if float(_path_value(data, "map_camera/min_zoom", 0.0)) > float(_path_value(data, "map_camera/max_zoom", 0.0)):
		errors.append("map_camera/min_zoom 不能大于 max_zoom")
	if float(_path_value(data, "construction_ux/radial_dead_zone", 0.0)) >= float(_path_value(data, "construction_ux/radial_radius", 0.0)):
		errors.append("construction_ux/radial_dead_zone 必须小于 radial_radius")
	var start := float(_path_value(data, "entropy/start_entropy", 0.0))
	var full := float(_path_value(data, "entropy/full_effect_entropy", 0.0))
	if start < 0.0:
		errors.append("entropy/start_entropy 不能小于 0")
	if full <= start:
		errors.append("entropy/full_effect_entropy 必须大于 start_entropy")
	var visual_start := float(_path_value(data, "entropy/visual_start_entropy", 0.0))
	var visual_full := float(_path_value(data, "entropy/visual_full_entropy", 0.0))
	if visual_full <= visual_start:
		errors.append("entropy/visual_full_entropy 必须大于 visual_start_entropy")
	_require_range(data, "entropy/max_split_share_deviation_ratio", 0.0, 0.5, errors)
	_validate_monotone_curve(_path_value(data, "entropy/uncertainty_curve", []),
		"entropy/uncertainty_curve", true, errors)
	_validate_monotone_curve(_path_value(data, "waves/dev_wave_01/pressure_curve", []),
		"waves/dev_wave_01/pressure_curve", false, errors)
	_validate_monotone_curve(_path_value(data, "waves/endless/pressure_curve", []),
		"waves/endless/pressure_curve", false, errors)
	for kind in (data.get("devices", {}) as Dictionary).keys():
		_require_positive(data, "devices/%s/activation_required" % kind, errors)
		_require_positive(data, "devices/%s/max_hp" % kind, errors)
		_require_positive(data, "devices/%s/light_radius" % kind, errors)
		if float(_path_value(data, "devices/%s/activation_required" % kind, 0.0)) <= float(_path_value(data, "tower/projectile_mass", 0.0)) * float(_path_value(data, "tower/projectile_speed", 0.0)):
			errors.append("devices/%s/activation_required 必须大于单发塔弹丸动量" % kind)
	_require_positive(data, "devices/bounce_plate/half_length", errors)
	_require_positive(data, "devices/speed_increaser/speed_multiplier", errors)
	_require_positive(data, "devices/mass_increaser/mass_multiplier", errors)
	if float(_path_value(data, "devices/speed_increaser/speed_multiplier", 0.0)) <= 1.0:
		errors.append("devices/speed_increaser/speed_multiplier 必须大于 1")
	if float(_path_value(data, "devices/mass_increaser/mass_multiplier", 0.0)) <= 1.0:
		errors.append("devices/mass_increaser/mass_multiplier 必须大于 1")
	_require_positive(data, "devices/splitter/splitter_half_separation", errors)
	_require_positive(data, "devices/wave_converter/wave_point_count", errors)
	_require_positive(data, "devices/wave_converter/wave_speed", errors)
	_require_positive(data, "devices/wave_converter/reconstruction_mass", errors)
	_require_positive(data, "devices/wave_converter/reconstruction_speed", errors)
	_require_positive(data, "devices/magnetic_field/field_radius", errors)
	_require_positive(data, "devices/electric_field/field_radius", errors)
	for enemy_kind in (data.get("enemies", {}) as Dictionary).keys():
		if String(enemy_kind) == "settings":
			continue
		_require_positive(data, "enemies/%s/max_hp" % enemy_kind, errors)
		_require_range(data, "enemies/%s/momentum_absorption" % enemy_kind, 0.0, 1.0, errors)
		_require_range(data, "enemies/%s/entropy_transfer_ratio" % enemy_kind, 0.0, 1.0, errors)
		_require_positive(data, "enemies/%s/radius" % enemy_kind, errors)
		_require_positive(data, "enemies/%s/attack_interval" % enemy_kind, errors)
	_require_positive(data, "enemies/settings/target_refresh_seconds", errors)
	_require_positive(data, "enemies/settings/target_spatial_cell_size", errors)
	var spawn_inset := float(_path_value(data, "enemies/settings/spawn_edge_inset", 0.0))
	var minimum_map_extent := minf(float(_path_value(data, "map_camera/map_width", 0.0)), float(_path_value(data, "map_camera/map_height", 0.0)))
	if spawn_inset * 2.0 >= minimum_map_extent:
		errors.append("enemies/settings/spawn_edge_inset 必须小于地图短边的一半")
	if float(_path_value(data, "visuals/warning_low_threshold", 0.0)) >= float(_path_value(data, "visuals/warning_high_threshold", 0.0)):
		errors.append("visuals/warning_low_threshold 必须小于 warning_high_threshold")
	_validate_wave_values(data, errors)
	_validate_endless_values(data, errors)
	_validate_diode_tutorial_values(data, errors)
	return errors


static func _validate_catalog_ranges(value, path: String, errors: Array[String]) -> void:
	if value is Dictionary:
		for key in value.keys():
			_validate_catalog_ranges(value[key], _join(path, String(key)), errors)
		return
	if value is Array:
		for index in value.size():
			_validate_catalog_ranges(value[index], "%s/%d" % [path, index], errors)
		return
	if value is not int and value is not float:
		return
	var descriptor := BalanceFieldCatalogType.descriptor(path, value)
	if descriptor.is_empty():
		return
	var minimum := float(descriptor.get("minimum", -INF))
	var maximum := float(descriptor.get("maximum", INF))
	if float(value) < minimum or float(value) > maximum:
		errors.append("%s 必须位于 %s–%s" % [path, str(minimum), str(maximum)])


static func _validate_structure(data: Dictionary, errors: Array[String]) -> void:
	for section in PresentationSchemaType.FIELDS:
		_validate_exact_keys(data.get(section), section, PresentationSchemaType.FIELDS[section].keys(), errors)
	for section_name in SECTION_FIELDS.keys():
		_validate_exact_keys(data.get(section_name, null), String(section_name), SECTION_FIELDS[section_name], errors)
	var devices_value = data.get("devices", null)
	_validate_exact_keys(devices_value, "devices", DEVICE_KINDS, errors)
	if devices_value is Dictionary:
		for kind in DEVICE_KINDS:
			var fields: Array = DEVICE_COMMON_FIELDS + (DEVICE_EXTRA_FIELDS[kind] as Array)
			_validate_exact_keys(devices_value.get(kind, null), "devices/%s" % kind, fields, errors)
	var enemies_value = data.get("enemies", null)
	_validate_exact_keys(enemies_value, "enemies", ENEMY_KINDS, errors)
	if enemies_value is Dictionary:
		for kind in ENEMY_KINDS:
			if kind == "settings":
				continue
			_validate_exact_keys(enemies_value.get(kind, null), "enemies/%s" % kind, ENEMY_FIELDS, errors)
		_validate_exact_keys(enemies_value.get("settings", null), "enemies/settings", ENEMY_SETTINGS_FIELDS, errors)
	var waves_value = data.get("waves", null)
	_validate_exact_keys(waves_value, "waves", ["dev_wave_01", "endless"], errors)
	if waves_value is Dictionary:
		var wave_value = waves_value.get("dev_wave_01", null)
		_validate_exact_keys(wave_value, "waves/dev_wave_01", WAVE_FIELDS, errors)
		if wave_value is Dictionary:
			var groups_value = wave_value.get("groups", null)
			if groups_value is not Array or groups_value.is_empty():
				errors.append("waves/dev_wave_01/groups 至少需要一个生成组")
			elif groups_value is Array:
				for index in groups_value.size():
					_validate_group_structure(groups_value[index], "waves/dev_wave_01/groups/%d" % index, errors)
		var endless_value = waves_value.get("endless", null)
		_validate_exact_keys(endless_value, "waves/endless", ENDLESS_FIELDS, errors)
		if endless_value is Dictionary:
			var templates_value = endless_value.get("templates", null)
			if templates_value is not Array or templates_value.is_empty():
				errors.append("waves/endless/templates 至少需要一个方向模板")
			elif templates_value is Array:
				for index in templates_value.size():
					_validate_exact_keys(templates_value[index], "waves/endless/templates/%d" % index, ENDLESS_TEMPLATE_FIELDS, errors)
	var levels_value = data.get("levels", null)
	if levels_value is not Dictionary or levels_value.is_empty():
		errors.append("levels 必须是非空关卡配置对象")
	if levels_value is Dictionary:
		for level_id in levels_value:
			if not String(level_id).is_valid_identifier():
				errors.append("levels/%s 必须使用稳定配置标识，不允许路径分隔符" % level_id)
			_validate_tutorial_structure(levels_value[level_id], "levels/%s" % level_id, errors)


static func _validate_tutorial_structure(tutorial_value, base: String, errors: Array[String]) -> void:
	if tutorial_value is Dictionary and tutorial_value.get("session_kind") != "tutorial_diode":
		errors.append("%s/session_kind 未支持的关卡配置类型" % base)
	_validate_exact_keys(tutorial_value, base, DIODE_TUTORIAL_FIELDS, errors)
	if tutorial_value is Dictionary:
		_validate_exact_keys(tutorial_value.get("feedback"), base + "/feedback", ["no_damage_seconds", "confirmation_seconds", "reminder_interval_seconds"], errors)
		var tutorial_waves = tutorial_value.get("waves", null)
		if tutorial_waves is not Array or tutorial_waves.size() != 2:
			errors.append("%s/waves 必须包含两个教学波次" % base)
		elif tutorial_waves is Array:
			for wave_index in tutorial_waves.size():
				var wave_path := "%s/waves/%d" % [base, wave_index]
				_validate_exact_keys(tutorial_waves[wave_index], wave_path, WAVE_FIELDS, errors)
				if tutorial_waves[wave_index] is Dictionary:
					var groups = tutorial_waves[wave_index].get("groups", null)
					if groups is not Array or groups.is_empty():
						errors.append("%s/groups 至少需要一个生成组" % wave_path)
					elif groups is Array:
						for group_index in groups.size():
							_validate_group_structure(groups[group_index], "%s/groups/%d" % [wave_path, group_index], errors)


static func _validate_wave_values(data: Dictionary, errors: Array[String]) -> void:
	var wave = _path_value(data, "waves/dev_wave_01", null)
	if wave is not Dictionary:
		return
	_require_positive(data, "waves/dev_wave_01/duration", errors)
	if String(wave.get("finish_policy", "")) != "immediate":
		errors.append("waves/dev_wave_01/finish_policy 当前只支持 immediate")
	var groups = wave.get("groups", [])
	if groups is not Array:
		return
	var duration := float(wave.get("duration", 0.0))
	for index in groups.size():
		var group = groups[index]
		if group is not Dictionary:
			continue
		var path := "waves/dev_wave_01/groups/%d" % index
		_require_positive(data, "%s/count" % path, errors)
		_validate_spawn_region(data, group, path, errors)
		var start_time := float(group.get("start_time", -1.0))
		var end_time := float(group.get("end_time", -1.0))
		if start_time < 0.0 or end_time < start_time or end_time > duration:
			errors.append("%s 的时间必须满足 0 ≤ start_time ≤ end_time ≤ duration" % path)
		if String(group.get("direction", "")) not in ["east", "south", "west", "north"]:
			errors.append("%s/direction 无效" % path)
		if String(group.get("enemy", "")) not in ["dev_melee", "dev_ranged"]:
			errors.append("%s/enemy 无效" % path)


static func _validate_endless_values(data: Dictionary, errors: Array[String]) -> void:
	var base := "waves/endless"
	var endless = _path_value(data, base, null)
	if endless is not Dictionary:
		return
	for leaf in [
		"base_threat_budget", "intermission_seconds", "max_active_enemy_guard",
		"opening_preparation_seconds", "run_seed", "wave_duration_seconds",
	]:
		_require_positive(data, "%s/%s" % [base, leaf], errors)
	for leaf in [
		"damage_growth_per_wave", "hp_growth_per_wave", "ranged_share_growth_per_wave",
		"speed_growth_per_wave", "target_growth_per_wave", "threat_budget_growth_per_wave",
	]:
		_require_range(data, "%s/%s" % [base, leaf], 0.0, 1000000.0, errors)
	for leaf in ["base_target_utilization", "target_utilization_cap", "ranged_share_cap", "spawn_start_ratio", "spawn_end_ratio"]:
		_require_range(data, "%s/%s" % [base, leaf], 0.0, 1.0, errors)
	for leaf in ["damage_multiplier_cap", "hp_multiplier_cap", "speed_multiplier_cap"]:
		if float(_path_value(data, "%s/%s" % [base, leaf], 0.0)) < 1.0:
			errors.append("%s/%s 不能小于 1" % [base, leaf])
	if float(endless.get("base_target_utilization", 0.0)) > float(endless.get("target_utilization_cap", 0.0)):
		errors.append("waves/endless/base_target_utilization 不能大于 target_utilization_cap")
	if float(endless.get("spawn_start_ratio", 0.0)) > float(endless.get("spawn_end_ratio", 0.0)):
		errors.append("waves/endless/spawn_start_ratio 不能大于 spawn_end_ratio")
	if String(endless.get("seed_mode", "")) not in ["fixed", "random_each_run"]:
		errors.append("waves/endless/seed_mode 无效")
	var templates = endless.get("templates", [])
	if templates is not Array:
		return
	var ids: Dictionary = {}
	var forced_waves: Dictionary = {}
	for index in templates.size():
		var template = templates[index]
		if template is not Dictionary:
			continue
		var path := "%s/templates/%d" % [base, index]
		var template_id := String(template.get("id", "")).strip_edges()
		if template_id.is_empty() or ids.has(template_id):
			errors.append("%s/id 必须非空且唯一" % path)
		ids[template_id] = true
		var min_wave := int(template.get("min_wave", 0))
		var force_wave := int(template.get("force_wave", 0))
		if min_wave < 1 or force_wave < min_wave:
			errors.append("%s 必须满足 1 ≤ min_wave ≤ force_wave" % path)
		if forced_waves.has(force_wave):
			errors.append("%s/force_wave 必须唯一" % path)
		forced_waves[force_wave] = true
		if float(template.get("weight", 0.0)) <= 0.0:
			errors.append("%s/weight 必须大于 0" % path)
		var offsets = template.get("direction_offsets", [])
		var shares = template.get("budget_shares", [])
		var delays = template.get("start_delay_ratios", [])
		if offsets is not Array or offsets.is_empty() or shares is not Array or delays is not Array \
				or offsets.size() != shares.size() or offsets.size() != delays.size():
			errors.append("%s 的方向、预算份额和错峰数组必须非空且等长" % path)
			continue
		var seen_offsets: Dictionary = {}
		var share_total := 0.0
		for lane in offsets.size():
			var offset := int(offsets[lane])
			if offset < 0 or offset > 3 or seen_offsets.has(offset):
				errors.append("%s/direction_offsets 必须是互不重复的 0–3" % path)
			seen_offsets[offset] = true
			var share := float(shares[lane])
			var delay := float(delays[lane])
			if share <= 0.0:
				errors.append("%s/budget_shares 必须全部大于 0" % path)
			if delay < 0.0 or delay + float(endless.get("spawn_start_ratio", 0.0)) > float(endless.get("spawn_end_ratio", 1.0)):
				errors.append("%s/start_delay_ratios 超出生成时间窗口" % path)
			share_total += share
		if not is_equal_approx(share_total, 1.0):
			errors.append("%s/budget_shares 之和必须为 1" % path)


static func _validate_diode_tutorial_values(data: Dictionary, errors: Array[String]) -> void:
	var levels = data.get("levels", {})
	if levels is Dictionary:
		for level_id in levels:
			_validate_tutorial_values(data, "levels/%s" % level_id, errors)


static func _validate_tutorial_values(data: Dictionary, base: String, errors: Array[String]) -> void:
	var tutorial = _path_value(data, base, null)
	if tutorial is not Dictionary:
		return
	if String(tutorial.get("lesson_device", "")) != "diode":
		errors.append("%s/lesson_device 必须为 diode" % base)
	for leaf in ["observation_seconds", "marker_radius", "route_min_north_distance", "path_hint_length", "direction_hint_length", "direction_tolerance_degrees", "intermission_seconds"]:
		_require_positive(data, "%s/%s" % [base, leaf], errors)
	for leaf in ["no_damage_seconds", "confirmation_seconds", "reminder_interval_seconds"]:
		_require_positive(data, "%s/feedback/%s" % [base, leaf], errors)
	var tutorial_waves = tutorial.get("waves", [])
	if tutorial_waves is not Array:
		return
	for wave_index in tutorial_waves.size():
		var wave = tutorial_waves[wave_index]
		if wave is not Dictionary:
			continue
		var path := "%s/waves/%d" % [base, wave_index]
		_require_positive(data, "%s/duration" % path, errors)
		_require_range(data, "%s/target_utilization" % path, 0.0, 1.0, errors)
		if String(wave.get("finish_policy", "")) != "clear":
			errors.append("%s/finish_policy 必须为 clear" % path)
		_validate_monotone_curve(wave.get("pressure_curve", []), "%s/pressure_curve" % path, false, errors)
		var groups = wave.get("groups", [])
		if groups is not Array:
			continue
		for group_index in groups.size():
			var group = groups[group_index]
			if group is not Dictionary:
				continue
			var group_path := "%s/groups/%d" % [path, group_index]
			_require_positive(data, "%s/count" % group_path, errors)
			_validate_spawn_region(data, group, group_path, errors)
			var start_time := float(group.get("start_time", -1.0))
			var end_time := float(group.get("end_time", -1.0))
			if start_time < 0.0 or end_time < start_time or end_time > float(wave.get("duration", 0.0)):
				errors.append("%s 的时间必须满足 0 ≤ start_time ≤ end_time ≤ duration" % group_path)
			if String(group.get("direction", "")) not in ["east", "south", "west", "north"]:
				errors.append("%s/direction 无效" % group_path)
			if String(group.get("enemy", "")) not in ["tutorial_breaker", "tutorial_suppressor"]:
				errors.append("%s/enemy 必须使用教学敌人" % group_path)


static func _validate_exact_keys(value, path: String, expected_keys: Array, errors: Array[String]) -> void:
	if value is not Dictionary:
		errors.append("%s 必须是对象" % path)
		return
	var dictionary: Dictionary = value
	for key in expected_keys:
		if not dictionary.has(key):
			errors.append("缺少字段：%s/%s" % [path, key])
	for key in dictionary.keys():
		if not expected_keys.has(String(key)):
			errors.append("未知字段：%s/%s" % [path, key])


static func _validate_leaf_types(value, path: String, errors: Array[String]) -> void:
	if value is Dictionary:
		for key in value.keys():
			_validate_leaf_types(value[key], _join(path, String(key)), errors)
		return
	if value is Array:
		for index in value.size():
			_validate_leaf_types(value[index], "%s/%d" % [path, index], errors)
		return
	var leaf := path.get_file()
	var field_type := BalanceFieldCatalogType.field_type(path)
	var string_field := field_type == TYPE_STRING
	if string_field and value is not String:
		errors.append("%s 必须是字符串" % path)
	elif string_field and (leaf == "color" or leaf.ends_with("_color")) and not Color.html_is_valid(String(value)):
		errors.append("%s 必须是合法 HTML 颜色" % path)
	elif field_type == TYPE_BOOL and value is not bool:
		errors.append("%s 必须是布尔值" % path)
	elif not string_field and field_type != TYPE_BOOL and not (value is int or value is float):
		errors.append("%s 必须是数值" % path)


static func sample_curve(points_value, x: float) -> float:
	if points_value is not Array or points_value.is_empty():
		return clampf(x, 0.0, 1.0)
	var points: Array = points_value
	var clamped_x := clampf(x, 0.0, 1.0)
	var previous: Dictionary = points[0]
	if clamped_x <= float(previous.get("x", 0.0)):
		return float(previous.get("y", 0.0))
	for index in range(1, points.size()):
		var current: Dictionary = points[index]
		var current_x := float(current.get("x", 1.0))
		if clamped_x <= current_x:
			var previous_x := float(previous.get("x", 0.0))
			var ratio := (clamped_x - previous_x) / maxf(current_x - previous_x, 0.000001)
			return lerpf(float(previous.get("y", 0.0)), float(current.get("y", 1.0)), ratio)
		previous = current
	return float(previous.get("y", 1.0))


static func _validate_value(value, path: String, errors: Array[String]) -> void:
	if value is float and not is_finite(value):
		errors.append("%s 不是有限数值" % path)
	elif value is Dictionary:
		for key in value.keys():
			_validate_value(value[key], _join(path, String(key)), errors)
	elif value is Array:
		for index in value.size():
			_validate_value(value[index], "%s/%d" % [path, index], errors)


static func _validate_monotone_curve(value, path: String, normalized: bool, errors: Array[String]) -> void:
	if value is not Array or value.size() < 2:
		errors.append("%s 至少需要两个点" % path)
		return
	var previous_x := -INF
	var previous_y := -INF
	for index in value.size():
		if value[index] is not Dictionary:
			errors.append("%s/%d 必须是曲线点" % [path, index])
			continue
		var point: Dictionary = value[index]
		var x := float(point.get("x", NAN))
		var y := float(point.get("y", NAN))
		if not is_finite(x) or not is_finite(y) or x < previous_x or y < previous_y:
			errors.append("%s 必须按 x、y 单调不下降" % path)
			break
		previous_x = x
		previous_y = y
	if normalized:
		var first: Dictionary = value[0]
		var last: Dictionary = value[-1]
		if not is_equal_approx(float(first.get("x", -1.0)), 0.0) or not is_equal_approx(float(first.get("y", -1.0)), 0.0):
			errors.append("%s 起点必须为 (0, 0)" % path)
		if not is_equal_approx(float(last.get("x", -1.0)), 1.0) or not is_equal_approx(float(last.get("y", -1.0)), 1.0):
			errors.append("%s 终点必须为 (1, 1)" % path)


static func _require_positive(data: Dictionary, path: String, errors: Array[String]) -> void:
	var found = _path_value(data, path, null)
	if found == null or not (found is int or found is float) or float(found) <= 0.0:
		errors.append("%s 必须大于 0" % path)


static func _require_range(data: Dictionary, path: String, minimum: float, maximum: float, errors: Array[String]) -> void:
	var found = _path_value(data, path, null)
	if found == null or not (found is int or found is float) or float(found) < minimum or float(found) > maximum:
		errors.append("%s 必须位于 %.3f–%.3f" % [path, minimum, maximum])


static func _path_value(data: Dictionary, path: String, fallback):
	var cursor = data
	for part in path.split("/"):
		if cursor is Dictionary and cursor.has(part):
			cursor = cursor[part]
		elif cursor is Array and part.is_valid_int() and part.to_int() >= 0 and part.to_int() < cursor.size():
			cursor = cursor[part.to_int()]
		else:
			return fallback
	return cursor


static func _join(base: String, key: String) -> String:
	return key if base.is_empty() else "%s/%s" % [base, key]


static func _default_endless_config() -> Dictionary:
	return {
		"base_target_utilization": 0.15,
		"base_threat_budget": 18.0,
		"damage_growth_per_wave": 0.02,
		"damage_multiplier_cap": 2.0,
		"display_name": "DEV 无尽模式",
		"hp_growth_per_wave": 0.03,
		"hp_multiplier_cap": 2.5,
		"intermission_seconds": 15.0,
		"max_active_enemy_guard": 1000,
		"opening_preparation_seconds": 20.0,
		"pressure_curve": [
			{"x": 0.0, "y": 1.0}, {"x": 0.33, "y": 1.0},
			{"x": 0.34, "y": 1.35}, {"x": 0.67, "y": 1.35},
			{"x": 0.68, "y": 1.75}, {"x": 1.0, "y": 1.75},
		],
		"ranged_share_cap": 0.45,
		"ranged_share_growth_per_wave": 0.08,
		"run_seed": 20260901,
		"seed_mode": "fixed",
		"spawn_end_ratio": 0.75,
		"spawn_start_ratio": 0.1,
		"speed_growth_per_wave": 0.005,
		"speed_multiplier_cap": 1.25,
		"target_growth_per_wave": 0.015,
		"target_utilization_cap": 0.6,
		"templates": [
			_endless_template("single_front", "单方向", 1, 1, 1.0, [0], [1.0], [0.0]),
			_endless_template("adjacent_split", "相邻双方向", 2, 2, 1.0, [0, 1], [0.65, 0.35], [0.0, 0.12]),
			_endless_template("opposite_pincer", "对向夹击", 3, 3, 1.0, [0, 2], [0.55, 0.45], [0.0, 0.0]),
			_endless_template("three_front_staggered", "三方向错峰", 5, 5, 0.8, [0, 1, 3], [0.5, 0.3, 0.2], [0.0, 0.12, 0.24]),
			_endless_template("four_front_pressure", "四方向压力", 8, 8, 0.6, [0, 1, 2, 3], [0.4, 0.25, 0.2, 0.15], [0.0, 0.08, 0.16, 0.24]),
		],
		"threat_budget_growth_per_wave": 4.0,
		"warning_lead_seconds": 8.0,
		"wave_duration_seconds": 90.0,
	}


static func _default_frontend_config() -> Dictionary:
	return {
		"body_font_size": 18,
		"button_height": 52.0,
		"card_height": 96.0,
		"content_width": 760.0,
		"item_gap": 12.0,
		"outer_margin": 48.0,
		"pause_panel_height": 360.0,
		"pause_panel_width": 520.0,
		"subtitle_font_size": 20,
		"title_font_size": 48,
	}


static func _endless_template(
		id: String,
		display_name: String,
		min_wave: int,
		force_wave: int,
		weight: float,
		direction_offsets: Array,
		budget_shares: Array,
		start_delay_ratios: Array
) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"min_wave": min_wave,
		"force_wave": force_wave,
		"weight": weight,
		"direction_offsets": direction_offsets,
		"budget_shares": budget_shares,
		"start_delay_ratios": start_delay_ratios,
	}


static func _default_tutorial_enemy(display_name: String, color: String, ranged: bool) -> Dictionary:
	return {
		"display_name": display_name,
		"color": color,
		"max_hp": 44.0 if ranged else 64.0,
		"radius": 16.0 if ranged else 18.0,
		"move_speed": 54.0 if ranged else 68.0,
		"sense_radius": 460.0 if ranged else 240.0,
		"attack_range": 340.0 if ranged else 40.0,
		"attack_interval": 1.5 if ranged else 1.05,
		"attack_damage": 8.0 if ranged else 11.0,
		"ranged_charge_seconds": 0.65 if ranged else 0.0,
		"momentum_absorption": 0.25 if ranged else 0.35,
		"damage_per_momentum": 1.0,
		"entropy_transfer_ratio": 0.5,
		"entropy_decay_per_second": 0.0,
		"aim_max_deviation_degrees": 18.0 if ranged else 0.0,
		"threat_weight": 1.4 if ranged else 1.0,
		"ranged": ranged,
	}


static func _default_diode_tutorial() -> Dictionary:
	return {
		"display_name": "第一关：改写路径",
		"lesson_device": "diode",
		"observation_seconds": 3.0,
		"marker_radius": 34.0,
		"direction_tolerance_degrees": 20.0,
		"practice_entry_x": 120.0,
		"practice_entry_y": 120.0,
		"practice_exit_x": 240.0,
		"practice_exit_y": 120.0,
		"route_entry_x": 180.0,
		"route_entry_y": 0.0,
		"route_exit_x": 180.0,
		"route_exit_y": -180.0,
		"route_exit_angle_degrees": -90.0,
		"intermission_seconds": 20.0,
		"waves": [
			{
				"display_name": "北侧破线",
				"duration": 75.0,
				"target_utilization": 0.1,
				"finish_policy": "clear",
				"pressure_curve": [{"x": 0.0, "y": 1.0}, {"x": 1.0, "y": 1.35}],
				"groups": [{
					"direction": "north", "enemy": "tutorial_breaker", "count": 8,
					"start_time": 8.0, "end_time": 58.0, "warning_lead": 8.0,
				}],
			},
			{
				"display_name": "北侧压制",
				"duration": 120.0,
				"target_utilization": 0.18,
				"finish_policy": "clear",
				"pressure_curve": [{"x": 0.0, "y": 1.0}, {"x": 0.65, "y": 1.2}, {"x": 1.0, "y": 1.55}],
				"groups": [
					{"direction": "north", "enemy": "tutorial_breaker", "count": 6, "start_time": 8.0, "end_time": 88.0, "warning_lead": 8.0},
					{"direction": "north", "enemy": "tutorial_suppressor", "count": 5, "start_time": 26.0, "end_time": 100.0, "warning_lead": 10.0},
				],
			},
		],
	}

static func _validate_group_structure(group, path: String, errors: Array[String]) -> void:
	_validate_exact_keys(group, path, WAVE_GROUP_FIELDS, errors)
	if group is Dictionary:
		_validate_exact_keys(group.get("spawn_region"), path + "/spawn_region", ["mode", "center_ratio", "half_width"], errors)


static func _validate_spawn_region(data: Dictionary, group: Dictionary, path: String, errors: Array[String]) -> void:
	var region := SpawnRegion.from_spec(group.spawn_region)
	var map: Dictionary = data.map_camera
	var rect := Rect2(float(map.map_x), float(map.map_y), float(map.map_width), float(map.map_height))
	if region == null or not region.fits(rect, float(data.enemies.settings.spawn_edge_inset), StringName(group.direction)):
		errors.append(path + "/spawn_region 出生区段无效或超出边缘范围")
