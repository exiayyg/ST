class_name BalanceRuntimeOverlay
extends CanvasLayer

const BalancePanelType := preload("res://scripts/config/balance_panel.gd")
const PauseState := preload("res://scripts/combat/runtime_pause_state.gd")

var panel: BalancePanel
var modal: Node
var _previous_focus: WeakRef
var _input_shield: Control
var _close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	_input_shield = Control.new()
	_input_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_shield.hide()
	add_child(_input_shield)
	panel = BalancePanelType.new() as BalancePanel
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var service := get_node("/root/_balance_service")
	var layout = service.active_profile().runtime_config().frontend
	panel.offset_left = layout.tuning_inset_x
	panel.offset_top = layout.tuning_inset_y
	panel.offset_right = -layout.tuning_inset_x
	panel.offset_bottom = -layout.tuning_inset_y
	add_child(panel)
	panel.setup(service.active_profile(), service, true)
	service.apply_failed.connect(panel.show_apply_error)
	panel.visibility_changed.connect(_visibility_changed)
	_close_button = Button.new()
	_close_button.name = "CloseTuning"
	_close_button.text = "关闭数值编辑"
	_close_button.theme = panel.theme
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var controls: RuntimeBalance.ConstructionUx = service.active_profile().runtime_config().construction_ux
	_close_button.offset_left = -controls.action_button_width - controls.action_inset
	_close_button.offset_right = -controls.action_inset
	_close_button.offset_top = controls.action_inset
	_close_button.offset_bottom = controls.action_inset + controls.action_button_height
	_close_button.hide()
	add_child(_close_button)
	_close_button.pressed.connect(close_panel)


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or panel == null:
		return
	if panel.visible:
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not panel.is_ancestor_of(focus):
			panel.focus_search()
		elif event.keycode == KEY_TAB:
			var next := focus.find_prev_valid_focus() if event.shift_pressed else focus.find_next_valid_focus()
			if next == null or not panel.is_ancestor_of(next):
				panel.focus_search()
				get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	pass


func is_open() -> bool:
	return panel != null and panel.visible


func toggle_panel() -> void:
	if panel != null:
		panel.visible = not panel.visible


func close_panel() -> bool:
	if panel == null or not panel.visible:
		return false
	panel.visible = false
	return true


func _visibility_changed() -> void:
	_input_shield.visible = panel.visible
	if _close_button != null:
		_close_button.visible = panel.visible
	if panel.visible:
		var focus := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus) if focus != null else null
		if modal != null:
			modal.cancel_transient()
		PauseState.acquire(get_tree(), get_instance_id(), &"tuning")
		panel.focus_search()
	else:
		PauseState.release(get_tree(), get_instance_id(), &"tuning")
		if _previous_focus != null:
			var previous = _previous_focus.get_ref()
			if is_instance_valid(previous) and previous.is_visible_in_tree():
				previous.grab_focus()


func _exit_tree() -> void:
	PauseState.release(get_tree(), get_instance_id(), &"tuning")
