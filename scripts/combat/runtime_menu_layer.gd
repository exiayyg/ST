class_name RuntimeMenuLayer
extends CanvasLayer

const PauseState := preload("res://scripts/combat/runtime_pause_state.gd")
const PauseOverlay := preload("res://scripts/combat/combat_pause_overlay.gd")
var menu: CombatPauseOverlay
var confirmation: ConfirmationDialog
var modal: Node
signal retry_requested
signal return_requested
signal quit_requested
var _pending: Callable
var _profile: BalanceProfile
var settings: PresentationSettings
var help: AcceptDialog


func configure(profile: BalanceProfile, coordinator: Node) -> void:
	_profile = profile
	modal = coordinator
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu = PauseOverlay.new()
	add_child(menu)
	menu.configure(profile)
	menu.resume_requested.connect(close)
	menu.retry_requested.connect(func(): request_action(func(): retry_requested.emit()))
	menu.return_requested.connect(func(): request_action(func(): return_requested.emit()))
	menu.quit_requested.connect(func(): request_action(func(): quit_requested.emit()))
	help = AcceptDialog.new()
	help.title = "鼠标操作"
	help.dialog_text = "亮区长按左键打开轮盘，松开即放置；二极管整对生成。\n装置按住左键并拖动即可移动；右键拖拽预览旋转，松开固定，预览时左键取消。\n蓄积器短按左键释放；选中后按住拆除按钮拆除。\n中键拖动相机、滚轮缩放；右上角切换发射和暂停。"
	help.add_to_group("screen_modal_dialog")
	add_child(help)
	menu.help_requested.connect(func(): help.popup_centered())
	menu.tuning_requested.connect(func():
		if modal.can_open_tuning(): modal.tuning.toggle_panel())
	confirmation = ConfirmationDialog.new()
	confirmation.title = "离开当前局面"
	confirmation.dialog_text = "当前局面不会保存。确定继续吗？"
	confirmation.ok_button_text = "确定离开"
	confirmation.cancel_button_text = "取消"
	confirmation.min_size.x = int(profile.value("frontend/confirmation_width"))
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm)
	confirmation.canceled.connect(_cancel_confirmation)
	confirmation.close_requested.connect(_cancel_confirmation)


func open() -> void:
	modal.cancel_transient()
	menu.open(modal.return_label())
	PauseState.acquire(get_tree(), get_instance_id(), &"menu")


func close() -> void:
	menu.close()
	PauseState.release(get_tree(), get_instance_id(), &"menu")


func request_action(action: Callable) -> void:
	if modal.is_terminal():
		action.call()
		return
	modal.cancel_transient()
	_pending = action
	PauseState.acquire(get_tree(), get_instance_id(), &"confirmation")
	confirmation.popup_centered()
	confirmation.get_cancel_button().grab_focus()


func _confirm() -> void:
	var action := _pending
	_cancel_confirmation()
	close()
	if action.is_valid():
		action.call()


func _cancel_confirmation() -> void:
	_pending = Callable()
	confirmation.hide()
	PauseState.release(get_tree(), get_instance_id(), &"confirmation")
	if menu.is_open():
		menu.focus_default()


func cancel_confirmation() -> void:
	_cancel_confirmation()


func _exit_tree() -> void:
	PauseState.release(get_tree(), get_instance_id(), &"confirmation")
	PauseState.release(get_tree(), get_instance_id(), &"menu")

func attach_presentation(director: PresentationDirector) -> void:
	settings = PresentationSettings.new()
	add_child(settings)
	settings.configure(_profile, director)
	menu.settings_requested.connect(settings.open)
