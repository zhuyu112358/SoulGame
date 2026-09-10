extends Node
## FurnitureSystem - Manages furniture placement and customization in Soul Home
## Follows GDD v2.0 Chapter 8: Soul Home (Furniture Customization System)
## M2.8 Soul Home

## Furniture categories
const CATEGORIES := {
	"bedroom": {"name": "卧室", "icon_index": 0},
	"living": {"name": "客厅", "icon_index": 1},
	"kitchen": {"name": "厨房", "icon_index": 2},
	"study": {"name": "书房", "icon_index": 3},
	"training": {"name": "训练场", "icon_index": 4},
	"garden": {"name": "花园", "icon_index": 5},
	"bathroom": {"name": "浴室", "icon_index": 6},
	"decoration": {"name": "装饰", "icon_index": 7}
}

## Furniture definitions (30 furniture items)
const FURNITURE := {
	# Bedroom
	"bed": {"name": "灵魂之床", "category": "bedroom", "icon_index": 0, "effect": {"mood": 5, "energy": 10}, "description": "舒适的床，提升睡眠质量"},
	"nightstand": {"name": "床头柜", "category": "bedroom", "icon_index": 1, "effect": {"mood": 2}, "description": "床边的小柜子"},
	"dresser": {"name": "梳妆台", "category": "bedroom", "icon_index": 2, "effect": {"mood": 3}, "description": "整理仪容的地方"},
	"mirror": {"name": "魔法镜", "category": "bedroom", "icon_index": 3, "effect": {"mood": 4, "charm": 2}, "description": "能映照灵魂本质的镜子"},
	"desk_lamp": {"name": "柔光台灯", "category": "bedroom", "icon_index": 4, "effect": {"mood": 2, "focus": 3}, "description": "温暖的阅读灯光"},
	# Living room
	"sofa": {"name": "云朵沙发", "category": "living", "icon_index": 5, "effect": {"mood": 6, "comfort": 5}, "description": "柔软如云朵的沙发"},
	"coffee_table": {"name": "茶几", "category": "living", "icon_index": 6, "effect": {"mood": 2}, "description": "放置茶具的小桌"},
	"bookshelf": {"name": "古老书架", "category": "living", "icon_index": 7, "effect": {"knowledge": 5, "mood": 3}, "description": "装满魔法书籍的书架"},
	"rug": {"name": "符文地毯", "category": "living", "icon_index": 8, "effect": {"mood": 3, "comfort": 3}, "description": "刻有古老符文的地毯"},
	"fireplace": {"name": "永恒壁炉", "category": "living", "icon_index": 9, "effect": {"mood": 5, "warmth": 5}, "description": "永不熄灭的温暖火焰"},
	# Kitchen
	"stove": {"name": "魔法灶台", "category": "kitchen", "icon_index": 10, "effect": {"cooking": 5}, "description": "能烹饪灵魂食物的灶台"},
	"fridge": {"name": "保鲜魔柜", "category": "kitchen", "icon_index": 11, "effect": {"mood": 2}, "description": "保持食物新鲜的魔法柜"},
	"dining_table": {"name": "餐桌", "category": "kitchen", "icon_index": 12, "effect": {"mood": 3, "comfort": 2}, "description": "共享美食的地方"},
	# Study
	"desk": {"name": "学习桌", "category": "study", "icon_index": 13, "effect": {"knowledge": 5, "focus": 5}, "description": "专注学习的书桌"},
	"chair": {"name": "冥想椅", "category": "study", "icon_index": 14, "effect": {"focus": 4, "calm": 3}, "description": "帮助冥想的椅子"},
	"crystal_ball": {"name": "预言水晶球", "category": "study", "icon_index": 15, "effect": {"wisdom": 5, "mood": 3}, "description": "能预见未来的水晶球"},
	# Training
	"training_dummy": {"name": "训练假人", "category": "training", "icon_index": 16, "effect": {"attack": 3, "training": 5}, "description": "用于战斗训练的假人"},
	"weights": {"name": "重力哑铃", "category": "training", "icon_index": 17, "effect": {"strength": 4, "training": 3}, "description": "增强力量的哑铃"},
	"target": {"name": "魔法靶", "category": "training", "icon_index": 18, "effect": {"accuracy": 4, "training": 4}, "description": "练习技能的靶子"},
	# Garden
	"flower_pot": {"name": "灵花盆", "category": "garden", "icon_index": 19, "effect": {"mood": 4, "nature": 3}, "description": "培育灵魂花朵的花盆"},
	"fountain": {"name": "治愈喷泉", "category": "garden", "icon_index": 20, "effect": {"mood": 5, "healing": 4}, "description": "流淌治愈之水的喷泉"},
	"bench": {"name": "月光长椅", "category": "garden", "icon_index": 21, "effect": {"mood": 3, "calm": 4}, "description": "沐浴月光的长椅"},
	# Bathroom
	"bathtub": {"name": "星辰浴缸", "category": "bathroom", "icon_index": 22, "effect": {"mood": 5, "cleanliness": 5}, "description": "盛满星光的浴缸"},
	"towel_rack": {"name": "毛巾架", "category": "bathroom", "icon_index": 23, "effect": {"mood": 1}, "description": "柔软毛巾的架子"},
	# Decoration
	"painting": {"name": "幻境画作", "category": "decoration", "icon_index": 24, "effect": {"mood": 4, "art": 3}, "description": "会变化的魔法画作"},
	"statue": {"name": "守护雕像", "category": "decoration", "icon_index": 25, "effect": {"protection": 5, "mood": 2}, "description": "守护灵魂的雕像"},
	"plant": {"name": "生命之树", "category": "decoration", "icon_index": 26, "effect": {"mood": 4, "nature": 4}, "description": "散发生命气息的小树"},
	"lamp": {"name": "灵魂灯笼", "category": "decoration", "icon_index": 27, "effect": {"mood": 3, "warmth": 3}, "description": "温暖灵魂的灯笼"},
	"clock": {"name": "时光钟", "category": "decoration", "icon_index": 28, "effect": {"wisdom": 3, "mood": 2}, "description": "记录时光的古老钟"},
	"candle": {"name": "冥想蜡烛", "category": "decoration", "icon_index": 29, "effect": {"calm": 4, "focus": 3}, "description": "帮助冥想的蜡烛"}
}

## Placed furniture (room -> list of placed furniture)
var _placed_furniture: Dictionary = {}

## Furniture inventory (owned furniture items)
var _inventory: Array = []

## Save file path
const SAVE_PATH := "user://soul_home_furniture.save"

## Signal emitted when furniture is placed
signal furniture_placed(furniture_id, room, position)

## Signal emitted when furniture is removed
signal furniture_removed(furniture_id, room)


func _ready() -> void:
	_load_data()
	# Initialize rooms
	for room in ["main", "bedroom", "living", "kitchen", "study", "training", "garden", "bathroom"]:
		if not _placed_furniture.has(room):
			_placed_furniture[room] = []


## Get furniture definition
func get_furniture(furniture_id: String) -> Dictionary:
	return FURNITURE.get(furniture_id, {})


## Get all furniture IDs
func get_all_furniture_ids() -> Array:
	return FURNITURE.keys()


## Get furniture by category
func get_furniture_by_category(category: String) -> Array:
	var result = []
	for furniture_id in FURNITURE.keys():
		if FURNITURE[furniture_id]["category"] == category:
			result.append(furniture_id)
	return result


## Get all categories
func get_all_categories() -> Dictionary:
	return CATEGORIES.duplicate()


## Place furniture in a room
func place_furniture(furniture_id: String, room: String, position: Vector2) -> bool:
	if not FURNITURE.has(furniture_id):
		return false
	if not _placed_furniture.has(room):
		_placed_furniture[room] = []
	# Check if furniture already placed (only one of each type per room)
	for placed in _placed_furniture[room]:
		if placed["id"] == furniture_id:
			return false
	var placed_item = {
		"id": furniture_id,
		"position": position,
		"rotation": 0.0,
		"scale": 1.0
	}
	_placed_furniture[room].append(placed_item)
	furniture_placed.emit(furniture_id, room, position)
	_save_data()
	return true


## Remove furniture from a room
func remove_furniture(furniture_id: String, room: String) -> bool:
	if not _placed_furniture.has(room):
		return false
	var room_furniture = _placed_furniture[room]
	for i in range(room_furniture.size()):
		if room_furniture[i]["id"] == furniture_id:
			room_furniture.remove_at(i)
			furniture_removed.emit(furniture_id, room)
			_save_data()
			return true
	return false


## Get placed furniture in a room
func get_placed_furniture(room: String) -> Array:
	if not _placed_furniture.has(room):
		return []
	return _placed_furniture[room].duplicate()


## Move furniture to new position
func move_furniture(furniture_id: String, room: String, new_position: Vector2) -> bool:
	if not _placed_furniture.has(room):
		return false
	for placed in _placed_furniture[room]:
		if placed["id"] == furniture_id:
			placed["position"] = new_position
			_save_data()
			return true
	return false


## Get total mood bonus from all placed furniture
func get_total_mood_bonus() -> float:
	var total = 0.0
	for room in _placed_furniture.keys():
		for placed in _placed_furniture[room]:
			var furniture = FURNITURE.get(placed["id"], {})
			if furniture.has("effect") and furniture["effect"].has("mood"):
				total += furniture["effect"]["mood"]
	return total


## Get furniture effect for a specific stat
func get_stat_bonus(stat: String) -> float:
	var total = 0.0
	for room in _placed_furniture.keys():
		for placed in _placed_furniture[room]:
			var furniture = FURNITURE.get(placed["id"], {})
			if furniture.has("effect") and furniture["effect"].has(stat):
				total += furniture["effect"][stat]
	return total


## Add furniture to inventory
func add_to_inventory(furniture_id: String) -> void:
	if FURNITURE.has(furniture_id) and furniture_id not in _inventory:
		_inventory.append(furniture_id)
		_save_data()


## Get inventory
func get_inventory() -> Array:
	return _inventory.duplicate()


## Reset all furniture (for testing)
func reset_all() -> void:
	_placed_furniture = {}
	_inventory = []
	for room in ["main", "bedroom", "living", "kitchen", "study", "training", "garden", "bathroom"]:
		_placed_furniture[room] = []
	_save_data()


## Save furniture data to file
func _save_data() -> void:
	var save_data = {
		"placed_furniture": _placed_furniture,
		"inventory": _inventory
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))
		f.close()


## Load furniture data from file
func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var json_string = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(json_string)
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("placed_furniture"):
				_placed_furniture = parsed["placed_furniture"]
			if parsed.has("inventory"):
				_inventory = parsed["inventory"]
