@tool
extends EditorPlugin

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const BalancePanelType := preload("res://scripts/config/balance_panel.gd")
const TOOL_MENU_LABEL := "一炮千径：打开数值编辑器"
const ENTRY_TEST_ARG := "--test-balance-editor-entry"

var dock: BalancePanel
var bottom_panel_button: Button
var tool_menu_registered := false


func _enter_tree() -> void:
	var profile := BalanceRepositoryType.load_profile()
	if profile == null:
		push_error("Singular Tower Balance Tuner 无法加载 balance.json")
		return
	dock = BalancePanelType.new() as BalancePanel
	dock.name = "一炮千径数值"
	dock.setup(profile, self, false)
	bottom_panel_button = add_control_to_bottom_panel(dock, "一炮千径数值")
	bottom_panel_button.tooltip_text = "打开《一炮千径》统一数值编辑器"
	add_tool_menu_item(TOOL_MENU_LABEL, _show_balance_panel)
	tool_menu_registered = true
	_show_panel_after_editor_settles.call_deferred()
	if ENTRY_TEST_ARG in OS.get_cmdline_user_args():
		_test_editor_entry.call_deferred()


func _show_balance_panel() -> void:
	if dock != null:
		make_bottom_panel_item_visible(dock)


func _show_panel_after_editor_settles() -> void:
	await get_tree().create_timer(1.0).timeout
	_show_balance_panel()


func _test_editor_entry() -> void:
	await get_tree().create_timer(5.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(1.0).timeout
	var attached := dock != null and dock.is_inside_tree()
	var visible := attached and dock.is_visible_in_tree()
	print("Balance editor entry present: attached=%s visible=%s size=%s" % [attached, visible, dock.size if attached else Vector2.ZERO])
	if "--capture-balance-editor" in OS.get_cmdline_user_args() and attached and visible:
		await RenderingServer.frame_post_draw
		var error := EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png("res://artifacts/v041-editor-tuning.png")
		if error != OK:
			get_tree().quit(error)
			return
		await get_tree().create_timer(3.0).timeout
	get_tree().quit(0 if attached and visible else 17)


func _exit_tree() -> void:
	if tool_menu_registered:
		remove_tool_menu_item(TOOL_MENU_LABEL)
		tool_menu_registered = false
	if dock != null:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null
	bottom_panel_button = null


func save(profile: BalanceProfile) -> Array[String]:
	return BalanceRepositoryType.save_profile(profile)


func apply_and_reset(profile: BalanceProfile) -> Array[String]:
	var errors := profile.validate()
	if not errors.is_empty():
		return errors
	errors = BalanceRepositoryType.save_profile(profile)
	if not errors.is_empty():
		return errors
	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
		EditorInterface.play_main_scene.call_deferred()
	return []
