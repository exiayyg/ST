class_name WorldScreen
extends Node2D

const WorldRuntimeType := preload("res://scripts/runtime/world_runtime.gd")
const ScreenModalCoordinatorType := preload("res://scripts/runtime/screen_modal_coordinator.gd")
const SessionSpecType := preload("res://scripts/combat/session_spec.gd")
const MouseControlsType := preload("res://scripts/runtime/world_mouse_controls.gd")

signal gameplay_event(event: Dictionary)

@export var enable_diagnostic_targets := true
var runtime: WorldRuntimeType
var modal: ScreenModalCoordinatorType
var _profile: BalanceProfile
var _camera_controller: PrototypeCameraController
var _world_view: NetworkWorldView
var _hud: PrototypeHud
var _balance_overlay: BalanceRuntimeOverlay
var _runtime_menu: RuntimeMenuLayer
var _pause_overlay: CombatPauseOverlay
var _combat_hud: CombatHud
var _campaign_service: Node
var _playtest_active := false
var _playtest_recorder: PlaytestRecorder
var _playtest_overlay: PlaytestOverlay
var _playtest_end_reason := "normal_close"
var _playtest_completion_pending := false
var _frame_delta := 0.0
var presentation: PresentationDirector
var _mouse_controls: MouseControlsType
var _cursor_shape := Input.CURSOR_ARROW

var _campaign_launch_active := false
var _campaign_level_id: StringName
var _result_recorded := false
var _pending_completion: Dictionary = {}

func session_kind() -> StringName:
	return &"construction"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_profile = get_node("/root/_balance_service").active_profile()
	if _profile == null:
		set_process(false)
		return
	_campaign_service = get_node_or_null("/root/_campaign_service")
	# Windows has no native closed-hand drag cursor; use the same vector on all platforms.
	var grab_cursor := preload("res://assets/ui/closed_grab.svg")
	Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_DRAG, grab_cursor.get_size() * 0.5)
	var resolved_kind := session_kind()
	var options: Dictionary = {}
	if _campaign_service != null:
		var launch: Dictionary = _campaign_service.current_launch_snapshot()
		if not launch.is_empty() and String(launch.get("scene_path", "")) == scene_file_path:
			resolved_kind = StringName(launch.get("session_kind", resolved_kind))
			_playtest_active = StringName(launch.get("kind", &"")) == &"playtest"
			_campaign_launch_active = StringName(launch.get("kind", &"")) == &"campaign"
			_campaign_level_id = StringName(launch.get("level_id", &""))
			options = launch
	var camera := Camera2D.new()
	camera.name = "WorldCamera"
	camera.enabled = true
	add_child(camera)
	_camera_controller = PrototypeCameraController.new(camera, _profile.map_rect(), get_viewport(), _profile)
	runtime = WorldRuntimeType.new()
	runtime.gameplay_event.connect(func(event: Dictionary): gameplay_event.emit(event))
	runtime.run_finished.connect(_on_run_finished)
	var spec := SessionSpecType.development(resolved_kind) if options.is_empty() else SessionSpecType.from_launch(options)
	if not runtime.initialize(_profile, spec, _camera_controller, get_viewport(), enable_diagnostic_targets):
		push_error("无法初始化世界会话：%s" % resolved_kind)
		set_process(false)
		set_process_unhandled_input(false)
		return
	_world_view = NetworkWorldView.new()
	_world_view.name = "NetworkWorldView"
	add_child(_world_view)
	_world_view.configure(_profile)
	_world_view.lit_query = runtime.fog.is_lit
	_world_view.target_positions.assign(runtime.diagnostic_positions)
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	_hud = PrototypeHud.new()
	_hud.name = "PrototypeHud"
	_hud.catalog = runtime.catalog
	_hud.configure(_profile)
	_hud.show_prototype_status = resolved_kind == &"construction"
	layer.add_child(_hud)
	runtime.message.connect(_hud.push_message)
	_balance_overlay = BalanceRuntimeOverlay.new()
	_balance_overlay.name = "BalanceRuntimeOverlay"
	add_child(_balance_overlay)
	_runtime_menu = RuntimeMenuLayer.new()
	add_child(_runtime_menu)
	modal = ScreenModalCoordinatorType.new()
	modal.name = "ScreenModalCoordinatorType"
	add_child(modal)
	modal.configure(_balance_overlay, _runtime_menu, cancel_transient_interaction, _is_run_terminal, _return_label)
	modal.terminal_return_requested.connect(_return_from_run)
	_runtime_menu.configure(_profile, modal)
	_runtime_menu.retry_requested.connect(_perform_restart)
	_runtime_menu.return_requested.connect(_perform_return)
	_runtime_menu.quit_requested.connect(_perform_quit)
	_pause_overlay = _runtime_menu.menu
	var mouse_layer := CanvasLayer.new()
	mouse_layer.name = "MouseActions"
	mouse_layer.layer = 5
	add_child(mouse_layer)
	_mouse_controls = MouseControlsType.new()
	mouse_layer.add_child(_mouse_controls)
	_mouse_controls.configure(_profile)
	_mouse_controls.intent.connect(runtime.input.handle_command)
	runtime.input.command_requested.connect(func(command: StringName):
		if command == &"pause": _runtime_menu.open())
	if resolved_kind != &"construction":
		var combat_layer := CanvasLayer.new()
		combat_layer.name = "CombatHudLayer"
		add_child(combat_layer)
		_combat_hud = CombatHud.new()
		_combat_hud.name = "CombatHud"
		combat_layer.add_child(_combat_hud)
		_combat_hud.configure(_profile, runtime.enemies.definitions)
		_combat_hud.playtest_navigation = _playtest_active
		_combat_hud.set_campaign_navigation(_campaign_launch_active)
		_combat_hud.restart_requested.connect(_restart_run)
		_combat_hud.return_requested.connect(_return_from_run)
		_combat_hud.save_retry_requested.connect(_retry_result_save)
	if _playtest_active and spec.record_enabled:
		_playtest_recorder = PlaytestRecorder.new()
		_playtest_overlay = PlaytestOverlay.new()
		add_child(_playtest_overlay)
		_playtest_overlay.configure(_profile, _playtest_recorder)
		_playtest_recorder.begin(true, {
			"level_id": String(spec.level_id), "random_seed": _profile.runtime_config().simulation.random_seed,
			"config_hash": JSON.stringify(_profile.data, "", true, true).sha256_text(),
			"godot_version": Engine.get_version_info().string}, _profile.runtime_config().playtest)
		runtime.gameplay_event.connect(_playtest_recorder.ingest_event)
		runtime.input.semantic_event.connect(_playtest_recorder.ingest_event)
	presentation = PresentationDirector.new()
	presentation.name = "PresentationDirector"
	add_child(presentation)
	presentation.configure(_profile, _presentation_visible)
	runtime.gameplay_event.connect(presentation.ingest_event)
	runtime.presentation_event.connect(presentation.ingest_event)
	_runtime_menu.attach_presentation(presentation)
	presentation.bind_controls(self)
	_refresh_views()

func _process(delta: float) -> void:
	_frame_delta = delta
	runtime.advance(delta)
	_refresh_views()

func _refresh_views() -> void:
	var view := runtime.snapshot(_camera_controller.visible_world_rect())
	if _playtest_overlay != null:
		_playtest_overlay.observe(_frame_delta, view)
		if _playtest_completion_pending:
			_playtest_completion_pending = false
			_playtest_recorder.finish("settlement", runtime.session.completion_snapshot())
			_playtest_overlay.show_terminal()
	if presentation != null:
		presentation.advance(_frame_delta, view)
		_world_view.presentation_effects = presentation.effects
		_world_view.decoration_time = presentation.decoration_time
		_world_view.reduced_motion = presentation.preferences.reduced_motion
	_hud.selected_context = ""
	_hud.has_selection = int(view.selected_id) > 0
	_mouse_controls.set_snapshot(view, runtime.session.is_terminal())
	var interaction: Dictionary = view.interaction
	_world_view.interaction_preview = interaction.preview
	_world_view.hold_progress = float(interaction.hold_progress)
	_sync_pointer_cursor()
	_world_view.hold_position = interaction.hold_position
	var cues: Array[Dictionary] = []
	cues.assign(view.session.get("world_cues", []))
	_world_view.set_state(view.render, view.devices, view.selected_id, view.fog,
		view.destruction_effects, view.selected_anchor, interaction.dismantle_progress, cues, view.teleport_effects)
	_hud.set_state(view.stats, interaction.radial_open, interaction.radial_center, interaction.radial_hover, view.auto_fire, interaction.pending_diode)
	if _combat_hud != null:
		_world_view.set_combat_state(view.enemies, view.tracers, view.tower_hp, view.tower_max_hp)
		var hud_snapshot: Dictionary = view.session.duplicate()
		hud_snapshot["tower_hp"] = view.tower_hp
		hud_snapshot["tower_max_hp"] = view.tower_max_hp
		_combat_hud.set_snapshot(hud_snapshot)

func _input(event: InputEvent) -> void:
	if runtime == null or get_tree().paused:
		return
	if runtime.input.has_pointer_capture() and (event is InputEventMouseButton or event is InputEventMouseMotion):
		if runtime.input.handle_input(event):
			_sync_pointer_cursor()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if runtime.session.is_terminal() and not (event is InputEventKey and event.keycode == KEY_ESCAPE):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
	else:
		if runtime.input.handle_input(event):
			_sync_pointer_cursor()
			get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		modal.handle_escape()
		return
	if event.keycode == KEY_F3 and OS.is_debug_build() and _combat_hud != null:
		_combat_hud.toggle_debug()
		return
	if runtime.input.handle_input(event):
		get_viewport().set_input_as_handled()

func cancel_transient_interaction() -> bool:
	var cancelled := runtime.input.cancel() if runtime != null and runtime.input != null else false
	_sync_pointer_cursor()
	return cancelled

func _sync_pointer_cursor() -> void:
	var shape := int(runtime.input.snapshot().cursor_shape) if runtime != null and runtime.input != null else Input.CURSOR_ARROW
	if shape != _cursor_shape:
		_cursor_shape = shape
		Input.set_default_cursor_shape(shape as Input.CursorShape)

func has_cancelable_interaction() -> bool:
	return runtime.input.has_cancelable_interaction()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_transient_interaction()

func _exit_tree() -> void:
	if _playtest_recorder != null:
		var balance_service := get_node_or_null("/root/_balance_service")
		if balance_service != null and (balance_service.is_reset_pending() or balance_service.active_profile() != _profile):
			_playtest_end_reason = "balance_reset"
		if runtime != null and runtime.input != null:
			runtime.input.cancel()
		_playtest_recorder.finish(_playtest_end_reason)
	if runtime != null:
		runtime.shutdown()
		_sync_pointer_cursor()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_DRAG)


func _restart_run() -> void:
	_runtime_menu.request_action(_perform_restart)

func _perform_restart() -> void:
	_playtest_end_reason = "retry"
	if runtime.session == null:
		return
	_resume_run()
	set_process(false)
	if _campaign_service != null and _campaign_service.has_method("retry_current") \
			and not (_campaign_service.current_launch_snapshot() as Dictionary).is_empty():
		var error := int(_campaign_service.retry_current())
		if error == OK:
			return
	get_tree().call_deferred("reload_current_scene")

func _on_run_finished(_result: StringName) -> void:
	if runtime.input != null:
		runtime.input.cancel()
	_playtest_completion_pending = _playtest_recorder != null
	if _result_recorded or not _campaign_launch_active or _campaign_level_id == &"":
		return
	_result_recorded = true
	_pending_completion = runtime.session.completion_snapshot().duplicate(true)
	_retry_result_save()

func _retry_result_save() -> void:
	if _pending_completion.is_empty():
		return
	var save_error := int(_campaign_service.record_campaign_result(
		_campaign_level_id, _pending_completion
	))
	if is_instance_valid(_combat_hud):
		_combat_hud.set_save_failed(save_error != OK)
	if save_error == OK:
		_pending_completion.clear()

func _pause_run() -> void:
	if _pause_overlay == null or _pause_overlay.is_open() or runtime.session == null or runtime.session.is_terminal():
		return
	_runtime_menu.open()

func _resume_run() -> void:
	_runtime_menu.close()

func _return_from_run() -> void:
	_runtime_menu.request_action(_perform_return)

func _perform_return() -> void:
	_playtest_end_reason = "return_to_frontend"
	_resume_run()
	set_process(false)
	if _campaign_service != null and _campaign_service.has_method("return_to_frontend"):
		var error := int(_campaign_service.return_to_frontend(_campaign_launch_active))
		if error == OK:
			return
	get_tree().change_scene_to_file("res://scenes/frontend/main_menu.tscn")

func _return_label() -> String:
	return "返回关卡选择" if _campaign_launch_active else "返回主菜单"

func _perform_quit() -> void:
	_playtest_end_reason = "quit"
	preload("res://scripts/combat/runtime_pause_state.gd").reset(get_tree())
	get_tree().quit()

func _is_run_terminal() -> bool:
	return runtime.session != null and runtime.session.is_terminal()

func _presentation_visible(position: Vector2) -> bool:
	return runtime != null and _camera_controller.visible_world_rect().has_point(position) and runtime.fog.is_lit(position)
