class_name WorldRuntime
extends RefCounted

const ConstructionInputControllerType := preload("res://scripts/runtime/construction_input_controller.gd")
const ConstructionSessionType := preload("res://scripts/combat/construction_session.gd")
const SessionSpecType := preload("res://scripts/combat/session_spec.gd")

signal presentation_event(event: Dictionary)
signal gameplay_event(event: Dictionary)
signal message(text: String)
signal run_finished(result: StringName)

var simulation: SimulationController
var construction: ConstructionController
var catalog: DeviceCatalog
var fog: FogOfWar
var tower: TowerController
var enemies: EnemyManager
var session: CombatSessionDirector
var input: ConstructionInputControllerType
var profile: BalanceProfile
var auto_fire := true
var emit_accumulator := 0.0
var lighting_dirty := true
var diagnostic_positions: Array[Vector2] = []
var _enemy_proxies_cleared := false
var _stats: Dictionary = {}
var _hud_snapshot: Dictionary = {}
var _emit_interval: float
var _light_radius: float
var _render_margin: float
var _camera: PrototypeCameraController
var _visible_enemy_count := 0

func initialize(balance: BalanceProfile, spec: SessionSpecType, camera: PrototypeCameraController, viewport: Viewport, diagnostic_targets: bool) -> bool:
	profile = balance
	_camera = camera
	simulation = SimulationController.new(profile)
	if not simulation.initialize():
		return false
	catalog = DeviceCatalog.new(profile)
	construction = ConstructionController.new(simulation, profile)
	fog = FogOfWar.new(simulation.native, profile)
	tower = TowerController.new(profile)
	_emit_interval = float(profile.value("tower/fire_interval"))
	_light_radius = float(profile.value("tower/light_radius"))
	_render_margin = float(profile.value("simulation/render_snapshot_margin"))
	input = ConstructionInputControllerType.new()
	input.initialize(construction, catalog, fog, camera, viewport, profile)
	input.message.connect(func(text: String): message.emit(text))
	input.lighting_changed.connect(func(): lighting_dirty = true)
	input.command_requested.connect(handle_command)
	if spec.session_kind == &"construction":
		session = ConstructionSessionType.new()
	else:
		enemies = EnemyManager.new(profile, simulation, construction, tower)
		session = CombatSessionFactory.create(spec, profile, enemies, simulation, tower, construction)
	if session == null:
		return false
	construction.gameplay_event.connect(_ingest_construction_event)
	gameplay_event.connect(session.ingest_event)
	session.run_finished.connect(_on_run_finished)
	if diagnostic_targets:
		var count := int(profile.value("diagnostics/target_count"))
		for index in count:
			var position := Vector2(float(profile.value("diagnostics/target_x")), (float(index) - float(count - 1) * 0.5) * float(profile.value("diagnostics/target_vertical_spacing")))
			diagnostic_positions.append(position)
			simulation.add_diagnostic_target(position)
	rebuild_fog()
	if not session.start():
		return false
	if enemies != null:
		enemies.sync_native_proxies()
		enemies.presentation_event.connect(_forward_presentation_event)
	_update_snapshot()
	return true

func advance(delta: float) -> void:
	# Preserve pre-refactor ordering, including native batch ingestion before enemy HP events.
	session.advance(delta)
	var combat_active := session.should_simulate_enemies()
	if enemies != null:
		if enemies.update(delta, combat_active):
			lighting_dirty = true
		if combat_active:
			enemies.sync_native_proxies()
			_enemy_proxies_cleared = false
		else:
			_clear_enemy_proxies_once()
	if session.is_terminal():
		auto_fire = false
	construction.advance_effects(delta)
	input.advance(delta)
	if auto_fire:
		emit_accumulator += delta
		while emit_accumulator >= _emit_interval:
			emit_accumulator -= _emit_interval
			simulation.emit_tower_projectile(tower.position)
			presentation_event.emit({"type":"tower_fired", "position":tower.position})
	simulation.step(delta)
	var events: Array = simulation.native.consume_events()
	_collect_events(events)
	if enemies != null:
		for event: Dictionary in events:
			enemies.apply_native_event(event)
	if construction.sync(simulation.native.get_device_snapshot()):
		lighting_dirty = true
	if lighting_dirty:
		rebuild_fog()
	_stats = simulation.native.get_stats()
	session.evaluate(_stats)
	if session.needs_world_observation():
		var visible_enemies := 0
		var visible_rect := _camera.visible_world_rect()
		if enemies != null:
			for enemy in enemies.enemies:
				if enemy.alive and visible_rect.has_point(enemy.position) and fog.is_lit(enemy.position):
					visible_enemies += 1
		_visible_enemy_count = visible_enemies
		session.observe_world(delta, auto_fire, visible_enemies)
	if not session.should_simulate_enemies():
		_clear_enemy_proxies_once()
	if session.is_terminal():
		auto_fire = false
	_hud_snapshot = session.hud_snapshot(_stats)

func handle_command(command: StringName) -> void:
	match command:
		&"toggle_auto_fire": auto_fire = not auto_fire
		&"cancel": input.cancel()

func snapshot(view_rect: Rect2) -> Dictionary:
	var stats := _stats.duplicate()
	stats["fog_rebuild_milliseconds"] = fog.last_rebuild_milliseconds
	return {"render": simulation.native.get_render_snapshot(view_rect, _render_margin),
		"devices": construction.view_records(), "selected_id": construction.selected_device_id,
		"selected_anchor": construction.selected_anchor, "fog": fog.texture,
		"destruction_effects": construction.destruction_effects, "teleport_effects": construction.teleport_effects,
		"interaction": input.snapshot(), "auto_fire": auto_fire, "stats": stats,
		"visible_enemy_count": _visible_enemy_count, "session": _hud_snapshot, "enemies": _enemy_view_records(),
		"tracers": enemies.tracers if enemies != null else [], "tower_hp": tower.hp, "tower_max_hp": tower.max_hp}

func rebuild_fog() -> void:
	fog.rebuild(construction.light_sources(tower.position, _light_radius))
	lighting_dirty = false

func _update_snapshot() -> void:
	_stats = simulation.native.get_stats()
	_hud_snapshot = session.hud_snapshot(_stats)

func _clear_enemy_proxies_once() -> void:
	if enemies == null or _enemy_proxies_cleared:
		return
	enemies.clear_native_proxies()
	_enemy_proxies_cleared = true

func _ingest_construction_event(event: Dictionary) -> void:
	gameplay_event.emit(event)

func _on_run_finished(result: StringName) -> void:
	input.cancel()
	run_finished.emit(result)

func shutdown() -> void:
	if enemies != null and enemies.presentation_event.is_connected(_forward_presentation_event):
		enemies.presentation_event.disconnect(_forward_presentation_event)
	if input != null:
		input.cancel()
	if session != null:
		if gameplay_event.is_connected(session.ingest_event):
			gameplay_event.disconnect(session.ingest_event)
		if session.run_finished.is_connected(_on_run_finished):
			session.run_finished.disconnect(_on_run_finished)
	if construction != null and construction.gameplay_event.is_connected(_ingest_construction_event):
		construction.gameplay_event.disconnect(_ingest_construction_event)
	input = null
	session = null
	enemies = null
	construction = null
	fog = null
	simulation = null

func _collect_events(events: Array) -> void:
	for event: Dictionary in events:
		if StringName(event.get("type", "")) == &"enemy_hit":
			var hit_position: Vector2 = event.get("position", Vector2.ZERO)
			event["player_visible"] = _camera.visible_world_rect().has_point(hit_position) and fog.is_lit(hit_position)
		match StringName(event.get("type", "")):
			&"device_activated":
				message.emit("装置永久激活 · 新照明已接入网络")
				lighting_dirty = true
			&"projectile_accelerated":
				message.emit("加速器：速度提升，质量不变")
			&"projectile_mass_increased":
				message.emit("质量器：质量提升，速度不变")
			&"projectile_split":
				message.emit("分流器：P → P/2 + P/2，同向平行")
			&"projectile_teleported":
				construction.record_diode_teleport(int(event.get("device_id", 0)))
				message.emit("二极管：空间拓扑跳转")
			&"wave_emitted":
				message.emit("波粒转换：离散扇形波点已发射")
			&"wave_reconstructed":
				message.emit("波动量达到阈值：自动重构标准弹丸")
			&"accumulator_released":
				message.emit("蓄积器：全部质量与动量一次释放")
			&"interaction_guard_triggered":
				message.emit("诊断：单步交互保护已触发，实体未被删除")
		gameplay_event.emit(event)
func _enemy_view_records() -> Array[Dictionary]:
	if enemies == null:
		return []
	var records := enemies.view_records()
	var visible_records: Array[Dictionary] = []
	for record in records:
		if float(record.get("hit_flash_remaining", 0.0)) > 0.0 and not fog.is_lit(record.position):
			if bool(record.get("hit_flash_only", false)):
				continue
			record["hit_flash_remaining"] = 0.0
		visible_records.append(record)
	return visible_records

func _forward_presentation_event(event: Dictionary) -> void:
	presentation_event.emit(event)
