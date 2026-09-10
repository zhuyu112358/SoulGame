extends Node
## CollectionSystem - Collection and gallery system
## Follows GDD v2.0 Chapter 13: Achievements & Meta Game (Collection)
## M2.13 Achievements & Meta Game - Collection System
##
## Manages collectibles: items, concept art, soul entries, and other
## unlockable content. Tracks collection progress and provides
## gallery viewing functionality.

## Collection categories
enum CollectionCategory {
	ITEM,       # Collected items
	CONCEPT_ART,# Concept art / illustrations
	SOUL,       # Soul entries (integrated with SoulCodex)
	TRAP,       # Discovered traps
	MAP,        # Discovered maps
	EMOTE       # Unlocked emotes/expressions
}

## Item collection data (17 items from ItemSystem)
var _item_definitions: Dictionary = {
	"health_potion": {"name": "生命药水", "description": "恢复50点生命值", "rarity": "common"},
	"energy_potion": {"name": "能量药水", "description": "恢复30点能量", "rarity": "common"},
	"attack_boost": {"name": "攻击强化", "description": "攻击力+20%，持续10秒", "rarity": "uncommon"},
	"defense_boost": {"name": "防御强化", "description": "防御力+30%，持续10秒", "rarity": "uncommon"},
	"speed_boost": {"name": "速度强化", "description": "移动速度+25%，持续8秒", "rarity": "uncommon"},
	"crit_boost": {"name": "暴击强化", "description": "暴击率+15%，持续10秒", "rarity": "rare"},
	"shield": {"name": "护盾", "description": "获得50点护盾", "rarity": "uncommon"},
	"revive": {"name": "复活羽毛", "description": "死亡时复活，恢复30%生命", "rarity": "epic"},
	"teleport": {"name": "传送卷轴", "description": "传送到指定位置", "rarity": "rare"},
	"invisibility": {"name": "隐身药水", "description": "隐身5秒", "rarity": "rare"},
	"damage_amplify": {"name": "伤害增幅", "description": "造成伤害+50%，持续8秒", "rarity": "epic"},
	"heal_aura": {"name": "治疗光环", "description": "周围友军每秒恢复5生命，持续10秒", "rarity": "rare"},
	"energy_surge": {"name": "能量涌动", "description": "能量恢复速度+100%，持续10秒", "rarity": "uncommon"},
	"rage": {"name": "狂暴药剂", "description": "攻击+50%，防御-20%，持续8秒", "rarity": "rare"},
	"freeze": {"name": "冰冻炸弹", "description": "冻结范围内敌人3秒", "rarity": "epic"},
	"lightning": {"name": "闪电卷轴", "description": "召唤闪电打击目标", "rarity": "rare"},
	"soul_stone": {"name": "灵魂石", "description": "稀有材料，用于灵魂进化", "rarity": "legendary"}
}

## Concept art collection data
var _concept_art_definitions: Dictionary = {
	"main_menu_concept": {"name": "主菜单概念图", "description": "主菜单界面设计概念", "category": "ui"},
	"battle_arena_concept": {"name": "战斗竞技场概念图", "description": "战斗场景设计概念", "category": "scene"},
	"soul_home_concept": {"name": "灵魂之家概念图", "description": "灵魂之家设计概念", "category": "scene"},
	"fire_soul_concept": {"name": "火灵概念图", "description": "火灵·小焰角色设计", "category": "character"},
	"water_soul_concept": {"name": "水灵概念图", "description": "水灵·小涟角色设计", "category": "character"},
	"earth_soul_concept": {"name": "土灵概念图", "description": "土灵·小岩角色设计", "category": "character"},
	"wind_soul_concept": {"name": "风灵概念图", "description": "风灵·小风角色设计", "category": "character"},
	"thunder_soul_concept": {"name": "雷灵概念图", "description": "雷灵·小雷角色设计", "category": "character"},
	"ice_soul_concept": {"name": "冰灵概念图", "description": "冰灵·小冰角色设计", "category": "character"},
	"dark_soul_concept": {"name": "暗灵概念图", "description": "暗灵·小暗角色设计", "category": "character"},
	"light_soul_concept": {"name": "光灵概念图", "description": "光灵·小光角色设计", "category": "character"},
	"world_map_concept": {"name": "世界地图概念图", "description": "灵界世界地图设计", "category": "world"},
	"item_icons_concept": {"name": "道具图标概念图", "description": "17种道具图标设计", "category": "ui"},
	"skill_icons_concept": {"name": "技能图标概念图", "description": "16种技能图标设计", "category": "ui"}
}

## Trap collection data (12 traps from TrapSystem)
var _trap_definitions: Dictionary = {
	"spike_trap": {"name": "尖刺陷阱", "description": "造成30点物理伤害"},
	"fire_trap": {"name": "火焰陷阱", "description": "造成40点火焰伤害+燃烧"},
	"ice_trap": {"name": "冰冻陷阱", "description": "冻结2秒"},
	"poison_trap": {"name": "毒雾陷阱", "description": "每秒5点毒伤害，持续5秒"},
	"lightning_trap": {"name": "闪电陷阱", "description": "造成50点雷电伤害+眩晕"},
	"slow_trap": {"name": "减速陷阱", "description": "移动速度-50%，持续3秒"},
	"bomb_trap": {"name": "炸弹陷阱", "description": "范围爆炸造成60点伤害"},
	"net_trap": {"name": "捕网陷阱", "description": "定身3秒"},
	"dark_trap": {"name": "暗影陷阱", "description": "致盲3秒，命中率-50%"},
	"heal_trap": {"name": "治疗陷阱", "description": "友方恢复30生命"},
	"energy_trap": {"name": "能量陷阱", "description": "友方恢复20能量"},
	"teleport_trap": {"name": "传送陷阱", "description": "传送到随机位置"}
}

## Collected items (persistent)
var _collected_items: Dictionary = {}

## Collected concept art (persistent)
var _collected_concept_art: Dictionary = {}

## Discovered traps (persistent)
var _discovered_traps: Dictionary = {}

## Signals
signal item_collected(item_id, item_data)
signal concept_art_unlocked(art_id, art_data)
signal trap_discovered(trap_id, trap_data)
signal collection_updated(category)


func _ready() -> void:
	_load_collection()
	GameLog.info("CollectionSystem: Ready - %d items, %d concept art, %d traps" % [
		_collected_items.size(), _collected_concept_art.size(), _discovered_traps.size()
	], "Collection")


## Collect an item
func collect_item(p_item_id: String) -> Dictionary:
	if not _item_definitions.has(p_item_id):
		return {"success": false, "reason": "未知道具"}

	if _collected_items.has(p_item_id):
		_collected_items[p_item_id]["count"] += 1
	else:
		var item_def = _item_definitions[p_item_id].duplicate()
		item_def["count"] = 1
		item_def["first_collected"] = Time.get_datetime_string_from_system()
		_collected_items[p_item_id] = item_def
		item_collected.emit(p_item_id, item_def)

	_save_collection()
	collection_updated.emit(CollectionCategory.ITEM)
	return {"success": true, "item_id": p_item_id, "item_data": _collected_items[p_item_id]}


## Unlock concept art
func unlock_concept_art(p_art_id: String) -> Dictionary:
	if not _concept_art_definitions.has(p_art_id):
		return {"success": false, "reason": "未知概念图"}

	if _collected_concept_art.has(p_art_id):
		return {"success": false, "reason": "已解锁"}

	var art_def = _concept_art_definitions[p_art_id].duplicate()
	art_def["unlocked_time"] = Time.get_datetime_string_from_system()
	_collected_concept_art[p_art_id] = art_def

	_save_collection()
	concept_art_unlocked.emit(p_art_id, art_def)
	collection_updated.emit(CollectionCategory.CONCEPT_ART)
	return {"success": true, "art_id": p_art_id, "art_data": art_def}


## Discover a trap
func discover_trap(p_trap_id: String) -> Dictionary:
	if not _trap_definitions.has(p_trap_id):
		return {"success": false, "reason": "未知陷阱"}

	if _discovered_traps.has(p_trap_id):
		_discovered_traps[p_trap_id]["encounter_count"] += 1
	else:
		var trap_def = _trap_definitions[p_trap_id].duplicate()
		trap_def["encounter_count"] = 1
		trap_def["first_discovered"] = Time.get_datetime_string_from_system()
		_discovered_traps[p_trap_id] = trap_def
		trap_discovered.emit(p_trap_id, trap_def)

	_save_collection()
	collection_updated.emit(CollectionCategory.TRAP)
	return {"success": true, "trap_id": p_trap_id, "trap_data": _discovered_traps[p_trap_id]}


## Get collected items
func get_collected_items() -> Array:
	var result: Array = []
	for item_id in _collected_items.keys():
		var item = _collected_items[item_id].duplicate()
		item["id"] = item_id
		result.append(item)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


## Get all item definitions (including uncollected)
func get_all_items() -> Array:
	var result: Array = []
	for item_id in _item_definitions.keys():
		var item = _item_definitions[item_id].duplicate()
		item["id"] = item_id
		item["collected"] = _collected_items.has(item_id)
		result.append(item)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


## Get collected concept art
func get_collected_concept_art() -> Array:
	var result: Array = []
	for art_id in _collected_concept_art.keys():
		var art = _collected_concept_art[art_id].duplicate()
		art["id"] = art_id
		result.append(art)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


## Get all concept art definitions (including locked)
func get_all_concept_art() -> Array:
	var result: Array = []
	for art_id in _concept_art_definitions.keys():
		var art = _concept_art_definitions[art_id].duplicate()
		art["id"] = art_id
		art["unlocked"] = _collected_concept_art.has(art_id)
		result.append(art)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


## Get discovered traps
func get_discovered_traps() -> Array:
	var result: Array = []
	for trap_id in _discovered_traps.keys():
		var trap = _discovered_traps[trap_id].duplicate()
		trap["id"] = trap_id
		result.append(trap)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


## Get all trap definitions (including undiscovered)
func get_all_traps() -> Array:
	var result: Array = []
	for trap_id in _trap_definitions.keys():
		var trap = _trap_definitions[trap_id].duplicate()
		trap["id"] = trap_id
		trap["discovered"] = _discovered_traps.has(trap_id)
		result.append(trap)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


## Get collection progress for a category
func get_collection_progress(p_category: int) -> Dictionary:
	match p_category:
		CollectionCategory.ITEM:
			return {
				"collected": _collected_items.size(),
				"total": _item_definitions.size(),
				"percentage": float(_collected_items.size()) / float(_item_definitions.size()) if _item_definitions.size() > 0 else 0.0
			}
		CollectionCategory.CONCEPT_ART:
			return {
				"collected": _collected_concept_art.size(),
				"total": _concept_art_definitions.size(),
				"percentage": float(_collected_concept_art.size()) / float(_concept_art_definitions.size()) if _concept_art_definitions.size() > 0 else 0.0
			}
		CollectionCategory.TRAP:
			return {
				"collected": _discovered_traps.size(),
				"total": _trap_definitions.size(),
				"percentage": float(_discovered_traps.size()) / float(_trap_definitions.size()) if _trap_definitions.size() > 0 else 0.0
			}
	return {"collected": 0, "total": 0, "percentage": 0.0}


## Get total collection progress (all categories)
func get_total_progress() -> Dictionary:
	var total_collected = _collected_items.size() + _collected_concept_art.size() + _discovered_traps.size()
	var total_all = _item_definitions.size() + _concept_art_definitions.size() + _trap_definitions.size()
	return {
		"collected": total_collected,
		"total": total_all,
		"percentage": float(total_collected) / float(total_all) if total_all > 0 else 0.0,
		"items": get_collection_progress(CollectionCategory.ITEM),
		"concept_art": get_collection_progress(CollectionCategory.CONCEPT_ART),
		"traps": get_collection_progress(CollectionCategory.TRAP)
	}


## Get rarity color
func get_rarity_color(p_rarity: String) -> Color:
	match p_rarity:
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.3, 0.9, 0.4)
		"rare": return Color(0.3, 0.6, 1.0)
		"epic": return Color(0.7, 0.4, 1.0)
		"legendary": return Color(1.0, 0.85, 0.3)
	return Color.WHITE


## Get rarity name
func get_rarity_name(p_rarity: String) -> String:
	match p_rarity:
		"common": return "普通"
		"uncommon": return "优秀"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
	return "未知"


## Save collection to file
func _save_collection() -> void:
	var config = ConfigFile.new()

	# Save collected items
	config.set_value("items", "count", _collected_items.size())
	for item_id in _collected_items.keys():
		var section = "item_%s" % item_id
		var item = _collected_items[item_id]
		config.set_value(section, "count", item.get("count", 1))
		config.set_value(section, "first_collected", item.get("first_collected", ""))

	# Save collected concept art
	config.set_value("concept_art", "count", _collected_concept_art.size())
	for art_id in _collected_concept_art.keys():
		var section = "art_%s" % art_id
		var art = _collected_concept_art[art_id]
		config.set_value(section, "unlocked_time", art.get("unlocked_time", ""))

	# Save discovered traps
	config.set_value("traps", "count", _discovered_traps.size())
	for trap_id in _discovered_traps.keys():
		var section = "trap_%s" % trap_id
		var trap = _discovered_traps[trap_id]
		config.set_value(section, "encounter_count", trap.get("encounter_count", 1))
		config.set_value(section, "first_discovered", trap.get("first_discovered", ""))

	var err = config.save("user://collection.cfg")
	if err == OK:
		GameLog.info("CollectionSystem: Saved collection", "Collection")
	else:
		GameLog.warning("CollectionSystem: Failed to save (error %d)" % err, "Collection")


## Load collection from file
func _load_collection() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://collection.cfg")
	if err != OK:
		GameLog.info("CollectionSystem: No saved collection data", "Collection")
		return

	# Load collected items
	var sections = config.get_sections()
	for section in sections:
		if section.begins_with("item_"):
			var item_id = section.substr(5)  # len("item_") = 5
			if _item_definitions.has(item_id):
				var item_def = _item_definitions[item_id].duplicate()
				item_def["count"] = config.get_value(section, "count", 1)
				item_def["first_collected"] = config.get_value(section, "first_collected", "")
				_collected_items[item_id] = item_def

		elif section.begins_with("art_"):
			var art_id = section.substr(4)  # len("art_") = 4
			if _concept_art_definitions.has(art_id):
				var art_def = _concept_art_definitions[art_id].duplicate()
				art_def["unlocked_time"] = config.get_value(section, "unlocked_time", "")
				_collected_concept_art[art_id] = art_def

		elif section.begins_with("trap_"):
			var trap_id = section.substr(5)  # len("trap_") = 5
			if _trap_definitions.has(trap_id):
				var trap_def = _trap_definitions[trap_id].duplicate()
				trap_def["encounter_count"] = config.get_value(section, "encounter_count", 1)
				trap_def["first_discovered"] = config.get_value(section, "first_discovered", "")
				_discovered_traps[trap_id] = trap_def

	GameLog.info("CollectionSystem: Loaded %d items, %d concept art, %d traps" % [
		_collected_items.size(), _collected_concept_art.size(), _discovered_traps.size()
	], "Collection")
