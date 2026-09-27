@tool
class_name BalanceEditSession
extends RefCounted

const Adapter := preload("res://scripts/config/balance_edit_adapter.gd")
signal changed(path: String)
var working: BalanceProfile
var baseline: BalanceProfile
var saved: BalanceProfile
var adapter: Adapter
var runtime_mode := false

func initialize(profile: BalanceProfile, backend: Adapter, is_runtime: bool) -> void:
	adapter = backend
	runtime_mode = is_runtime
	working = profile.duplicate_profile()
	baseline = profile.duplicate_profile()
	saved = adapter.load_saved(profile.source_path)
	if saved == null:
		saved = profile.duplicate_profile()

func edit(path: String, value) -> bool:
	if not working.set_value(path, value):
		return false
	changed.emit(path)
	return true

func edit_shots_per_second(rate: float) -> bool:
	if not is_finite(rate) or rate <= 0.0:
		return false
	var field := BalanceFieldCatalog.descriptor("tower/fire_interval", 1.0 / rate)
	if 1.0 / rate < float(field.minimum) or 1.0 / rate > float(field.maximum):
		return false
	return edit("tower/fire_interval", 1.0 / rate)

func errors() -> Array[String]:
	return working.validate()

func snapshot() -> Dictionary:
	var interval := float(working.value("tower/fire_interval"))
	var momentum := working.tower_momentum()
	return {"applied": working.data == baseline.data, "saved": working.data == saved.data,
		"interval": interval, "momentum": momentum, "momentum_per_second": momentum / interval if interval > 0.0 else 0.0}

func apply() -> Array[String]:
	var failures := errors()
	if not failures.is_empty():
		return failures
	failures = adapter.apply(working)
	if failures.is_empty():
		baseline = working.duplicate_profile()
		if adapter.apply_updates_saved():
			saved = working.duplicate_profile()
		changed.emit("")
	return failures

func save() -> Array[String]:
	var failures := adapter.save(working)
	if failures.is_empty():
		saved = working.duplicate_profile()
		if not runtime_mode:
			baseline = working.duplicate_profile()
		changed.emit("")
	return failures

func reload() -> bool:
	var loaded := adapter.load_saved(working.source_path)
	if loaded == null:
		return false
	working = loaded.duplicate_profile()
	saved = loaded.duplicate_profile()
	if not runtime_mode:
		baseline = loaded.duplicate_profile()
	changed.emit("")
	return true

func undo() -> void:
	working = baseline.duplicate_profile()
	changed.emit("")
