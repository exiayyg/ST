class_name CombatHud
extends Control

signal restart_requested
signal return_requested
signal save_retry_requested

var profile: BalanceProfile
var enemy_definitions: Dictionary
var mode: StringName = &"single_wave"
var wave_name := ""
var wave_index := 1
var completed_waves := 0
var phase: StringName = &"idle"
var alive_enemies := 0
var remaining := 0.0
var utilization := 0.0
var target := 0.0
var target_reached := false
var state_text := ""
var result: StringName
var terminal := false
var warnings: Dictionary = {}
var selected_direction := ""
var debug_visible := false
var stats: Dictionary = {}
var debug_info: Dictionary = {}
var instruction_key: StringName
var target_flash_remaining := 0.0
var _target_was_reached := false
var color_background := Color("090d14")
var color_text := Color("dce7f7")
var color_muted := Color("8190a8")
var color_success := Color("5ee6a8")
var color_warning := Color("ffcf5c")
var color_danger := Color("ff5d6c")
var top_bar_height := 68.0
var target_flash_seconds := 0.8
var target_flash_alpha := 0.28
var settlement_dim_alpha := 0.72
var settlement_panel_width := 520.0
var settlement_panel_height := 290.0
var settlement_panel_border_width := 2.0
var settlement_button_width := 220.0
var settlement_button_height := 44.0
var settlement_title_font_size := 30
var settlement_body_font_size := 18
var settlement_button_font_size := 18
var settlement_button_gap := 12.0
var playtest_navigation := false
var campaign_navigation := false
var _retry_button: Button
var _return_button: Button
var _save_button: Button
var _save_failed := false
const RuntimeBalanceType := preload("res://scripts/config/runtime_balance.gd")
var _visual_config: RuntimeBalanceType.Visuals


func configure(balance_profile: BalanceProfile, definitions: Dictionary) -> void:
	profile = balance_profile
	theme = EnergyTheme.build(profile)
	_visual_config = profile.runtime_config().visuals
	enemy_definitions = definitions
	color_background = Color(String(profile.value("visuals/hud_background_color", color_background.to_html(false))))
	color_text = Color(String(profile.value("visuals/hud_text_color", color_text.to_html(false))))
	color_muted = Color(String(profile.value("visuals/hud_muted_color", color_muted.to_html(false))))
	color_success = Color(String(profile.value("visuals/hud_success_color", color_success.to_html(false))))
	color_warning = Color(String(profile.value("visuals/hud_warning_color", color_warning.to_html(false))))
	color_danger = Color(String(profile.value("visuals/hud_danger_color", color_danger.to_html(false))))
	top_bar_height = float(profile.value("visuals/hud_top_bar_height", top_bar_height))
	target_flash_seconds = float(profile.value("visuals/target_reached_flash_seconds", target_flash_seconds))
	target_flash_alpha = float(profile.value("visuals/target_reached_flash_alpha", target_flash_alpha))
	settlement_dim_alpha = float(profile.value("visuals/settlement_dim_alpha", settlement_dim_alpha))
	settlement_panel_width = float(profile.value("visuals/settlement_panel_width", settlement_panel_width))
	settlement_panel_height = float(profile.value("visuals/settlement_panel_height", settlement_panel_height))
	settlement_panel_border_width = float(profile.value("visuals/settlement_panel_border_width", settlement_panel_border_width))
	settlement_button_width = float(profile.value("visuals/settlement_button_width", settlement_button_width))
	settlement_button_height = float(profile.value("visuals/settlement_button_height", settlement_button_height))
	settlement_title_font_size = int(profile.value("visuals/settlement_title_font_size", settlement_title_font_size))
	settlement_body_font_size = int(profile.value("visuals/settlement_body_font_size", settlement_body_font_size))
	settlement_button_font_size = int(profile.value("visuals/settlement_button_font_size", settlement_button_font_size))
	settlement_button_gap = float(profile.value("frontend/item_gap"))
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	_retry_button = _action_button("重试", func(): restart_requested.emit())
	_return_button = _action_button("返回", func(): return_requested.emit())
	_save_button = _action_button("成绩未保存 · 重试保存", func(): save_retry_requested.emit())
	resized.connect(_layout_actions)


func set_state(director: WaveDirector, new_stats: Dictionary, tower: TowerController) -> void:
	var phase_name: StringName
	match director.state:
		WaveDirector.State.ACTIVE: phase_name = &"active"
		WaveDirector.State.TARGET_REACHED: phase_name = &"clearing"
		WaveDirector.State.FINISHED: phase_name = &"finished"
		WaveDirector.State.FAILED: phase_name = &"failed"
		_: phase_name = &"idle"
	set_snapshot({
		"mode": &"single_wave",
		"wave_name": director.display_name(),
		"wave_index": 1,
		"completed_waves": 1 if director.result == &"success" else 0,
		"phase": phase_name,
		"remaining": director.remaining_time(),
		"stats": new_stats,
		"target_utilization": director.target_utilization,
		"target_reached": director.target_latched,
		"warnings": director.latest_warnings,
		"result": director.result,
		"terminal": director.is_terminal(),
		"alive_enemies": director.enemy_manager.alive_count(),
		"debug": director.debug_snapshot(),
	}, tower)


func set_snapshot(snapshot: Dictionary, tower = null) -> void:
	var was_terminal := terminal
	mode = StringName(snapshot.get("mode", &"single_wave"))
	wave_name = String(snapshot.get("wave_name", ""))
	wave_index = int(snapshot.get("wave_index", 1))
	completed_waves = int(snapshot.get("completed_waves", 0))
	phase = StringName(snapshot.get("phase", &"idle"))
	remaining = float(snapshot.get("remaining", 0.0))
	stats = (snapshot.get("stats", {}) as Dictionary).duplicate(true)
	utilization = float(stats.get("utilization", 0.0))
	target = float(snapshot.get("target_utilization", 0.0))
	target_reached = bool(snapshot.get("target_reached", false))
	alive_enemies = int(snapshot.get("alive_enemies", 0))
	if target_reached and not _target_was_reached:
		target_flash_remaining = target_flash_seconds
	_target_was_reached = target_reached
	warnings = (snapshot.get("warnings", {}) as Dictionary).duplicate(true)
	if not selected_direction.is_empty() and not warnings.has(selected_direction):
		selected_direction = ""
	debug_info = (snapshot.get("debug", {}) as Dictionary).duplicate(true)
	instruction_key = StringName(snapshot.get("instruction_key", &""))
	result = StringName(snapshot.get("result", &""))
	terminal = bool(snapshot.get("terminal", false))
	_layout_actions()
	if terminal and not was_terminal:
		_focus_default()
	mouse_filter = Control.MOUSE_FILTER_STOP if terminal else Control.MOUSE_FILTER_PASS
	match phase:
		&"tutorial": state_text = "路径教学"
		&"preparing": state_text = "首波准备"
		&"clearing": state_text = "目标已达成 · 清除剩余敌人 %d" % alive_enemies
		&"intermission": state_text = "实时休整"
		&"finished": state_text = "波次完成"
		&"failed": state_text = "失败：%s" % _result_reason()
		_: state_text = "塔 HP %.0f / %.0f" % [float(snapshot.get("tower_hp", tower.hp if tower != null else 0.0)), float(snapshot.get("tower_max_hp", tower.max_hp if tower != null else 0.0))]
	queue_redraw()


func set_campaign_navigation(enabled: bool) -> void:
	campaign_navigation = enabled
	if terminal:
		_focus_default()
	queue_redraw()


func request_default_terminal_action() -> void:
	if not terminal:
		return
	if campaign_navigation and result == &"success":
		return_requested.emit()
	else:
		restart_requested.emit()


func toggle_debug() -> void:
	debug_visible = not debug_visible
	queue_redraw()


func _process(delta: float) -> void:
	if target_flash_remaining <= 0.0:
		return
	target_flash_remaining = maxf(0.0, target_flash_remaining - delta)
	queue_redraw()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, Vector2(viewport_size.x, top_bar_height)), color_background)
	if target_flash_remaining > 0.0:
		var flash_ratio := target_flash_remaining / maxf(target_flash_seconds, 0.000001)
		draw_rect(Rect2(Vector2.ZERO, Vector2(viewport_size.x, top_bar_height)), Color(color_success, target_flash_alpha * flash_ratio))
	draw_string(ThemeDB.fallback_font, Vector2(22.0, 28.0), "波次 %d  %s" % [wave_index, wave_name],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, color_text)
	draw_string(ThemeDB.fallback_font, Vector2(22.0, 54.0), _time_label(),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, color_muted)
	draw_string(ThemeDB.fallback_font, Vector2(260.0, 43.0), "动量利用率 %.1f%% / 目标 %.1f%%" % [utilization * 100.0, target * 100.0],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, color_success if target_reached else color_text)
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x - 230.0, 42.0), state_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, color_warning)
	for direction in warnings.keys():
		_draw_warning(String(direction), warnings[direction])
	if not instruction_key.is_empty() and not terminal:
		_draw_tutorial_instruction(viewport_size)
	if not selected_direction.is_empty() and warnings.has(selected_direction):
		_draw_warning_panel(selected_direction, warnings[selected_direction])
	if debug_visible:
		draw_rect(Rect2(14.0, top_bar_height + 16.0, 430.0, 184.0), Color(color_background, 0.85))
		var debug := ("F3 诊断 · seed %d · %s\n" % [int(debug_info.get("run_seed", 0)), String(debug_info.get("template_id", ""))]
			+ "预算 %.1f · 倍率 HP %.2f / 伤 %.2f / 速 %.2f\n" % [float(debug_info.get("threat_budget", 0.0)), float(debug_info.get("hp_multiplier", 1.0)), float(debug_info.get("damage_multiplier", 1.0)), float(debug_info.get("speed_multiplier", 1.0))]
			+ "背压 %s · 累计延后 %d\n" % ["是" if bool(debug_info.get("spawn_backpressure_active", false)) else "否", int(debug_info.get("spawn_backpressure_deferred", 0))]
			+ "弹体 %d · 波点 %d · 敌人 %d\n固定步 %.3f ms · 敌碰候选 %d" % [
			int(stats.get("projectile_count", 0)), int(stats.get("wave_point_count", 0)),
			int(stats.get("enemy_proxy_count", 0)), float(stats.get("last_step_milliseconds", 0.0)),
			int(stats.get("enemy_candidate_checks", 0))])
		draw_multiline_string(ThemeDB.fallback_font, Vector2(28.0, top_bar_height + 40.0), debug,
			HORIZONTAL_ALIGNMENT_LEFT, 400.0, 16, -1, color_muted)
	if terminal:
		_draw_settlement(viewport_size)


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if terminal:
		var viewport_size := get_viewport_rect().size
		if _settlement_button_rect(viewport_size).has_point(event.position):
			restart_requested.emit()
			accept_event()
			return
		if _settlement_return_button_rect(viewport_size).has_point(event.position):
			return_requested.emit()
			accept_event()
			return
	for direction in warnings.keys():
		if _warning_rect(String(direction)).has_point(event.position):
			selected_direction = String(direction)
			queue_redraw()
			accept_event()
			return


func _has_point(point: Vector2) -> bool:
	if terminal:
		return true
	for direction in warnings.keys():
		if _warning_rect(String(direction)).has_point(point):
			return true
	return false


func _draw_warning(direction: String, entry: Dictionary) -> void:
	var rect := _warning_rect(direction)
	var pressure := float(entry.get("pressure", 0.0))
	var low := float(profile.value("visuals/warning_low_threshold", 4.0))
	var high := float(profile.value("visuals/warning_high_threshold", 10.0))
	var color := color_success if pressure < low else color_warning if pressure < high else color_danger
	var center := rect.get_center()
	var direction_vector := _direction_vector(direction)
	var tangent := direction_vector.orthogonal()
	var points := PackedVector2Array([
		center + direction_vector * 28.0,
		center - direction_vector * 20.0 + tangent * 20.0,
		center - direction_vector * 20.0 - tangent * 20.0,
	])
	draw_colored_polygon(points, Color(color, 0.9))
	draw_string(ThemeDB.fallback_font, center + Vector2(-18.0, 40.0), "%.0f" % pressure,
		HORIZONTAL_ALIGNMENT_CENTER, 36.0, 15, color)


func _draw_warning_panel(direction: String, entry: Dictionary) -> void:
	var viewport_size := get_viewport_rect().size
	var rect := Rect2(viewport_size.x - 330.0, top_bar_height + 22.0, 310.0, 54.0 + float((entry.types as Dictionary).size()) * 28.0)
	draw_rect(rect, Color(color_background, 0.85))
	draw_rect(rect, color_muted, false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(16.0, 28.0), "%s方向来袭" % _direction_label(direction),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, color_text)
	var y := rect.position.y + 56.0
	for enemy_kind in (entry.types as Dictionary).keys():
		var definition := enemy_definitions.get(StringName(enemy_kind)) as EnemyDefinition
		var name := definition.display_name if definition != null else String(enemy_kind)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 16.0, y), "%s  × %d" % [name, int(entry.types[enemy_kind])],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, color_muted)
		y += 28.0


func _draw_settlement(viewport_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(color_background, settlement_dim_alpha))
	var panel_rect := _settlement_panel_rect(viewport_size)
	var accent := color_success if result == &"success" else color_danger
	draw_rect(panel_rect, color_background)
	draw_rect(panel_rect, accent, false, settlement_panel_border_width)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(0.0, 58.0), _result_title(),
		HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, settlement_title_font_size, accent)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(0.0, 108.0), "最终动量利用率  %.1f%%" % (utilization * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, settlement_body_font_size, color_text)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(0.0, 142.0), "本波目标  %.1f%%" % (target * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, settlement_body_font_size, color_muted)
	if mode == &"endless" or mode == &"tutorial":
		draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(0.0, 174.0), "已完成波次  %d" % completed_waves,
			HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, settlement_body_font_size, color_muted)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(0.0, 204.0 if mode == &"endless" or mode == &"tutorial" else 176.0), _result_reason(),
		HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, settlement_body_font_size, color_warning)


func _settlement_panel_rect(viewport_size: Vector2) -> Rect2:
	var extra_height := settlement_button_height + settlement_button_gap if _save_failed else 0.0
	var panel_size := Vector2(minf(settlement_panel_width, viewport_size.x - 32.0), minf(settlement_panel_height + extra_height, viewport_size.y - 32.0))
	return Rect2((viewport_size - panel_size) * 0.5, panel_size)


func _settlement_button_rect(viewport_size: Vector2) -> Rect2:
	var panel_rect := _settlement_panel_rect(viewport_size)
	var maximum_width := (panel_rect.size.x - 32.0 - settlement_button_gap) * 0.5
	var button_size := Vector2(minf(settlement_button_width, maximum_width), settlement_button_height)
	var extra_height := settlement_button_height + settlement_button_gap if _save_failed else 0.0
	return Rect2(Vector2(panel_rect.get_center().x - settlement_button_gap * 0.5 - button_size.x, panel_rect.end.y - button_size.y - 24.0 - extra_height), button_size)


func _settlement_return_button_rect(viewport_size: Vector2) -> Rect2:
	var retry_rect := _settlement_button_rect(viewport_size)
	return Rect2(Vector2(retry_rect.end.x + settlement_button_gap, retry_rect.position.y), retry_rect.size)


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.hide()
	button.add_theme_font_size_override("font_size", settlement_button_font_size)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _layout_actions() -> void:
	if not is_instance_valid(_retry_button):
		return
	var viewport_size := get_viewport_rect().size
	var retry_rect := _settlement_button_rect(viewport_size)
	var return_rect := _settlement_return_button_rect(viewport_size)
	_retry_button.position = retry_rect.position
	_retry_button.size = retry_rect.size
	_return_button.position = return_rect.position
	_return_button.size = return_rect.size
	_retry_button.text = "再试一次" if playtest_navigation else ("重新挑战" if result == &"success" else "重试")
	_return_button.text = "返回关卡选择" if campaign_navigation else "返回主菜单"
	_retry_button.visible = terminal
	_return_button.visible = terminal
	_save_button.visible = terminal and _save_failed
	_save_button.position = Vector2(retry_rect.position.x, retry_rect.end.y + settlement_button_gap)
	_save_button.size = Vector2(return_rect.end.x - retry_rect.position.x, retry_rect.size.y)
	_retry_button.focus_neighbor_right = _retry_button.get_path_to(_return_button)
	_return_button.focus_neighbor_left = _return_button.get_path_to(_retry_button)


func _focus_default() -> void:
	if is_instance_valid(_return_button):
		(_return_button if campaign_navigation and result == &"success" else _retry_button).grab_focus()


func set_save_failed(failed: bool) -> void:
	var was_failed := _save_failed
	_save_failed = failed
	_layout_actions()
	if was_failed and not failed and terminal:
		_focus_default()
	queue_redraw()


func _result_title() -> String:
	if mode == &"endless":
		return "DEV 无尽运行结束"
	if mode == &"tutorial":
		return "路径教学完成" if result == &"success" else "路径教学失败"
	if result == &"success":
		return "波次目标达成"
	if result == &"tower_destroyed":
		return "奇点塔已摧毁"
	return "波次目标未达成"


func _result_reason() -> String:
	match result:
		&"success": return "网络保持运转，目标利用率已经达到"
		&"tower_destroyed": return "中心塔 HP 归零，本局立即失败"
		&"timeout": return "时限结束时利用率仍低于目标"
		&"invalid_wave": return "无尽波次配置无效，本局已安全停止"
		&"invalid_level": return "教学关卡配置无效，本局已安全停止"
		_: return ""


func _time_label() -> String:
	match phase:
		&"tutorial": return "观察并操作战场"
		&"preparing": return "首波准备 %.1f s" % remaining
		&"intermission": return "下一波 %.1f s" % remaining
		&"clearing": return "清场中"
		_: return "剩余 %.1f s" % remaining


func _draw_tutorial_instruction(viewport_size: Vector2) -> void:
	var text := _instruction_text()
	if text.is_empty():
		return
	var inset := profile.runtime_config().presentation.ui_inset
	var width := minf(_visual_config.tutorial_instruction_width, viewport_size.x - inset * 2.0)
	var paragraph := TextParagraph.new()
	paragraph.width = width - inset * 2.0
	paragraph.add_string(text, ThemeDB.fallback_font, theme.default_font_size)
	var height := maxf(_visual_config.tutorial_instruction_height, paragraph.get_size().y + inset + inset)
	var rect := Rect2(Vector2(inset, top_bar_height + inset), Vector2(width, height))
	draw_rect(rect, color_background)
	draw_rect(rect, color_success, false, profile.runtime_config().presentation.line_width)
	paragraph.draw(get_canvas_item(), rect.position + Vector2(inset, inset), color_text)


func _instruction_text() -> String:
	match instruction_key:
		&"observe_unique_path": return "观察：所有初始弹丸都从唯一炮口沿同一条路径前进"
		&"place_practice_diode": return "亮区长按左键选择二极管，松开一次放置整对端点"
		&"dismantle_practice_diode": return "选中刚才的二极管，按住“拆除”按钮完成练习"
		&"build_north_route": return "入口接入初始弹道；按住并拖动出口到北侧，右键拖拽预览朝向并松开固定"
		&"defend_north": return "让重定向后的弹丸应对北侧来袭；装置仍可随时移动与旋转"
		&"route_connected": return "路径已接通。"
		&"first_effective_hit_offscreen": return "弹丸已在视野外命中敌人。"
		&"first_effective_hit": return "弹道已命中敌人，动量开始产生有效作用。"
		&"check_route_damage": return "近期没有造成有效伤害，检查出口位置和朝向。"
		&"route_node_lost": return "路径节点已被摧毁，需要重新接入。"
		&"route_node_removed": return "路径节点已被拆除，需要重新接入。"
		&"tower_stopped": return "当前已停止发射，点击右上角发射开关恢复。"
		&"target_reached_clear": return "目标已达到，清除剩余敌人。"
		&"prepare_second_wave": return "压制者会在远处攻击；移动出口可调整照明与弹道"
		&"tutorial_complete": return "你已经把唯一弹道改写为第一条装置路径"
		&"tutorial_failed": return "检查入口位置、出口朝向和装置生命值后重新尝试"
		_: return ""


func _warning_rect(direction: String) -> Rect2:
	var viewport_size := get_viewport_rect().size
	match direction:
		"west": return Rect2(12.0, viewport_size.y * 0.5 - 44.0, 88.0, 88.0)
		"north": return Rect2(viewport_size.x * 0.5 - 44.0, top_bar_height + 6.0, 88.0, 88.0)
		"south": return Rect2(viewport_size.x * 0.5 - 44.0, viewport_size.y - 100.0, 88.0, 88.0)
		_: return Rect2(viewport_size.x - 100.0, viewport_size.y * 0.5 - 44.0, 88.0, 88.0)


func _direction_vector(direction: String) -> Vector2:
	match direction:
		"west": return Vector2.LEFT
		"north": return Vector2.UP
		"south": return Vector2.DOWN
		_: return Vector2.RIGHT


func _direction_label(direction: String) -> String:
	match direction:
		"west": return "西"
		"north": return "北"
		"south": return "南"
		_: return "东"
