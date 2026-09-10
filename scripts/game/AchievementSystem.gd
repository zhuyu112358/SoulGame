extends Node
## AchievementSystem - Manages achievements, unlock conditions, and stats tracking
## Follows GDD v2.0 Chapter 13: Achievements & Meta-Game
## M2.13 Achievements & Meta-Game (Base)

## Achievement definitions (20 achievements: 5 combat + 5 skill + 5 collection + 5 progression)
const ACHIEVEMENTS := {
	# Combat achievements (5)
	"first_victory": {
		"name": "初战告捷",
		"description": "赢得第一场战斗",
		"category": "combat",
		"icon_index": 0,
		"rarity": "common",
		"condition": {"type": "battles_won", "value": 1}
	},
	"ten_victories": {
		"name": "小有成就",
		"description": "累计赢得10场战斗",
		"category": "combat",
		"icon_index": 1,
		"rarity": "uncommon",
		"condition": {"type": "battles_won", "value": 10}
	},
	"fifty_victories": {
		"name": "百战不殆",
		"description": "累计赢得50场战斗",
		"category": "combat",
		"icon_index": 2,
		"rarity": "rare",
		"condition": {"type": "battles_won", "value": 50}
	},
	"perfect_victory": {
		"name": "完美胜利",
		"description": "在不损失任何生命值的情况下赢得战斗",
		"category": "combat",
		"icon_index": 3,
		"rarity": "epic",
		"condition": {"type": "perfect_victory", "value": 1}
	},
	"speed_demon": {
		"name": "闪电战",
		"description": "在60秒内赢得战斗",
		"category": "combat",
		"icon_index": 4,
		"rarity": "rare",
		"condition": {"type": "fast_victory", "value": 60}
	},
	# Skill achievements (5)
	"skill_master": {
		"name": "技能大师",
		"description": "单场战斗使用技能20次",
		"category": "skill",
		"icon_index": 5,
		"rarity": "uncommon",
		"condition": {"type": "skills_used", "value": 20}
	},
	"crit_expert": {
		"name": "暴击专家",
		"description": "单场战斗触发暴击10次",
		"category": "skill",
		"icon_index": 6,
		"rarity": "uncommon",
		"condition": {"type": "crits_dealt", "value": 10}
	},
	"healer": {
		"name": "治愈者",
		"description": "单场战斗恢复生命值500点",
		"category": "skill",
		"icon_index": 7,
		"rarity": "common",
		"condition": {"type": "healing_done", "value": 500}
	},
	"shield_guardian": {
		"name": "护盾守护者",
		"description": "单场战斗护盾吸收伤害300点",
		"category": "skill",
		"icon_index": 8,
		"rarity": "uncommon",
		"condition": {"type": "shield_absorbed", "value": 300}
	},
	"combo_master": {
		"name": "连击大师",
		"description": "单场战斗达成5连击",
		"category": "skill",
		"icon_index": 9,
		"rarity": "rare",
		"condition": {"type": "max_combo", "value": 5}
	},
	# Collection achievements (5)
	"soul_collector": {
		"name": "灵魂收藏家",
		"description": "解锁所有8个元素灵魂",
		"category": "collection",
		"icon_index": 10,
		"rarity": "rare",
		"condition": {"type": "souls_unlocked", "value": 8}
	},
	"item_hunter": {
		"name": "道具猎人",
		"description": "累计拾取道具50个",
		"category": "collection",
		"icon_index": 11,
		"rarity": "common",
		"condition": {"type": "items_picked", "value": 50}
	},
	"talent_master": {
		"name": "天赋大师",
		"description": "单场战斗选择4个天赋",
		"category": "collection",
		"icon_index": 12,
		"rarity": "uncommon",
		"condition": {"type": "talents_selected", "value": 4}
	},
	"map_explorer": {
		"name": "地图探索者",
		"description": "在所有2张地图上赢得战斗",
		"category": "collection",
		"icon_index": 13,
		"rarity": "uncommon",
		"condition": {"type": "maps_won", "value": 2}
	},
	"codex_complete": {
		"name": "图鉴完成者",
		"description": "查看所有灵魂图鉴条目",
		"category": "collection",
		"icon_index": 14,
		"rarity": "epic",
		"condition": {"type": "codex_viewed", "value": 8}
	},
	# Progression achievements (5)
	"novice": {
		"name": "新手冒险者",
		"description": "完成第一场战斗",
		"category": "progression",
		"icon_index": 15,
		"rarity": "common",
		"condition": {"type": "battles_played", "value": 1}
	},
	"intermediate": {
		"name": "进阶战士",
		"description": "累计完成20场战斗",
		"category": "progression",
		"icon_index": 16,
		"rarity": "uncommon",
		"condition": {"type": "battles_played", "value": 20}
	},
	"expert": {
		"name": "专家指挥官",
		"description": "累计完成100场战斗",
		"category": "progression",
		"icon_index": 17,
		"rarity": "rare",
		"condition": {"type": "battles_played", "value": 100}
	},
	"master": {
		"name": "大师级灵魂",
		"description": "任意灵魂达到10级",
		"category": "progression",
		"icon_index": 18,
		"rarity": "epic",
		"condition": {"type": "soul_level", "value": 10}
	},
	"legend": {
		"name": "传奇指挥官",
		"description": "累计赢得100场战斗",
		"category": "progression",
		"icon_index": 19,
		"rarity": "legendary",
		"condition": {"type": "battles_won", "value": 100}
	}
}

## Unlocked achievements (persistent)
var _unlocked_achievements: Dictionary = {}

## Player statistics (persistent)
var _stats: Dictionary = {
	"battles_played": 0,
	"battles_won": 0,
	"battles_lost": 0,
	"total_damage_dealt": 0.0,
	"total_damage_taken": 0.0,
	"total_healing_done": 0.0,
	"total_skills_used": 0,
	"total_crits_dealt": 0,
	"total_items_picked": 0,
	"total_talents_selected": 0,
	"souls_unlocked": 1,
	"maps_won": [],
	"perfect_victories": 0,
	"fast_victories": 0,
	"max_combo": 0,
	"play_time_seconds": 0.0
}

## Current battle stats (reset each battle)
var _battle_stats: Dictionary = {}

## Achievement icon sheet (4 rows x 5 cols, 1024x1024, 20 icons)
var _achievement_icon_sheet: Texture2D = null

## Save file path
const SAVE_PATH := "user://achievements.save"

## Signal emitted when achievement is unlocked
signal achievement_unlocked(achievement_id, achievement_data)

## Signal emitted when stats update
signal stats_updated(stats)


func _ready() -> void:
	# Load achievement icon sheet
	var sheet_path := "res://assets/art/achievement_icon_sheet_v1.png"
	if ResourceLoader.exists(sheet_path):
		_achievement_icon_sheet = load(sheet_path)
	else:
		push_warning("AchievementSystem: achievement_icon_sheet_v1.png not found")
	# Load saved data
	_load_data()


## Start tracking a new battle
func start_battle_tracking() -> void:
	_battle_stats = {
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"healing_done": 0.0,
		"skills_used": 0,
		"crits_dealt": 0,
		"items_picked": 0,
		"talents_selected": 0,
		"max_combo": 0,
		"current_combo": 0,
		"shield_absorbed": 0.0,
		"start_hp": 0.0,
		"battle_duration": 0.0
	}


## End battle tracking and check achievements
func end_battle_tracking(victory: bool, map_name: String = "", battle_duration: float = 0.0) -> void:
	# Update persistent stats
	_stats["battles_played"] += 1
	if victory:
		_stats["battles_won"] += 1
		# Track maps won
		if map_name != "" and map_name not in _stats["maps_won"]:
			_stats["maps_won"].append(map_name)
		# Perfect victory check (no damage taken)
		if _battle_stats.get("damage_taken", 0.0) <= 0:
			_stats["perfect_victories"] += 1
		# Fast victory check
		if battle_duration > 0 and battle_duration <= 60:
			_stats["fast_victories"] += 1
	else:
		_stats["battles_lost"] += 1

	# Accumulate battle stats
	_stats["total_damage_dealt"] += _battle_stats.get("damage_dealt", 0.0)
	_stats["total_damage_taken"] += _battle_stats.get("damage_taken", 0.0)
	_stats["total_healing_done"] += _battle_stats.get("healing_done", 0.0)
	_stats["total_skills_used"] += _battle_stats.get("skills_used", 0)
	_stats["total_crits_dealt"] += _battle_stats.get("crits_dealt", 0)
	_stats["total_items_picked"] += _battle_stats.get("items_picked", 0)
	_stats["total_talents_selected"] += _battle_stats.get("talents_selected", 0)
	if _battle_stats.get("max_combo", 0) > _stats["max_combo"]:
		_stats["max_combo"] = _battle_stats["max_combo"]

	# Check all achievements
	_check_all_achievements(victory, map_name, battle_duration)

	# Save data
	_save_data()

	# Sync stats to Steam Manager
	_sync_stats_to_steam()

	# Emit stats updated
	stats_updated.emit(_stats)


## Sync player stats to Steam Manager
func _sync_stats_to_steam() -> void:
	if not _is_steam_manager_available():
		return
	# Sync key stats to Steam
	SteamManager.set_stat("battles_played", int(_stats.get("battles_played", 0)))
	SteamManager.set_stat("battles_won", int(_stats.get("battles_won", 0)))
	SteamManager.set_stat("battles_lost", int(_stats.get("battles_lost", 0)))
	SteamManager.set_stat("total_damage_dealt", int(_stats.get("total_damage_dealt", 0)))
	SteamManager.set_stat("total_skills_used", int(_stats.get("total_skills_used", 0)))
	SteamManager.set_stat("total_crits_dealt", int(_stats.get("total_crits_dealt", 0)))
	SteamManager.set_stat("perfect_victories", int(_stats.get("perfect_victories", 0)))
	SteamManager.set_stat("fast_victories", int(_stats.get("fast_victories", 0)))
	SteamManager.store_stats()


## Record damage dealt
func record_damage_dealt(amount: float) -> void:
	_battle_stats["damage_dealt"] = _battle_stats.get("damage_dealt", 0.0) + amount
	# Increment combo
	_battle_stats["current_combo"] = _battle_stats.get("current_combo", 0) + 1
	if _battle_stats["current_combo"] > _battle_stats.get("max_combo", 0):
		_battle_stats["max_combo"] = _battle_stats["current_combo"]


## Record damage taken
func record_damage_taken(amount: float) -> void:
	_battle_stats["damage_taken"] = _battle_stats.get("damage_taken", 0.0) + amount
	# Reset combo on damage taken
	_battle_stats["current_combo"] = 0


## Record healing done
func record_healing_done(amount: float) -> void:
	_battle_stats["healing_done"] = _battle_stats.get("healing_done", 0.0) + amount


## Record skill used
func record_skill_used() -> void:
	_battle_stats["skills_used"] = _battle_stats.get("skills_used", 0) + 1


## Record crit dealt
func record_crit_dealt() -> void:
	_battle_stats["crits_dealt"] = _battle_stats.get("crits_dealt", 0) + 1


## Record item picked
func record_item_picked() -> void:
	_battle_stats["items_picked"] = _battle_stats.get("items_picked", 0) + 1


## Record talent selected
func record_talent_selected() -> void:
	_battle_stats["talents_selected"] = _battle_stats.get("talents_selected", 0) + 1


## Record shield absorbed
func record_shield_absorbed(amount: float) -> void:
	_battle_stats["shield_absorbed"] = _battle_stats.get("shield_absorbed", 0.0) + amount


## Check all achievements for unlock
func _check_all_achievements(victory: bool, map_name: String, battle_duration: float) -> void:
	for achievement_id in ACHIEVEMENTS.keys():
		if _unlocked_achievements.has(achievement_id):
			continue  # Already unlocked
		var achievement = ACHIEVEMENTS[achievement_id]
		var condition = achievement["condition"]
		if _check_condition(condition, victory, map_name, battle_duration):
			_unlock_achievement(achievement_id)


## Check if achievement condition is met
func _check_condition(condition: Dictionary, victory: bool, map_name: String, battle_duration: float) -> bool:
	var cond_type = condition["type"]
	var cond_value = condition["value"]

	match cond_type:
		"battles_won":
			return _stats["battles_won"] >= cond_value
		"battles_played":
			return _stats["battles_played"] >= cond_value
		"perfect_victory":
			return _stats["perfect_victories"] >= cond_value
		"fast_victory":
			return victory and battle_duration > 0 and battle_duration <= cond_value
		"skills_used":
			return _battle_stats.get("skills_used", 0) >= cond_value
		"crits_dealt":
			return _battle_stats.get("crits_dealt", 0) >= cond_value
		"healing_done":
			return _battle_stats.get("healing_done", 0.0) >= cond_value
		"shield_absorbed":
			return _battle_stats.get("shield_absorbed", 0.0) >= cond_value
		"max_combo":
			return _battle_stats.get("max_combo", 0) >= cond_value
		"souls_unlocked":
			return _stats["souls_unlocked"] >= cond_value
		"items_picked":
			return _stats["total_items_picked"] >= cond_value
		"talents_selected":
			return _battle_stats.get("talents_selected", 0) >= cond_value
		"maps_won":
			return _stats["maps_won"].size() >= cond_value
		"codex_viewed":
			return _stats.get("codex_viewed", 0) >= cond_value
		"soul_level":
			return _stats.get("max_soul_level", 1) >= cond_value
		_:
			return false


## Unlock an achievement
func _unlock_achievement(achievement_id: String) -> void:
	if _unlocked_achievements.has(achievement_id):
		return
	var achievement = ACHIEVEMENTS.get(achievement_id, null)
	if achievement == null:
		return
	_unlocked_achievements[achievement_id] = {
		"unlocked_at": Time.get_datetime_string_from_system(),
		"name": achievement["name"],
		"description": achievement["description"]
	}
	achievement_unlocked.emit(achievement_id, achievement)
	GameLog.info("Achievement unlocked: %s" % achievement["name"], "Achievement")
	# Sync to Steam Manager if available
	_sync_achievement_to_steam(achievement_id)


## Sync achievement unlock to Steam Manager
func _sync_achievement_to_steam(achievement_id: String) -> void:
	if Engine.has_singleton("SteamManager") or _is_steam_manager_available():
		SteamManager.unlock_achievement(achievement_id)


## Check if Steam Manager singleton is available
func _is_steam_manager_available() -> bool:
	return get_node_or_null("/root/SteamManager") != null


## Check if achievement is unlocked
func is_achievement_unlocked(achievement_id: String) -> bool:
	return _unlocked_achievements.has(achievement_id)


## Get achievement definition
func get_achievement(achievement_id: String) -> Dictionary:
	return ACHIEVEMENTS.get(achievement_id, {})


## Get all achievement IDs
func get_all_achievement_ids() -> Array:
	return ACHIEVEMENTS.keys()


## Get unlocked achievements count
func get_unlocked_count() -> int:
	return _unlocked_achievements.size()


## Get total achievements count
func get_total_count() -> int:
	return ACHIEVEMENTS.size()


## Get player stats
func get_stats() -> Dictionary:
	return _stats


## Get achievement icon texture from sheet
func get_achievement_icon(achievement_id: String) -> Texture2D:
	if _achievement_icon_sheet == null:
		return null
	var achievement = ACHIEVEMENTS.get(achievement_id, null)
	if achievement == null:
		return null
	var icon_idx = achievement.get("icon_index", 0)
	var row: int = icon_idx / 5
	var col: int = icon_idx % 5
	var cell_w: int = 204  # 1024 / 5
	var cell_h: int = 256  # 1024 / 4
	var atlas = AtlasTexture.new()
	atlas.atlas = _achievement_icon_sheet
	atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	return atlas


## Save achievement data to file
func _save_data() -> void:
	var save_data = {
		"unlocked": _unlocked_achievements,
		"stats": _stats
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))
		f.close()


## Load achievement data from file
func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var json_string = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(json_string)
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("unlocked"):
				_unlocked_achievements = parsed["unlocked"]
			if parsed.has("stats"):
				# Merge with default stats to ensure all keys exist
				for key in _stats.keys():
					if parsed["stats"].has(key):
						_stats[key] = parsed["stats"][key]


## Reset all achievement data (for testing)
func reset_all() -> void:
	_unlocked_achievements.clear()
	_stats = {
		"battles_played": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"total_damage_dealt": 0.0,
		"total_damage_taken": 0.0,
		"total_healing_done": 0.0,
		"total_skills_used": 0,
		"total_crits_dealt": 0,
		"total_items_picked": 0,
		"total_talents_selected": 0,
		"souls_unlocked": 1,
		"maps_won": [],
		"perfect_victories": 0,
		"fast_victories": 0,
		"max_combo": 0,
		"play_time_seconds": 0.0
	}
	_save_data()
