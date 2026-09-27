class_name FrontendController
extends Control

const ScreenModalCoordinatorType := preload("res://scripts/runtime/screen_modal_coordinator.gd")

const BalanceOverlayType := preload("res://scripts/config/balance_runtime_overlay.gd")

var _profile: BalanceProfile
var _campaign_service: Node
var _main_view: VBoxContainer
var _level_view: VBoxContainer
var _status_label: Label
var _balance_overlay: BalanceRuntimeOverlay
var _body_font_size: int
var _button_height: float
var _card_height: float
var _item_gap: float
var _help: AcceptDialog
var _playtest_consent: ConfirmationDialog
var _record_consent: CheckBox
var presentation: PresentationDirector
var _presentation_settings: PresentationSettings
var modal: ScreenModalCoordinatorType


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_campaign_service = get_node_or_null("/root/_campaign_service")
	var balance_service := get_node_or_null("/root/_balance_service")
	_profile = balance_service.active_profile() if balance_service != null else null
	if _profile == null:
		push_error("前端无法加载 BalanceProfile")
		return
	_body_font_size = int(_profile.value("frontend/body_font_size"))
	_button_height = float(_profile.value("frontend/button_height"))
	_card_height = float(_profile.value("frontend/card_height"))
	_item_gap = float(_profile.value("frontend/item_gap"))
	theme = EnergyTheme.build(_profile)
	presentation = PresentationDirector.new()
	add_child(presentation)
	presentation.configure(_profile)
	_presentation_settings = PresentationSettings.new()
	add_child(_presentation_settings)
	_presentation_settings.configure(_profile, presentation)
	_build_interface()
	presentation.bind_controls(self)
	_balance_overlay = BalanceOverlayType.new() as BalanceRuntimeOverlay
	_balance_overlay.name = "BalanceRuntimeOverlay"
	add_child(_balance_overlay)
	modal = ScreenModalCoordinatorType.new()
	modal.name = "ScreenModalCoordinatorType"
	add_child(modal)
	modal.configure(_balance_overlay)
	var show_levels := false
	if _campaign_service != null and _campaign_service.has_method("consume_frontend_level_target"):
		show_levels = bool(_campaign_service.consume_frontend_level_target())
	_show_levels() if show_levels else _show_main()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _balance_overlay != null and _balance_overlay.close_panel():
			get_viewport().set_input_as_handled()
			return
		if _level_view != null and _level_view.visible:
			_show_main()
			get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(String(_profile.value("visuals/world_background_color", "05080d")))
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var energy_background := EnergyBackdrop.new()
	add_child(energy_background)
	energy_background.configure(_profile, presentation.preferences)

	var outer := MarginContainer.new()
	outer.name = "OuterMargin"
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer_margin := int(round(float(_profile.value("frontend/outer_margin"))))
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, outer_margin)
	add_child(outer)
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	outer.add_child(center)
	var content := VBoxContainer.new()
	content.name = "FrontEndContent"
	content.custom_minimum_size.x = float(_profile.value("frontend/content_width"))
	content.add_theme_constant_override("separation", int(round(_item_gap)))
	center.add_child(content)

	var title := Label.new()
	title.text = "一炮千径"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(_profile.value("frontend/title_font_size")))
	title.add_theme_color_override("font_color", Color(String(_profile.value("visuals/hud_success_color", "5ee6a8"))))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "SINGULAR TOWER · 编织唯一动量源"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", int(_profile.value("frontend/subtitle_font_size")))
	subtitle.add_theme_color_override("font_color", Color(String(_profile.value("visuals/hud_muted_color", "8190a8"))))
	content.add_child(subtitle)
	content.add_child(HSeparator.new())

	_main_view = VBoxContainer.new()
	_main_view.name = "MainModeView"
	_main_view.add_theme_constant_override("separation", int(round(_item_gap)))
	content.add_child(_main_view)
	_build_main_view()
	_level_view = VBoxContainer.new()
	_level_view.name = "LevelSelectView"
	_level_view.add_theme_constant_override("separation", int(round(_item_gap)))
	content.add_child(_level_view)
	_build_level_view()

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", _body_font_size)
	_status_label.add_theme_color_override("font_color", Color(String(_profile.value("visuals/hud_warning_color", "ffcf5c"))))
	content.add_child(_status_label)
	if _campaign_service == null:
		_status_label.text = "关卡服务未加载"
	elif not String(_campaign_service.progress_notice).is_empty():
		_status_label.text = String(_campaign_service.progress_notice)
	elif not (_campaign_service.errors as Array).is_empty():
		_status_label.text = "部分内容无法载入，请检查项目配置。"


func _build_main_view() -> void:
	var heading := _make_label("选择运行方式", true)
	_main_view.add_child(heading)
	var campaign := _make_button("关卡模式", _button_height)
	campaign.pressed.connect(_show_levels)
	_main_view.add_child(campaign)
	var endless := _make_button("无尽模式", _button_height)
	endless.pressed.connect(_launch_endless)
	_main_view.add_child(endless)
	var settings_button := _make_button("视听设置", _button_height)
	settings_button.pressed.connect(_presentation_settings.open)
	_main_view.add_child(settings_button)
	var help_button := _make_button("操作说明", _button_height)
	help_button.pressed.connect(_show_help)
	_main_view.add_child(help_button)
	var quit_button := _make_button("退出游戏", _button_height)
	quit_button.pressed.connect(func(): get_tree().quit())
	_main_view.add_child(quit_button)
	if should_show_development_entries(OS.is_debug_build()):
		var dev_heading := _make_label("开发场景", false)
		dev_heading.add_theme_color_override("font_color", Color(String(_profile.value("visuals/hud_warning_color", "ffcf5c"))))
		_main_view.add_child(dev_heading)
		var playtest := _make_button("首关试玩", _button_height)
		playtest.pressed.connect(_show_playtest_consent)
		_main_view.add_child(playtest)
		var single_wave := _make_button("DEV · 单波战斗回归", _button_height)
		single_wave.pressed.connect(func(): _launch_development("res://scenes/combat/combat_sandbox.tscn", &"single_wave"))
		_main_view.add_child(single_wave)
		var network_lab := _make_button("DEV · 九装置建造实验场", _button_height)
		network_lab.pressed.connect(func(): _launch_development("res://scenes/prototype/momentum_prototype.tscn"))
		_main_view.add_child(network_lab)


func _build_level_view() -> void:
	_level_view.add_child(_make_label("关卡模式", true))
	var levels: Array[Dictionary] = []
	if _campaign_service != null and _campaign_service.has_method("levels_snapshot"):
		levels = _campaign_service.levels_snapshot()
	for entry in levels:
		var completed := bool(entry.get("completed", false))
		var locked := bool(entry.get("locked", true))
		var best := float(entry.get("best_utilization", 0.0))
		var state_text := "%s · 最佳利用率 %.1f%%" % ["已完成" if completed else "尚未完成", best * 100.0]
		if locked:
			state_text = "尚未解锁"
		var button := _make_button(
			"%s\n%s\n%s" % [entry.get("display_name", entry.get("id", "")), entry.get("description", ""), state_text],
			_card_height
		)
		button.disabled = locked
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var level_id := StringName(entry.get("id", &""))
		button.pressed.connect(_launch_level.bind(level_id))
		_level_view.add_child(button)
	var back := _make_button("返回", _button_height)
	back.pressed.connect(_show_main)
	_level_view.add_child(back)


func _show_main() -> void:
	_main_view.visible = true
	_level_view.visible = false
	var focus := _first_button(_main_view)
	if focus != null:
		focus.grab_focus()


func _show_levels() -> void:
	_main_view.visible = false
	_level_view.visible = true
	var focus := _first_button(_level_view)
	if focus != null:
		focus.grab_focus()


func _launch_level(level_id: StringName) -> void:
	if _campaign_service == null:
		_set_status("关卡服务未加载")
		return
	_report_navigation_error(int(_campaign_service.launch_level(level_id)))


func _launch_endless() -> void:
	if _campaign_service == null:
		_set_status("关卡服务未加载")
		return
	_report_navigation_error(int(_campaign_service.launch_endless()))


func _launch_development(scene_path: String, session_kind: StringName = &"") -> void:
	if _campaign_service == null:
		_set_status("关卡服务未加载")
		return
	_report_navigation_error(int(_campaign_service.launch_development_scene(scene_path, session_kind)))


func _report_navigation_error(error: int) -> void:
	if error != OK:
		_set_status("无法打开目标场景（错误 %d）" % error)


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _make_label(text: String, prominent: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(_profile.value(
		"frontend/subtitle_font_size" if prominent else "frontend/body_font_size"
	)))
	label.add_theme_color_override("font_color", Color(String(_profile.value("visuals/hud_text_color", "dce7f7"))))
	return label


func _make_button(label: String, height: float) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", _body_font_size)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _first_button(container: Container) -> Button:
	for child in container.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
	return null


static func should_show_development_entries(debug_build: bool) -> bool:
	return debug_build


func _show_help() -> void:
	if _help == null:
		_help = AcceptDialog.new()
		_help.title = "操作说明"
		_help.ok_button_text = "返回"
		_help.dialog_text = "亮区空地长按左键：打开九装置轮盘，选择后松开放置。\n二极管一次生成整对；按住并拖动端点，右键拖拽预览旋转，松开固定。\n选中后按住拆除按钮；短按蓄积器释放，按住并拖动移动。\n中键拖动平移，滚轮缩放；右上角切换自动发射和暂停。\nEsc 优先取消当前操作，再打开暂停菜单。"
		if OS.is_debug_build():
			_help.dialog_text += "\n开发功能：F2 暂停并调参数，F3 查看性能诊断。"
		_help.min_size.x = int(_profile.value("frontend/confirmation_width"))
		add_child(_help)
	_help.popup_centered()

func _show_playtest_consent() -> void:
	if _playtest_consent == null:
		_playtest_consent = ConfirmationDialog.new()
		_playtest_consent.name = "PlaytestConsent"
		_playtest_consent.title = "首关试玩"
		_playtest_consent.ok_button_text = "开始试玩"
		_playtest_consent.cancel_button_text = "取消"
		_playtest_consent.min_size.x = int(_profile.runtime_config().playtest.consent_width)
		add_child(_playtest_consent)
		_playtest_consent.add_to_group("screen_modal_dialog")
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", int(_item_gap))
		_playtest_consent.add_child(content)
		var explanation := _make_label("从头体验首关，不影响正式成绩。\n记录仅保存在本机，不联网、不录屏，\n不采集原始按键或个人身份。未同意也可正常试玩。", false)
		content.add_child(explanation)
		_record_consent = CheckBox.new()
		_record_consent.name = "RecordConsent"
		_record_consent.text = "同意记录本次试玩"
		content.add_child(_record_consent)
		_playtest_consent.confirmed.connect(func():
			_report_navigation_error(int(_campaign_service.launch_playtest(&"diode_tutorial", _record_consent.button_pressed))))
	_record_consent.button_pressed = false
	_playtest_consent.popup_centered()
	_playtest_consent.get_cancel_button().grab_focus()
