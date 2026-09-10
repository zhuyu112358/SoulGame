extends Node
## SoulCodexSystem - Soul codex (bestiary/collection) system
## Follows GDD v2.0 Chapter 13: Achievements and Meta Game
## M2.13 Achievements & Meta Game - Soul Codex
##
## Tracks discovered souls and displays detailed information.
## 8 element souls with stats, skills, personality, and lore.

## Soul codex data
var _soul_data: Dictionary = {
	"fire": {
		"name": "火灵·小焰",
		"element": "fire",
		"element_name": "火",
		"rarity": "common",
		"description": "热情奔放的火元素灵魂，永远充满活力。喜欢在战场上冲锋陷阵，是最可靠的进攻者。",
		"lore": "传说中，小焰是第一只被人类指挥官召唤的灵魂。它的火焰温暖而炽热，象征着勇气和希望。",
		"base_stats": {
			"hp": 100,
			"attack": 15,
			"defense": 8,
			"speed": 160,
			"crit_rate": 0.15,
			"crit_multiplier": 1.6
		},
		"skills": ["火球术", "烈焰冲击", "火焰护盾", "末日烈焰"],
		"personality": "激进",
		"strengths": ["高攻击力", "高暴击率", "持续伤害"],
		"weaknesses": ["防御力低", "怕水元素"],
		"color": Color(1.0, 0.4, 0.2),
		"unlocked": false
	},
	"water": {
		"name": "水灵·小涟",
		"element": "water",
		"element_name": "水",
		"rarity": "common",
		"description": "温柔冷静的水元素灵魂，善于治疗和防守。在队伍中扮演着守护者的角色。",
		"lore": "小涟来自灵界最深的湖泊，它的水流能治愈一切伤痛。据说它的眼泪可以让枯萎的植物重新生长。",
		"base_stats": {
			"hp": 120,
			"attack": 10,
			"defense": 12,
			"speed": 140,
			"crit_rate": 0.08,
			"crit_multiplier": 1.4
		},
		"skills": ["冰霜箭", "治愈之泉", "水之屏障", "海啸"],
		"personality": "冷静",
		"strengths": ["高生命值", "治疗能力", "防御力强"],
		"weaknesses": ["攻击力低", "怕雷元素"],
		"color": Color(0.2, 0.5, 1.0),
		"unlocked": false
	},
	"earth": {
		"name": "土灵·小岩",
		"element": "earth",
		"element_name": "土",
		"rarity": "common",
		"description": "沉稳可靠的土元素灵魂，是队伍中最坚实的盾牌。固执但忠诚，永远守护着队友。",
		"lore": "小岩是灵界最古老的灵魂之一，它的身体由千年岩石构成。它见证了灵界的兴衰，始终守护着这片土地。",
		"base_stats": {
			"hp": 150,
			"attack": 12,
			"defense": 18,
			"speed": 100,
			"crit_rate": 0.05,
			"crit_multiplier": 1.3
		},
		"skills": ["岩石护盾", "地震", "大地之力", "山崩"],
		"personality": "固执",
		"strengths": ["极高生命值", "极高防御力", "控制能力"],
		"weaknesses": ["速度慢", "怕风元素"],
		"color": Color(0.6, 0.4, 0.2),
		"unlocked": false
	},
	"wind": {
		"name": "风灵·小风",
		"element": "wind",
		"element_name": "风",
		"rarity": "common",
		"description": "自由奔放的风元素灵魂，速度极快，喜欢探索和冒险。总是第一个发现战场的变化。",
		"lore": "小风来自灵界最高的山峰，它的身影如风般难以捕捉。它喜欢在世界各地旅行，收集有趣的故事。",
		"base_stats": {
			"hp": 90,
			"attack": 11,
			"defense": 7,
			"speed": 200,
			"crit_rate": 0.12,
			"crit_multiplier": 1.5
		},
		"skills": ["风刃", "疾风步", "龙卷风", "风暴之怒"],
		"personality": "好奇",
		"strengths": ["极高速度", "高闪避", "探索能力"],
		"weaknesses": ["生命值低", "怕冰元素"],
		"color": Color(0.3, 0.9, 0.6),
		"unlocked": false
	},
	"thunder": {
		"name": "雷灵·小雷",
		"element": "thunder",
		"element_name": "雷",
		"rarity": "rare",
		"description": "勇敢无畏的雷元素灵魂，攻击力惊人，速度极快。是战场上最令人畏惧的存在。",
		"lore": "小雷诞生于灵界最猛烈的雷暴中，它的力量足以撕裂天空。它勇敢地面对一切危险，从不退缩。",
		"base_stats": {
			"hp": 100,
			"attack": 18,
			"defense": 8,
			"speed": 180,
			"crit_rate": 0.20,
			"crit_multiplier": 1.7
		},
		"skills": ["雷电术", "闪电链", "雷神之怒", "天罚"],
		"personality": "勇敢",
		"strengths": ["极高攻击力", "高暴击", "速度快"],
		"weaknesses": ["防御力低", "怕土元素"],
		"color": Color(0.8, 0.6, 1.0),
		"unlocked": false
	},
	"ice": {
		"name": "冰灵·小冰",
		"element": "ice",
		"element_name": "冰",
		"rarity": "rare",
		"description": "孤傲冷漠的冰元素灵魂，不喜欢与人亲近，但内心善良。它的冰冻能力让敌人寸步难行。",
		"lore": "小冰来自灵界最寒冷的极地，它的存在让周围的温度骤降。它看似冷漠，却在默默守护着需要帮助的灵魂。",
		"base_stats": {
			"hp": 110,
			"attack": 13,
			"defense": 14,
			"speed": 130,
			"crit_rate": 0.10,
			"crit_multiplier": 1.5
		},
		"skills": ["冰霜新星", "冰冻术", "极寒领域", "绝对零度"],
		"personality": "孤傲",
		"strengths": ["控制能力", "防御力强", "持续伤害"],
		"weaknesses": ["速度慢", "怕火元素"],
		"color": Color(0.5, 0.9, 1.0),
		"unlocked": false
	},
	"dark": {
		"name": "暗灵·小暗",
		"element": "dark",
		"element_name": "暗",
		"rarity": "epic",
		"description": "神秘严肃的暗元素灵魂，行踪不定，善于暗杀和潜行。它的过去充满了谜团。",
		"lore": "小暗来自灵界最黑暗的深渊，它的力量来自于阴影。没有人知道它的真实身份，只知道它在关键时刻总会出现。",
		"base_stats": {
			"hp": 95,
			"attack": 16,
			"defense": 9,
			"speed": 170,
			"crit_rate": 0.25,
			"crit_multiplier": 1.8
		},
		"skills": ["暗影突袭", "隐身术", "黑暗吞噬", "深渊之怒"],
		"personality": "严肃",
		"strengths": ["极高暴击", "暗杀能力", "潜行"],
		"weaknesses": ["生命值低", "怕光元素"],
		"color": Color(0.5, 0.3, 0.7),
		"unlocked": false
	},
	"light": {
		"name": "光灵·小光",
		"element": "light",
		"element_name": "光",
		"rarity": "epic",
		"description": "友善温暖的光元素灵魂，是队伍的精神支柱。它的光芒能驱散黑暗，治愈心灵。",
		"lore": "小光是灵界最纯净的存在，它的光芒照亮了整个灵界。它相信每一个灵魂都有善良的一面，总是愿意帮助他人。",
		"base_stats": {
			"hp": 115,
			"attack": 14,
			"defense": 13,
			"speed": 150,
			"crit_rate": 0.12,
			"crit_multiplier": 1.5
		},
		"skills": ["神圣之光", "治愈术", "光明护盾", "圣光审判"],
		"personality": "友善",
		"strengths": ["治疗能力", "全面均衡", "克制暗元素"],
		"weaknesses": ["没有明显弱点"],
		"color": Color(1.0, 0.9, 0.4),
		"unlocked": false
	}
}

## Unlocked souls (loaded from save)
var _unlocked_souls: Array = []

## Codex stats
var _total_discovered: int = 0
var _total_souls: int = 8

## Signals
signal soul_unlocked(element)
signal codex_updated()


func _ready() -> void:
	_total_souls = _soul_data.size()
	_load_codex()
	GameLog.info("SoulCodexSystem: Ready, %d/%d souls discovered" % [_total_discovered, _total_souls], "Codex")


## Unlock a soul in the codex
func unlock_soul(p_element: String) -> void:
	if not _soul_data.has(p_element):
		GameLog.warning("SoulCodexSystem: Unknown element: %s" % p_element, "Codex")
		return

	if p_element in _unlocked_souls:
		return

	_unlocked_souls.append(p_element)
	_total_discovered = _unlocked_souls.size()
	_soul_data[p_element]["unlocked"] = true

	_save_codex()
	soul_unlocked.emit(p_element)
	codex_updated.emit()

	GameLog.info("SoulCodexSystem: Unlocked soul - %s (%d/%d)" % [
		_soul_data[p_element]["name"], _total_discovered, _total_souls
	], "Codex")


## Check if soul is unlocked
func is_soul_unlocked(p_element: String) -> bool:
	return p_element in _unlocked_souls


## Get soul data
func get_soul_data(p_element: String) -> Dictionary:
	if not _soul_data.has(p_element):
		return {}
	return _soul_data[p_element].duplicate()


## Get all soul data (for codex display)
func get_all_souls() -> Array:
	var result: Array = []
	for element in _soul_data.keys():
		var data = _soul_data[element].duplicate()
		data["unlocked"] = element in _unlocked_souls
		result.append(data)
	return result


## Get unlocked souls
func get_unlocked_souls() -> Array:
	return _unlocked_souls.duplicate()


## Get discovery progress
func get_discovery_progress() -> Dictionary:
	return {
		"discovered": _total_discovered,
		"total": _total_souls,
		"percentage": float(_total_discovered) / float(_total_souls) * 100.0
	}


## Get rarity name
func get_rarity_name(p_rarity: String) -> String:
	match p_rarity:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
	return p_rarity


## Get rarity color
func get_rarity_color(p_rarity: String) -> Color:
	match p_rarity:
		"common":
			return Color(0.7, 0.7, 0.7)
		"rare":
			return Color(0.3, 0.6, 1.0)
		"epic":
			return Color(0.7, 0.3, 1.0)
		"legendary":
			return Color(1.0, 0.8, 0.2)
	return Color.WHITE


## Save codex to file
func _save_codex() -> void:
	var file = FileAccess.open("user://soul_codex.cfg", FileAccess.WRITE)
	if file == null:
		GameLog.warning("SoulCodexSystem: Cannot save codex", "Codex")
		return

	file.store_line("[codex]")
	file.store_line("unlocked=" + ",".join(_unlocked_souls))
	file.close()


## Load codex from file
func _load_codex() -> void:
	if not FileAccess.file_exists("user://soul_codex.cfg"):
		# Default: unlock fire soul (starter)
		_unlocked_souls = ["fire"]
		_total_discovered = 1
		_soul_data["fire"]["unlocked"] = true
		_save_codex()
		return

	var file = FileAccess.open("user://soul_codex.cfg", FileAccess.READ)
	if file == null:
		return

	var content = file.get_as_text()
	file.close()

	# Parse unlocked souls
	for line in content.split("\n"):
		if line.begins_with("unlocked="):
			var value = line.substr(9)
			if value != "":
				_unlocked_souls = value.split(",")
				# Filter valid elements
				var valid: Array = []
				for element in _unlocked_souls:
					if _soul_data.has(element):
						valid.append(element)
						_soul_data[element]["unlocked"] = true
				_unlocked_souls = valid

	_total_discovered = _unlocked_souls.size()

	# Ensure at least fire soul is unlocked
	if _unlocked_souls.is_empty():
		_unlocked_souls = ["fire"]
		_total_discovered = 1
		_soul_data["fire"]["unlocked"] = true


## Reset codex
func reset_codex() -> void:
	_unlocked_souls = ["fire"]
	_total_discovered = 1
	for element in _soul_data.keys():
		_soul_data[element]["unlocked"] = (element == "fire")
	_save_codex()
	codex_updated.emit()
	GameLog.info("SoulCodexSystem: Codex reset", "Codex")
