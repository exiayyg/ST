@tool
class_name BalanceFieldCatalog
extends RefCounted

const PresentationSchemaType := preload("res://scripts/config/presentation_schema.gd")
const SECTION_LABELS := {
	"presentation": "能量空间表现", "audio": "基础音效",
	"playtest": "本机试玩与反馈",
	"simulation": "模拟核心", "map_camera": "地图与相机", "construction_ux": "建造交互",
	"tower": "中心塔", "entropy": "熵与不确定性", "fog": "战争迷雾", "visuals": "视觉反馈",
	"frontend": "主菜单与暂停", "devices": "九种装置", "enemies": "敌人", "waves": "开发波次", "levels": "教学关卡", "diagnostics": "诊断与性能",
}

const LABELS := {
	"click_max_seconds": "短按判定时限",
	"gesture_tolerance": "手势位移容差",
	"rotation_center_dead_zone": "旋转中心死区",
	"diode_initial_offset": "二极管初始间距",
	"preview_alpha": "预览透明度",
	"preview_line_width": "预览线宽",
	"preview_direction_length": "预览方向线长度",
	"preview_font_size": "预览字号",
	"action_button_width": "操作按钮宽度",
	"action_button_height": "操作按钮高度",
	"action_inset": "操作区边距",
	"sample_interval_seconds": "试玩摘要采样间隔",
	"flush_interval_seconds": "试玩记录刷盘间隔",
	"hold_ring_radius": "建造长按环半径",
	"hold_ring_width": "建造长按环线宽",
	"endpoint_label_font_size": "端点标签字号",
	"endpoint_label_offset": "端点标签偏移",
	"exit_arrow_length": "选中出口箭头长度",
	"enemy_hit_flash_seconds": "敌人有效命中闪烁时间",
	"enemy_hit_flash_color": "敌人有效命中闪烁色",
	"consent_width": "试玩授权和反馈面板宽度",
	"feedback_field_height": "试玩意见输入框高度",
	"mode": "出生区域模式", "center_ratio": "边缘中心比例", "half_width": "区段半宽",
	"no_damage_seconds": "无有效伤害提醒延迟", "confirmation_seconds": "瞬态确认时间", "reminder_interval_seconds": "无伤害提醒最短间隔",
	"session_kind": "关卡会话类型", "route_min_north_distance": "出口最小北向距离",
	"path_hint_length": "初始路径引导线长度", "direction_hint_length": "出口朝向箭头长度",
	"tuning_min_height": "调参面板最小高度", "tuning_title_font_size": "调参标题字号",
	"tuning_field_label_width": "完整参数标签宽度", "tuning_error_height": "配置错误列表高度",
	"tuning_inset_x": "F2 水平外边距", "tuning_inset_y": "F2 垂直外边距",
	"radial_top_clearance": "轮盘顶部保留空间", "radial_bottom_clearance": "轮盘底部保留空间",
	"tutorial_instruction_width": "教学提示框宽度", "tutorial_instruction_height": "教学提示框高度",
	"tutorial_instruction_top_offset": "教学提示框顶部偏移",
	"tuning_columns_breakpoint": "调参双列切换宽度", "tuning_label_width": "常用参数标签宽度",
	"tuning_common_gap": "常用参数间距", "confirmation_width": "离开确认框宽度",
	"schema_version": "配置结构版本", "fixed_step_seconds": "固定步长", "max_substeps": "每帧最大子步",
	"momentum_zero_epsilon": "零动量容差", "projectile_radius": "弹丸碰撞半径", "wave_point_radius": "波点碰撞半径",
	"spatial_cell_size": "装置空间哈希格", "enemy_spatial_cell_size": "敌人空间哈希格",
	"max_interactions_per_step": "单子步交互保护", "random_seed": "固定随机种子",
	"render_snapshot_margin": "渲染快照边距", "map_x": "地图左上 X", "map_y": "地图左上 Y",
	"map_width": "地图宽度", "map_height": "地图高度", "map_margin": "地图边距", "pan_speed": "相机平移速度",
	"min_zoom": "最小缩放", "max_zoom": "最大缩放", "zoom_step_base": "滚轮缩放倍率",
	"radial_hold_seconds": "径向菜单长按", "radial_radius": "径向菜单半径", "radial_dead_zone": "径向菜单死区",
	"radial_screen_margin": "菜单屏幕边距", "device_pick_radius": "装置拾取半径",
	"damage_debug_amount": "调试伤害", "dismantle_hold_seconds": "拆除长按时间", "position_x": "位置 X", "position_y": "位置 Y", "max_hp": "最大 HP",
	"collision_radius": "碰撞半径", "light_radius": "照明半径", "fire_interval": "发射间隔",
	"projectile_mass": "弹丸质量", "projectile_speed": "弹丸初速度", "muzzle_offset": "炮口偏移", "per_second": "飞行熵增长",
	"per_interaction": "交互熵增长", "interaction_acceleration": "连续交互增长加速", "start_entropy": "机械不确定性阈值",
	"full_effect_entropy": "机械不确定性饱和值", "uncertainty_curve": "不确定性增长曲线",
	"max_angle_deviation_degrees": "最大角度偏移", "max_speed_deviation_ratio": "最大速度比例偏移",
	"max_mass_deviation_ratio": "最大质量比例偏移", "max_diode_exit_offset": "二极管出口位置偏移",
	"max_diode_angle_deviation_degrees": "二极管出口角度偏移", "max_split_direction_deviation_degrees": "分流方向偏移",
	"max_split_share_deviation_ratio": "分流分配误差", "visual_start_entropy": "熵视觉预警起点",
	"max_enemy_target_score_deviation_ratio": "敌人索敌评分偏移", "max_enemy_shield_position_offset": "敌人盾牌位置偏移",
	"visual_full_entropy": "熵视觉饱和值", "grid_width": "迷雾网格宽", "grid_height": "迷雾网格高",
	"edge_softness": "迷雾软边", "dark_red": "迷雾红通道", "dark_green": "迷雾绿通道",
	"dark_blue": "迷雾蓝通道", "maximum_alpha": "迷雾最大透明度", "projectile_base_diameter": "弹丸基础直径",
	"projectile_entropy_extra_diameter": "熵反馈额外直径", "wave_point_diameter": "波点直径",
	"low_hp_ratio": "低 HP 阈值", "low_hp_flash_milliseconds": "低 HP 闪烁周期", "device_bar_width": "装置状态条宽",
	"device_hp_bar_height": "装置 HP 条高", "device_activation_bar_height": "激活条高", "enemy_bar_width": "敌人 HP 条宽",
	"enemy_bar_height": "敌人 HP 条高", "destroy_effect_seconds": "破坏效果时长", "tracer_seconds": "曳光时长",
	"warning_low_threshold": "低压预警阈值", "warning_high_threshold": "高压预警阈值", "display_name": "中文名称",
	"short_name": "短名称", "color": "显示颜色", "activation_required": "激活动量", "activation_radius": "交互半径",
	"half_length": "板面半长", "entropy_sensitivity": "熵敏感度", "speed_multiplier": "速度倍率",
	"mass_multiplier": "质量倍率", "splitter_half_separation": "分流半间距", "wave_point_count": "波点数量",
	"wave_fan_degrees": "波点扇形角", "wave_speed": "波点速度", "field_radius": "场半径",
	"magnetic_angular_speed": "磁场旋转角速度", "shockwave_radius": "冲击波半径", "electric_acceleration": "电场加速度",
	"radius": "半径", "move_speed": "移动速度", "sense_radius": "感知半径", "attack_range": "攻击距离",
	"attack_interval": "攻击间隔", "attack_damage": "攻击伤害", "ranged_charge_seconds": "远程蓄力时间",
	"momentum_absorption": "动量吸收比例", "damage_per_momentum": "单位动量伤害", "entropy_transfer_ratio": "熵传递比例",
	"entropy_decay_per_second": "熵衰减速度", "aim_max_deviation_degrees": "最大瞄准偏移", "threat_weight": "预警压力权重",
	"ranged": "远程单位", "duration": "波次时长", "target_utilization": "目标利用率", "finish_policy": "结束策略",
	"pressure_curve": "压力曲线", "direction": "来袭方向", "enemy": "敌人类型", "count": "生成数量",
	"start_time": "开始时间", "end_time": "结束时间", "warning_lead": "预警提前量", "target_radius": "诊断靶半径",
	"target_damage_per_momentum": "诊断靶单位动量伤害", "target_momentum_absorption": "诊断靶吸收比例",
	"target_x": "诊断靶 X", "target_vertical_spacing": "诊断靶垂直间距", "target_count": "诊断靶数量",
	"enemy_ai_profile_interval": "敌人 AI 采样间隔", "performance_enemy_count": "性能目标敌人数",
	"stress_enemy_count": "压力测试敌人数", "x": "曲线 X", "y": "曲线 Y",
	"spawn_edge_inset": "敌人出生边缘内缩", "spawn_distribution_step": "出生分布步长",
	"ranged_ray_extra_distance": "远程射线额外距离", "target_forward_dot_min": "前方装置判定阈值",
	"target_refresh_seconds": "敌人索敌刷新间隔", "target_spatial_cell_size": "敌人索敌空间格",
	"base_target_utilization": "初始目标利用率",
	"base_threat_budget": "初始威胁预算", "threat_budget_growth_per_wave": "每波威胁预算增长",
	"target_growth_per_wave": "每波目标增长", "target_utilization_cap": "目标利用率上限",
	"ranged_share_growth_per_wave": "每波远程占比增长", "ranged_share_cap": "远程占比上限",
	"hp_growth_per_wave": "每波 HP 增长", "hp_multiplier_cap": "HP 倍率上限",
	"damage_growth_per_wave": "每波伤害增长", "damage_multiplier_cap": "伤害倍率上限",
	"speed_growth_per_wave": "每波速度增长", "speed_multiplier_cap": "速度倍率上限",
	"opening_preparation_seconds": "首波实时准备", "intermission_seconds": "波间实时休整",
	"warning_lead_seconds": "无尽预警提前量", "wave_duration_seconds": "无尽单波时长",
	"spawn_start_ratio": "生成窗口起点", "spawn_end_ratio": "生成窗口终点",
	"max_active_enemy_guard": "存活敌人异常保护", "run_seed": "无尽运行种子",
	"seed_mode": "种子模式", "templates": "方向模板", "id": "模板标识",
	"min_wave": "最早出现波次", "force_wave": "首次强制波次", "weight": "模板权重",
	"direction_offsets": "方向偏移", "budget_shares": "预算份额", "start_delay_ratios": "错峰延迟比例",
	"entity_spawn_clearance": "新实体出生净空", "reconstruction_mass": "重构弹丸质量",
	"reconstruction_speed": "重构弹丸速度",
	"lesson_device": "教学装置", "observation_seconds": "固定弹道观察时间", "marker_radius": "教学标记半径",
	"direction_tolerance_degrees": "方向提示容差", "practice_entry_x": "练习入口 X", "practice_entry_y": "练习入口 Y",
	"practice_exit_x": "练习出口 X", "practice_exit_y": "练习出口 Y", "route_entry_x": "实战入口 X",
	"route_entry_y": "实战入口 Y", "route_exit_x": "实战出口 X", "route_exit_y": "实战出口 Y",
	"route_exit_angle_degrees": "建议出口角度",
	"world_background_color": "世界背景色", "world_grid_color": "世界网格色", "world_axis_color": "世界轴线色",
	"map_border_color": "地图边框色", "map_border_width": "地图边框宽", "grid_spacing": "世界网格间距",
	"tower_color": "塔轮廓色", "tower_fill_color": "塔填充色", "inactive_device_color": "未激活装置色",
	"diagnostic_target_color": "诊断靶颜色", "low_hp_color": "低 HP 颜色", "healthy_hp_color": "健康 HP 颜色",
	"bar_background_color": "状态条背景色", "enemy_entropy_color": "敌人熵预警色", "charge_color": "蓄力提示色",
	"projectile_low_entropy_color": "低熵弹丸色", "projectile_high_entropy_color": "高熵弹丸色",
	"projectile_charged_color": "带电弹丸色", "projectile_charge_blend_ratio": "带电颜色混合比例",
	"wave_point_color": "波点颜色", "destruction_fill_color": "破坏填充色",
	"destruction_stroke_color": "破坏轮廓色", "destruction_fill_alpha": "破坏填充透明度",
	"destruction_stroke_width": "破坏轮廓宽", "destroy_effect_start_radius": "破坏初始半径",
	"destroy_effect_end_radius": "破坏结束半径", "device_cull_margin": "装置绘制裁剪边距",
	"selection_extra_radius": "选中圈额外半径", "selection_fill_alpha": "选中圈填充透明度",
	"tower_bar_width": "塔 HP 条宽", "tower_bar_height": "塔 HP 条高", "tracer_line_width": "曳光宽度",
	"enemy_fill_alpha": "敌人填充透明度", "hud_background_color": "HUD 背景色",
	"hud_text_color": "HUD 正文色", "hud_muted_color": "HUD 次要文字色", "hud_success_color": "HUD 成功色",
	"hud_warning_color": "HUD 警告色", "hud_danger_color": "HUD 危险色", "hud_top_bar_height": "HUD 顶栏高度",
	"device_hit_flash_color": "装置受击闪光色", "device_hit_flash_seconds": "装置受击闪光时长",
	"target_reached_flash_alpha": "达标闪光透明度", "target_reached_flash_seconds": "达标闪光时长",
	"settlement_dim_alpha": "结算背景遮罩透明度", "settlement_panel_width": "结算面板宽度",
	"settlement_panel_height": "结算面板高度", "settlement_panel_border_width": "结算面板边框宽度",
	"settlement_button_width": "重开按钮宽度", "settlement_button_height": "重开按钮高度",
	"settlement_title_font_size": "结算标题字号", "settlement_body_font_size": "结算正文字号",
	"settlement_button_font_size": "重开按钮字号", "dismantle_progress_color": "拆除进度颜色",
	"dismantle_progress_width": "拆除进度线宽", "tutorial_cue_color": "教学标记颜色",
	"tutorial_cue_pulse_seconds": "教学标记脉冲周期", "tutorial_path_color": "唯一弹道提示颜色",
	"tutorial_path_width": "唯一弹道提示线宽", "diode_teleport_pulse_color": "二极管传送脉冲颜色",
	"diode_teleport_pulse_seconds": "二极管传送脉冲时长", "diode_teleport_pulse_start_radius": "传送脉冲起始半径",
	"diode_teleport_pulse_end_radius": "传送脉冲结束半径", "diode_teleport_pulse_width": "传送脉冲线宽",
	"content_width": "前端内容宽度", "outer_margin": "前端外边距", "title_font_size": "前端标题字号",
	"subtitle_font_size": "前端副标题字号", "body_font_size": "前端正文字号", "card_height": "关卡卡片高度",
	"button_height": "前端按钮高度", "item_gap": "前端项目间距", "pause_panel_width": "暂停面板宽度",
	"pause_panel_height": "暂停面板高度",
}

const INTEGER_FIELDS := [
	"endpoint_label_font_size",
	"tuning_title_font_size",
	"schema_version", "max_substeps", "max_interactions_per_step", "random_seed",
	"grid_width", "grid_height", "dark_red", "dark_green", "dark_blue",
	"low_hp_flash_milliseconds", "warning_low_threshold", "warning_high_threshold",
	"wave_point_count", "count", "target_count", "performance_enemy_count", "stress_enemy_count",
	"settlement_title_font_size", "settlement_body_font_size", "settlement_button_font_size",
	"title_font_size", "subtitle_font_size", "body_font_size",
	"max_active_enemy_guard", "run_seed", "min_wave", "force_wave", "direction_offsets",
]


static func section_label(section_name: String) -> String:
	return String(SECTION_LABELS.get(section_name, section_name))


static func field_type(path: String) -> int:
	var custom := PresentationSchemaType.descriptor(path)
	if not custom.is_empty(): return int(custom.type)
	var leaf := path.get_file()
	if leaf == "ranged":
		return TYPE_BOOL
	if leaf in ["display_name", "short_name", "color", "finish_policy", "direction", "enemy", "id", "seed_mode", "lesson_device", "session_kind", "mode"] or leaf.ends_with("_color"):
		return TYPE_STRING
	return TYPE_FLOAT


static func descriptor(path: String, value) -> Dictionary:
	var custom := PresentationSchemaType.descriptor(path)
	if not custom.is_empty(): return custom
	var leaf := path.get_file()
	if leaf.is_valid_int():
		leaf = path.get_base_dir().get_file()
	if not LABELS.has(leaf):
		return {}
	var result := {
		"path": path,
		"label": String(LABELS[leaf]),
		"unit": _unit_for(path, leaf),
		"description": _description_for(path, leaf),
		"minimum": -1000000000.0,
		"maximum": 1000000000.0,
		"step": 1.0 if value is int else 0.01,
		"editor": "default",
		"integer": INTEGER_FIELDS.has(leaf),
		"type": field_type(path),
	}
	if value is float or value is int:
		_apply_numeric_range(result, path, leaf)
	elif value is String and (leaf == "color" or leaf.ends_with("_color")):
		result.editor = "color"
	elif leaf == "finish_policy":
		result.editor = "enum"
		result.options = ["immediate", "clear"]
	elif leaf == "seed_mode":
		result.editor = "enum"
		result.options = ["fixed", "random_each_run"]
	elif leaf == "mode":
		result.editor = "enum"
		result.options = ["full_edge", "segment"]
	elif leaf == "direction":
		result.editor = "enum"
		result.options = ["east", "south", "west", "north"]
	elif leaf == "enemy":
		result.editor = "enum"
		result.options = ["dev_melee", "dev_ranged", "tutorial_breaker", "tutorial_suppressor"]
	elif leaf == "lesson_device":
		result.editor = "enum"
		result.options = ["diode"]
	elif leaf == "session_kind":
		result.editor = "enum"
		result.options = ["tutorial_diode"]
	return result


static func unregistered_leaf_paths(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_collect_unregistered(data, "", result)
	return result


static func is_integer_field(path: String) -> bool:
	var custom := PresentationSchemaType.descriptor(path)
	if not custom.is_empty(): return bool(custom.integer)
	var leaf := path.get_file()
	if leaf.is_valid_int():
		leaf = path.get_base_dir().get_file()
	return INTEGER_FIELDS.has(leaf)


static func _collect_unregistered(value, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key in value.keys():
			_collect_unregistered(value[key], _join(path, String(key)), result)
	elif value is Array:
		if _is_curve(value):
			return
		for index in value.size():
			_collect_unregistered(value[index], "%s/%d" % [path, index], result)
	elif descriptor(path, value).is_empty():
		result.append(path)


static func _apply_numeric_range(result: Dictionary, path: String, leaf: String) -> void:
	if leaf in ["click_max_seconds", "gesture_tolerance", "rotation_center_dead_zone", "diode_initial_offset", "preview_line_width", "preview_direction_length", "preview_font_size", "action_button_width", "action_button_height", "action_inset"]:
		result.minimum = 0.001
		result.maximum = 10000.0
		result.step = 0.01
	elif leaf == "preview_alpha":
		result.minimum = 0.0
		result.maximum = 1.0
		result.step = 0.01
	elif leaf == "fixed_step_seconds":
		result.minimum = 0.00001
		result.maximum = 1.0
		result.step = 0.0001
	elif leaf == "momentum_zero_epsilon":
		result.minimum = 0.000000001
		result.maximum = 1.0
		result.step = 0.000001
	elif leaf == "x" and path.contains("_curve/"):
		result.minimum = 0.0
		result.maximum = 1.0
		result.step = 0.005
	elif leaf == "y" and path.contains("entropy/uncertainty_curve/"):
		result.minimum = 0.0
		result.maximum = 1.0
		result.step = 0.005
	elif leaf in ["maximum_alpha", "low_hp_ratio", "momentum_absorption", "entropy_transfer_ratio", "target_momentum_absorption", "target_utilization", "base_target_utilization", "target_utilization_cap", "ranged_share_cap", "destruction_fill_alpha", "selection_fill_alpha", "enemy_fill_alpha", "target_reached_flash_alpha", "settlement_dim_alpha", "budget_shares"] or leaf.ends_with("_ratio") or (leaf.ends_with("_per_wave") and leaf != "threat_budget_growth_per_wave"):
		result.minimum = 0.0
		result.maximum = 1.0
		result.step = 0.005
		result.editor = "slider"
	elif leaf == "spawn_distribution_step":
		result.minimum = 0.0
		result.maximum = 1.0
		result.step = 0.001
		result.editor = "slider"
	elif leaf == "target_forward_dot_min":
		result.minimum = -1.0
		result.maximum = 1.0
		result.step = 0.01
		result.editor = "slider"
	elif leaf in ["dark_red", "dark_green", "dark_blue"]:
		result.minimum = 0.0
		result.maximum = 255.0
		result.step = 1.0
		result.editor = "slider"
	elif leaf == "route_exit_angle_degrees":
		result.minimum = -180.0
		result.maximum = 180.0
		result.step = 1.0
	elif leaf.contains("degrees"):
		result.minimum = 0.0
		result.maximum = 360.0
		result.step = 0.1
	elif leaf in ["min_zoom", "max_zoom"]:
		result.minimum = 0.05
		result.maximum = 8.0
		result.step = 0.05
	elif leaf in ["random_seed", "run_seed"]:
		result.minimum = 0.0
		result.maximum = 2147483647.0
		result.step = 1.0
	elif leaf == "wave_point_count":
		result.minimum = 1.0
		result.maximum = 4096.0
		result.step = 1.0
	elif leaf in ["map_x", "map_y", "position_x", "position_y", "practice_entry_x", "practice_entry_y", "practice_exit_x", "practice_exit_y", "route_entry_x", "route_entry_y", "route_exit_x", "route_exit_y"]:
		result.minimum = -100000.0
		result.maximum = 100000.0
		result.step = 1.0
	elif leaf == "schema_version":
		result.minimum = 11.0
		result.maximum = 11.0
		result.step = 1.0
	elif leaf == "direction_offsets":
		result.minimum = 0.0
		result.maximum = 3.0
		result.step = 1.0
	elif leaf in ["min_wave", "force_wave"]:
		result.minimum = 1.0
		result.maximum = 1000000.0
		result.step = 1.0
	elif leaf in ["entropy_decay_per_second", "aim_max_deviation_degrees"] and path.contains("dev_melee"):
		result.minimum = 0.0
		result.maximum = 1000.0
	else:
		result.minimum = 0.0
		result.maximum = 1000000.0


static func _unit_for(path: String, leaf: String) -> String:
	if leaf in ["gesture_tolerance", "rotation_center_dead_zone", "action_button_width", "action_button_height", "action_inset"]:
		return "屏幕逻辑 px"
	if leaf in ["diode_initial_offset", "preview_line_width", "preview_direction_length", "preview_font_size"]:
		return "世界 px"
	if leaf == "preview_alpha": return "0–1"
	if path.begins_with("playtest/") and not leaf.ends_with("_seconds") and not leaf.ends_with("_color"):
		return "px"
	if leaf == "half_width":
		return "像素"
	if leaf.ends_with("_seconds") or leaf in ["fixed_step_seconds", "fire_interval", "attack_interval", "duration", "start_time", "end_time", "warning_lead", "destroy_effect_seconds", "tracer_seconds"]:
		return "秒"
	if leaf.ends_with("_milliseconds"):
		return "毫秒"
	if leaf.contains("degrees"):
		return "度"
	if leaf in ["map_x", "map_y", "map_width", "map_height", "map_margin", "projectile_radius", "wave_point_radius", "render_snapshot_margin", "radial_radius", "radial_dead_zone", "radial_screen_margin", "device_pick_radius", "collision_radius", "light_radius", "muzzle_offset", "edge_softness", "projectile_base_diameter", "projectile_entropy_extra_diameter", "wave_point_diameter", "device_bar_width", "device_hp_bar_height", "device_activation_bar_height", "enemy_bar_width", "enemy_bar_height", "activation_radius", "half_length", "splitter_half_separation", "field_radius", "shockwave_radius", "radius", "sense_radius", "attack_range", "max_diode_exit_offset", "max_enemy_shield_position_offset", "target_radius", "target_x", "target_vertical_spacing", "spatial_cell_size", "enemy_spatial_cell_size", "target_spatial_cell_size", "entity_spawn_clearance", "ranged_ray_extra_distance", "spawn_edge_inset", "grid_spacing", "map_border_width", "destruction_stroke_width", "destroy_effect_start_radius", "destroy_effect_end_radius", "device_cull_margin", "selection_extra_radius", "tower_bar_width", "tower_bar_height", "tracer_line_width", "hud_top_bar_height", "settlement_panel_width", "settlement_panel_height", "settlement_panel_border_width", "settlement_button_width", "settlement_button_height", "settlement_title_font_size", "settlement_body_font_size", "settlement_button_font_size", "marker_radius", "practice_entry_x", "practice_entry_y", "practice_exit_x", "practice_exit_y", "route_entry_x", "route_entry_y", "route_exit_x", "route_exit_y", "dismantle_progress_width", "tutorial_path_width", "diode_teleport_pulse_start_radius", "diode_teleport_pulse_end_radius", "diode_teleport_pulse_width", "content_width", "outer_margin", "title_font_size", "subtitle_font_size", "body_font_size", "card_height", "button_height", "item_gap", "pause_panel_width", "pause_panel_height"]:
		return "px"
	if leaf in ["pan_speed", "projectile_speed", "wave_speed", "move_speed", "reconstruction_speed"]:
		return "px/s"
	if leaf == "reconstruction_mass":
		return "质量"
	if leaf in ["electric_acceleration"]:
		return "px/s²"
	if leaf == "magnetic_angular_speed":
		return "rad/s"
	if leaf.ends_with("_ratio") or leaf in ["maximum_alpha", "momentum_absorption", "target_momentum_absorption", "target_utilization", "base_target_utilization", "target_utilization_cap", "ranged_share_cap", "budget_shares"]:
		return "0–1"
	if leaf in ["activation_required"]:
		return "动量"
	if leaf in ["max_hp", "attack_damage", "damage_debug_amount"]:
		return "HP"
	if leaf.contains("entropy") or leaf in ["per_second", "per_interaction"]:
		return "熵"
	return ""


static func _description_for(path: String, leaf: String) -> String:
	if path == "playtest/sample_interval_seconds":
		return "仅在同意记录的试玩中采样聚合战况；暂停时不采样世界，暂停时长单独累计。"
	if path == "playtest/flush_interval_seconds":
		return "授权记录的刷盘间隔（包含暂停期间）；正常结束立即保存，不等待下次刷盘。"
	if leaf == "click_max_seconds":
		return "蓄积器只有按住时间短于此值且未拖动才会在松开时释放；此时限不阻挡移动。"
	if leaf == "gesture_tolerance":
		return "屏幕逻辑像素；装置按住后超过此距离立即拖动，不等待计时；回到起点也不触发短按。"
	if leaf == "rotation_center_dead_zone":
		return "屏幕逻辑像素；鼠标进入旋转中心附近时保留最后有效预览角度。"
	if leaf == "diode_initial_offset":
		return "整对放置时出口向世界右方偏移的像素距离；两个端点都必须合法。"
	if path.begins_with("playtest/"):
		return "仅调整试玩界面或战斗表现，不改变碰撞、照明、动量或难度。应用并重置后生效。"
	if path == "entropy/start_entropy":
		return "熵小于或等于此值时，机械偏移严格为 0。"
	if path == "entropy/full_effect_entropy":
		return "熵达到此值后，不确定性权重固定为 1。"
	if path == "entropy/uncertainty_curve":
		return "阈值与饱和值之间的单调归一化权重；端点固定为 (0,0) 与 (1,1)。"
	if path == "entropy/max_enemy_shield_position_offset":
		return "为后续具有可移动盾牌的敌人预留的行为响应上限；当前开发敌人不使用盾牌。"
	if leaf == "fixed_step_seconds":
		return "原生模拟固定步长；只在完整重置后统一生效。"
	if leaf == "random_seed":
		return "使机械偏移、敌人偏射和测试可重复。"
	if leaf == "run_seed":
		return "固定模式下决定每波模板、主方向和生成编成；F3 显示实际运行种子。"
	if leaf == "max_active_enemy_guard":
		return "异常工程保护；达到上限时延后生成并写入 F3，不删除现有敌人。"
	if leaf == "target_refresh_seconds":
		return "敌人按稳定 ID 错峰刷新索敌；当前目标失效时立即刷新。"
	if leaf == "target_spatial_cell_size":
		return "GDScript 敌人感知使用的装置空间索引格尺寸。"
	if leaf == "dismantle_hold_seconds":
		return "按住拆除按钮（或可选 Delete 快捷键）达到该时长才拆除；提前松开会取消。"
	if leaf.begins_with("diode_teleport_pulse_"):
		return "真实二极管传送事件触发的瞬态视觉反馈；不改变弹丸、动量或教学判定。"
	if leaf == "lesson_device":
		return "当前关卡重点教学的装置；不会限制径向菜单中的其他装置。"
	if leaf == "activation_required":
		return "未激活装置累计吸收达到该动量后永久激活。"
	if leaf == "finish_policy":
		return "immediate 立即结束；clear 停止生成但保留现存敌人行动，清空后结束。"
	return "项目统一数值字段；修改仅进入工作副本，应用并重置后统一生效。"


static func _is_curve(values: Array) -> bool:
	if values.size() < 2:
		return false
	for item in values:
		if item is not Dictionary or not item.has("x") or not item.has("y") or item.size() != 2:
			return false
	return true


static func _join(base: String, key: String) -> String:
	return key if base.is_empty() else "%s/%s" % [base, key]
