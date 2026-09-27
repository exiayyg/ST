class_name CombatPauseOverlay
extends Control

signal resume_requested
signal retry_requested
signal return_requested
signal quit_requested
signal settings_requested
signal help_requested
signal tuning_requested

var _title: Label
var _return_button: Button
var _default_focus: Button
var _font_size: int


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func configure(profile: BalanceProfile) -> void:
	theme = EnergyTheme.build(profile)
	_font_size = int(profile.value("frontend/body_font_size"))
	for child in get_children():
		child.queue_free()
	var background := ColorRect.new()
	background.name = "PauseDim"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(
		Color(String(profile.value("visuals/hud_background_color", "090d14"))),
		float(profile.value("visuals/settlement_dim_alpha", 0.72))
	)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var panel := PanelContainer.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_size := Vector2(
		float(profile.value("frontend/pause_panel_width")),
		float(profile.value("frontend/pause_panel_height"))
	)
	panel.position = -panel_size * 0.5
	panel.size = panel_size
	panel.resized.connect(func(): panel.position = (size - panel.size) * 0.5)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(String(profile.value("visuals/hud_background_color", "090d14")))
	panel_style.border_color = Color(String(profile.value("visuals/hud_success_color", "5ee6a8")))
	var border_width := int(round(float(profile.value("visuals/settlement_panel_border_width", 2.0))))
	panel_style.set_border_width_all(border_width)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	var inner_margin := int(round(float(profile.value("frontend/outer_margin")) * 0.5))
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, inner_margin)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(round(float(profile.value("frontend/item_gap")))))
	margin.add_child(column)

	_title = Label.new()
	_title.text = "已暂停"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", int(profile.value("frontend/title_font_size")))
	_title.add_theme_color_override("font_color", Color(String(profile.value("visuals/hud_success_color", "5ee6a8"))))
	column.add_child(_title)
	var hint := Label.new()
	hint.text = "动量网络、敌人和波次计时均已冻结"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", int(profile.value("frontend/body_font_size")))
	hint.add_theme_color_override("font_color", Color(String(profile.value("visuals/hud_muted_color", "8190a8"))))
	column.add_child(hint)

	_default_focus = _make_button("继续", float(profile.value("frontend/button_height")))
	_default_focus.pressed.connect(func(): resume_requested.emit())
	column.add_child(_default_focus)
	var retry := _make_button("重新开始", float(profile.value("frontend/button_height")))
	retry.pressed.connect(func(): retry_requested.emit())
	column.add_child(retry)
	_return_button = _make_button("返回菜单", float(profile.value("frontend/button_height")))
	_return_button.pressed.connect(func(): return_requested.emit())
	column.add_child(_return_button)
	var settings_button := _make_button("视听设置", float(profile.value("frontend/button_height")))
	settings_button.pressed.connect(func(): settings_requested.emit())
	column.add_child(settings_button)
	var help := _make_button("操作说明", float(profile.value("frontend/button_height")))
	help.pressed.connect(func(): help_requested.emit())
	column.add_child(help)
	if OS.is_debug_build():
		var tuning := _make_button("数值编辑", float(profile.value("frontend/button_height")))
		tuning.pressed.connect(func(): tuning_requested.emit())
		column.add_child(tuning)
	var quit := _make_button("退出游戏", float(profile.value("frontend/button_height")))
	quit.pressed.connect(func(): quit_requested.emit())
	column.add_child(quit)


func open(return_label: String) -> void:
	if _return_button != null:
		_return_button.text = return_label
	visible = true
	if _default_focus != null:
		_default_focus.grab_focus()


func close() -> void:
	visible = false


func focus_default() -> void:
	_default_focus.grab_focus()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	pass # RuntimeMenuLayer owns modal keyboard precedence.


func _make_button(label: String, height: float) -> Button:
	var button := Button.new()
	button.text = label
	button.add_theme_font_size_override("font_size", _font_size)
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_ALL
	return button
