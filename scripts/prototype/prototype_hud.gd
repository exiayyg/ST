class_name PrototypeHud
extends Control

var stats: Dictionary = {}
var catalog: DeviceCatalog
var radial_open := false
var radial_center := Vector2.ZERO
var radial_hover := -1
var auto_fire := true
var _energy: RuntimeBalance.Presentation
var selected_context := ""
var has_selection := false
var _input_config: RuntimeBalance.ConstructionUx
var event_messages: Array[String] = []
var pending_diode := false
var show_prototype_status := true
var radial_radius := 112.0
var radial_dead_zone := 34.0
var color_background := Color("090d14")
var color_text := Color("dce7f7")
var color_muted := Color("8190a8")
var color_active := Color("5ee6a8")
var color_warning := Color("ffcf5c")


func configure(profile: BalanceProfile) -> void:
	_energy = profile.runtime_config().presentation
	_input_config = profile.runtime_config().construction_ux
	theme = EnergyTheme.build(profile)
	radial_radius = float(profile.value("construction_ux/radial_radius", radial_radius))
	radial_dead_zone = float(profile.value("construction_ux/radial_dead_zone", radial_dead_zone))
	color_background = Color(String(profile.value("visuals/hud_background_color", color_background.to_html(false))))
	color_text = Color(String(profile.value("visuals/hud_text_color", color_text.to_html(false))))
	color_muted = Color(String(profile.value("visuals/hud_muted_color", color_muted.to_html(false))))
	color_active = Color(String(profile.value("visuals/hud_success_color", color_active.to_html(false))))
	color_warning = Color(String(profile.value("visuals/hud_warning_color", color_warning.to_html(false))))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_state(
		new_stats: Dictionary,
		new_radial_open: bool,
		new_radial_center: Vector2,
		new_radial_hover: int,
		new_auto_fire: bool,
		new_pending_diode: bool
) -> void:
	stats = new_stats
	radial_open = new_radial_open
	radial_center = new_radial_center
	radial_hover = new_radial_hover
	auto_fire = new_auto_fire
	pending_diode = new_pending_diode
	queue_redraw()


func push_message(message: String) -> void:
	if not event_messages.is_empty() and event_messages[0] == message:
		return
	event_messages.push_front(message)
	if event_messages.size() > 4:
		event_messages.resize(4)


func _draw() -> void:
	var size := get_viewport_rect().size
	if show_prototype_status:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 68.0)), color_background)
		draw_string(ThemeDB.fallback_font, Vector2(22.0, 42.0), "SINGULAR TOWER  /  一炮千径",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, color_text)
		var utilization := float(stats.get("utilization", 0.0)) * 100.0
		var metrics := "利用率 %.1f%%   弹体 %d   波点 %d   固定步 %.2f ms" % [
			utilization,
			int(stats.get("projectile_count", 0)),
			int(stats.get("wave_point_count", 0)),
			float(stats.get("last_step_milliseconds", 0.0)),
		]
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 525.0 - _input_config.action_button_width * 3.0 - _input_config.action_inset, 40.0), metrics,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, color_active if utilization > 100.0 else color_text)
		draw_rect(Rect2(0.0, size.y - 42.0, size.x, 42.0), color_background)
		var controls := "长按左键建造 · 按住并拖动移动 · 右键预览旋转 · 点击蓄积器释放 · 中键移动 · 滚轮缩放"
		if not has_selection:
			draw_string(ThemeDB.fallback_font, Vector2(22.0, size.y - 15.0), controls,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, color_muted)
		var fire_text := "发射中" if auto_fire else "已暂停"
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 88.0, size.y - 15.0), fire_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, color_active if auto_fire else color_warning)
	var message_y := 98.0
	for message in (event_messages if show_prototype_status else []):
		draw_string(ThemeDB.fallback_font, Vector2(22.0, message_y), message,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(color_text, 0.78))
		message_y += 22.0
	if not selected_context.is_empty() and not radial_open:
		draw_multiline_string(ThemeDB.fallback_font, Vector2(_energy.ui_inset, size.y - _energy.ui_inset * 3.0), selected_context, HORIZONTAL_ALIGNMENT_LEFT, _energy.context_width, theme.default_font_size)
	if radial_open:
		_draw_radial_menu()


func _draw_radial_menu() -> void:
	if catalog == null:
		return
	var count := catalog.definitions.size()
	var sector_size := TAU / float(count)
	for index in count:
		var center_angle := -PI * 0.5 + float(index) * sector_size
		var points := PackedVector2Array()
		for step in 9:
			var angle := center_angle - sector_size * 0.48 + sector_size * 0.96 * float(step) / 8.0
			points.append(radial_center + Vector2.RIGHT.rotated(angle) * radial_radius)
		for step in range(8, -1, -1):
			var angle := center_angle - sector_size * 0.48 + sector_size * 0.96 * float(step) / 8.0
			points.append(radial_center + Vector2.RIGHT.rotated(angle) * radial_dead_zone)
		var definition := catalog.definitions[index]
		var fill := Color(definition.color, 0.42 if index == radial_hover else 0.20)
		draw_colored_polygon(points, fill)
		var label_position := radial_center + Vector2.RIGHT.rotated(center_angle) * radial_radius * 0.6875
		EnergyGlyphs.draw(self, definition.kind, label_position - Vector2(0.0, _energy.icon_radius), _energy.icon_radius, 0.0, definition.color, _energy.line_width)
		draw_string(ThemeDB.fallback_font, label_position - Vector2(19.0, -_energy.icon_radius),
			definition.short_name, HORIZONTAL_ALIGNMENT_CENTER, 42.0, 14,
			Color.WHITE if index == radial_hover else Color(color_text, 0.84))
	draw_arc(radial_center, radial_dead_zone, 0.0, TAU, 32, Color("70809a"), 2.0, true)
	if radial_hover < 0:
		draw_string(ThemeDB.fallback_font, radial_center + Vector2(-18.0, 6.0), "建造",
			HORIZONTAL_ALIGNMENT_CENTER, 36.0, 13, color_muted)
