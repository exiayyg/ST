extends "res://scripts/prototype/momentum_prototype.gd"

const TowerControllerType := preload("res://scripts/combat/tower_controller.gd")
const EnemyManagerType := preload("res://scripts/combat/enemy_manager.gd")
const CombatHudType := preload("res://scripts/combat/combat_hud.gd")
const SingleWaveSessionType := preload("res://scripts/combat/single_wave_session.gd")
const EndlessRunDirectorType := preload("res://scripts/combat/endless_run_director.gd")

@export_enum("single_wave", "endless") var session_mode := "single_wave"

var _tower: TowerController
var _enemy_manager: EnemyManager
var _session: CombatSessionDirector
var _combat_hud: CombatHud
var _enemy_proxies_cleared := false


func _ready() -> void:
	super._ready()
	if _profile == null or _simulation == null:
		return
	_hud.show_prototype_status = false
	_hud.queue_redraw()
	_world_view.target_positions.clear()
	_tower = TowerControllerType.new(_profile) as TowerController
	_enemy_manager = EnemyManagerType.new(_profile, _simulation, _construction, _tower) as EnemyManager
	if session_mode == "endless":
		_session = EndlessRunDirectorType.new(_profile, _enemy_manager, _simulation, _tower) as EndlessRunDirector
	else:
		_session = SingleWaveSessionType.new(_profile, _enemy_manager, _simulation, _tower) as SingleWaveSession
	var combat_layer := CanvasLayer.new()
	combat_layer.name = "CombatHudLayer"
	add_child(combat_layer)
	_combat_hud = CombatHudType.new() as CombatHud
	_combat_hud.name = "CombatHud"
	combat_layer.add_child(_combat_hud)
	_combat_hud.configure(_profile, _enemy_manager.definitions)
	_combat_hud.restart_requested.connect(_restart_run)
	if not _session.start():
		push_error("无法启动战斗会话：%s" % session_mode)
		return
	_enemy_manager.sync_native_proxies()
	_enemy_proxies_cleared = false
	_world_view.set_combat_state([], [], _tower.hp, _tower.max_hp)


func _process(delta: float) -> void:
	if _session == null:
		super._process(delta)
		return
	_session.advance(delta)
	var combat_active := _session.should_simulate_enemies()
	if _enemy_manager.update(delta, combat_active):
		_lighting_dirty = true
	if combat_active:
		_enemy_manager.sync_native_proxies()
		_enemy_proxies_cleared = false
	else:
		_clear_enemy_proxies_once()
	if _session.is_terminal():
		_auto_fire = false
	super._process(delta)
	var live_stats := _simulation.native.get_stats()
	_session.evaluate(live_stats)
	if not _session.should_simulate_enemies():
		_clear_enemy_proxies_once()
	if _session.is_terminal():
		_auto_fire = false
	_world_view.set_combat_state(
		_enemy_manager.view_records(), _enemy_manager.tracers, _tower.hp, _tower.max_hp
	)
	_combat_hud.set_snapshot(_session.hud_snapshot(live_stats), _tower)


func _collect_events(events: Array) -> void:
	super._collect_events(events)
	if _enemy_manager == null:
		return
	for event: Dictionary in events:
		_enemy_manager.apply_native_event(event)


func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ENTER and _session != null and _session.is_terminal():
		_restart_run()
		return
	if event.keycode == KEY_F3 and _combat_hud != null:
		_combat_hud.toggle_debug()
		return
	super._handle_key(event)


func _clear_enemy_proxies_once() -> void:
	if _enemy_proxies_cleared:
		return
	_enemy_manager.clear_native_proxies()
	_enemy_proxies_cleared = true


func _restart_run() -> void:
	if _session == null or not _session.is_terminal():
		return
	set_process(false)
	get_tree().call_deferred("reload_current_scene")
