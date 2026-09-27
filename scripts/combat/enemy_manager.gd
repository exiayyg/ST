class_name EnemyManager
extends RefCounted

signal presentation_event(event: Dictionary)

const EnemyDefinitionType := preload("res://scripts/combat/enemy_definition.gd")
const EnemyRuntimeType := preload("res://scripts/combat/enemy_runtime.gd")

var _hit_flash_seconds: float
var profile: BalanceProfile
var simulation: SimulationController
var construction: ConstructionController
var tower: TowerController
var definitions: Dictionary = {}
var enemies: Array[EnemyRuntime] = []
var tracers: Array[Dictionary] = []
var _depleted_hit_flashes: Array[Dictionary] = []
var next_enemy_id := 1
var random := RandomNumberGenerator.new()
var _device_target_cells: Dictionary = {}
var _device_target_anchors: Array[Dictionary] = []
var _device_target_index_revision := -1
var _device_target_min_cell := Vector2i.ZERO
var _device_target_max_cell := Vector2i.ZERO
var _device_target_min_position := Vector2.ZERO
var _device_target_max_position := Vector2.ZERO
var _device_target_index_empty := true
var _needs_enemy_prune := false
var _target_refresh_seconds := 0.2
var _target_spatial_cell_size := 256.0
var _target_forward_dot_min := 0.0
var _spawn_distribution_step := 0.61803398875
var _ranged_ray_extra_distance := 100.0
var _entropy_start := 50.0
var _max_target_score_deviation_ratio := 0.0


func _init(
		balance_profile: BalanceProfile,
		simulation_controller: SimulationController,
		construction_controller: ConstructionController,
		tower_controller: TowerController
) -> void:
	profile = balance_profile
	_hit_flash_seconds = profile.runtime_config().playtest.enemy_hit_flash_seconds
	simulation = simulation_controller
	construction = construction_controller
	tower = tower_controller
	random.seed = int(profile.value("simulation/random_seed", 1))
	_target_refresh_seconds = float(profile.value("enemies/settings/target_refresh_seconds", 0.2))
	_target_spatial_cell_size = float(profile.value("enemies/settings/target_spatial_cell_size", 256.0))
	_target_forward_dot_min = float(profile.value("enemies/settings/target_forward_dot_min", 0.0))
	_spawn_distribution_step = float(profile.value("enemies/settings/spawn_distribution_step", 0.61803398875))
	_ranged_ray_extra_distance = float(profile.value("enemies/settings/ranged_ray_extra_distance", 100.0))
	_entropy_start = float(profile.value("entropy/start_entropy", 50.0))
	_max_target_score_deviation_ratio = float(profile.value(
		"entropy/max_enemy_target_score_deviation_ratio", 0.0
	))
	for key in profile.section("enemies").keys():
		if String(key) == "settings":
			continue
		definitions[StringName(key)] = EnemyDefinitionType.from_config(StringName(key), profile.value("enemies/%s" % key, {}))


func spawn(enemy_kind: StringName, direction: StringName, modifiers: Dictionary = {}, spawn_region: SpawnRegion = null) -> int:
	var definition := definitions.get(enemy_kind) as EnemyDefinition
	if definition == null:
		return 0
	var region := spawn_region if spawn_region != null else SpawnRegion.new()
	var spawn_position := _spawn_position(direction, region)
	if not spawn_position.is_finite():
		return 0
	var stagger := _target_refresh_seconds * fposmod(
		float(next_enemy_id) * _spawn_distribution_step, 1.0
	)
	var enemy := EnemyRuntimeType.new(
		next_enemy_id, definition, spawn_position, modifiers, stagger
	) as EnemyRuntime
	next_enemy_id += 1
	enemies.append(enemy)
	_select_target(enemy)
	return enemy.id


func update(delta: float, combat_active: bool) -> bool:
	var lighting_changed := false
	for flash in _depleted_hit_flashes:
		flash["hit_flash_remaining"] = maxf(0.0, float(flash.hit_flash_remaining) - delta)
	_depleted_hit_flashes = _depleted_hit_flashes.filter(func(flash: Dictionary): return float(flash.hit_flash_remaining) > 0.0)
	if _needs_enemy_prune:
		enemies = enemies.filter(func(enemy: EnemyRuntime): return enemy.alive and enemy.hp > 0.0)
		_needs_enemy_prune = false
	if not tracers.is_empty():
		for tracer in tracers:
			tracer["remaining"] = float(tracer.get("remaining", 0.0)) - delta
		tracers = tracers.filter(func(tracer: Dictionary): return float(tracer.get("remaining", 0.0)) > 0.0)
	for enemy in enemies:
		enemy.hit_flash_remaining = maxf(0.0, enemy.hit_flash_remaining - delta)
	if not combat_active:
		return false
	var tower_destroyed := tower.is_destroyed()
	var tower_position := tower.position
	for enemy in enemies:
		if not enemy.alive or enemy.hp <= 0.0:
			continue
		if enemy.definition.entropy_decay_per_second > 0.0 and enemy.entropy > 0.0:
			enemy.entropy = maxf(0.0, enemy.entropy - enemy.definition.entropy_decay_per_second * delta)
		enemy.target_refresh_remaining -= delta
		var target_invalid := tower_destroyed if enemy.target_kind == &"tower" else (
			enemy.target_kind != &"device" or not construction.devices.has(enemy.target_id)
			or not construction.get_device_position(enemy.target_id, enemy.target_anchor).is_finite()
		)
		if enemy.target_refresh_remaining <= 0.0 or target_invalid:
			_select_target(enemy)
			enemy.target_refresh_remaining = _target_refresh_seconds
		var target_position := construction.get_device_position(enemy.target_id, enemy.target_anchor) \
			if enemy.target_kind == &"device" else tower_position
		if not target_position.is_finite():
			enemy.target_kind = &"tower"
			enemy.target_id = 0
			target_position = tower.position
		var offset := target_position - enemy.position
		var distance_squared := offset.length_squared()
		var attack_range := enemy.definition.attack_range
		if distance_squared > attack_range * attack_range:
			enemy.charge_remaining = -1.0
			var distance := sqrt(distance_squared)
			var travel_ratio := minf(enemy.move_speed * delta / distance, 1.0)
			enemy.position += offset * travel_ratio
		else:
			lighting_changed = _advance_attack(enemy, target_position, delta) or lighting_changed
	return lighting_changed


func _advance_attack(enemy: EnemyRuntime, target_position: Vector2, delta: float) -> bool:
	if not enemy.definition.ranged:
		enemy.attack_cooldown -= delta
		if enemy.attack_cooldown <= 0.0:
			enemy.attack_cooldown += enemy.definition.attack_interval
			return _attack(enemy, target_position)
		return false
	if enemy.charge_remaining >= 0.0:
		enemy.charge_remaining -= delta
		if enemy.charge_remaining <= 0.0:
			enemy.charge_remaining = -1.0
			enemy.attack_cooldown = enemy.definition.attack_interval
			return _ranged_attack(enemy, target_position)
		return false
	enemy.attack_cooldown -= delta
	if enemy.attack_cooldown <= 0.0:
		enemy.charge_remaining = enemy.definition.ranged_charge_seconds
	return false


func sync_native_proxies() -> bool:
	var ids := PackedInt64Array()
	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	var hit_points := PackedFloat32Array()
	var absorptions := PackedFloat32Array()
	var damage_scales := PackedFloat32Array()
	var entropy_ratios := PackedFloat32Array()
	for enemy in enemies:
		if not enemy.alive or enemy.hp <= 0.0:
			continue
		ids.append(enemy.id)
		positions.append(enemy.position)
		radii.append(enemy.definition.radius)
		hit_points.append(enemy.hp)
		absorptions.append(enemy.definition.momentum_absorption)
		damage_scales.append(enemy.definition.damage_per_momentum)
		entropy_ratios.append(enemy.definition.entropy_transfer_ratio)
	return simulation.native.sync_enemy_proxies({
		"ids": ids,
		"positions": positions,
		"radii": radii,
		"remaining_hp": hit_points,
		"momentum_absorption": absorptions,
		"damage_per_momentum": damage_scales,
		"entropy_transfer_ratio": entropy_ratios,
	})


func clear_native_proxies() -> void:
	simulation.native.clear_enemy_proxies()


func apply_native_event(event: Dictionary) -> void:
	if StringName(event.get("type", "")) != &"enemy_hit":
		return
	var enemy := find_enemy(int(event.get("subject_id", 0)))
	if enemy == null or not enemy.alive:
		return
	if float(event.get("damage", 0.0)) > 0.0:
		enemy.hit_flash_remaining = _hit_flash_seconds
	enemy.hp = maxf(0.0, enemy.hp - float(event.get("damage", 0.0)))
	enemy.entropy += maxf(0.0, float(event.get("entropy_transferred", 0.0)))
	if enemy.hp <= 0.0:
		enemy.alive = false
		_needs_enemy_prune = true
		if enemy.hit_flash_remaining > 0.0:
			var flash := enemy.view_record()
			flash["hit_flash_only"] = true
			_depleted_hit_flashes.append(flash)


func find_enemy(enemy_id: int) -> EnemyRuntime:
	for enemy in enemies:
		if enemy.id == enemy_id:
			return enemy
	return null


func view_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.alive:
			result.append(enemy.view_record())
	for flash in _depleted_hit_flashes:
		result.append(flash.duplicate())
	return result


func alive_count() -> int:
	var count := 0
	for enemy in enemies:
		count += 1 if enemy.alive else 0
	return count


func _select_target(enemy: EnemyRuntime) -> void:
	_ensure_device_target_index()
	var forward := (tower.position - enemy.position).normalized()
	var best_id := 0
	var best_anchor := 0
	var best_score := INF
	var uncertainty := 0.0 if enemy.entropy <= _entropy_start else profile.entropy_weight(enemy.entropy)
	# Melee interceptors express entropy through target choice. Ranged suppressors
	# keep target scoring deterministic and express it only through their aim ray.
	var score_deviation := 0.0 if enemy.definition.ranged else _max_target_score_deviation_ratio * uncertainty
	var radius := enemy.definition.sense_radius
	var radius_squared := radius * radius
	if _device_target_index_empty \
			or enemy.position.x + radius < _device_target_min_position.x \
			or enemy.position.x - radius > _device_target_max_position.x \
			or enemy.position.y + radius < _device_target_min_position.y \
			or enemy.position.y - radius > _device_target_max_position.y:
		enemy.target_kind = &"tower"
		enemy.target_id = 0
		return
	var minimum := _target_cell(enemy.position - Vector2(radius, radius), _target_spatial_cell_size)
	var maximum := _target_cell(enemy.position + Vector2(radius, radius), _target_spatial_cell_size)
	if maximum.x < _device_target_min_cell.x or minimum.x > _device_target_max_cell.x \
			or maximum.y < _device_target_min_cell.y or minimum.y > _device_target_max_cell.y:
		enemy.target_kind = &"tower"
		enemy.target_id = 0
		return
	minimum.x = maxi(minimum.x, _device_target_min_cell.x)
	minimum.y = maxi(minimum.y, _device_target_min_cell.y)
	maximum.x = mini(maximum.x, _device_target_max_cell.x)
	maximum.y = mini(maximum.y, _device_target_max_cell.y)
	for cell_y in range(minimum.y, maximum.y + 1):
		for cell_x in range(minimum.x, maximum.x + 1):
			var candidates: Array = _device_target_cells.get(Vector2i(cell_x, cell_y), [])
			for value: Dictionary in candidates:
				var device_position: Vector2 = value.get("position", Vector2.INF)
				var offset := device_position - enemy.position
				var distance_squared := offset.length_squared()
				if distance_squared > radius_squared or not _passes_forward_cone(offset, distance_squared, forward):
					continue
				var score := distance_squared
				if score_deviation > 0.0:
					var factor := 1.0 + random.randf_range(-score_deviation, score_deviation)
					score *= factor * factor
				var candidate_id := int(value.get("id", 0))
				var anchor_index := int(value.anchor_index)
				var tied := is_equal_approx(score, best_score)
				if (score < best_score and not tied) or (tied and (candidate_id < best_id or (candidate_id == best_id and anchor_index < best_anchor))):
					best_score = score
					best_id = candidate_id
					best_anchor = anchor_index
	if best_id > 0:
		enemy.target_kind = &"device"
		enemy.target_id = best_id
		enemy.target_anchor = best_anchor
	else:
		enemy.target_kind = &"tower"
		enemy.target_id = 0


func _attack(enemy: EnemyRuntime, target_position: Vector2) -> bool:
	if enemy.definition.ranged:
		return _ranged_attack(enemy, target_position)
	var lighting_changed := false
	if enemy.target_kind == &"device":
		lighting_changed = construction.damage_device(enemy.target_id, enemy.attack_damage)
	else:
		tower.apply_damage(enemy.attack_damage)
	presentation_event.emit({"type":"enemy_attack", "position":enemy.position, "subject_id":enemy.id})
	return lighting_changed


func _ranged_attack(enemy: EnemyRuntime, target_position: Vector2) -> bool:
	var ideal := (target_position - enemy.position).normalized()
	var uncertainty := profile.entropy_weight(enemy.entropy)
	var maximum_angle := deg_to_rad(enemy.definition.aim_max_deviation_degrees) * uncertainty
	var direction := ideal.rotated(random.randf_range(-maximum_angle, maximum_angle))
	var maximum_distance := enemy.definition.attack_range + _ranged_ray_extra_distance
	var ray_end := enemy.position + direction * maximum_distance
	var best_fraction := INF
	var best_kind: StringName
	var best_id := 0
	var tower_fraction := _segment_circle_fraction(enemy.position, ray_end, tower.position, tower.radius)
	if tower_fraction < best_fraction:
		best_fraction = tower_fraction
		best_kind = &"tower"
	_ensure_device_target_index()
	# Anchors are sorted by stable device ID then endpoint; strict comparison
	# retains the existing tower-first tie and applies one shared-HP hit only.
	for value: Dictionary in _device_target_anchors:
		var radius := float(value.radius)
		var fraction := _segment_circle_fraction(enemy.position, ray_end, value.get("position", Vector2.INF), radius)
		if fraction < best_fraction:
			best_fraction = fraction
			best_kind = &"device"
			best_id = int(value.get("id", 0))
	var hit_position := ray_end
	var lighting_changed := false
	if is_finite(best_fraction):
		hit_position = enemy.position.lerp(ray_end, best_fraction)
		if best_kind == &"tower":
			tower.apply_damage(enemy.attack_damage)
		else:
			lighting_changed = construction.damage_device(best_id, enemy.attack_damage)
	presentation_event.emit({"type":"enemy_attack", "position":enemy.position, "subject_id":enemy.id})
	tracers.append({
		"from": enemy.position,
		"to": hit_position,
		"color": enemy.definition.color,
		"remaining": float(profile.value("visuals/tracer_seconds", 0.12)),
	})
	return lighting_changed


func accepts_spawn_region(direction: StringName, region: SpawnRegion) -> bool:
	return region != null and region.fits(profile.map_rect(), float(profile.value("enemies/settings/spawn_edge_inset")), direction)


func _spawn_position(direction: StringName, region: SpawnRegion) -> Vector2:
	var rect := profile.map_rect()
	var inset := float(profile.value("enemies/settings/spawn_edge_inset", 32.0))
	var ratio := fposmod(float(next_enemy_id) * _spawn_distribution_step, 1.0)
	return region.position(rect, inset, direction, ratio)


func _ensure_device_target_index() -> void:
	if _device_target_index_revision == construction.target_revision:
		return
	_device_target_cells.clear()
	_device_target_anchors = construction.target_anchors()
	_device_target_index_empty = true
	for value: Dictionary in _device_target_anchors:
		var position: Vector2 = value.get("position", Vector2.INF)
		if not position.is_finite():
			continue
		var cell := _target_cell(position, _target_spatial_cell_size)
		if _device_target_index_empty:
			_device_target_min_cell = cell
			_device_target_max_cell = cell
			_device_target_min_position = position
			_device_target_max_position = position
			_device_target_index_empty = false
		else:
			_device_target_min_cell.x = mini(_device_target_min_cell.x, cell.x)
			_device_target_min_cell.y = mini(_device_target_min_cell.y, cell.y)
			_device_target_max_cell.x = maxi(_device_target_max_cell.x, cell.x)
			_device_target_max_cell.y = maxi(_device_target_max_cell.y, cell.y)
			_device_target_min_position.x = minf(_device_target_min_position.x, position.x)
			_device_target_min_position.y = minf(_device_target_min_position.y, position.y)
			_device_target_max_position.x = maxf(_device_target_max_position.x, position.x)
			_device_target_max_position.y = maxf(_device_target_max_position.y, position.y)
		var entries: Array = _device_target_cells.get(cell, [])
		entries.append(value)
		_device_target_cells[cell] = entries
	_device_target_index_revision = construction.target_revision


func _target_cell(position: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func _passes_forward_cone(offset: Vector2, distance_squared: float, forward: Vector2) -> bool:
	if distance_squared <= 0.00000001:
		return true
	var projection := offset.dot(forward)
	if is_zero_approx(_target_forward_dot_min):
		return projection >= 0.0
	return projection / sqrt(distance_squared) >= _target_forward_dot_min


func _segment_circle_fraction(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	if not center.is_finite():
		return INF
	var segment := to - from
	var offset := from - center
	var a := segment.length_squared()
	if a <= 0.000001:
		return INF
	var b := 2.0 * offset.dot(segment)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return INF
	var fraction := (-b - sqrt(discriminant)) / (2.0 * a)
	return fraction if fraction >= 0.0 and fraction <= 1.0 else INF
