extends Node
## SoulUpgradeSystem - Manages permanent cross-battle soul upgrades across 7 dimensions
## Follows GDD v2.0 Chapter 5: Three Upgrade Systems (Soul Upgrade - Permanent)
## M2.7 Three Upgrade Systems (Soul Upgrade)

## 7 upgrade dimensions (permanent, cross-battle)
const DIMENSIONS := {
	"health": {
		"name": "生命强化",
		"description": "提升最大生命值",
		"base_value": 120.0,
		"per_level": 15.0,
		"max_level": 20,
		"icon_index": 0
	},
	"attack": {
		"name": "攻击强化",
		"description": "提升攻击力",
		"base_value": 13.0,
		"per_level": 2.0,
		"max_level": 20,
		"icon_index": 1
	},
	"defense": {
		"name": "防御强化",
		"description": "提升伤害减免",
		"base_value": 0.0,
		"per_level": 0.02,
		"max_level": 20,
		"icon_index": 2
	},
	"speed": {
		"name": "速度强化",
		"description": "提升移动速度",
		"base_value": 150.0,
		"per_level": 5.0,
		"max_level": 20,
		"icon_index": 3
	},
	"crit": {
		"name": "暴击强化",
		"description": "提升暴击率",
		"base_value": 0.10,
		"per_level": 0.015,
		"max_level": 20,
		"icon_index": 4
	},
	"energy": {
		"name": "能量强化",
		"description": "提升最大能量和回复速度",
		"base_value": 50.0,
		"per_level": 5.0,
		"max_level": 20,
		"icon_index": 5
	},
	"skill": {
		"name": "技能强化",
		"description": "提升技能伤害和效果",
		"base_value": 1.0,
		"per_level": 0.05,
		"max_level": 20,
		"icon_index": 6
	}
}

## Upgrade levels for each dimension (persistent)
var _upgrade_levels: Dictionary = {
	"health": 0,
	"attack": 0,
	"defense": 0,
	"speed": 0,
	"crit": 0,
	"energy": 0,
	"skill": 0
}

## Total soul experience (earned from battles)
var _total_experience: int = 0

## Available upgrade points (earned from soul level ups)
var _upgrade_points: int = 0

## Soul level (overall)
var _soul_level: int = 1

## Soul experience
var _soul_experience: int = 0

## Experience needed for next soul level
var _experience_to_next: int = 100

## Save file path
const SAVE_PATH := "user://soul_upgrades.save"

## Signal emitted when upgrade is applied
signal upgrade_applied(dimension, new_level)

## Signal emitted when soul levels up
signal soul_leveled_up(new_level)


func _ready() -> void:
	_load_data()


## Get current upgrade level for a dimension
func get_upgrade_level(dimension: String) -> int:
	return _upgrade_levels.get(dimension, 0)


## Get upgraded value for a dimension
func get_upgraded_value(dimension: String) -> float:
	var dim = DIMENSIONS.get(dimension, null)
	if dim == null:
		return 0.0
	var level = _upgrade_levels.get(dimension, 0)
	return dim["base_value"] + dim["per_level"] * level


## Get upgrade bonus multiplier (for percentage-based stats)
func get_upgrade_multiplier(dimension: String) -> float:
	var dim = DIMENSIONS.get(dimension, null)
	if dim == null:
		return 1.0
	var level = _upgrade_levels.get(dimension, 0)
	return 1.0 + dim["per_level"] * level


## Apply upgrade to a dimension (costs 1 upgrade point)
func apply_upgrade(dimension: String) -> bool:
	if _upgrade_points <= 0:
		return false
	var dim = DIMENSIONS.get(dimension, null)
	if dim == null:
		return false
	var current_level = _upgrade_levels.get(dimension, 0)
	if current_level >= dim["max_level"]:
		return false
	_upgrade_levels[dimension] = current_level + 1
	_upgrade_points -= 1
	upgrade_applied.emit(dimension, current_level + 1)
	_save_data()
	return true


## Add soul experience and check for level up
func add_experience(amount: int) -> void:
	_soul_experience += amount
	_total_experience += amount
	# Check for level up
	while _soul_experience >= _experience_to_next:
		_soul_experience -= _experience_to_next
		_soul_level += 1
		_upgrade_points += 1  # Gain 1 upgrade point per level
		_experience_to_next = _calc_experience_to_next(_soul_level)
		soul_leveled_up.emit(_soul_level)
	_save_data()


## Calculate experience needed for next level
func _calc_experience_to_next(level: int) -> int:
	return int(100 * pow(1.15, level - 1))


## Get soul level
func get_soul_level() -> int:
	return _soul_level


## Get soul experience
func get_soul_experience() -> int:
	return _soul_experience


## Get experience to next level
func get_experience_to_next() -> int:
	return _experience_to_next


## Get available upgrade points
func get_upgrade_points() -> int:
	return _upgrade_points


## Get total experience
func get_total_experience() -> int:
	return _total_experience


## Get all upgrade levels
func get_all_upgrade_levels() -> Dictionary:
	return _upgrade_levels.duplicate()


## Get dimension definition
func get_dimension(dimension: String) -> Dictionary:
	return DIMENSIONS.get(dimension, {})


## Get all dimension IDs
func get_all_dimension_ids() -> Array:
	return DIMENSIONS.keys()


## Apply all permanent upgrades to a soul unit
func apply_upgrades_to_unit(unit) -> void:
	if unit == null:
		return
	# Health upgrade
	var health_level = _upgrade_levels.get("health", 0)
	if health_level > 0:
		var health_bonus = DIMENSIONS["health"]["per_level"] * health_level
		unit.max_hp += health_bonus
		unit.current_hp = unit.max_hp
	# Attack upgrade
	var attack_level = _upgrade_levels.get("attack", 0)
	if attack_level > 0:
		var attack_bonus = DIMENSIONS["attack"]["per_level"] * attack_level
		unit.attack_damage += attack_bonus
	# Defense upgrade (damage reduction)
	var defense_level = _upgrade_levels.get("defense", 0)
	if defense_level > 0:
		unit.damage_reduction = DIMENSIONS["defense"]["per_level"] * defense_level
	# Speed upgrade
	var speed_level = _upgrade_levels.get("speed", 0)
	if speed_level > 0:
		var speed_bonus = DIMENSIONS["speed"]["per_level"] * speed_level
		unit.move_speed += speed_bonus
	# Crit upgrade
	var crit_level = _upgrade_levels.get("crit", 0)
	if crit_level > 0:
		var crit_bonus = DIMENSIONS["crit"]["per_level"] * crit_level
		unit.crit_rate += crit_bonus
	# Energy upgrade
	var energy_level = _upgrade_levels.get("energy", 0)
	if energy_level > 0:
		var energy_bonus = DIMENSIONS["energy"]["per_level"] * energy_level
		unit.max_energy += energy_bonus
		unit.energy_regen += 0.2 * energy_level
	# Skill upgrade (skill damage multiplier)
	var skill_level = _upgrade_levels.get("skill", 0)
	if skill_level > 0:
		unit.skill_damage_multiplier = 1.0 + DIMENSIONS["skill"]["per_level"] * skill_level


## Reset all upgrades (for testing)
func reset_all() -> void:
	_upgrade_levels = {
		"health": 0,
		"attack": 0,
		"defense": 0,
		"speed": 0,
		"crit": 0,
		"energy": 0,
		"skill": 0
	}
	_total_experience = 0
	_upgrade_points = 0
	_soul_level = 1
	_soul_experience = 0
	_experience_to_next = 100
	_save_data()


## Save upgrade data to file
func _save_data() -> void:
	var save_data = {
		"upgrade_levels": _upgrade_levels,
		"total_experience": _total_experience,
		"upgrade_points": _upgrade_points,
		"soul_level": _soul_level,
		"soul_experience": _soul_experience,
		"experience_to_next": _experience_to_next
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))
		f.close()


## Load upgrade data from file
func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var json_string = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(json_string)
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("upgrade_levels"):
				for key in _upgrade_levels.keys():
					if parsed["upgrade_levels"].has(key):
						_upgrade_levels[key] = parsed["upgrade_levels"][key]
			if parsed.has("total_experience"):
				_total_experience = parsed["total_experience"]
			if parsed.has("upgrade_points"):
				_upgrade_points = parsed["upgrade_points"]
			if parsed.has("soul_level"):
				_soul_level = parsed["soul_level"]
			if parsed.has("soul_experience"):
				_soul_experience = parsed["soul_experience"]
			if parsed.has("experience_to_next"):
				_experience_to_next = parsed["experience_to_next"]
