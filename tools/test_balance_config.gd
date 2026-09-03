extends SceneTree

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const BalancePanelType := preload("res://scripts/config/balance_panel.gd")
const BalanceFieldCatalogType := preload("res://scripts/config/balance_field_catalog.gd")
const BalanceSchemaType := preload("res://scripts/config/balance_schema.gd")
const BalanceRuntimeOverlayType := preload("res://scripts/config/balance_runtime_overlay.gd")

var _failed := false


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	var profile := BalanceRepositoryType.load_profile()
	_check(profile != null, "balance.json must load")
	if profile == null:
		quit(1)
		return
	_check(profile.validate().is_empty(), "project balance profile must validate")
	_check(int(profile.value("schema_version", 0)) == 2, "project balance profile must use schema v2")
	_check(BalanceFieldCatalogType.unregistered_leaf_paths(profile.data).is_empty(),
			"every balance leaf must be registered in the visual schema")
	var legacy := profile.data.duplicate(true)
	legacy.schema_version = 1
	legacy.waves.erase("endless")
	legacy.diagnostics.enemy_ai_profile_interval = legacy.enemies.settings.target_refresh_seconds
	legacy.enemies.settings.erase("target_refresh_seconds")
	var migrated := BalanceSchemaType.migrate(legacy)
	_check(int(migrated.get("schema_version", 0)) == 2 and migrated.waves.has("endless")
			and is_equal_approx(float(migrated.enemies.settings.target_refresh_seconds), 0.2),
			"schema v1 must migrate in memory without losing the AI refresh value")
	_check(BalanceSchemaType.validate(migrated).is_empty(), "migrated schema v1 data must validate as v2")
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
	var invalid_wave_timing := profile.duplicate_profile()
	invalid_wave_timing.data.waves.dev_wave_01.groups[0].start_time = invalid_wave_timing.data.waves.dev_wave_01.duration + 1.0
	_check(not invalid_wave_timing.validate().is_empty(), "wave groups outside the wave duration must be rejected")

	var service := root.get_node_or_null("_balance_service")
	if service != null:
		var active_before: Dictionary = service.active_profile().data.duplicate(true)
		_check(not service.apply_and_reset(invalid_curve).is_empty(), "invalid apply must fail")
		_check(service.active_profile().data == active_before, "invalid apply must preserve the entire active profile")

	var panel := BalancePanelType.new() as BalancePanel
	root.add_child(panel)
	panel.setup(profile, null, true)
	var editable_paths: Array[String] = []
	_collect_editable_paths(profile.data, "", editable_paths)
	var controls: Dictionary = panel.get("_path_controls")
	for path in editable_paths:
		_check(controls.has(path), "visual panel is missing field control: %s" % path)
	panel.free()

	var runtime_overlay := BalanceRuntimeOverlayType.new() as BalanceRuntimeOverlay
	root.add_child(runtime_overlay)
	await process_frame
	_check(runtime_overlay.panel != null and not runtime_overlay.panel.visible,
			"development runtime balance panel must exist and start closed")
	var f2_event := InputEventKey.new()
	f2_event.keycode = KEY_F2
	f2_event.pressed = true
	runtime_overlay._unhandled_input(f2_event)
	_check(runtime_overlay.panel != null and runtime_overlay.panel.visible,
			"F2 must make the development runtime balance panel visible")
	runtime_overlay.free()

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
	quit(1 if _failed else 0)


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
