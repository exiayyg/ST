@tool
class_name EnergyTheme
extends RefCounted

static func build(profile: BalanceProfile) -> Theme:
	var theme := Theme.new()
	var config := profile.runtime_config()
	theme.default_font_size = int(config.frontend.body_font_size)
	var background := Color(config.visuals.hud_background_color)
	var accent := Color(config.visuals.hud_success_color)
	var text := Color(config.visuals.hud_text_color)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = background.lerp(accent, config.presentation.halo_alpha if state in ["hover", "pressed"] else 0.0)
		style.border_color = accent if state in ["hover", "focus", "pressed"] else Color(config.visuals.world_axis_color)
		style.set_border_width_all(int(config.presentation.line_width))
		style.set_corner_radius_all(int(config.presentation.ui_corner_radius))
		style.content_margin_left = config.presentation.ui_inset
		style.content_margin_right = config.presentation.ui_inset
		style.content_margin_top = config.frontend.item_gap
		style.content_margin_bottom = config.frontend.item_gap
		theme.set_stylebox(state, "Button", style)
		theme.set_stylebox(state, "OptionButton", style)
		theme.set_color("font_color" if state == "normal" else "font_%s_color" % state, "Button", text)
	var panel := theme.get_stylebox("normal", "Button").duplicate() as StyleBoxFlat
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	var window := panel.duplicate() as StyleBoxFlat
	window.expand_margin_top = config.frontend.body_font_size + config.frontend.item_gap
	theme.set_stylebox("embedded_border", "Window", window)
	theme.set_stylebox("embedded_unfocused_border", "Window", window)
	theme.set_color("title_color", "Window", text)
	theme.set_color("title_unfocused_color", "Window", text)
	var icon_size := int(config.presentation.icon_radius + config.presentation.icon_radius)
	theme.set_icon("unchecked", "CheckBox", _check_icon(icon_size, int(config.presentation.line_width), text, false))
	theme.set_icon("checked", "CheckBox", _check_icon(icon_size, int(config.presentation.line_width), accent, true))
	for state in ["normal", "hover", "pressed", "focus"]:
		theme.set_color("font_color" if state == "normal" else "font_%s_color" % state, "CheckBox", text)
		theme.set_color("icon_%s_color" % state, "CheckBox", text)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(config.visuals.world_axis_color)
	track.content_margin_top = config.presentation.line_width
	track.content_margin_bottom = config.presentation.line_width
	theme.set_stylebox("slider", "HSlider", track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = accent
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_color("font_color", "Label", text)
	return theme

static func _check_icon(size: int, stroke: int, color: Color, checked: bool) -> Texture2D:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		for y in size:
			if checked or x < stroke or y < stroke or x >= size - stroke or y >= size - stroke:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
