@tool
class_name BalancePanel
extends PanelContainer

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const EntropyCurveEditorType := preload("res://scripts/config/entropy_curve_editor.gd")
const BalanceFieldCatalogType := preload("res://scripts/config/balance_field_catalog.gd")

const EditSession := preload("res://scripts/config/balance_edit_session.gd")
const EditAdapter := preload("res://scripts/config/balance_edit_adapter.gd")
var edit_session: EditSession
var working: BalanceProfile:
	get: return edit_session.working
var baseline: BalanceProfile:
	get: return edit_session.baseline
var saved_profile: BalanceProfile:
	get: return edit_session.saved
var balance_service
var runtime_mode := false

func focus_search() -> void:
	_search.grab_focus()

func show_apply_error(errors: Array[String]) -> void:
	_status_label.text = "应用失败：%s" % ", ".join(errors)
	if runtime_mode and balance_service != null:
		edit_session.baseline = balance_service.active_profile().duplicate_profile()
		_sync_numeric_views()

var _content: VBoxContainer
var _error_label: Label
var _error_list: ItemList
var _status_label: Label
var _search: LineEdit
var _preview_entropy: SpinBox
var _preview_label: Label
var _path_controls: Dictionary = {}
var _group_controls: Array[Dictionary] = []
var _scroll: ScrollContainer
var _numeric_bindings: Array[Dictionary] = []
var _common_grid: GridContainer
var _source_preview: Label
var _state_label: Label
var _collapse_state: Dictionary = {}
const SECTION_ORDER := ["tower", "devices", "enemies", "levels", "waves", "entropy", "construction_ux", "map_camera", "visuals", "presentation", "audio", "frontend", "playtest", "fog", "simulation", "diagnostics", "schema_version"]
const COMMON_PATHS := ["tower/projectile_speed", "tower/fire_interval", "tower/projectile_mass", "tower/max_hp", "tower/light_radius", "entropy/start_entropy", "entropy/full_effect_entropy"]


func setup(profile: BalanceProfile, service = null, is_runtime := false) -> void:
	theme = preload("res://scripts/presentation/energy_theme.gd").build(profile)
	edit_session = EditSession.new()
	var adapter: EditAdapter
	if is_runtime:
		adapter = EditAdapter.Runtime.new()
	else:
		adapter = EditAdapter.Editor.new()
	adapter.target = service
	edit_session.initialize(profile, adapter, is_runtime)
	balance_service = service
	runtime_mode = is_runtime
	if not resized.is_connected(_layout_common):
		resized.connect(_layout_common)
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_path_controls.clear()
	_group_controls.clear()
	_numeric_bindings.clear()
	custom_minimum_size = Vector2(0.0, float(working.value("frontend/tuning_min_height")))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(String(working.value("visuals/hud_background_color")))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, float(working.value("frontend/tuning_common_gap")))
	add_theme_stylebox_override("panel", panel_style)
	var root := VBoxContainer.new()
	add_child(root)
	var title := Label.new()
	title.text = "一炮千径 · 统一数值面板%s" % ("（运行时工作副本）" if runtime_mode else "（项目配置）")
	title.add_theme_font_size_override("font_size", int(working.value("frontend/tuning_title_font_size")))
	root.add_child(title)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	_add_button(actions, "应用并重置", _apply_and_reset)
	_add_button(actions, "保存 JSON", _save)
	_add_button(actions, "重新加载", _reload)
	_add_button(actions, "撤销未应用", _restore_baseline)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索路径或字段名"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_filter_rows)
	actions.add_child(_search)
	_state_label = Label.new()
	root.add_child(_state_label)
	_build_common(root)
	var preview := HBoxContainer.new()
	root.add_child(preview)
	var preview_title := Label.new()
	preview_title.text = "熵响应预览"
	preview.add_child(preview_title)
	_preview_entropy = SpinBox.new()
	_preview_entropy.min_value = 0.0
	_preview_entropy.max_value = 1000000.0
	_preview_entropy.value = float(working.value("entropy/start_entropy", 50.0))
	_preview_entropy.value_changed.connect(func(_value): _refresh_preview())
	preview.add_child(_preview_entropy)
	_preview_label = Label.new()
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(_preview_label)
	_error_label = Label.new()
	root.add_child(_error_label)
	_error_list = ItemList.new()
	_error_list.custom_minimum_size.y = float(working.value("frontend/tuning_error_height"))
	_error_list.item_clicked.connect(_jump_to_error)
	root.add_child(_error_list)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	for section_name in SECTION_ORDER:
		if String(section_name) == "schema_version":
			_add_value_row(_content, "schema_version", working.data[section_name])
			continue
		_add_group(_content, BalanceFieldCatalogType.section_label(String(section_name)), working.data[section_name], String(section_name), 0)
	_status_label = Label.new()
	root.add_child(_status_label)
	_refresh_validation()
	_refresh_preview()
	_sync_numeric_views()


func _add_group(parent: VBoxContainer, title: String, value, path: String, depth: int) -> void:
	var button := Button.new()
	button.text = "%s%s" % ["  ".repeat(depth), title]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(button)
	var body := VBoxContainer.new()
	body.set_meta("balance_path", path.to_lower())
	parent.add_child(body)
	_group_controls.append({"button": button, "body": body, "path": path.to_lower()})
	if not _collapse_state.has(path):
		_collapse_state[path] = path in ["simulation", "diagnostics", "fog"]
	body.visible = not bool(_collapse_state[path])
	button.pressed.connect(func():
		_collapse_state[path] = not bool(_collapse_state[path])
		body.visible = not bool(_collapse_state[path])
	)
	if value is Dictionary:
		var skipped: Dictionary = {}
		for key in value.keys():
			if skipped.has(String(key)):
				continue
			var child_path := "%s/%s" % [path, key]
			var child = value[key]
			var pair := _vector_pair(path, String(key), value)
			if not pair.is_empty():
				_add_vector2_row(body, child_path, "%s/%s" % [path, pair.y_key], Vector2(float(child), float(value[pair.y_key])))
				skipped[pair.y_key] = true
				continue
			if child is Dictionary:
				_add_group(body, String(child.get("display_name", key)), child, child_path, depth + 1)
			elif child is Array:
				_add_array(body, String(key), child, child_path, depth + 1)
			else:
				_add_value_row(body, child_path, child)
	elif value is Array:
		_add_array(body, title, value, path, depth + 1)


func _add_array(parent: VBoxContainer, title: String, values: Array, path: String, depth: int) -> void:
	if _is_curve(values):
		var box := VBoxContainer.new()
		var descriptor := BalanceFieldCatalogType.descriptor(path, values)
		box.set_meta("balance_path", _search_text(path, descriptor))
		parent.add_child(box)
		var label := Label.new()
		label.text = "%s · 双击添加点，拖动中间点，右键删除" % descriptor.get("label", title)
		label.tooltip_text = "%s\n%s" % [path, descriptor.get("description", "")]
		box.add_child(label)
		var editor := EntropyCurveEditorType.new() as EntropyCurveEditor
		editor.set_points(values)
		editor.curve_changed.connect(func(points: Array):
			edit_session.edit(path, points)
			var original = baseline.value(path, [])
			label.modulate = Color("ffcf5c") if original != points else Color.WHITE
			label.text = "%s%s · 双击添加点，拖动中间点，右键删除" % [descriptor.get("label", title), "（已修改）" if original != points else ""]
			_refresh_validation()
			_refresh_preview()
		)
		box.add_child(editor)
		_path_controls[path] = box
		return
	for index in values.size():
		var child_path := "%s/%d" % [path, index]
		if values[index] is Dictionary or values[index] is Array:
			_add_group(parent, "%s[%d]" % [title, index], values[index], child_path, depth)
		else:
			_add_value_row(parent, child_path, values[index])


func _add_value_row(parent: VBoxContainer, path: String, current) -> void:
	var descriptor := BalanceFieldCatalogType.descriptor(path, current)
	var row := HBoxContainer.new()
	row.set_meta("balance_path", _search_text(path, descriptor))
	parent.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = float(working.value("frontend/tuning_field_label_width"))
	label.text = "%s%s  [%s]" % [descriptor.get("label", path.get_file()), _unit_suffix(descriptor), str(baseline.value(path, current))]
	label.tooltip_text = "%s\n%s" % [path, descriptor.get("description", "")]
	row.add_child(label)
	if current is bool:
		var check := CheckBox.new()
		check.button_pressed = current
		check.toggled.connect(func(value: bool): _set_working_value(path, value, label))
		row.add_child(check)
	elif current is int or current is float:
		var spin := SpinBox.new()
		spin.min_value = float(descriptor.get("minimum", -1000000000.0))
		spin.max_value = float(descriptor.get("maximum", 1000000000.0))
		spin.step = float(descriptor.get("step", 1.0 if bool(descriptor.get("integer", false)) else 0.01))
		if path == "tower/fire_interval":
			spin.step = 0.0 # Preserve the exact reciprocal of fractional shots per second.
		spin.value = float(current)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(value: float):
			_set_working_value(path, int(round(value)) if bool(descriptor.get("integer", false)) else value, label)
		)
		_numeric_bindings.append({"path": path, "spin": spin, "label": label, "reciprocal": false})
		row.add_child(spin)
		if String(descriptor.get("editor", "")) == "slider":
			var slider := HSlider.new()
			slider.min_value = spin.min_value
			slider.max_value = spin.max_value
			slider.step = spin.step
			slider.value = spin.value
			slider.custom_minimum_size.x = 150.0
			slider.value_changed.connect(func(value: float): spin.value = value)
			spin.value_changed.connect(func(value: float): slider.value = value)
			_numeric_bindings.back()["slider"] = slider
			row.add_child(slider)
	elif String(descriptor.get("editor", "")) == "color":
		var color := ColorPickerButton.new()
		color.color = Color(current)
		color.color_changed.connect(func(value: Color): _set_working_value(path, value.to_html(false), label))
		row.add_child(color)
	elif String(descriptor.get("editor", "")) == "enum":
		var options := OptionButton.new()
		var configured_options: Array = descriptor.get("options", [])
		for option in configured_options:
			options.add_item(String(option))
			if String(option) == String(current):
				options.select(options.item_count - 1)
		options.item_selected.connect(func(index: int): _set_working_value(path, options.get_item_text(index), label))
		row.add_child(options)
	else:
		var edit := LineEdit.new()
		edit.text = str(current)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(value: String): _set_working_value(path, value, label))
		row.add_child(edit)
	_path_controls[path] = row


func _set_working_value(path: String, value, label: Label) -> void:
	edit_session.edit(path, value)
	var original = baseline.value(path, value)
	label.modulate = Color("ffcf5c") if original != value else Color.WHITE
	var descriptor := BalanceFieldCatalogType.descriptor(path, value)
	var field_name := String(descriptor.get("label", path.get_file())) + _unit_suffix(descriptor)
	label.text = "%s  [%s → %s]" % [field_name, str(original), str(value)] if original != value else "%s  [%s]" % [field_name, str(original)]
	_refresh_validation()
	_refresh_preview()


func _refresh_validation() -> void:
	_sync_numeric_views()
	var errors := edit_session.errors()
	_error_label.text = "配置有效，修改将在统一重置后生效。" if errors.is_empty() else "配置错误（点击可跳转）："
	_error_label.modulate = Color("5ee6a8") if errors.is_empty() else Color("ff6b7a")
	_error_list.clear()
	_error_list.visible = not errors.is_empty()
	for error in errors:
		_error_list.add_item(error)
		_error_list.set_item_metadata(_error_list.item_count - 1, _extract_error_path(error))


func _refresh_preview() -> void:
	if _preview_label == null or working == null:
		return
	var entropy_value := float(_preview_entropy.value)
	var weight := working.entropy_weight(entropy_value)
	var angle := float(working.value("entropy/max_angle_deviation_degrees", 0.0)) * weight
	var speed := float(working.value("entropy/max_speed_deviation_ratio", 0.0)) * weight * 100.0
	var mass := float(working.value("entropy/max_mass_deviation_ratio", 0.0)) * weight * 100.0
	var diode_offset := float(working.value("entropy/max_diode_exit_offset", 0.0)) * weight
	var diode_angle := float(working.value("entropy/max_diode_angle_deviation_degrees", 0.0)) * weight
	var split_angle := float(working.value("entropy/max_split_direction_deviation_degrees", 0.0)) * weight
	var split_share := float(working.value("entropy/max_split_share_deviation_ratio", 0.0)) * weight * 100.0
	var enemy_aim := float(working.value("enemies/dev_ranged/aim_max_deviation_degrees", 0.0)) * weight
	var target_score := float(working.value("entropy/max_enemy_target_score_deviation_ratio", 0.0)) * weight * 100.0
	var shield_offset := float(working.value("entropy/max_enemy_shield_position_offset", 0.0)) * weight
	var reconstruction_momentum := float(working.value("devices/wave_converter/reconstruction_mass", 0.0)) * float(working.value("devices/wave_converter/reconstruction_speed", 0.0))
	_preview_label.text = ("权重 %.3f · 通用角 ±%.2f° · 速 ±%.1f%% · 质 ±%.1f%%\n" % [weight, angle, speed, mass]
		+ "二极管 ±%.1f px / ±%.2f° · 分流 ±%.2f° / ±%.1f%% · 敌瞄 ±%.2f° · 索敌 ±%.1f%% · 盾位 ±%.1f px · 重构 P %.2f" % [
			diode_offset, diode_angle, split_angle, split_share, enemy_aim, target_score, shield_offset, reconstruction_momentum,
		])


func _apply_and_reset() -> void:
	var failures := edit_session.apply()
	_sync_numeric_views()
	_status_label.text = "正在按工作副本重置……" if failures.is_empty() else "应用失败：%s" % ", ".join(failures)


func _save() -> void:
	var failures := edit_session.save()
	if failures.is_empty() and not runtime_mode:
		_build_ui()
	_sync_numeric_views()
	_status_label.text = "balance.json 已事务保存。" if failures.is_empty() else "保存失败：%s" % ", ".join(failures)


func _reload() -> void:
	if edit_session.reload():
		_build_ui()
	else:
		_status_label.text = "重新加载失败，当前工作副本未改变。"


func _restore_baseline() -> void:
	edit_session.undo()
	_build_ui()


func _filter_rows(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for control in _path_controls.values():
		var path := String(control.get_meta("balance_path", ""))
		control.visible = needle.is_empty() or path.contains(needle)
	for index in range(_group_controls.size() - 1, -1, -1):
		var group: Dictionary = _group_controls[index]
		var group_path := String(group.get("path", ""))
		var visible := needle.is_empty() or group_path.contains(needle)
		if not visible:
			var prefix := group_path + "/"
			for field_path in _path_controls.keys():
				if String(field_path).begins_with(prefix) and (_path_controls[field_path] as Control).visible:
					visible = true
					break
		(group.get("button") as Control).visible = visible
		(group.get("body") as Control).visible = visible and (not needle.is_empty() or not bool(_collapse_state.get(group_path, false)))


func _add_button(parent: Container, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _add_vector2_row(parent: VBoxContainer, x_path: String, y_path: String, current: Vector2) -> void:
	var row := HBoxContainer.new()
	var descriptor := BalanceFieldCatalogType.descriptor(x_path, current.x)
	row.set_meta("balance_path", _search_text(x_path, descriptor) + " " + y_path.to_lower())
	parent.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = float(working.value("frontend/tuning_field_label_width"))
	label.text = "%s [(%s, %s)]" % ["二维位置", str(current.x), str(current.y)]
	label.tooltip_text = "%s + %s" % [x_path, y_path]
	row.add_child(label)
	for axis in 2:
		var path := x_path if axis == 0 else y_path
		var spin := SpinBox.new()
		var axis_descriptor := BalanceFieldCatalogType.descriptor(path, current[axis])
		spin.prefix = "X " if axis == 0 else "Y "
		spin.min_value = float(axis_descriptor.get("minimum", -100000.0))
		spin.max_value = float(axis_descriptor.get("maximum", 100000.0))
		spin.step = float(axis_descriptor.get("step", 1.0))
		spin.value = current[axis]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var update_axis := func(value: float, bound_path: String):
			_set_working_value(bound_path, value, label)
		spin.value_changed.connect(update_axis.bind(path))
		row.add_child(spin)
	_path_controls[x_path] = row
	_path_controls[y_path] = row


func _vector_pair(parent_path: String, key: String, values: Dictionary) -> Dictionary:
	if parent_path == "map_camera" and key == "map_x" and values.has("map_y"):
		return {"y_key": "map_y"}
	if parent_path == "tower" and key == "position_x" and values.has("position_y"):
		return {"y_key": "position_y"}
	return {}


func _jump_to_error(index: int, _position: Vector2, _button: int) -> void:
	var path := String(_error_list.get_item_metadata(index))
	var control := _path_controls.get(path) as Control
	if control != null:
		for group in _group_controls:
			if path.begins_with(String(group.path) + "/"):
				(group.button as Control).show()
				(group.body as Control).show()
		control.visible = true
		_scroll.ensure_control_visible(control)


func _extract_error_path(error: String) -> String:
	for path in _path_controls.keys():
		if error.contains(String(path)):
			return String(path)
	return ""


func _search_text(path: String, descriptor: Dictionary) -> String:
	return (path + " " + String(descriptor.get("label", "")) + " " + String(descriptor.get("description", ""))).to_lower()


func _unit_suffix(descriptor: Dictionary) -> String:
	var unit := String(descriptor.get("unit", ""))
	return "（%s）" % unit if not unit.is_empty() else ""


func _is_curve(values: Array) -> bool:
	if values.size() < 2:
		return false
	for item in values:
		if item is not Dictionary or not item.has("x") or not item.has("y") or item.size() != 2:
			return false
	return true


func _build_common(parent: VBoxContainer) -> void:
	var heading := Button.new()
	heading.text = "常用参数"
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(heading)
	var common_body := VBoxContainer.new()
	parent.add_child(common_body)
	common_body.visible = not bool(_collapse_state.get("__common", false))
	heading.pressed.connect(func():
		common_body.visible = not common_body.visible
		_collapse_state["__common"] = not common_body.visible
	)
	_common_grid = GridContainer.new()
	_common_grid.add_theme_constant_override("h_separation", int(working.value("frontend/tuning_common_gap")))
	common_body.add_child(_common_grid)
	for path in COMMON_PATHS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_common_grid.add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = float(working.value("frontend/tuning_label_width"))
		row.add_child(label)
		var spin := SpinBox.new()
		var descriptor := BalanceFieldCatalogType.descriptor(path, working.value(path))
		var reciprocal: bool = path == "tower/fire_interval"
		spin.min_value = 1.0 / float(descriptor.maximum) if reciprocal else float(descriptor.minimum)
		spin.max_value = 1.0 / float(descriptor.minimum) if reciprocal and float(descriptor.minimum) > 0.0 else float(descriptor.maximum)
		spin.allow_greater = reciprocal and float(descriptor.minimum) == 0.0
		spin.step = 0.0 if reciprocal else float(descriptor.step)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(value: float):
			if reciprocal:
				if not is_finite(value) or value <= 0.0:
					_sync_numeric_views()
					return
				value = 1.0 / value
			_set_working_value(path, value, label)
		)
		row.add_child(spin)
		_numeric_bindings.append({"path": path, "spin": spin, "label": label, "reciprocal": reciprocal})
	_source_preview = Label.new()
	_source_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	common_body.add_child(_source_preview)
	_layout_common()


func _layout_common() -> void:
	if is_instance_valid(_common_grid):
		_common_grid.columns = 2 if size.x >= float(working.value("frontend/tuning_columns_breakpoint")) else 1


func _sync_numeric_views() -> void:
	for binding in _numeric_bindings:
		var value := float(working.value(binding.path))
		var original := float(baseline.value(binding.path))
		var displayed := 1.0 / value if binding.reciprocal and value > 0.0 else value
		var prior := 1.0 / original if binding.reciprocal and original > 0.0 else original
		(binding.spin as SpinBox).set_value_no_signal(displayed)
		if binding.has("slider"):
			(binding.slider as HSlider).set_value_no_signal(displayed)
		var descriptor := BalanceFieldCatalogType.descriptor(binding.path, value)
		var title := "每秒发射数（发/s）" if binding.reciprocal else String(descriptor.label) + _unit_suffix(descriptor)
		if binding.path == "tower/max_hp":
			title = "塔 HP（HP）"
		elif binding.path == "tower/light_radius":
			title = "塔照明半径（px）"
		(binding.label as Label).text = "%s [%s → %s]" % [title, prior, displayed] if value != original else title
		(binding.label as Label).modulate = Color("ffcf5c") if value != original else Color.WHITE
	if is_instance_valid(_source_preview):
		var derived := edit_session.snapshot()
		var interval := float(derived.interval)
		var momentum := float(derived.momentum)
		_source_preview.text = "发射间隔 %s s · 单发动量 %s · 每秒源动量 %s" % [interval, momentum, momentum / interval if interval > 0.0 else 0.0]
	if is_instance_valid(_state_label):
		_state_label.text = "%s · %s" % [
			"当前生效" if runtime_mode and working.data == baseline.data else "未应用修改" if runtime_mode else "编辑器工作副本",
			"已保存" if working.data == saved_profile.data else "有未保存修改"
		]
