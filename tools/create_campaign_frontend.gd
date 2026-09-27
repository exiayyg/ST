extends SceneTree

const LevelDefinitionType := preload("res://scripts/campaign/level_definition.gd")
const LevelCatalogType := preload("res://scripts/campaign/level_catalog.gd")
const FrontendControllerType := preload("res://scripts/frontend/frontend_controller.gd")
const FrontendCaptureType := preload("res://tools/capture_frontend_stage.gd")
const BalanceConfigTestType := preload("res://tools/test_balance_config.gd")
const NativeLifecycleTestType := preload("res://tools/test_native_lifecycle.gd")
const RuntimeUxTestType := preload("res://tools/test_runtime_ux_regressions.gd")
const TutorialTestType := preload("res://tools/test_v03_tutorial.gd")
const CampaignFrameworkTestType := preload("res://tools/test_campaign_framework.gd")
const FrontendNavigationTestType := preload("res://tools/test_frontend_navigation.gd")

const LEVEL_RESOURCE := "res://resources/levels/diode_tutorial.tres"
const CATALOG_RESOURCE := "res://resources/levels/campaign_catalog.tres"
const FRONTEND_SCENE := "res://scenes/frontend/main_menu.tscn"
const CAPTURE_SCENE := "res://scenes/tests/capture_frontend_stage.tscn"
const TEST_SCENES := {
	"res://scenes/tests/balance_config_test.tscn": [BalanceConfigTestType, "BalanceConfigTest"],
	"res://scenes/tests/native_lifecycle_test.tscn": [NativeLifecycleTestType, "NativeLifecycleTest"],
	"res://scenes/tests/runtime_ux_regressions_test.tscn": [RuntimeUxTestType, "RuntimeUxRegressionsTest"],
	"res://scenes/tests/v03_tutorial_test.tscn": [TutorialTestType, "V03TutorialTest"],
	"res://scenes/tests/campaign_framework_test.tscn": [CampaignFrameworkTestType, "CampaignFrameworkTest"],
	"res://scenes/tests/frontend_navigation_test.tscn": [FrontendNavigationTestType, "FrontendNavigationTest"],
}


func _init() -> void:
	_generate()


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/levels"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/frontend"))
	var definition = LevelDefinitionType.new()
	definition.id = &"diode_tutorial"
	definition.display_name = "第一关：改写路径"
	definition.description = "将唯一初始弹道接入二极管，并把动量网络重定向到北侧。"
	definition.scene_path = "res://scenes/levels/diode_tutorial.tscn"
	definition.session_kind = "tutorial_diode"
	definition.balance_key = "levels/diode_tutorial"
	definition.sort_order = 10
	definition.release_visible = true
	var error := ResourceSaver.save(definition, LEVEL_RESOURCE)
	if error != OK:
		push_error("无法保存首关定义：%d" % error)
		quit(1)
		return
	var catalog = LevelCatalogType.new()
	catalog.levels.append(load(LEVEL_RESOURCE))
	error = ResourceSaver.save(catalog, CATALOG_RESOURCE)
	if error != OK:
		push_error("无法保存关卡目录：%d" % error)
		quit(1)
		return

	var root = FrontendControllerType.new()
	root.name = "MainMenu"
	var packed := PackedScene.new()
	error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, FRONTEND_SCENE)
	root.free()
	if error != OK:
		push_error("无法保存主菜单场景：%d" % error)
		quit(1)
		return
	var capture_root = FrontendCaptureType.new()
	capture_root.name = "CaptureFrontendStage"
	var capture_packed := PackedScene.new()
	error = capture_packed.pack(capture_root)
	if error == OK:
		error = ResourceSaver.save(capture_packed, CAPTURE_SCENE)
	capture_root.free()
	if error != OK:
		push_error("无法保存前端截图场景：%d" % error)
		quit(1)
		return
	for test_scene_path in TEST_SCENES:
		var test_spec: Array = TEST_SCENES[test_scene_path]
		error = _save_script_scene(test_spec[0] as Script, String(test_spec[1]), test_scene_path)
		if error != OK:
			push_error("无法保存测试场景 %s：%d" % [test_scene_path, error])
			quit(1)
			return
	ProjectSettings.set_setting("application/run/main_scene", FRONTEND_SCENE)
	ProjectSettings.set_setting("autoload/_campaign_service", "*res://scripts/campaign/campaign_service.gd")
	error = ProjectSettings.save()
	if error != OK:
		push_error("无法保存项目设置：%d" % error)
		quit(1)
		return
	print("Generated campaign catalog, first level definition and frontend main scene")
	quit(0)


func _save_script_scene(script: Script, root_name: String, scene_path: String) -> Error:
	var scene_root := script.new() as Node
	if scene_root == null:
		return ERR_CANT_CREATE
	scene_root.name = root_name
	var packed := PackedScene.new()
	var error := packed.pack(scene_root)
	if error == OK:
		error = ResourceSaver.save(packed, scene_path)
	scene_root.free()
	return error
