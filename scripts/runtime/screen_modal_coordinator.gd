class_name ScreenModalCoordinator
extends Node

var tuning: BalanceRuntimeOverlay
var menu: RuntimeMenuLayer
var cancel_interaction: Callable
var terminal_query: Callable
var return_label_query: Callable
signal terminal_return_requested

func configure(overlay: BalanceRuntimeOverlay, runtime_menu: RuntimeMenuLayer = null,
		cancel := Callable(), terminal := Callable(), label_query := Callable()) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tuning = overlay
	menu = runtime_menu
	cancel_interaction = cancel
	terminal_query = terminal
	return_label_query = label_query
	tuning.modal = self

func cancel_transient() -> bool:
	return bool(cancel_interaction.call()) if cancel_interaction.is_valid() else false

func is_terminal() -> bool:
	return bool(terminal_query.call()) if terminal_query.is_valid() else false

func return_label() -> String:
	return String(return_label_query.call()) if return_label_query.is_valid() else "返回主菜单"

func can_open_tuning() -> bool:
	for dialog in get_tree().get_nodes_in_group("screen_modal_dialog"):
		if dialog.visible:
			return false
	return menu == null or not menu.confirmation.visible

func handle_escape() -> bool:
	for dialog in get_tree().get_nodes_in_group("screen_modal_dialog"):
		if dialog.visible:
			dialog.hide()
			return true
	if menu != null and menu.confirmation.visible:
		menu.cancel_confirmation()
		return true
	if tuning.close_panel():
		return true
	if menu == null:
		return false
	if menu.menu.is_open():
		menu.close()
	elif is_terminal():
		terminal_return_requested.emit()
	elif not cancel_transient():
		menu.open()
	return true

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and handle_escape():
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F2 and OS.is_debug_build() and can_open_tuning():
		tuning.toggle_panel()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	cancel_transient()
	cancel_interaction = Callable()
	terminal_query = Callable()
	return_label_query = Callable()
