class_name WorldMouseControls
extends Control

signal intent(command: StringName)
var _config: RuntimeBalance.ConstructionUx
var _fire: Button
var _pause: Button
var _remove: Button
var _label: Label

func configure(profile: BalanceProfile) -> void:
	_config = profile.runtime_config().construction_ux
	theme = EnergyTheme.build(profile)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fire = _button("AutoFire", "发射中")
	_fire.pressed.connect(func(): intent.emit(&"toggle_auto_fire"))
	_pause = _button("Pause", "暂停")
	_pause.pressed.connect(func(): intent.emit(&"pause"))
	_remove = _button("Dismantle", "按住拆除")
	_remove.button_down.connect(func(): intent.emit(&"dismantle_begin"))
	_remove.button_up.connect(func(): intent.emit(&"dismantle_end"))
	_remove.mouse_exited.connect(func(): intent.emit(&"dismantle_end"))
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	resized.connect(_layout)
	_layout()

func _button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(_config.action_button_width, _config.action_button_height)
	add_child(button)
	return button

func _layout() -> void:
	_pause.position = Vector2(size.x - _config.action_inset - _config.action_button_width, _config.action_inset)
	_fire.size.x = maxf(_config.action_button_width, _fire.get_minimum_size().x)
	_fire.position = _pause.position - Vector2(_fire.size.x + _config.action_inset, 0.0)
	_remove.position = Vector2(_config.action_inset, size.y - _config.action_button_height - _config.action_inset)
	_label.position = _remove.position - Vector2(0.0, _label.get_minimum_size().y + _config.action_inset)

func set_snapshot(view: Dictionary, terminal: bool) -> void:
	visible = not terminal
	_fire.text = "发射中 · 点击停火" if view.auto_fire else "已停火 · 点击发射"
	_fire.size.x = maxf(_config.action_button_width, _fire.get_minimum_size().x)
	_fire.position.x = _pause.position.x - _config.action_inset - _fire.size.x
	_remove.visible = int(view.selected_id) > 0 and not bool(view.interaction.radial_open)
	_label.visible = _remove.visible
	var text := ""
	for device: Dictionary in view.devices:
		if int(device.id) != int(view.selected_id): continue
		var definition := device.definition as DeviceDefinition
		var endpoint := (" · 入口" if int(view.selected_anchor) == 0 else " · 出口") if definition.kind == &"diode" else ""
		text = definition.display_name + endpoint + "\n按住左键并拖动 · 右键拖拽预览，松开固定"
		if definition.kind == &"accumulator": text += "\n短按左键释放全部存量"
	if _label.text != text:
		_label.text = text
		_layout()
