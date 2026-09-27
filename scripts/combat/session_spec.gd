class_name SessionSpec
extends RefCounted

const DEFAULT_KEYS := {&"construction": "", &"single_wave": "waves/dev_wave_01", &"endless": "waves/endless", &"tutorial_diode": "levels/diode_tutorial"}
var source: StringName
var level_id: StringName
var session_kind: StringName
var balance_key: String
var record_enabled := false

static func development(kind: StringName) -> SessionSpec:
	var spec := SessionSpec.new()
	spec.source = &"development"
	spec.session_kind = kind
	spec.balance_key = String(DEFAULT_KEYS.get(kind, ""))
	return spec

static func from_launch(launch: Dictionary) -> SessionSpec:
	var spec := development(StringName(launch.get("session_kind", &"")))
	spec.source = StringName(launch.get("kind", &"development"))
	spec.record_enabled = spec.source == &"playtest" and OS.is_debug_build() and bool(launch.get("record_enabled", false))
	spec.level_id = StringName(launch.get("level_id", &""))
	# Campaign launches must explicitly bind configuration; never silently use the tutorial.
	spec.balance_key = String(launch.get("balance_key", "" if spec.source in [&"campaign", &"playtest"] else spec.balance_key))
	return spec
