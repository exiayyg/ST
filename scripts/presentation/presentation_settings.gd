class_name PresentationSettings
extends AcceptDialog

var director: PresentationDirector
var _notice: Label

func configure(profile: BalanceProfile, presentation: PresentationDirector) -> void:
	director = presentation
	title = "视听设置"
	ok_button_text = "返回"
	min_size.x = int(profile.runtime_config().presentation.settings_width)
	theme = EnergyTheme.build(profile)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("screen_modal_dialog")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(profile.runtime_config().frontend.item_gap))
	add_child(column)
	for key in ["master_volume", "sfx_volume"]:
		var label := Label.new()
		label.text = "总音量" if key == "master_volume" else "音效音量"
		column.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = director.preferences.get(key)
		slider.value_changed.connect(func(value): _update(key, value))
		slider.drag_ended.connect(func(_changed): director.play_ui())
		column.add_child(slider)
	for key in ["muted", "reduced_motion"]:
		var checkbox := CheckBox.new()
		checkbox.text = "静音" if key == "muted" else "减少动态效果"
		checkbox.button_pressed = director.preferences.get(key)
		checkbox.toggled.connect(func(value): _update(key, value))
		column.add_child(checkbox)
	var preview := Button.new()
	preview.text = "试听确认音"
	preview.pressed.connect(func(): director.play_ui())
	column.add_child(preview)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.text = director.preferences.notice
	column.add_child(_notice)
	confirmed.connect(func(): director.play_ui("ui_cancel"))
	close_requested.connect(hide)
	canceled.connect(hide)

func _update(key: String, value) -> void:
	director.preferences.update(key, value)
	director.apply_preferences()
	_notice.text = director.preferences.notice

func open() -> void:
	popup_centered()
	get_ok_button().grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		director.play_ui("ui_cancel")
		hide()
		set_input_as_handled()
