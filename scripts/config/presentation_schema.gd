@tool
class_name PresentationSchema
extends RefCounted

# Defaults are used only by historical migration and offline asset generation.
# Live consumers receive validated BalanceProfile data, never these defaults.
const FIELDS := {
	"presentation": {
		"particle_edge_ratio": [0.72,"弹体软边起点",0.1,0.95,"0–1"],
		"particle_core_ratio": [0.55,"弹体亮核半径",0.1,0.9,"0–1"],
		"particle_white_ratio": [0.42,"弹体亮核白色混合",0,1,"0–1"],
		"enabled": [
			true,
			"启用世界装饰",
			0,
			1,
			""
		],
		"reduced_motion": [
			false,
			"默认减少动态效果",
			0,
			1,
			""
		],
		"line_width": [
			2,
			"能量轮廓线宽",
			0.5,
			8,
			"px"
		],
		"halo_width": [
			6,
			"局部辉光线宽",
			1,
			16,
			"px"
		],
		"halo_alpha": [
			0.12,
			"局部辉光透明度",
			0,
			0.35,
			"0–1"
		],
		"body_radius": [
			23,
			"装置能量核心半径",
			8,
			40,
			"px"
		],
		"core_ratio": [
			0.36,
			"内核比例",
			0.05,
			0.8,
			"0–1"
		],
		"cycle_seconds": [
			3,
			"装饰循环周期",
			1,
			20,
			"秒"
		],
		"field_line_count": [
			5,
			"场纹数量",
			2,
			12,
			""
		],
		"effect_limit": [
			8,
			"装饰效果上限",
			1,
			256,
			""
		],
		"effect_seconds": [
			0.26,
			"交互脉冲时长",
			0.05,
			1,
			"秒"
		],
		"effect_radius": [
			32,
			"交互脉冲半径",
			4,
			80,
			"px"
		],
		"icon_radius": [
			13,
			"轮盘图标半径",
			6,
			20,
			"px"
		],
		"ui_corner_radius": [
			8,
			"界面圆角",
			0,
			24,
			"px"
		],
		"ui_inset": [
			18,
			"界面内部间距",
			4,
			40,
			"px"
		],
		"settings_width": [
			520,
			"视听设置宽度",
			320,
			900,
			"px"
		],
		"context_width": [
			380,
			"装置说明宽度",
			180,
			600,
			"px"
		]
	},
	"audio": {
		"device_check_seconds": [1,"音频设备检查间隔",0.1,60,"秒"],
		"harmonic_ratio": [0.25,"合成泛音比例",0,1,"0–1"],
		"harmonic_multiple": [2,"合成泛音倍频",1,8,"倍"],
		"master_volume": [
			0.7,
			"默认总音量",
			0,
			1,
			"0–1"
		],
		"sfx_volume": [
			0.8,
			"默认音效音量",
			0,
			1,
			"0–1"
		],
		"muted": [
			false,
			"默认静音",
			0,
			1,
			""
		],
		"world_voices": [
			8,
			"世界声音上限",
			1,
			24,
			""
		],
		"ui_voices": [
			2,
			"界面声音上限",
			1,
			4,
			""
		],
		"sample_rate": [
			22050,
			"合成采样率",
			8000,
			48000,
			"Hz"
		],
		"attack_seconds": [
			0.008,
			"音效起音",
			0.001,
			0.04,
			"秒"
		],
		"release_ratio": [
			0.65,
			"音效衰减比例",
			0.1,
			1,
			"0–1"
		],
		"peak_gain": [
			0.12,
			"单声音峰值",
			0.01,
			0.2,
			"0–1"
		],
		"ui_confirm_frequency": [
			740,
			"界面确认频率",
			40,
			4000,
			"Hz"
		],
		"ui_confirm_duration": [
			0.08,
			"界面确认时长",
			0.03,
			1,
			"秒"
		],
		"ui_confirm_gain": [
			0.65,
			"界面确认音量",
			0,
			1,
			"0–1"
		],
		"ui_confirm_cooldown": [
			0.04,
			"界面确认冷却",
			0.01,
			5,
			"秒"
		],
		"ui_confirm_priority": [
			4,
			"界面确认优先级",
			0,
			10,
			""
		],
		"ui_cancel_frequency": [
			330,
			"界面取消频率",
			40,
			4000,
			"Hz"
		],
		"ui_cancel_duration": [
			0.09,
			"界面取消时长",
			0.03,
			1,
			"秒"
		],
		"ui_cancel_gain": [
			0.65,
			"界面取消音量",
			0,
			1,
			"0–1"
		],
		"ui_cancel_cooldown": [
			0.04,
			"界面取消冷却",
			0.01,
			5,
			"秒"
		],
		"ui_cancel_priority": [
			4,
			"界面取消优先级",
			0,
			10,
			""
		],
		"place_frequency": [
			440,
			"放置频率",
			40,
			4000,
			"Hz"
		],
		"place_duration": [
			0.1,
			"放置时长",
			0.03,
			1,
			"秒"
		],
		"place_gain": [
			0.7,
			"放置音量",
			0,
			1,
			"0–1"
		],
		"place_cooldown": [
			0.08,
			"放置冷却",
			0.01,
			5,
			"秒"
		],
		"place_priority": [
			2,
			"放置优先级",
			0,
			10,
			""
		],
		"activate_frequency": [
			880,
			"激活频率",
			40,
			4000,
			"Hz"
		],
		"activate_duration": [
			0.24,
			"激活时长",
			0.03,
			1,
			"秒"
		],
		"activate_gain": [
			0.8,
			"激活音量",
			0,
			1,
			"0–1"
		],
		"activate_cooldown": [
			0.15,
			"激活冷却",
			0.01,
			5,
			"秒"
		],
		"activate_priority": [
			5,
			"激活优先级",
			0,
			10,
			""
		],
		"dismantle_frequency": [
			220,
			"拆除频率",
			40,
			4000,
			"Hz"
		],
		"dismantle_duration": [
			0.18,
			"拆除时长",
			0.03,
			1,
			"秒"
		],
		"dismantle_gain": [
			0.65,
			"拆除音量",
			0,
			1,
			"0–1"
		],
		"dismantle_cooldown": [
			0.1,
			"拆除冷却",
			0.01,
			5,
			"秒"
		],
		"dismantle_priority": [
			3,
			"拆除优先级",
			0,
			10,
			""
		],
		"tower_fire_frequency": [
			150,
			"塔发射频率",
			40,
			4000,
			"Hz"
		],
		"tower_fire_duration": [
			0.07,
			"塔发射时长",
			0.03,
			1,
			"秒"
		],
		"tower_fire_gain": [
			0.35,
			"塔发射音量",
			0,
			1,
			"0–1"
		],
		"tower_fire_cooldown": [
			0.1,
			"塔发射冷却",
			0.01,
			5,
			"秒"
		],
		"tower_fire_priority": [
			1,
			"塔发射优先级",
			0,
			10,
			""
		],
		"transform_frequency": [
			620,
			"装置转换频率",
			40,
			4000,
			"Hz"
		],
		"transform_duration": [
			0.09,
			"装置转换时长",
			0.03,
			1,
			"秒"
		],
		"transform_gain": [
			0.35,
			"装置转换音量",
			0,
			1,
			"0–1"
		],
		"transform_cooldown": [
			0.12,
			"装置转换冷却",
			0.01,
			5,
			"秒"
		],
		"transform_priority": [
			1,
			"装置转换优先级",
			0,
			10,
			""
		],
		"hit_frequency": [
			260,
			"有效命中频率",
			40,
			4000,
			"Hz"
		],
		"hit_duration": [
			0.06,
			"有效命中时长",
			0.03,
			1,
			"秒"
		],
		"hit_gain": [
			0.45,
			"有效命中音量",
			0,
			1,
			"0–1"
		],
		"hit_cooldown": [
			0.08,
			"有效命中冷却",
			0.01,
			5,
			"秒"
		],
		"hit_priority": [
			2,
			"有效命中优先级",
			0,
			10,
			""
		],
		"destroy_frequency": [
			90,
			"节点摧毁频率",
			40,
			4000,
			"Hz"
		],
		"destroy_duration": [
			0.24,
			"节点摧毁时长",
			0.03,
			1,
			"秒"
		],
		"destroy_gain": [
			0.8,
			"节点摧毁音量",
			0,
			1,
			"0–1"
		],
		"destroy_cooldown": [
			0.12,
			"节点摧毁冷却",
			0.01,
			5,
			"秒"
		],
		"destroy_priority": [
			6,
			"节点摧毁优先级",
			0,
			10,
			""
		],
		"warning_frequency": [
			520,
			"预警频率",
			40,
			4000,
			"Hz"
		],
		"warning_duration": [
			0.3,
			"预警时长",
			0.03,
			1,
			"秒"
		],
		"warning_gain": [
			0.8,
			"预警音量",
			0,
			1,
			"0–1"
		],
		"warning_cooldown": [
			0.5,
			"预警冷却",
			0.01,
			5,
			"秒"
		],
		"warning_priority": [
			7,
			"预警优先级",
			0,
			10,
			""
		],
		"target_frequency": [
			1040,
			"达标频率",
			40,
			4000,
			"Hz"
		],
		"target_duration": [
			0.3,
			"达标时长",
			0.03,
			1,
			"秒"
		],
		"target_gain": [
			0.8,
			"达标音量",
			0,
			1,
			"0–1"
		],
		"target_cooldown": [
			0.5,
			"达标冷却",
			0.01,
			5,
			"秒"
		],
		"target_priority": [
			8,
			"达标优先级",
			0,
			10,
			""
		],
		"victory_frequency": [
			1320,
			"胜利频率",
			40,
			4000,
			"Hz"
		],
		"victory_duration": [
			0.45,
			"胜利时长",
			0.03,
			1,
			"秒"
		],
		"victory_gain": [
			0.85,
			"胜利音量",
			0,
			1,
			"0–1"
		],
		"victory_cooldown": [
			1,
			"胜利冷却",
			0.01,
			5,
			"秒"
		],
		"victory_priority": [
			9,
			"胜利优先级",
			0,
			10,
			""
		],
		"failure_frequency": [
			130,
			"失败频率",
			40,
			4000,
			"Hz"
		],
		"failure_duration": [
			0.45,
			"失败时长",
			0.03,
			1,
			"秒"
		],
		"failure_gain": [
			0.8,
			"失败音量",
			0,
			1,
			"0–1"
		],
		"failure_cooldown": [
			1,
			"失败冷却",
			0.01,
			5,
			"秒"
		],
		"failure_priority": [
			9,
			"失败优先级",
			0,
			10,
			""
		],
		"enemy_attack_frequency": [
			180,
			"敌人攻击频率",
			40,
			4000,
			"Hz"
		],
		"enemy_attack_duration": [
			0.12,
			"敌人攻击时长",
			0.03,
			1,
			"秒"
		],
		"enemy_attack_gain": [
			0.5,
			"敌人攻击音量",
			0,
			1,
			"0–1"
		],
		"enemy_attack_cooldown": [
			0.12,
			"敌人攻击冷却",
			0.01,
			5,
			"秒"
		],
		"enemy_attack_priority": [
			2,
			"敌人攻击优先级",
			0,
			10,
			""
		]
	}
}

static func defaults(section: String) -> Dictionary:
	var result := {}
	for key in FIELDS[section]:
		result[key] = FIELDS[section][key][0]
	return result

static func descriptor(path: String) -> Dictionary:
	var parts := path.split("/")
	if parts.size() != 2 or not FIELDS.has(parts[0]) or not FIELDS[parts[0]].has(parts[1]):
		return {}
	var field: Array = FIELDS[parts[0]][parts[1]]
	var boolean := field[0] is bool
	var integer := parts[1] in ["field_line_count", "effect_limit", "world_voices", "ui_voices", "sample_rate"] or parts[1].ends_with("_priority")
	return {"path":path, "label":field[1], "unit":field[4], "description":"仅影响视听表现；项目数值应用并重置后生效。个人音量与减少动态效果可即时覆盖。", "minimum":field[2], "maximum":field[3], "step":1.0 if integer else 0.01, "editor":"default", "integer":integer, "type":TYPE_BOOL if boolean else TYPE_FLOAT}
