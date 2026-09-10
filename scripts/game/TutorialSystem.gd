extends Node
## TutorialSystem - Manages tutorial levels and step progression
## Follows GDD v2.0 Chapter 15: Tutorial and Story Mode
## M2.10 Tutorial & Story - Tutorial System
##
## Defines 6 tutorial levels with step-by-step guidance.
## Tracks progress and validates objectives.

## Tutorial level IDs
enum TutorialLevel {
	BASIC_CONTROLS,    # 基础操作
	SOUL_UNITS,        # 灵魂单位
	SKILL_SYSTEM,      # 技能系统
	TACTICAL_COMMANDS, # 战术指令
	ITEMS_TRAPS,       # 道具陷阱
	COMBINED_BATTLE    # 综合实战
}

## Tutorial step types
enum StepType {
	INFO,           # Information display
	OBJECTIVE,      # Objective to complete
	DIALOGUE,       # Dialogue sequence
	ACTION_REQUIRED # Wait for player action
}

## Tutorial levels configuration
const TUTORIAL_LEVELS := {
	TutorialLevel.BASIC_CONTROLS: {
		"id": "basic_controls",
		"name": "基础操作",
		"description": "学习游戏的基本操作方式",
		"icon": "ui_tutorial_basic",
		"estimated_time": 120,
		"steps": [
			{
				"type": StepType.INFO,
				"title": "欢迎来到战策",
				"text": "欢迎来到战策Battleplan！在这个教程中，你将学习游戏的基本操作。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "灵魂指挥官",
				"text": "你是灵魂指挥官，你的灵魂会自主战斗。你需要通过战术指令和技能释放来引导他们。",
				"speaker": "系统"
			},
			{
				"type": StepType.OBJECTIVE,
				"title": "观察战斗",
				"text": "观察你的灵魂单位如何自主移动和攻击。等待战斗开始。",
				"objective": "watch_battle",
				"duration": 5.0
			},
			{
				"type": StepType.INFO,
				"title": "教程完成",
				"text": "基础操作教程完成！你已经了解了游戏的基本玩法。",
				"speaker": "系统"
			}
		]
	},
	TutorialLevel.SOUL_UNITS: {
		"id": "soul_units",
		"name": "灵魂单位",
		"description": "了解灵魂单位的属性和元素",
		"icon": "ui_tutorial_soul",
		"estimated_time": 150,
		"steps": [
			{
				"type": StepType.INFO,
				"title": "八大元素",
				"text": "灵魂分为八大元素：火、水、土、风、雷、冰、暗、光。每个元素有不同的特性和技能。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "元素相克",
				"text": "元素之间存在相克关系：火克冰、水克火、土克雷、风克土、雷克水、冰克风、暗克光、光克暗。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "灵魂属性",
				"text": "每个灵魂有生命值、攻击力、攻击速度、移动速度、暴击率等属性。升级可以提升这些属性。",
				"speaker": "系统"
			},
			{
				"type": StepType.OBJECTIVE,
				"title": "查看灵魂信息",
				"text": "在战斗中观察灵魂单位的血条和能量条。",
				"objective": "view_soul_info",
				"duration": 5.0
			},
			{
				"type": StepType.INFO,
				"title": "教程完成",
				"text": "灵魂单位教程完成！你已经了解了灵魂的基本属性。",
				"speaker": "系统"
			}
		]
	},
	TutorialLevel.SKILL_SYSTEM: {
		"id": "skill_system",
		"name": "技能系统",
		"description": "学习技能释放和冷却机制",
		"icon": "ui_tutorial_skill",
		"estimated_time": 180,
		"steps": [
			{
				"type": StepType.INFO,
				"title": "技能系统",
				"text": "每个灵魂有4个技能：普通攻击、元素技能、终极技能、被动技能。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "能量消耗",
				"text": "释放技能需要消耗能量。能量会随时间自动恢复，攻击敌人也能获得能量。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "技能冷却",
				"text": "技能释放后会进入冷却时间。冷却结束后才能再次释放。",
				"speaker": "系统"
			},
			{
				"type": StepType.OBJECTIVE,
				"title": "释放技能",
				"text": "点击技能按钮释放一个技能，观察技能效果。",
				"objective": "use_skill",
				"duration": 10.0
			},
			{
				"type": StepType.INFO,
				"title": "教程完成",
				"text": "技能系统教程完成！你已经学会了如何释放技能。",
				"speaker": "系统"
			}
		]
	},
	TutorialLevel.TACTICAL_COMMANDS: {
		"id": "tactical_commands",
		"name": "战术指令",
		"description": "学习6种战术指令的使用",
		"icon": "ui_tutorial_tactical",
		"estimated_time": 180,
		"steps": [
			{
				"type": StepType.INFO,
				"title": "战术指令",
				"text": "作为灵魂指挥官，你可以下达6种战术指令：进攻、防守、撤退、集火、分散、跟随。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "进攻指令",
				"text": "进攻指令会让灵魂单位更积极地攻击敌人，提高攻击性。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "防守指令",
				"text": "防守指令会让灵魂单位更注重防御，减少受到的伤害。",
				"speaker": "系统"
			},
			{
				"type": StepType.OBJECTIVE,
				"title": "使用战术指令",
				"text": "尝试使用不同的战术指令，观察灵魂单位的行为变化。",
				"objective": "use_tactical_command",
				"duration": 10.0
			},
			{
				"type": StepType.INFO,
				"title": "教程完成",
				"text": "战术指令教程完成！你已经学会了如何指挥你的灵魂。",
				"speaker": "系统"
			}
		]
	},
	TutorialLevel.ITEMS_TRAPS: {
		"id": "items_traps",
		"name": "道具陷阱",
		"description": "学习道具拾取和陷阱躲避",
		"icon": "ui_tutorial_item",
		"estimated_time": 150,
		"steps": [
			{
				"type": StepType.INFO,
				"title": "战场道具",
				"text": "战场上会定期刷新道具，拾取道具可以获得各种增益效果。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "道具类型",
				"text": "道具包括：生命恢复、能量恢复、攻击提升、防御提升、速度提升等17种。",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "地面陷阱",
				"text": "战场上也会出现陷阱，踩到陷阱会受到伤害或负面效果。注意躲避！",
				"speaker": "系统"
			},
			{
				"type": StepType.OBJECTIVE,
				"title": "拾取道具",
				"text": "等待道具刷新，让你的灵魂单位拾取一个道具。",
				"objective": "pickup_item",
				"duration": 15.0
			},
			{
				"type": StepType.INFO,
				"title": "教程完成",
				"text": "道具陷阱教程完成！你已经了解了战场道具和陷阱。",
				"speaker": "系统"
			}
		]
	},
	TutorialLevel.COMBINED_BATTLE: {
		"id": "combined_battle",
		"name": "综合实战",
		"description": "运用所学知识完成一场完整战斗",
		"icon": "ui_tutorial_battle",
		"estimated_time": 300,
		"steps": [
			{
				"type": StepType.INFO,
				"title": "综合实战",
				"text": "现在，运用你学到的所有知识，完成一场完整的战斗！",
				"speaker": "系统"
			},
			{
				"type": StepType.INFO,
				"title": "战斗目标",
				"text": "击败敌方灵魂单位即可获胜。合理使用技能和战术指令，注意道具和陷阱。",
				"speaker": "系统"
			},
			{
				"type": StepType.OBJECTIVE,
				"title": "赢得战斗",
				"text": "使用技能和战术指令，赢得这场战斗！",
				"objective": "win_battle",
				"duration": 180.0
			},
			{
				"type": StepType.INFO,
				"title": "恭喜！",
				"text": "你已经完成了所有教程！现在你已经准备好进入真正的战斗了。",
				"speaker": "系统"
			}
		]
	}
}

## Current tutorial state
var _current_level: int = -1
var _current_step: int = 0
var _tutorial_active: bool = false
var _step_timer: float = 0.0
var _completed_levels: Array = []
var _objective_completed: bool = false


## Start a tutorial level
func start_tutorial(level_id: int) -> bool:
	if not TUTORIAL_LEVELS.has(level_id):
		GameLog.warning("TutorialSystem: Invalid level id %d" % level_id, "Tutorial")
		return false

	_current_level = level_id
	_current_step = 0
	_tutorial_active = true
	_step_timer = 0.0
	_objective_completed = false

	var level = TUTORIAL_LEVELS[level_id]
	GameLog.info("TutorialSystem: Starting tutorial '%s'" % level["name"], "Tutorial")
	emit_signal("tutorial_started", level_id, level["name"])
	_show_current_step()
	return true


## Get current step data
func get_current_step() -> Dictionary:
	if _current_level < 0 or _current_step < 0:
		return {}
	var level = TUTORIAL_LEVELS.get(_current_level, {})
	var steps = level.get("steps", [])
	if _current_step < steps.size():
		return steps[_current_step]
	return {}


## Advance to next step
func next_step() -> bool:
	if not _tutorial_active:
		return false

	var level = TUTORIAL_LEVELS.get(_current_level, {})
	var steps = level.get("steps", [])

	_current_step += 1
	_step_timer = 0.0
	_objective_completed = false

	if _current_step >= steps.size():
		_complete_tutorial()
		return false

	_show_current_step()
	return true


## Complete current objective
func complete_objective() -> void:
	if not _tutorial_active:
		return
	_objective_completed = true
	var step = get_current_step()
	if step.get("type") == StepType.OBJECTIVE:
		GameLog.info("TutorialSystem: Objective completed: %s" % step.get("title", ""), "Tutorial")
		emit_signal("objective_completed", step.get("objective", ""))


## Check if current step is complete
func is_step_complete() -> bool:
	var step = get_current_step()
	if step.is_empty():
		return false
	match step.get("type"):
		StepType.INFO, StepType.DIALOGUE:
			return true  # Info/dialogue steps complete when player advances
		StepType.OBJECTIVE:
			return _objective_completed
		StepType.ACTION_REQUIRED:
			return _objective_completed
	return false


## Update tutorial (call every frame)
func update(delta: float) -> void:
	if not _tutorial_active:
		return

	var step = get_current_step()
	if step.is_empty():
		return

	# Update step timer for objective steps with duration
	if step.get("type") == StepType.OBJECTIVE and step.has("duration"):
		_step_timer += delta
		if _step_timer >= step["duration"] and not _objective_completed:
			# Auto-complete objective after duration (for tutorial purposes)
			complete_objective()


## Complete current tutorial
func _complete_tutorial() -> void:
	var level_id = _current_level
	var level_name = TUTORIAL_LEVELS.get(level_id, {}).get("name", "Unknown")

	if not _completed_levels.has(level_id):
		_completed_levels.append(level_id)

	_tutorial_active = false
	_current_level = -1
	_current_step = 0

	GameLog.info("TutorialSystem: Tutorial '%s' completed" % level_name, "Tutorial")
	emit_signal("tutorial_completed", level_id, level_name)


## Show current step (emit signal for UI)
func _show_current_step() -> void:
	var step = get_current_step()
	if not step.is_empty():
		emit_signal("step_changed", _current_step, step)


## Get tutorial level info
func get_level_info(level_id: int) -> Dictionary:
	return TUTORIAL_LEVELS.get(level_id, {}).duplicate(true)


## Get all tutorial levels
func get_all_levels() -> Dictionary:
	return TUTORIAL_LEVELS.duplicate(true)


## Get tutorial level list (for UI)
func get_level_list() -> Array:
	var list = []
	for level_id in TUTORIAL_LEVELS.keys():
		var level = TUTORIAL_LEVELS[level_id]
		list.append({
			"id": level_id,
			"name": level["name"],
			"description": level["description"],
			"icon": level["icon"],
			"estimated_time": level["estimated_time"],
			"completed": _completed_levels.has(level_id),
			"step_count": level["steps"].size()
		})
	return list


## Check if tutorial is active
func is_tutorial_active() -> bool:
	return _tutorial_active


## Get current level id
func get_current_level() -> int:
	return _current_level


## Get current step index
func get_current_step_index() -> int:
	return _current_step


## Get completed levels
func get_completed_levels() -> Array:
	return _completed_levels.duplicate()


## Check if level is completed
func is_level_completed(level_id: int) -> bool:
	return _completed_levels.has(level_id)


## Get total progress (0-1)
func get_progress() -> float:
	if TUTORIAL_LEVELS.is_empty():
		return 0.0
	return float(_completed_levels.size()) / float(TUTORIAL_LEVELS.size())


## Reset all tutorial progress
func reset_progress() -> void:
	_completed_levels.clear()
	_current_level = -1
	_current_step = 0
	_tutorial_active = false
	GameLog.info("TutorialSystem: All tutorial progress reset", "Tutorial")


## Signals
signal tutorial_started(level_id, level_name)
signal step_changed(step_index, step_data)
signal objective_completed(objective_id)
signal tutorial_completed(level_id, level_name)
