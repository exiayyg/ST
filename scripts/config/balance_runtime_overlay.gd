class_name BalanceRuntimeOverlay
extends CanvasLayer

const BalancePanelType := preload("res://scripts/config/balance_panel.gd")

var panel: BalancePanel


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	panel = BalancePanelType.new() as BalancePanel
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 80.0
	panel.offset_top = 50.0
	panel.offset_right = -80.0
	panel.offset_bottom = -50.0
	add_child(panel)
	var service := get_node("/root/_balance_service")
	panel.setup(service.active_profile(), service, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()
