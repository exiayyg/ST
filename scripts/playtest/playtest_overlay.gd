class_name PlaytestOverlay
extends CanvasLayer

## Presentation/lifecycle adapter. Paused sampling never advances the world.
var recorder: PlaytestRecorder
var _notice: Label
var _actions: HBoxContainer
var _dialog: ConfirmationDialog
var _fields: Dictionary = {}
var _last_frame: Dictionary = {}
var _profile: BalanceProfile

func configure(profile: BalanceProfile, observer: PlaytestRecorder) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile = profile
	recorder = observer
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.add_theme_constant_override("separation", int(profile.runtime_config().frontend.item_gap))
	add_child(column)
	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color(profile.runtime_config().visuals.hud_warning_color))
	column.add_child(_notice)
	_actions = HBoxContainer.new()
	_actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_actions.anchor_top = 0.5
	_actions.anchor_bottom = 0.5
	_actions.offset_top = profile.runtime_config().visuals.settlement_panel_height * 0.5 + profile.runtime_config().frontend.item_gap
	_actions.offset_bottom = _actions.offset_top + profile.runtime_config().frontend.button_height
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_actions)
	_actions.hide()
	var open := Button.new()
	open.text = "打开报告目录"
	open.custom_minimum_size.y = profile.runtime_config().frontend.button_height
	open.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path(recorder.report_directory())))
	_actions.add_child(open)
	var feedback := Button.new()
	feedback.text = "填写试玩意见（可跳过）"
	feedback.pressed.connect(_show_feedback)
	_actions.add_child(feedback)
	recorder.recording_failed.connect(show_notice)

func observe(delta: float, view: Dictionary) -> void:
	if not recorder.is_recording():
		return
	var session: Dictionary = view.session
	var stats: Dictionary = session.get("stats", view.stats)
	var diagnostic: Dictionary = session.get("debug", {})
	_last_frame = {"wave_index": session.get("wave_index", 0),
		"tutorial_phase": session.get("tutorial_phase", ""), "phase": session.get("phase", ""),
		"stats": stats.duplicate(true),
		"actual_damage": view.stats.get("damage_dealt", 0.0),
		"tower_source_momentum": stats.get("tower_source_momentum", 0.0),
		"live_source_momentum": view.stats.get("tower_source_momentum", 0.0),
		"utilization": stats.get("utilization", 0.0),
		"enemy_count": session.get("alive_enemies", 0),
		"visible_enemy_count": view.get("visible_enemy_count", 0), "tower_hp": view.tower_hp,
		"auto_fire": view.auto_fire, "device_losses": diagnostic.get("device_losses", 0),
		"no_damage_seconds": diagnostic.get("no_damage_seconds", 0.0),
		"maximum_no_damage_seconds": diagnostic.get("maximum_no_damage_seconds", 0.0)}
	recorder.observe_frame(delta, _last_frame)

func _process(delta: float) -> void:
	if get_tree().paused and recorder != null and recorder.is_recording():
		recorder.observe_frame(delta, _last_frame, true)

func show_terminal() -> void:
	_actions.visible = not recorder.report_directory().is_empty()

func show_notice(text: String) -> void:
	_notice.text = text

func _show_feedback() -> void:
	if _dialog == null:
		_dialog = ConfirmationDialog.new()
		_dialog.title = "本机试玩意见（可留空；请勿填写个人信息）"
		_dialog.ok_button_text = "保存意见"
		_dialog.cancel_button_text = "跳过"
		_dialog.min_size.x = int(_profile.runtime_config().playtest.consent_width)
		add_child(_dialog)
		_dialog.add_to_group("screen_modal_dialog")
		var column := VBoxContainer.new()
		_dialog.add_child(column)
		for field in {"stuck": "卡在哪里", "unclear": "哪里看不懂", "other": "其他意见"}:
			var input := TextEdit.new()
			input.placeholder_text = {"stuck": "卡在哪里", "unclear": "哪里看不懂", "other": "其他意见"}[field]
			input.custom_minimum_size.y = _profile.runtime_config().playtest.feedback_field_height
			column.add_child(input)
			_fields[field] = input
		_dialog.confirmed.connect(func():
			var feedback := {}
			for field in _fields:
				feedback[field] = _fields[field].text
			if recorder.submit_feedback(feedback):
				show_notice("试玩意见已保存在本机。"))
	_dialog.popup_centered()
	_dialog.get_cancel_button().grab_focus()
