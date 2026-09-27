class_name CombatSessionFactory
extends RefCounted

const SessionSpecType := preload("res://scripts/combat/session_spec.gd")
const TutorialConfig := preload("res://scripts/config/diode_tutorial_config.gd")

static func supported(kind: StringName) -> bool:
	return SessionSpecType.DEFAULT_KEYS.has(kind) and kind != &"construction"

static func binding_errors(kind: StringName, key: String, profile: BalanceProfile) -> Array[String]:
	if not supported(kind):
		return ["未知会话类型：%s" % kind]
	var config = profile.value(key)
	if key.is_empty() or config is not Dictionary:
		return ["配置不存在：%s" % key]
	match kind:
		&"tutorial_diode":
			if not key.begins_with("levels/") or config.get("session_kind") != "tutorial_diode":
				return ["配置与教学会话不匹配：%s" % key]
		&"single_wave":
			if not key.begins_with("waves/") or not config.has("groups"):
				return ["配置与单波会话不匹配：%s" % key]
		&"endless":
			if key != SessionSpecType.DEFAULT_KEYS[&"endless"]:
				return ["配置与无尽会话不匹配：%s" % key]
	return []

static func create(spec: SessionSpecType, profile: BalanceProfile, enemies: EnemyManager,
		simulation: SimulationController, tower: TowerController, construction: ConstructionController) -> CombatSessionDirector:
	if not profile.validate().is_empty():
		return null
	if not binding_errors(spec.session_kind, spec.balance_key, profile).is_empty():
		return null
	match spec.session_kind:
		&"single_wave":
			return SingleWaveSession.new(profile, enemies, simulation, tower, StringName(spec.balance_key.get_file()))
		&"endless":
			return EndlessRunDirector.new(profile, enemies, simulation, tower)
		&"tutorial_diode":
			return DiodeTutorialSession.new(profile, enemies, simulation, tower, construction, TutorialConfig.new(profile.value(spec.balance_key)))
	return null
