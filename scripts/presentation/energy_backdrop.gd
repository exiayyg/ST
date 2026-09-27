class_name EnergyBackdrop
extends Control

var config: RuntimeBalance.Presentation
var accent: Color
var preferences: PresentationPreferences
var elapsed := 0.0

func configure(profile: BalanceProfile, user_preferences: PresentationPreferences) -> void:
	config = profile.runtime_config().presentation
	accent = Color(profile.runtime_config().visuals.hud_success_color)
	preferences = user_preferences
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not preferences.reduced_motion: elapsed += delta
	queue_redraw()

func _draw() -> void:
	if config == null or not config.enabled: return
	var radius := minf(size.x, size.y) * 0.36
	var center := Vector2(size.x * 0.12, size.y * 0.5)
	var phase := elapsed * TAU / config.cycle_seconds if not preferences.reduced_motion else 0.0
	for index in 3:
		draw_arc(center, radius * float(index + 1) / 3.0, phase, phase + PI * 1.5, 64, Color(accent, config.halo_alpha), config.line_width, true)
	draw_line(center, Vector2(size.x, center.y), Color(accent, config.halo_alpha), config.line_width, true)
