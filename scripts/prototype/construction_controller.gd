class_name ConstructionController
extends RefCounted

signal gameplay_event(event: Dictionary)

var simulation: SimulationController
var devices: Dictionary = {}
var selected_device_id := 0
var selected_anchor := 0
var destruction_effects: Array[Dictionary] = []
var teleport_effects: Array[Dictionary] = []
var destroy_effect_seconds := 0.35
var diode_teleport_pulse_seconds := 0.32
var device_hit_flash_seconds := 0.16
var target_revision := 0


func _init(simulation_controller: SimulationController, profile: BalanceProfile = null) -> void:
	simulation = simulation_controller
	if profile != null:
		destroy_effect_seconds = float(profile.value("visuals/destroy_effect_seconds", destroy_effect_seconds))
		diode_teleport_pulse_seconds = float(profile.value(
			"visuals/diode_teleport_pulse_seconds", diode_teleport_pulse_seconds
		))
		device_hit_flash_seconds = float(profile.value("visuals/device_hit_flash_seconds", device_hit_flash_seconds))


func place(
		definition: DeviceDefinition,
		position: Vector2,
		angle: float = 0.0,
		secondary_position: Vector2 = Vector2.ZERO,
		secondary_angle: float = 0.0
) -> int:
	var device_id := simulation.add_device(
		definition, position, angle, secondary_position, secondary_angle
	)
	if device_id <= 0:
		return 0
	devices[device_id] = {
		"id": device_id,
		"definition": definition,
		"position": position,
		"angle_radians": angle,
		"secondary_position": secondary_position,
		"secondary_angle_radians": secondary_angle,
		"activation_progress": 0.0,
		"activation_required": definition.activation_required,
		"active": false,
		"hp": definition.max_hp,
		"max_hp": definition.max_hp,
		"stored_mass": 0.0,
		"stored_momentum": 0.0,
		"stored_wave_momentum": 0.0,
		"hit_flash_remaining": 0.0,
	}
	target_revision += 1
	selected_device_id = device_id
	selected_anchor = 0
	gameplay_event.emit({
		"type": &"device_placed",
		"device_id": device_id,
		"device_kind": definition.kind,
		"position": position,
		"secondary_position": secondary_position,
	})
	return device_id


func sync(native_snapshot: Array) -> bool:
	var lighting_changed := false
	for native_device: Dictionary in native_snapshot:
		var device_id := int(native_device.get("id", 0))
		if not devices.has(device_id):
			continue
		var record: Dictionary = devices[device_id]
		var was_active := bool(record.get("active", false))
		for key in [
			"position", "angle_radians", "secondary_position", "secondary_angle_radians",
			"activation_progress", "activation_required", "active", "stored_mass",
			"stored_momentum", "stored_wave_momentum"
		]:
			record[key] = native_device.get(key, record.get(key))
		devices[device_id] = record
		if was_active != bool(record.get("active", false)):
			lighting_changed = true
	return lighting_changed


func pick(world_position: Vector2, radius: float = 38.0) -> Dictionary:
	var best := {"id": 0, "anchor": 0}
	var best_distance := radius
	for value: Dictionary in devices.values():
		var position: Vector2 = value.get("position", Vector2.ZERO)
		var distance := world_position.distance_to(position)
		if distance < best_distance:
			best_distance = distance
			best = {"id": int(value.id), "anchor": 0}
		var definition := value.get("definition") as DeviceDefinition
		if definition != null and definition.kind == &"diode":
			var secondary: Vector2 = value.get("secondary_position", Vector2.ZERO)
			distance = world_position.distance_to(secondary)
			if distance < best_distance:
				best_distance = distance
				best = {"id": int(value.id), "anchor": 1}
	return best


func move_selected(position: Vector2) -> bool:
	if not devices.has(selected_device_id):
		return false
	var record: Dictionary = devices[selected_device_id]
	var definition := record.get("definition") as DeviceDefinition
	if definition != null and definition.kind == &"diode":
		var angle_key := "angle_radians" if selected_anchor == 0 else "secondary_angle_radians"
		var ok := simulation.native.set_device_anchor_transform(
			selected_device_id, selected_anchor, position, float(record.get(angle_key, 0.0))
		)
		if ok:
			record["position" if selected_anchor == 0 else "secondary_position"] = position
			devices[selected_device_id] = record
			target_revision += 1
		return ok
	var ok := simulation.native.set_device_transform(
		selected_device_id, position, float(record.get("angle_radians", 0.0))
	)
	if ok:
		record["position"] = position
		devices[selected_device_id] = record
		target_revision += 1
	return ok


func rotate_selected(delta_angle: float) -> bool:
	if not devices.has(selected_device_id):
		return false
	var record: Dictionary = devices[selected_device_id]
	var key := "secondary_angle_radians" if selected_anchor == 1 else "angle_radians"
	return set_anchor_rotation(selected_device_id, selected_anchor, float(record[key]) + delta_angle)

func set_anchor_rotation(device_id: int, anchor_index: int, angle: float) -> bool:
	if not devices.has(device_id) or not is_finite(angle):
		return false
	var record: Dictionary = devices[device_id]
	var definition := record.definition as DeviceDefinition
	if anchor_index < 0 or anchor_index > (1 if definition.kind == &"diode" else 0):
		return false
	var angle_key := "secondary_angle_radians" if anchor_index == 1 else "angle_radians"
	var position_key := "secondary_position" if anchor_index == 1 else "position"
	angle = wrapf(angle, -PI, PI)
	var position: Vector2 = record[position_key]
	var ok := simulation.native.set_device_anchor_transform(device_id, anchor_index, position, angle) \
		if definition.kind == &"diode" else simulation.native.set_device_transform(device_id, position, angle)
	if ok:
		record[angle_key] = angle
	return ok


func damage_selected(amount: float) -> bool:
	return damage_device(selected_device_id, amount)


func damage_device(device_id: int, amount: float) -> bool:
	if not devices.has(device_id) or not is_finite(amount) or amount <= 0.0:
		return false
	var record: Dictionary = devices[device_id]
	record["hp"] = maxf(0.0, float(record.get("hp", 0.0)) - amount)
	record["hit_flash_remaining"] = device_hit_flash_seconds
	if float(record.hp) <= 0.0:
		devices[device_id] = record
		return not _remove_device(device_id, &"device_destroyed").is_empty()
	devices[device_id] = record
	return false


func dismantle_selected() -> Dictionary:
	if selected_device_id <= 0:
		return {}
	return _remove_device(selected_device_id, &"device_dismantled")


func _remove_device(device_id: int, event_type: StringName) -> Dictionary:
	if not devices.has(device_id):
		return {}
	var record: Dictionary = devices[device_id]
	if not simulation.native.remove_device(device_id):
		return {}
	var position: Vector2 = record.get("position", Vector2.ZERO)
	var secondary_position: Vector2 = record.get("secondary_position", position)
	_append_destruction_effect(position, event_type)
	var definition := record.get("definition") as DeviceDefinition
	if definition != null and definition.kind == &"diode" \
			and secondary_position.distance_squared_to(position) > 0.000001:
		_append_destruction_effect(secondary_position, event_type)
	devices.erase(device_id)
	target_revision += 1
	if selected_device_id == device_id:
		selected_device_id = 0
		selected_anchor = 0
	var event := {
		"type": event_type,
		"device_id": device_id,
		"device_kind": definition.kind if definition != null else &"",
		"position": position,
		"secondary_position": secondary_position,
		"was_active": bool(record.get("active", false)),
		"discarded_activation_progress": float(record.get("activation_progress", 0.0)),
		"discarded_mass": float(record.get("stored_mass", 0.0)),
		"discarded_momentum": float(record.get("stored_momentum", 0.0)),
		"discarded_wave_momentum": float(record.get("stored_wave_momentum", 0.0)),
	}
	gameplay_event.emit(event)
	return event


func advance_effects(delta: float) -> void:
	for device_id in devices.keys():
		var record: Dictionary = devices[device_id]
		record["hit_flash_remaining"] = maxf(0.0, float(record.get("hit_flash_remaining", 0.0)) - delta)
		devices[device_id] = record
	for effect in destruction_effects:
		effect.remaining = float(effect.get("remaining", 0.0)) - delta
	destruction_effects = destruction_effects.filter(
		func(effect: Dictionary): return float(effect.get("remaining", 0.0)) > 0.0
	)
	for effect in teleport_effects:
		effect.remaining = float(effect.get("remaining", 0.0)) - delta
	teleport_effects = teleport_effects.filter(
		func(effect: Dictionary): return float(effect.get("remaining", 0.0)) > 0.0
	)


func record_diode_teleport(device_id: int) -> bool:
	if not devices.has(device_id):
		return false
	var record: Dictionary = devices[device_id]
	var definition := record.get("definition") as DeviceDefinition
	if definition == null or definition.kind != &"diode":
		return false
	for effect in teleport_effects:
		if int(effect.get("device_id", 0)) != device_id:
			continue
		effect["entry"] = record.get("position", Vector2.ZERO)
		effect["exit"] = record.get("secondary_position", Vector2.ZERO)
		effect["remaining"] = diode_teleport_pulse_seconds
		effect["total"] = diode_teleport_pulse_seconds
		return true
	teleport_effects.append({
		"device_id": device_id,
		"entry": record.get("position", Vector2.ZERO),
		"exit": record.get("secondary_position", Vector2.ZERO),
		"remaining": diode_teleport_pulse_seconds,
		"total": diode_teleport_pulse_seconds,
	})
	return true


func _append_destruction_effect(position: Vector2, event_type: StringName) -> void:
	destruction_effects.append({
		"position": position,
		"kind": event_type,
		"remaining": destroy_effect_seconds,
		"total": destroy_effect_seconds,
	})


func get_device_position(device_id: int, anchor_index := 0) -> Vector2:
	if not devices.has(device_id):
		return Vector2.INF
	var record: Dictionary = devices[device_id]
	if anchor_index == 0:
		return record.position
	var definition := record.definition as DeviceDefinition
	if anchor_index == 1 and definition.kind == &"diode":
		return record.secondary_position
	return Vector2.INF


func target_anchors() -> Array[Dictionary]:
	# Rebuilt by the AI only when target_revision changes.
	var anchors: Array[Dictionary] = []
	var ids := devices.keys()
	ids.sort()
	for device_id in ids:
		var record: Dictionary = devices[device_id]
		var definition := record.definition as DeviceDefinition
		anchors.append({"id": device_id, "anchor_index": 0, "position": record.position, "radius": definition.activation_radius})
		if definition.kind == &"diode":
			anchors.append({"id": device_id, "anchor_index": 1, "position": record.secondary_position, "radius": definition.activation_radius})
	return anchors


func release_selected() -> bool:
	return selected_device_id > 0 and simulation.native.release_accumulator(selected_device_id)


func light_sources(tower_position: Vector2, tower_radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"position": tower_position, "radius": tower_radius}]
	for record: Dictionary in devices.values():
		if not bool(record.get("active", false)) or float(record.get("hp", 0.0)) <= 0.0:
			continue
		var definition := record.get("definition") as DeviceDefinition
		if definition == null:
			continue
		result.append({"position": record.position, "radius": definition.light_radius})
		if definition.kind == &"diode":
			result.append({"position": record.secondary_position, "radius": definition.light_radius})
	return result


func view_records() -> Array:
	return devices.values()
