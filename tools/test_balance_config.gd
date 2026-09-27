extends Node

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const BalancePanelType := preload("res://scripts/config/balance_panel.gd")
const BalanceFieldCatalogType := preload("res://scripts/config/balance_field_catalog.gd")
const BalanceSchemaType := preload("res://scripts/config/balance_schema.gd")
const BalanceRuntimeOverlayType := preload("res://scripts/config/balance_runtime_overlay.gd")

var _failed := false

class MemorySaveService extends RefCounted:
	func save(_profile: BalanceProfile) -> Array[String]:
		return []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	var profile := BalanceRepositoryType.load_profile()
	_check(profile != null, "balance.json must load")
	if profile == null:
		get_tree().quit(1)
		return
	_check(profile.validate().is_empty(), "project balance profile must validate")
	_check(int(profile.value("schema_version", 0)) == 11, "project balance profile must use schema v11")
	_check(BalanceFieldCatalogType.unregistered_leaf_paths(profile.data).is_empty(),
			"every balance leaf must be registered in the visual schema")
	var version_four := profile.data.duplicate(true)
	preload("res://tools/input_test_driver.gd").legacy_input(version_four)
	version_four.erase("playtest")
	version_four.erase("presentation")
	version_four.erase("audio")
	version_four.levels.diode_tutorial.erase("feedback")
	for group in version_four.waves.dev_wave_01.groups:
		group.erase("spawn_region")
	for wave in version_four.levels.diode_tutorial.waves:
		for group in wave.groups:
			group.erase("spawn_region")
	version_four.schema_version = 4
	for field in ["tuning_columns_breakpoint", "tuning_label_width", "tuning_common_gap", "confirmation_width"]:
		version_four.frontend.erase(field)
	var migrated_v4 := BalanceSchemaType.migrate(version_four)
	_check(BalanceSchemaType.validate(migrated_v4).is_empty() and int(version_four.schema_version) == 4,
		"v4 migration must validate as v8 without modifying the input")
	var version_three := version_four.duplicate(true)
	version_three.schema_version = 3
	version_three.erase("frontend")
	var migrated_v3 := BalanceSchemaType.migrate(version_three)
	_check(int(migrated_v3.get("schema_version", 0)) == 11 and migrated_v3.has("frontend"),
			"schema v3 must transactionally migrate the frontend tuning section")
	_check(BalanceSchemaType.validate(migrated_v3).is_empty(), "migrated schema v3 data must validate as v8")
	var version_two := version_four.duplicate(true)
	version_two.schema_version = 2
	version_two.erase("frontend")
	version_two.erase("levels")
	version_two.construction_ux.erase("dismantle_hold_seconds")
	version_two.tower.lane_count = 3
	version_two.tower.lane_spacing = 5.0
	version_two.enemies.erase("tutorial_breaker")
	version_two.enemies.erase("tutorial_suppressor")
	for visual_field in ["dismantle_progress_color", "dismantle_progress_width", "tutorial_cue_color", "tutorial_cue_pulse_seconds", "tutorial_path_color", "tutorial_path_width", "diode_teleport_pulse_color", "diode_teleport_pulse_end_radius", "diode_teleport_pulse_seconds", "diode_teleport_pulse_start_radius", "diode_teleport_pulse_width"]:
		version_two.visuals.erase(visual_field)
	var migrated_v2 := BalanceSchemaType.migrate(version_two)
	_check(int(migrated_v2.get("schema_version", 0)) == 11 and migrated_v2.has("levels") and migrated_v2.has("frontend")
			and not migrated_v2.tower.has("lane_count") and not migrated_v2.tower.has("lane_spacing")
			and migrated_v2.enemies.has("tutorial_breaker") and migrated_v2.enemies.has("tutorial_suppressor"),
			"schema v2 must migrate through v8 and remove obsolete tower lanes")
	_check(BalanceSchemaType.validate(migrated_v2).is_empty(), "migrated schema v2 data must validate as v8")
	var legacy := version_two.duplicate(true)
	legacy.schema_version = 1
	legacy.waves.erase("endless")
	legacy.diagnostics.enemy_ai_profile_interval = legacy.enemies.settings.target_refresh_seconds
	legacy.enemies.settings.erase("target_refresh_seconds")
	var migrated := BalanceSchemaType.migrate(legacy)
	_check(int(migrated.get("schema_version", 0)) == 11 and migrated.waves.has("endless") and migrated.has("frontend")
			and is_equal_approx(float(migrated.enemies.settings.target_refresh_seconds), 0.2),
			"schema v1 must migrate through v8 without losing the AI refresh value")
	_check(BalanceSchemaType.validate(migrated).is_empty(), "migrated schema v1 data must validate as v8")
	for entropy_value in [0.0, 49.999, 50.0]:
		_check(profile.entropy_weight(entropy_value) == 0.0,
				"entropy at or below the threshold must have exactly zero mechanical weight")
	var previous := profile.entropy_weight(50.0)
	for entropy_value in [50.001, 62.5, 75.0, 99.999, 100.0, 1000.0]:
		var weight := profile.entropy_weight(entropy_value)
		_check(weight >= previous and weight >= 0.0 and weight <= 1.0,
				"entropy uncertainty must be monotone and clamped")
		previous = weight
	_check(profile.entropy_weight(50.001) > 0.0, "entropy above the threshold must start uncertainty")
	_check(profile.entropy_weight(100.0) == 1.0 and profile.entropy_weight(1000.0) == 1.0,
			"entropy at and above saturation must have weight one")

	var working := profile.duplicate_profile()
	working.set_value("simulation/fixed_step_seconds", 0.01)
	_check(not is_equal_approx(float(profile.value("simulation/fixed_step_seconds")), 0.01),
			"editing a working copy must not mutate the active baseline")
	var invalid_unknown := profile.duplicate_profile()
	invalid_unknown.data.simulation["unregistered_knob"] = 1.0
	_check(not invalid_unknown.validate().is_empty(), "unknown nested fields must be rejected")
	var invalid_obsolete_lane := profile.duplicate_profile()
	invalid_obsolete_lane.data.tower.lane_count = 3
	_check(not invalid_obsolete_lane.validate().is_empty(), "obsolete parallel tower lanes must be rejected by schema v8")
	var invalid_frontend := profile.duplicate_profile()
	invalid_frontend.data.frontend.pause_panel_width = 0.0
	_check(not invalid_frontend.validate().is_empty(), "frontend tuning values must remain positive")
	var invalid_missing := profile.duplicate_profile()
	invalid_missing.data.tower.erase("projectile_mass")
	_check(not invalid_missing.validate().is_empty(), "missing nested fields must be rejected")
	var invalid_type := profile.duplicate_profile()
	invalid_type.data.entropy.start_entropy = "50"
	_check(not invalid_type.validate().is_empty(), "incorrect field types must be rejected")
	var invalid_curve := profile.duplicate_profile()
	invalid_curve.data.entropy.uncertainty_curve = [{"x": 0.0, "y": 0.0}, {"x": 0.7, "y": 0.8}, {"x": 1.0, "y": 0.7}]
	_check(not invalid_curve.validate().is_empty(), "decreasing uncertainty curves must be rejected")
	var invalid_range := profile.duplicate_profile()
	invalid_range.data.enemies.dev_melee.momentum_absorption = 1.1
	_check(not invalid_range.validate().is_empty(), "out-of-range values must be rejected")
	var invalid_color := profile.duplicate_profile()
	invalid_color.data.visuals.world_background_color = "not-a-color"
	_check(not invalid_color.validate().is_empty(), "invalid visual colors must be rejected")
	var invalid_forward_dot := profile.duplicate_profile()
	invalid_forward_dot.data.enemies.settings.target_forward_dot_min = 1.1
	_check(not invalid_forward_dot.validate().is_empty(), "enemy shared settings must respect panel ranges")
	var invalid_radial_geometry := profile.duplicate_profile()
	invalid_radial_geometry.data.construction_ux.radial_dead_zone = invalid_radial_geometry.data.construction_ux.radial_radius
	_check(not invalid_radial_geometry.validate().is_empty(), "radial menu dead zone must remain inside its radius")
	var invalid_teleport_pulse := profile.duplicate_profile()
	invalid_teleport_pulse.data.visuals.diode_teleport_pulse_start_radius = \
		invalid_teleport_pulse.data.visuals.diode_teleport_pulse_end_radius + 1.0
	_check(not invalid_teleport_pulse.validate().is_empty(),
			"diode teleport pulse geometry must expand from its configured start radius")
	var invalid_wave_timing := profile.duplicate_profile()
	invalid_wave_timing.data.waves.dev_wave_01.groups[0].start_time = invalid_wave_timing.data.waves.dev_wave_01.duration + 1.0
	_check(not invalid_wave_timing.validate().is_empty(), "wave groups outside the wave duration must be rejected")
	var invalid_tutorial_enemy := profile.duplicate_profile()
	invalid_tutorial_enemy.data.levels.diode_tutorial.waves[0].groups[0].enemy = "dev_melee"
	_check(not invalid_tutorial_enemy.validate().is_empty(), "tutorial waves must use registered tutorial enemies")

	var service := get_tree().root.get_node_or_null("_balance_service")
	if service != null:
		var active_before: Dictionary = service.active_profile().data.duplicate(true)
		_check(not service.apply_and_reset(invalid_curve).is_empty(), "invalid apply must fail")
		_check(service.active_profile().data == active_before, "invalid apply must preserve the entire active profile")

	var panel := BalancePanelType.new() as BalancePanel
	add_child(panel)
	panel.setup(profile, MemorySaveService.new(), true)
	var editable_paths: Array[String] = []
	_collect_editable_paths(profile.data, "", editable_paths)
	var controls: Dictionary = panel.get("_path_controls")
	for path in editable_paths:
		_check(controls.has(path), "visual panel is missing field control: %s" % path)
	_test_common_controls(panel, profile)
	panel.free()

	var runtime_overlay := BalanceRuntimeOverlayType.new() as BalanceRuntimeOverlay
	add_child(runtime_overlay)
	var modal := preload("res://scripts/runtime/screen_modal_coordinator.gd").new()
	add_child(modal)
	modal.configure(runtime_overlay)
	await get_tree().process_frame
	_check(runtime_overlay.panel != null and not runtime_overlay.panel.visible,
			"development runtime balance panel must exist and start closed")
	var f2_event := InputEventKey.new()
	f2_event.keycode = KEY_F2
	f2_event.pressed = true
	get_viewport().push_input(f2_event)
	_check(runtime_overlay.panel != null and runtime_overlay.panel.visible,
			"F2 must make the development runtime balance panel visible")
	runtime_overlay.free()
	modal.free()

	var roundtrip_path := "user://balance_roundtrip.json"
	_cleanup_roundtrip(roundtrip_path)
	var roundtrip := profile.duplicate_profile()
	roundtrip.source_path = roundtrip_path
	var save_errors := BalanceRepositoryType.save_profile(roundtrip, roundtrip_path)
	_check(save_errors.is_empty(), "valid profile must save transactionally")
	var first_text := _read_text(roundtrip_path)
	var reloaded := BalanceRepositoryType.load_profile(roundtrip_path)
	_check(reloaded != null and reloaded.data == profile.data,
			"JSON roundtrip must preserve values and Curve control points")
	if reloaded != null:
		_check(BalanceRepositoryType.save_profile(reloaded, roundtrip_path).is_empty(),
				"reloaded profile must save again")
		_check(_read_text(roundtrip_path) == first_text, "stable JSON formatting and field order must be deterministic")
	_cleanup_roundtrip(roundtrip_path)

	if not _failed:
		print("Balance config tests passed: schema coverage, atomic rejection, stable roundtrip, entropy threshold and panel controls")
	get_tree().quit(1 if _failed else 0)


func _test_common_controls(panel: BalancePanel, profile: BalanceProfile) -> void:
	var rate: SpinBox
	var interval: SpinBox
	var speeds: Array[SpinBox] = []
	for binding in panel._numeric_bindings:
		if binding.path == "tower/fire_interval":
			if binding.reciprocal:
				rate = binding.spin
			else:
				interval = binding.spin
		if binding.path == "tower/projectile_speed":
			speeds.append(binding.spin)
	_check(rate != null and interval != null and speeds.size() == 2, "common and full controls must share registered fields")
	rate.value = 7.5
	_check(is_equal_approx(float(panel.working.value("tower/fire_interval")), 1.0 / 7.5)
		and is_equal_approx(interval.value, 1.0 / 7.5), "fractional shots/sec must invert and synchronize without rounding")
	interval.value = 0.2
	_check(is_equal_approx(rate.value, 5.0), "interval edits must update the reciprocal view")
	speeds[0].value = 321.0
	_check(speeds[1].value == 321.0 and float(profile.value("tower/projectile_speed")) != 321.0,
		"common speed changes must sync the full view but not the active world")
	speeds[1].value = 432.0
	_check(speeds[0].value == 432.0 and panel._state_label.text.contains("未应用"), "full view edits must sync the common view")
	var unchanged := panel.working.data.duplicate(true)
	for invalid in [0.0, -1.0, INF, NAN]:
		rate.value_changed.emit(invalid)
		_check(panel.working.data == unchanged, "invalid fire rates must never mutate the working copy")
	panel._filter_rows("simulation")
	panel._filter_rows("")
	for group in panel._group_controls:
		if group.path == "simulation":
			_check(not group.body.visible, "search must restore advanced category collapse")
	panel.size.x = 1600.0
	panel._layout_common()
	_check(panel._common_grid.columns == 2, "wide panels must display two common columns")
	panel.size.x = 700.0
	panel._layout_common()
	_check(panel._common_grid.columns == 1, "narrow docks must display one common column")
	panel._save()
	_check(panel.saved_profile.data == panel.working.data and panel.baseline.data == profile.data,
		"runtime save must change saved reference, not the currently applied undo baseline")
	panel._restore_baseline()
	_check(panel.working.data == profile.data, "undo must restore active rather than saved runtime configuration")
	panel.setup(profile, MemorySaveService.new(), false)
	panel.working.set_value("tower/projectile_speed", 654.0)
	panel._save()
	panel.working.set_value("tower/projectile_speed", 765.0)
	panel._restore_baseline()
	_check(float(panel.working.value("tower/projectile_speed")) == 654.0,
		"editor undo must restore its most recently saved configuration")


func _collect_editable_paths(value, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key in value.keys():
			_collect_editable_paths(value[key], key if path.is_empty() else "%s/%s" % [path, key], result)
	elif value is Array:
		if _is_curve(value):
			result.append(path)
		else:
			for index in value.size():
				_collect_editable_paths(value[index], "%s/%d" % [path, index], result)
	else:
		result.append(path)


func _is_curve(value: Array) -> bool:
	if value.size() < 2:
		return false
	for item in value:
		if item is not Dictionary or not item.has("x") or not item.has("y") or item.size() != 2:
			return false
	return true


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _cleanup_roundtrip(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(absolute)
