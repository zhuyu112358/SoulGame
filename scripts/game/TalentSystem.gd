extends Node
## TalentSystem.gd - In-battle talent upgrade system (GDD v2.0 Chapter 5)
## Three-choice-one talent selection: each upgrade shows 3 random talents, player picks 1.
## 20 talents total: Attack 5 + Defense 5 + Movement 5 + Special 5.
## Talents are per-battle only (reset after battle ends).

signal talent_selected(talent_id: String, talent_name: String)
signal talent_options_generated(options: Array)

## Talent definitions: id -> {name, description, category, icon_index, effect}
## Categories: attack, defense, movement, special
const TALENTS := {
	# Attack talents (5)
	"power_strike": {
		"name": "力量",
		"description": "攻击力+20%",
		"category": "attack",
		"icon_index": 0,
		"effect": {"attack_damage_mult": 1.2}
	},
	"critical_eye": {
		"name": "暴击",
		"description": "暴击率+15%",
		"category": "attack",
		"icon_index": 1,
		"effect": {"crit_rate_add": 0.15}
	},
	"armor_pierce": {
		"name": "穿透",
		"description": "无视30%防御",
		"category": "attack",
		"icon_index": 2,
		"effect": {"armor_pierce": 0.3}
	},
	"berserker": {
		"name": "狂暴",
		"description": "HP低于50%时攻击+30%",
		"category": "attack",
		"icon_index": 3,
		"effect": {"berserker_mode": true}
	},
	"combo_master": {
		"name": "连击",
		"description": "攻击速度+25%",
		"category": "attack",
		"icon_index": 4,
		"effect": {"attack_speed_mult": 1.25}
	},
	# Defense talents (5)
	"iron_wall": {
		"name": "铁壁",
		"description": "受到伤害-20%",
		"category": "defense",
		"icon_index": 5,
		"effect": {"damage_reduction": 0.2}
	},
	"reflect": {
		"name": "反射",
		"description": "反射15%受到的伤害",
		"category": "defense",
		"icon_index": 6,
		"effect": {"damage_reflect": 0.15}
	},
	"regeneration": {
		"name": "再生",
		"description": "每秒恢复2%最大HP",
		"category": "defense",
		"icon_index": 7,
		"effect": {"hp_regen_pct": 0.02}
	},
	"resistance": {
		"name": "抗性",
		"description": "状态效果持续时间-50%",
		"category": "defense",
		"icon_index": 8,
		"effect": {"status_resistance": 0.5}
	},
	"unbreakable": {
		"name": "坚不可摧",
		"description": "最大HP+30%",
		"category": "defense",
		"icon_index": 9,
		"effect": {"max_hp_mult": 1.3}
	},
	# Movement talents (5)
	"wind_step": {
		"name": "疾风",
		"description": "移动速度+20%",
		"category": "movement",
		"icon_index": 10,
		"effect": {"move_speed_mult": 1.2}
	},
	"evasion": {
		"name": "闪避",
		"description": "15%几率闪避攻击",
		"category": "movement",
		"icon_index": 11,
		"effect": {"evasion_chance": 0.15}
	},
	"dash": {
		"name": "冲刺",
		"description": "追击范围+30%",
		"category": "movement",
		"icon_index": 12,
		"effect": {"chase_range_mult": 1.3}
	},
	"ghost_form": {
		"name": "幽灵",
		"description": "可以穿过障碍物",
		"category": "movement",
		"icon_index": 13,
		"effect": {"phase_through": true}
	},
	"phase_shift": {
		"name": "相位",
		"description": "攻击范围+25%",
		"category": "movement",
		"icon_index": 14,
		"effect": {"attack_range_mult": 1.25}
	},
	# Special talents (5)
	"life_steal": {
		"name": "吸血",
		"description": "造成伤害的10%转化为HP",
		"category": "special",
		"icon_index": 15,
		"effect": {"life_steal": 0.1}
	},
	"experience": {
		"name": "经验",
		"description": "获得双倍经验值",
		"category": "special",
		"icon_index": 16,
		"effect": {"exp_mult": 2.0}
	},
	"item_master": {
		"name": "道具",
		"description": "道具效果+50%",
		"category": "special",
		"icon_index": 17,
		"effect": {"item_effect_mult": 1.5}
	},
	"elemental": {
		"name": "元素",
		"description": "技能伤害+25%",
		"category": "special",
		"icon_index": 18,
		"effect": {"skill_damage_mult": 1.25}
	},
	"tactical_genius": {
		"name": "战术",
		"description": "战术指令效果+30%",
		"category": "special",
		"icon_index": 19,
		"effect": {"tactical_effect_mult": 1.3}
	}
}

## Active talents for current battle (player side)
var _player_talents: Array = []

## Active talents for current battle (AI side)
var _ai_talents: Array = []

## Number of upgrades completed this battle
var _player_upgrade_count: int = 0
var _ai_upgrade_count: int = 0

## Upgrade thresholds (battle time in seconds)
const UPGRADE_TIMES := [30.0, 60.0, 90.0, 120.0]

## Current pending options (null if no selection pending)
var _pending_options: Array = []
var _selection_pending: bool = false


## Reset for new battle
func reset() -> void:
	_player_talents.clear()
	_ai_talents.clear()
	_player_upgrade_count = 0
	_ai_upgrade_count = 0
	_pending_options.clear()
	_selection_pending = false


## Generate 3 random talent options for player
## Avoid talents already selected
func generate_player_options() -> Array:
	var available = []
	for talent_id in TALENTS.keys():
		if not _player_talents.has(talent_id):
			available.append(talent_id)
	# Shuffle and pick 3
	available.shuffle()
	_pending_options = available.slice(0, min(3, available.size()))
	_selection_pending = true
	emit_signal("talent_options_generated", _pending_options)
	return _pending_options


## Generate 3 random talent options for AI (auto-pick first)
func generate_ai_options() -> Array:
	var available = []
	for talent_id in TALENTS.keys():
		if not _ai_talents.has(talent_id):
			available.append(talent_id)
	available.shuffle()
	var options = available.slice(0, min(3, available.size()))
	# AI auto-picks first option
	if options.size() > 0:
		select_ai_talent(options[0])
	return options


## Player selects a talent
func select_player_talent(talent_id: String) -> bool:
	if not _selection_pending:
		return false
	if not _pending_options.has(talent_id):
		return false
	if not TALENTS.has(talent_id):
		return false
	_player_talents.append(talent_id)
	_player_upgrade_count += 1
	_selection_pending = false
	_pending_options.clear()
	var talent = TALENTS[talent_id]
	emit_signal("talent_selected", talent_id, talent["name"])
	return true


## AI selects a talent (auto)
func select_ai_talent(talent_id: String) -> bool:
	if not TALENTS.has(talent_id):
		return false
	_ai_talents.append(talent_id)
	_ai_upgrade_count += 1
	return true


## Check if player should get an upgrade at this battle time
func check_player_upgrade(battle_time: float) -> bool:
	if _player_upgrade_count >= UPGRADE_TIMES.size():
		return false
	var threshold = UPGRADE_TIMES[_player_upgrade_count]
	return battle_time >= threshold


## Check if AI should get an upgrade at this battle time
func check_ai_upgrade(battle_time: float) -> bool:
	if _ai_upgrade_count >= UPGRADE_TIMES.size():
		return false
	var threshold = UPGRADE_TIMES[_ai_upgrade_count]
	return battle_time >= threshold


## Get combined effect value for player talents
## e.g. get_player_effect("attack_damage_mult", 1.0) returns product of all matching multipliers
func get_player_effect(effect_key: String, default_value: float = 1.0) -> float:
	var result = default_value
	var is_multiplier = effect_key.ends_with("_mult")
	var is_additive = effect_key.ends_with("_add")
	for talent_id in _player_talents:
		var talent = TALENTS[talent_id]
		if talent["effect"].has(effect_key):
			var value = talent["effect"][effect_key]
			if is_multiplier:
				result *= value
			elif is_additive:
				result += value
			else:
				result = value  # For boolean/flag effects, return last value
	return result


## Get combined effect value for AI talents
func get_ai_effect(effect_key: String, default_value: float = 1.0) -> float:
	var result = default_value
	var is_multiplier = effect_key.ends_with("_mult")
	var is_additive = effect_key.ends_with("_add")
	for talent_id in _ai_talents:
		var talent = TALENTS[talent_id]
		if talent["effect"].has(effect_key):
			var value = talent["effect"][effect_key]
			if is_multiplier:
				result *= value
			elif is_additive:
				result += value
			else:
				result = value
	return result


## Check if player has a specific talent
func player_has_talent(talent_id: String) -> bool:
	return _player_talents.has(talent_id)


## Check if AI has a specific talent
func ai_has_talent(talent_id: String) -> bool:
	return _ai_talents.has(talent_id)


## Get player talent count
func get_player_talent_count() -> int:
	return _player_talents.size()


## Get AI talent count
func get_ai_talent_count() -> int:
	return _ai_talents.size()


## Get pending options (for UI)
func get_pending_options() -> Array:
	return _pending_options


## Is selection pending?
func is_selection_pending() -> bool:
	return _selection_pending


## Get talent data by id
func get_talent(talent_id: String) -> Dictionary:
	return TALENTS.get(talent_id, {})


## Get all talent ids by category
func get_talents_by_category(category: String) -> Array:
	var result = []
	for talent_id in TALENTS.keys():
		if TALENTS[talent_id]["category"] == category:
			result.append(talent_id)
	return result
