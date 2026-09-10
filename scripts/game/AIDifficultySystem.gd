extends Node
## AIDifficultySystem - Manages AI difficulty levels for battle modes
## Follows GDD v2.0 Chapter 11: Battle Modes
## M2.11 Battle Modes - AI Difficulty System
##
## Defines 4 AI difficulty levels with stat modifiers and decision parameters.
## Used by training battles and random match AI opponents.

## Difficulty levels
enum Difficulty {
	EASY,      # 简单
	NORMAL,    # 普通
	HARD,      # 困难
	NIGHTMARE  # 噩梦
}

## Difficulty configurations
const DIFFICULTY_CONFIGS := {
	Difficulty.EASY: {
		"name": "简单",
		"description": "适合新手，AI反应较慢，属性较低",
		"stat_modifiers": {
			"hp_multiplier": 0.8,
			"attack_multiplier": 0.7,
			"defense_multiplier": 0.8,
			"speed_multiplier": 0.8,
			"crit_rate_multiplier": 0.5,
			"crit_damage_multiplier": 0.8
		},
		"ai_parameters": {
			"decision_interval": 2.5,      # seconds between decisions
			"reaction_speed": 0.5,         # 0-1, higher = faster
			"learning_rate": 0.0,          # 0-1, 0 = no learning
			"command_compliance": 1.0,     # 0-1, higher = more compliant
			"aggression": 0.3,             # 0-1, higher = more aggressive
			"caution": 0.7,                # 0-1, higher = more cautious
			"skill_usage_rate": 0.3,       # 0-1, probability of using skills
			"item_usage_rate": 0.2,        # 0-1, probability of using items
			"trap_avoidance": 0.4          # 0-1, higher = better at avoiding traps
		},
		"reward_multiplier": 0.5,
		"exp_multiplier": 0.5
	},
	Difficulty.NORMAL: {
		"name": "普通",
		"description": "标准难度，平衡的AI表现",
		"stat_modifiers": {
			"hp_multiplier": 1.0,
			"attack_multiplier": 1.0,
			"defense_multiplier": 1.0,
			"speed_multiplier": 1.0,
			"crit_rate_multiplier": 1.0,
			"crit_damage_multiplier": 1.0
		},
		"ai_parameters": {
			"decision_interval": 1.5,
			"reaction_speed": 0.7,
			"learning_rate": 0.3,
			"command_compliance": 0.8,
			"aggression": 0.5,
			"caution": 0.5,
			"skill_usage_rate": 0.6,
			"item_usage_rate": 0.5,
			"trap_avoidance": 0.6
		},
		"reward_multiplier": 1.0,
		"exp_multiplier": 1.0
	},
	Difficulty.HARD: {
		"name": "困难",
		"description": "挑战性难度，AI反应快，属性较高",
		"stat_modifiers": {
			"hp_multiplier": 1.2,
			"attack_multiplier": 1.2,
			"defense_multiplier": 1.1,
			"speed_multiplier": 1.1,
			"crit_rate_multiplier": 1.3,
			"crit_damage_multiplier": 1.2
		},
		"ai_parameters": {
			"decision_interval": 1.0,
			"reaction_speed": 0.85,
			"learning_rate": 0.6,
			"command_compliance": 0.6,
			"aggression": 0.7,
			"caution": 0.3,
			"skill_usage_rate": 0.8,
			"item_usage_rate": 0.7,
			"trap_avoidance": 0.8
		},
		"reward_multiplier": 1.5,
		"exp_multiplier": 1.5
	},
	Difficulty.NIGHTMARE: {
		"name": "噩梦",
		"description": "极限挑战，AI近乎完美，属性极高",
		"stat_modifiers": {
			"hp_multiplier": 1.5,
			"attack_multiplier": 1.5,
			"defense_multiplier": 1.3,
			"speed_multiplier": 1.3,
			"crit_rate_multiplier": 1.5,
			"crit_damage_multiplier": 1.5
		},
		"ai_parameters": {
			"decision_interval": 0.5,
			"reaction_speed": 0.95,
			"learning_rate": 0.9,
			"command_compliance": 0.4,
			"aggression": 0.9,
			"caution": 0.2,
			"skill_usage_rate": 0.95,
			"item_usage_rate": 0.9,
			"trap_avoidance": 0.95
		},
		"reward_multiplier": 2.0,
		"exp_multiplier": 2.0
	}
}

## Current selected difficulty
var _current_difficulty: int = Difficulty.NORMAL


## Set current difficulty
func set_difficulty(difficulty: int) -> void:
	if DIFFICULTY_CONFIGS.has(difficulty):
		_current_difficulty = difficulty
		GameLog.info("AIDifficulty: Set to %s" % get_difficulty_name(difficulty), "AI")


## Get current difficulty
func get_current_difficulty() -> int:
	return _current_difficulty


## Get difficulty name
func get_difficulty_name(difficulty: int = -1) -> String:
	var d = difficulty if difficulty >= 0 else _current_difficulty
	var config = DIFFICULTY_CONFIGS.get(d, null)
	if config:
		return config["name"]
	return "未知"


## Get difficulty description
func get_difficulty_description(difficulty: int = -1) -> String:
	var d = difficulty if difficulty >= 0 else _current_difficulty
	var config = DIFFICULTY_CONFIGS.get(d, null)
	if config:
		return config["description"]
	return ""


## Get stat modifiers for a difficulty
func get_stat_modifiers(difficulty: int = -1) -> Dictionary:
	var d = difficulty if difficulty >= 0 else _current_difficulty
	var config = DIFFICULTY_CONFIGS.get(d, null)
	if config:
		return config["stat_modifiers"].duplicate()
	return {}


## Get AI parameters for a difficulty
func get_ai_parameters(difficulty: int = -1) -> Dictionary:
	var d = difficulty if difficulty >= 0 else _current_difficulty
	var config = DIFFICULTY_CONFIGS.get(d, null)
	if config:
		return config["ai_parameters"].duplicate()
	return {}


## Get reward multiplier for a difficulty
func get_reward_multiplier(difficulty: int = -1) -> float:
	var d = difficulty if difficulty >= 0 else _current_difficulty
	var config = DIFFICULTY_CONFIGS.get(d, null)
	if config:
		return config["reward_multiplier"]
	return 1.0


## Get exp multiplier for a difficulty
func get_exp_multiplier(difficulty: int = -1) -> float:
	var d = difficulty if difficulty >= 0 else _current_difficulty
	var config = DIFFICULTY_CONFIGS.get(d, null)
	if config:
		return config["exp_multiplier"]
	return 1.0


## Apply stat modifiers to base stats
func apply_stat_modifiers(base_stats: Dictionary, difficulty: int = -1) -> Dictionary:
	var modifiers = get_stat_modifiers(difficulty)
	var result = base_stats.duplicate()
	for stat in modifiers.keys():
		var stat_key = stat.replace("_multiplier", "")
		if result.has(stat_key):
			result[stat_key] = int(result[stat_key] * modifiers[stat])
	return result


## Get all difficulty configs
func get_all_difficulties() -> Dictionary:
	return DIFFICULTY_CONFIGS.duplicate(true)


## Get difficulty list as array (for UI)
func get_difficulty_list() -> Array:
	var list = []
	for difficulty_id in DIFFICULTY_CONFIGS.keys():
		var config = DIFFICULTY_CONFIGS[difficulty_id]
		list.append({
			"id": difficulty_id,
			"name": config["name"],
			"description": config["description"],
			"reward_multiplier": config["reward_multiplier"],
			"exp_multiplier": config["exp_multiplier"]
		})
	return list


## Get difficulty by name
func get_difficulty_by_name(name: String) -> int:
	for difficulty_id in DIFFICULTY_CONFIGS.keys():
		if DIFFICULTY_CONFIGS[difficulty_id]["name"] == name:
			return difficulty_id
	return Difficulty.NORMAL


## Reset to default (normal)
func reset() -> void:
	_current_difficulty = Difficulty.NORMAL
