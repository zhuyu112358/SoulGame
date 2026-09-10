extends Node
## SoulEvolutionSystem - 5-stage soul evolution system
## Follows GDD v2.0 Chapter 6: Soul Character System (Evolution)
## M2.6 Soul Character - 5-Stage Evolution
##
## Manages soul evolution stages (1-5), each with unique appearance,
## stat bonuses, and unlocked abilities. Evolution is permanent and
## represents major growth milestones.

## Evolution stages
enum EvolutionStage {
	INFANT,     # Stage 1: 幼体 - initial form
	GROWING,    # Stage 2: 成长 - level 5
	MATURE,     # Stage 3: 成熟 - level 10
	AWAKENED,   # Stage 4: 觉醒 - level 15
	TRANSCENDENT # Stage 5: 超越 - level 20
}

## Evolution stage definitions
var _stages: Dictionary = {
	EvolutionStage.INFANT: {
		"name": "幼体",
		"description": "灵魂的初始形态，纯净而脆弱",
		"required_level": 1,
		"stat_multipliers": {
			"hp": 1.0,
			"attack": 1.0,
			"defense": 1.0,
			"speed": 1.0,
			"crit_rate": 1.0,
			"crit_multiplier": 1.0,
			"energy": 1.0
		},
		"appearance": {
			"scale": 1.0,
			"glow_intensity": 0.2,
			"aura_color": null,
			"particle_effect": "none"
		},
		"unlocked_abilities": [],
		"evolution_cost": 0
	},
	EvolutionStage.GROWING: {
		"name": "成长",
		"description": "灵魂开始成长，力量逐渐觉醒",
		"required_level": 5,
		"stat_multipliers": {
			"hp": 1.1,
			"attack": 1.1,
			"defense": 1.1,
			"speed": 1.05,
			"crit_rate": 1.1,
			"crit_multiplier": 1.05,
			"energy": 1.1
		},
		"appearance": {
			"scale": 1.1,
			"glow_intensity": 0.4,
			"aura_color": null,
			"particle_effect": "sparkle"
		},
		"unlocked_abilities": ["basic_skill_2"],
		"evolution_cost": 100
	},
	EvolutionStage.MATURE: {
		"name": "成熟",
		"description": "灵魂完全成熟，力量稳定而强大",
		"required_level": 10,
		"stat_multipliers": {
			"hp": 1.25,
			"attack": 1.2,
			"defense": 1.2,
			"speed": 1.1,
			"crit_rate": 1.2,
			"crit_multiplier": 1.1,
			"energy": 1.2
		},
		"appearance": {
			"scale": 1.2,
			"glow_intensity": 0.6,
			"aura_color": null,
			"particle_effect": "aura"
		},
		"unlocked_abilities": ["basic_skill_3", "passive_1"],
		"evolution_cost": 300
	},
	EvolutionStage.AWAKENED: {
		"name": "觉醒",
		"description": "灵魂觉醒了真正的力量，散发着耀眼的光芒",
		"required_level": 15,
		"stat_multipliers": {
			"hp": 1.4,
			"attack": 1.35,
			"defense": 1.3,
			"speed": 1.15,
			"crit_rate": 1.3,
			"crit_multiplier": 1.2,
			"energy": 1.3
		},
		"appearance": {
			"scale": 1.3,
			"glow_intensity": 0.8,
			"aura_color": "element",
			"particle_effect": "awakening"
		},
		"unlocked_abilities": ["ultimate_skill", "passive_2"],
		"evolution_cost": 600
	},
	EvolutionStage.TRANSCENDENT: {
		"name": "超越",
		"description": "灵魂超越了极限，成为传说中的存在",
		"required_level": 20,
		"stat_multipliers": {
			"hp": 1.6,
			"attack": 1.5,
			"defense": 1.4,
			"speed": 1.2,
			"crit_rate": 1.5,
			"crit_multiplier": 1.3,
			"energy": 1.5
		},
		"appearance": {
			"scale": 1.4,
			"glow_intensity": 1.0,
			"aura_color": "golden",
			"particle_effect": "transcendence"
		},
		"unlocked_abilities": ["transcendence_form", "passive_3"],
		"evolution_cost": 1000
	}
}

## Element colors for aura
var _element_colors: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.2, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.9, 0.6),
	"thunder": Color(0.8, 0.6, 1.0),
	"ice": Color(0.5, 0.9, 1.0),
	"dark": Color(0.5, 0.3, 0.7),
	"light": Color(1.0, 0.9, 0.4)
}

## Signals
signal evolution_started(soul_id, from_stage, to_stage)
signal evolution_completed(soul_id, new_stage)
signal evolution_failed(soul_id, reason)


func _ready() -> void:
	GameLog.info("SoulEvolutionSystem: Ready with %d evolution stages" % _stages.size(), "Evolution")


## Get evolution stage definition
func get_stage(p_stage: int) -> Dictionary:
	if not _stages.has(p_stage):
		GameLog.warning("SoulEvolutionSystem: Unknown stage: %d" % p_stage, "Evolution")
		return _stages[EvolutionStage.INFANT].duplicate()
	return _stages[p_stage].duplicate()


## Get stage name
func get_stage_name(p_stage: int) -> String:
	var stage = get_stage(p_stage)
	return stage.get("name", "未知")


## Get stage description
func get_stage_description(p_stage: int) -> String:
	var stage = get_stage(p_stage)
	return stage.get("description", "")


## Get required level for stage
func get_required_level(p_stage: int) -> int:
	var stage = get_stage(p_stage)
	return stage.get("required_level", 1)


## Get stat multipliers for stage
func get_stat_multipliers(p_stage: int) -> Dictionary:
	var stage = get_stage(p_stage)
	return stage.get("stat_multipliers", {}).duplicate()


## Get appearance modifiers for stage
func get_appearance(p_stage: int) -> Dictionary:
	var stage = get_stage(p_stage)
	return stage.get("appearance", {}).duplicate()


## Get unlocked abilities for stage
func get_unlocked_abilities(p_stage: int) -> Array:
	var stage = get_stage(p_stage)
	return stage.get("unlocked_abilities", []).duplicate()


## Get evolution cost for stage
func get_evolution_cost(p_stage: int) -> int:
	var stage = get_stage(p_stage)
	return stage.get("evolution_cost", 0)


## Check if soul can evolve to next stage
func can_evolve(p_soul_id: String, p_current_level: int, p_current_stage: int, p_soul_points: int) -> Dictionary:
	var next_stage = p_current_stage + 1
	if next_stage > EvolutionStage.TRANSCENDENT:
		return {"can_evolve": false, "reason": "已达最高进化阶段"}

	var stage_def = get_stage(next_stage)
	var required_level = stage_def.get("required_level", 1)
	var cost = stage_def.get("evolution_cost", 0)

	if p_current_level < required_level:
		return {"can_evolve": false, "reason": "需要等级 %d（当前 %d）" % [required_level, p_current_level]}

	if p_soul_points < cost:
		return {"can_evolve": false, "reason": "需要灵魂点数 %d（当前 %d）" % [cost, p_soul_points]}

	return {"can_evolve": true, "reason": "", "next_stage": next_stage, "cost": cost}


## Evolve soul to next stage
func evolve(p_soul_id: String, p_current_level: int, p_current_stage: int, p_soul_points: int) -> Dictionary:
	var check = can_evolve(p_soul_id, p_current_level, p_current_stage, p_soul_points)
	if not check["can_evolve"]:
		evolution_failed.emit(p_soul_id, check["reason"])
		return {"success": false, "reason": check["reason"]}

	var next_stage = check["next_stage"]
	var cost = check["cost"]

	evolution_started.emit(p_soul_id, p_current_stage, next_stage)

	# In a full implementation, this would deduct soul points and save progress
	# For now, return success with new stage info

	var stage_def = get_stage(next_stage)
	evolution_completed.emit(p_soul_id, next_stage)

	GameLog.info("SoulEvolutionSystem: Soul %s evolved to stage %d (%s)" % [
		p_soul_id, next_stage, stage_def["name"]
	], "Evolution")

	return {
		"success": true,
		"new_stage": next_stage,
		"stage_name": stage_def["name"],
		"cost_paid": cost,
		"stat_multipliers": stage_def["stat_multipliers"],
		"appearance": stage_def["appearance"],
		"unlocked_abilities": stage_def["unlocked_abilities"]
	}


## Get evolution progress (0.0 - 1.0)
func get_evolution_progress(p_current_level: int, p_current_stage: int) -> float:
	var next_stage = p_current_stage + 1
	if next_stage > EvolutionStage.TRANSCENDENT:
		return 1.0

	var current_required = get_required_level(p_current_stage)
	var next_required = get_required_level(next_stage)

	if next_required <= current_required:
		return 1.0

	var progress = float(p_current_level - current_required) / float(next_required - current_required)
	return clampf(progress, 0.0, 1.0)


## Get all stages (for UI display)
func get_all_stages() -> Array:
	var result: Array = []
	for stage in _stages.keys():
		var data = get_stage(stage)
		data["stage"] = stage
		result.append(data)
	result.sort_custom(func(a, b): return a["stage"] < b["stage"])
	return result


## Get stage count
func get_stage_count() -> int:
	return _stages.size()


## Apply evolution appearance to soul unit
func apply_appearance(p_soul_unit, p_stage: int, p_element: String) -> void:
	if p_soul_unit == null:
		return

	var appearance = get_appearance(p_stage)

	# Apply scale
	if appearance.has("scale") and p_soul_unit.has_method("set_scale"):
		var base_scale = p_soul_unit.get("base_scale") if "base_scale" in p_soul_unit else Vector2.ONE
		p_soul_unit.scale = base_scale * appearance["scale"]

	# Apply glow (modulate brightness)
	if appearance.has("glow_intensity") and p_soul_unit.has_method("set_modulate"):
		var intensity = appearance["glow_intensity"]
		p_soul_unit.modulate = Color(1.0 + intensity * 0.3, 1.0 + intensity * 0.2, 1.0)

	GameLog.info("SoulEvolutionSystem: Applied stage %d appearance to %s" % [p_stage, p_element], "Evolution")


## Get aura color for stage and element
func get_aura_color(p_stage: int, p_element: String) -> Color:
	var appearance = get_appearance(p_stage)
	var aura_type = appearance.get("aura_color", null)

	if aura_type == "element":
		return _element_colors.get(p_element, Color.WHITE)
	elif aura_type == "golden":
		return Color(1.0, 0.85, 0.3)
	return Color(0, 0, 0, 0)
