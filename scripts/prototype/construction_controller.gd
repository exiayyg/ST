class_name ConstructionController
extends RefCounted

var simulation: SimulationController
var devices: Dictionary = {}
var selected_device_id := 0
var selected_anchor := 0
var destruction_effects: Array[Dictionary] = []
var destroy_effect_seconds := 0.35
var device_hit_flash_seconds := 0.16
var target_revision := 0


func _init(simulation_controller: SimulationController, profile: BalanceProfile = null) -> void:
	simulation = simulation_controller
	if profile != null:
		destroy_effect_seconds = float(profile.value("visuals/destroy_effect_seconds", destroy_effect_seconds))
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
	var definition := record.get("definition") as DeviceDefinition
	var angle_key := "angle_radians"
	var position_key := "position"
	if definition != null and definition.kind == &"diode" and selected_anchor == 1:
		angle_key = "secondary_angle_radians"
		position_key = "secondary_position"
	var angle := wrapf(float(record.get(angle_key, 0.0)) + delta_angle, -PI, PI)
	var position: Vector2 = record.get(position_key, Vector2.ZERO)
	var ok := simulation.native.set_device_anchor_transform(
		selected_device_id, selected_anchor, position, angle
	) if definition != null and definition.kind == &"diode" else simulation.native.set_device_transform(
		selected_device_id, position, angle
	)
	if ok:
		record[angle_key] = angle
		devices[selected_device_id] = record
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
		simulation.native.remove_device(device_id)
		_append_destruction_effect(record.get("position", Vector2.ZERO))
		var definition := record.get("definition") as DeviceDefinition
		if definition != null and definition.kind == &"diode":
			var secondary_position: Vector2 = record.get("secondary_position", Vector2.ZERO)
			if secondary_position.distance_squared_to(record.get("position", Vector2.ZERO)) > 0.000001:
				_append_destruction_effect(secondary_position)
		devices.erase(device_id)
		target_revision += 1
		if selected_device_id == device_id:
			selected_device_id = 0
			selected_anchor = 0
		return true
	devices[device_id] = record
	return false


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


func _append_destruction_effect(position: Vector2) -> void:
	destruction_effects.append({
		"position": position,
		"remaining": destroy_effect_seconds,
		"total": destroy_effect_seconds,
	})


func get_device_position(device_id: int) -> Vector2:
	if not devices.has(device_id):
		return Vector2.INF
	return (devices[device_id] as Dictionary).get("position", Vector2.INF)


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
