class_name PresentationDirector
extends Node

signal availability_notice(message: String)
var preferences := PresentationPreferences.new()
var effects: Array[Dictionary] = []
var decoration_time := 0.0
var last_played: Array[String] = []
var _profile: BalanceProfile
var _config: RuntimeBalance.Presentation
var _audio: RuntimeBalance.Audio
var _bank: Dictionary = {}
var _cue_config: Dictionary = {}
var _pending: Dictionary = {}
var _pending_count := 0
var _overflow_cues: Dictionary = {}
var _pending_cues: Dictionary = {}
var _cooldowns: Dictionary = {}
var _world_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _is_visible: Callable
var _ui_pending: Dictionary = {}
var _ui_cooldowns: Dictionary = {}
var _session_phase := ""
var _warning_key := 0
var audio_available := true
var _controls_root: Node
var _notice: Label
var _device_check_elapsed := 0.0
var _world_paused := false

const EVENT_CUES := {
	"device_placed":"place", "device_activated":"activate", "device_dismantled":"dismantle",
	"device_destroyed":"destroy", "tower_fired":"tower_fire", "enemy_attack":"enemy_attack",
	"enemy_hit":"hit", "projectile_reflected":"transform", "projectile_accelerated":"transform",
	"projectile_mass_increased":"transform", "projectile_split":"transform", "projectile_teleported":"transform",
	"wave_emitted":"transform", "wave_reconstructed":"transform", "accumulator_released":"transform",
	"accumulator_stored":"transform", "projectile_charged":"transform",
	"magnetic_field_entered":"transform", "magnetic_field_exited":"transform", "wave_absorbed":"transform"
}

func configure(profile: BalanceProfile, visible_query := Callable()) -> void:
	reset()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile = profile
	_config = profile.runtime_config().presentation
	_audio = profile.runtime_config().audio
	_is_visible = visible_query
	preferences.configure(profile)
	_bank = EnergySoundBank.load_bank(profile)
	for cue in EnergySoundBank.CUES: _cue_config[cue] = _audio.cue(cue)
	_create_players(_world_players, _audio.world_voices)
	_create_players(_ui_players, _audio.ui_voices)
	if _notice == null:
		var layer := CanvasLayer.new()
		add_child(layer)
		_notice = Label.new()
		layer.add_child(_notice)
		_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notice.add_theme_color_override("font_color", Color(profile.runtime_config().visuals.hud_warning_color))
		_notice.text = preferences.notice
	audio_available = not AudioServer.get_output_device_list().is_empty() and DisplayServer.get_name() != "headless"
	if not audio_available and DisplayServer.get_name() != "headless":
		_notice.text = "音频输出不可用，游戏仍可继续。"
		availability_notice.emit(_notice.text)

func ingest_event(event: Dictionary) -> void:
	var kind := String(event.get("type", ""))
	if not EVENT_CUES.has(kind): return
	if kind == "enemy_hit" and float(event.get("damage", 0.0)) <= 0.0: return
	var cue: String = EVENT_CUES[kind]
	var subject := int(event.get("subject_id", 0) if kind in ["enemy_hit", "enemy_attack"] else event.get("device_id", 0))
	if not _pending.has(kind): _pending[kind] = {}
	var group: Dictionary = _pending[kind]
	# One representative per object/type; visibility is evaluated at frame end.
	if group.has(subject): return
	var position: Vector2 = event.get("position", Vector2.INF)
	if not position.is_finite(): return
	if _pending_count >= _config.effect_limit:
		# Bounded by cue types, independent of the decoration cap. Critical sounds
		# remain eligible even when a hit storm fills every decorative slot.
		_overflow_cues[cue] = position
		return
	group[subject] = {"kind":cue, "effect_kind":"store" if kind == "accumulator_stored" else cue, "position":position}
	_pending_count += 1

func advance(delta: float, view: Dictionary = {}) -> void:
	last_played.clear()
	if delta <= 0.0: return
	if _config.enabled and not preferences.reduced_motion: decoration_time += delta
	for effect in effects: effect.remaining -= delta
	effects = effects.filter(func(effect: Dictionary): return float(effect.remaining) > 0.0 and _is_visible.is_valid() and _is_visible.call(effect.position))
	var session: Dictionary = view.get("session", {})
	if not session.is_empty():
		var phase := "%s/%s/%s" % [session.get("wave_index", 0), session.get("phase", ""), session.get("result", "")]
		if phase != _session_phase:
			_session_phase = phase
			if String(session.get("phase", "")) == "clearing": _queue_global("target")
			elif bool(session.get("terminal", false)):
				_queue_global("victory" if String(session.get("result", "")) == "success" else "failure")
		var warnings: Dictionary = session.get("warnings", {})
		var warning_key := warnings.hash()
		if warning_key != _warning_key:
			_warning_key = warning_key
			if not warnings.is_empty(): _queue_global("warning")
	var cues := _pending_cues.duplicate()
	_pending_cues.clear()
	for group: Dictionary in _pending.values():
		for pending: Dictionary in group.values():
			if not _is_visible.is_valid() or not _is_visible.call(pending.position): continue
			cues[pending.kind] = true
			if _config.enabled and not preferences.reduced_motion and effects.size() < _config.effect_limit:
				effects.append({"kind":pending.effect_kind, "position":pending.position, "remaining":_config.effect_seconds, "total":_config.effect_seconds})
	for cue: String in _overflow_cues:
		if not cues.has(cue) and _is_visible.is_valid() and _is_visible.call(_overflow_cues[cue]): cues[cue] = true
	_pending.clear()
	_pending_count = 0
	_overflow_cues.clear()
	_play_batch(cues, _world_players, _cooldowns, delta)

func _queue_global(cue: String) -> void:
	_pending_cues[cue] = true

func play_ui(kind := "ui_confirm") -> void:
	if kind in ["ui_confirm", "ui_cancel"]: _ui_pending[kind] = true

func bind_controls(root: Node) -> void:
	_controls_root = root
	_bind_existing(root)
	if not get_tree().node_added.is_connected(_on_control_added):
		get_tree().node_added.connect(_on_control_added)

func _bind_existing(node: Node) -> void:
	if node is Button and not node.pressed.is_connected(_on_button.bind(node)):
		node.pressed.connect(_on_button.bind(node))
	for child in node.get_children(): _bind_existing(child)

func _on_control_added(node: Node) -> void:
	if is_instance_valid(_controls_root) and _controls_root.is_ancestor_of(node):
		_bind_existing(node)

func _on_button(button: Button) -> void:
	play_ui("ui_cancel" if button.text.contains("取消") or button.text.contains("返回") else "ui_confirm")

func _process(delta: float) -> void:
	if _audio == null: return
	_device_check_elapsed += delta
	if _device_check_elapsed >= _audio.device_check_seconds:
		_device_check_elapsed = 0.0
		var available := not AudioServer.get_output_device_list().is_empty() and DisplayServer.get_name() != "headless"
		if audio_available and not available and DisplayServer.get_name() != "headless":
			_notice.text = "音频输出已断开，游戏仍可继续。"
			availability_notice.emit(_notice.text)
		audio_available = available
	var paused := get_tree().paused
	if paused != _world_paused:
		_world_paused = paused
		for player in _world_players: player.stream_paused = paused
	_play_batch(_ui_pending, _ui_players, _ui_cooldowns, delta)
	_ui_pending.clear()

func _create_players(players: Array[AudioStreamPlayer], count: int) -> void:
	for index in count:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%s" % index
		add_child(player)
		player.set_meta("priority", 0)
		players.append(player)

func _play_batch(cues: Dictionary, players: Array[AudioStreamPlayer], cooldowns: Dictionary, delta: float) -> void:
	for kind in cooldowns: cooldowns[kind] = maxf(0.0, float(cooldowns[kind]) - delta)
	var ordered := cues.keys()
	ordered.sort_custom(func(a, b): return int(_cue_config[a].priority) > int(_cue_config[b].priority))
	for kind in ordered:
		if float(cooldowns.get(kind, 0.0)) > 0.0: continue
		var cue: Dictionary = _cue_config[kind]
		cooldowns[kind] = cue.cooldown
		if preferences.muted or not audio_available: continue
		var chosen: AudioStreamPlayer
		for player in players:
			if not player.playing:
				chosen = player
				break
			if int(player.get_meta("priority")) < int(cue.priority) and (chosen == null or int(player.get_meta("priority")) < int(chosen.get_meta("priority"))):
				chosen = player
		if chosen == null: continue
		chosen.stop()
		chosen.stream = _bank[kind]
		# Conservative worst-case sum bound, including simultaneous UI/world voices.
		var mix_gain := 1.0 / maxf(1.0, _audio.peak_gain * float(_audio.world_voices + _audio.ui_voices))
		chosen.volume_linear = preferences.master_volume * preferences.sfx_volume * float(cue.gain) * mix_gain
		chosen.set_meta("priority", cue.priority)
		chosen.play()
		last_played.append(kind)

func apply_preferences() -> void:
	for player in _world_players + _ui_players:
		if preferences.muted: player.stop()
		else: player.volume_linear = preferences.master_volume * preferences.sfx_volume * float(_audio.cue(_bank.find_key(player.stream)).gain) / maxf(1.0, _audio.peak_gain * float(_audio.world_voices + _audio.ui_voices)) if player.stream != null else 0.0
	if preferences.reduced_motion: effects.clear()

func reset() -> void:
	for player in _world_players + _ui_players:
		player.stop()
		player.queue_free()
	_world_players.clear()
	_ui_players.clear()
	effects.clear()
	_pending.clear()
	_pending_count = 0
	_overflow_cues.clear()
	_pending_cues.clear()
	_ui_pending.clear()
	_cooldowns.clear()
	_ui_cooldowns.clear()
	_bank.clear()
	_cue_config.clear()
	_session_phase = ""
	_warning_key = 0
	_world_paused = false
	decoration_time = 0.0
