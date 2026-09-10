extends Node
## ItemSystem - Manages battle items, spawn points, and pickup logic
## Follows GDD v2.0 Chapter 7: Item & Trap System
## M2.4 Item & Trap System (Base)

## Item definitions (17 items: 6 consumables + 6 buffs + 5 special)
const ITEMS := {
	# Consumables (6)
	"health_potion": {
		"name": "生命药水",
		"description": "立即恢复30%最大生命值",
		"type": "consumable",
		"effect": "heal_percent",
		"value": 0.30,
		"icon_index": 0,
		"rarity": "common"
	},
	"energy_potion": {
		"name": "能量药水",
		"description": "立即恢复50点能量",
		"type": "consumable",
		"effect": "energy",
		"value": 50.0,
		"icon_index": 1,
		"rarity": "common"
	},
	"revive_potion": {
		"name": "复活药水",
		"description": "死亡时自动复活（50%生命）",
		"type": "consumable",
		"effect": "revive",
		"value": 0.50,
		"icon_index": 2,
		"rarity": "rare"
	},
	"cleanse_potion": {
		"name": "净化药水",
		"description": "清除所有负面状态效果",
		"type": "consumable",
		"effect": "cleanse",
		"value": 0.0,
		"icon_index": 3,
		"rarity": "uncommon"
	},
	"rage_potion": {
		"name": "狂暴药水",
		"description": "攻击力+50%，持续10秒",
		"type": "consumable",
		"effect": "attack_buff",
		"value": 0.50,
		"duration": 10.0,
		"icon_index": 4,
		"rarity": "uncommon"
	},
	"shield_potion": {
		"name": "护盾药水",
		"description": "获得吸收30%最大生命值的护盾，持续15秒",
		"type": "consumable",
		"effect": "shield",
		"value": 0.30,
		"duration": 15.0,
		"icon_index": 5,
		"rarity": "uncommon"
	},
	# Buff items (6)
	"attack_boost": {
		"name": "攻击符文",
		"description": "攻击力+20%，持续20秒",
		"type": "buff",
		"effect": "attack_buff",
		"value": 0.20,
		"duration": 20.0,
		"icon_index": 6,
		"rarity": "common"
	},
	"defense_boost": {
		"name": "防御符文",
		"description": "受到伤害-20%，持续20秒",
		"type": "buff",
		"effect": "defense_buff",
		"value": 0.20,
		"duration": 20.0,
		"icon_index": 7,
		"rarity": "common"
	},
	"speed_boost": {
		"name": "疾风符文",
		"description": "移动速度+30%，持续15秒",
		"type": "buff",
		"effect": "speed_buff",
		"value": 0.30,
		"duration": 15.0,
		"icon_index": 8,
		"rarity": "common"
	},
	"crit_boost": {
		"name": "暴击符文",
		"description": "暴击率+25%，持续20秒",
		"type": "buff",
		"effect": "crit_buff",
		"value": 0.25,
		"duration": 20.0,
		"icon_index": 9,
		"rarity": "uncommon"
	},
	"regen_boost": {
		"name": "再生符文",
		"description": "每秒恢复2%生命，持续20秒",
		"type": "buff",
		"effect": "regen_buff",
		"value": 0.02,
		"duration": 20.0,
		"icon_index": 10,
		"rarity": "uncommon"
	},
	"invisibility": {
		"name": "隐身药水",
		"description": "隐身8秒，AI无法锁定目标",
		"type": "buff",
		"effect": "invisible",
		"value": 0.0,
		"duration": 8.0,
		"icon_index": 11,
		"rarity": "rare"
	},
	# Special items (5)
	"teleport_scroll": {
		"name": "传送卷轴",
		"description": "传送到随机安全位置",
		"type": "special",
		"effect": "teleport",
		"value": 0.0,
		"icon_index": 12,
		"rarity": "rare"
	},
	"vision_potion": {
		"name": "视野药水",
		"description": "战争迷雾全图可见，持续30秒",
		"type": "special",
		"effect": "vision",
		"value": 0.0,
		"duration": 30.0,
		"icon_index": 13,
		"rarity": "uncommon"
	},
	"exp_potion": {
		"name": "经验药水",
		"description": "本局经验获取x2，持续60秒",
		"type": "special",
		"effect": "exp_boost",
		"value": 2.0,
		"duration": 60.0,
		"icon_index": 14,
		"rarity": "uncommon"
	},
	"gold_bag": {
		"name": "金币袋",
		"description": "获得100金币（局外货币）",
		"type": "special",
		"effect": "gold",
		"value": 100.0,
		"icon_index": 15,
		"rarity": "common"
	},
	"soul_shard": {
		"name": "灵魂碎片",
		"description": "灵魂升级经验+50（跨局永久）",
		"type": "special",
		"effect": "soul_exp",
		"value": 50.0,
		"icon_index": 16,
		"rarity": "rare"
	}
}

## Active items on battlefield (id -> {item_id, position, sprite})
var _active_items: Dictionary = {}

## Item spawn timer
var _spawn_timer: float = 0.0
var _spawn_interval: float = 15.0  # Spawn item every 15 seconds
var _max_active_items: int = 4  # Max 4 items on battlefield

## Battlefield bounds for item spawning
var _battlefield_min: Vector2 = Vector2(150, 150)
var _battlefield_max: Vector2 = Vector2(1130, 500)

## Parent node for item sprites (set by arena controller)
var _item_parent: Node = null

## Item icon sheet (3 rows x 6 cols, 1024x1024, 18 icons)
var _item_icon_sheet: Texture2D = null

## Signal emitted when item is picked up
signal item_picked_up(item_id, unit)

## Signal emitted when item spawns
signal item_spawned(item_id, position)


func _ready() -> void:
	# Load item icon sheet
	var sheet_path := "res://assets/art/item_icon_sheet_v1.png"
	if ResourceLoader.exists(sheet_path):
		_item_icon_sheet = load(sheet_path)
	else:
		push_warning("ItemSystem: item_icon_sheet_v1.png not found, items will have no icons")


## Start item spawning system
func start_item_system() -> void:
	_spawn_timer = 0.0
	_active_items.clear()


## Stop item spawning system and clear all items
func stop_item_system() -> void:
	for item_id in _active_items.keys():
		var item_data = _active_items[item_id]
		if item_data.has("sprite") and item_data["sprite"] != null:
			item_data["sprite"].queue_free()
	_active_items.clear()


## Update item system (called every frame)
func update(delta: float, player_unit, ai_unit) -> void:
	# Spawn items
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval and _active_items.size() < _max_active_items:
		_spawn_timer = 0.0
		_spawn_random_item()

	# Check pickups
	_check_pickups(player_unit, ai_unit)


## Spawn a random item at random position
func _spawn_random_item() -> void:
	# Weighted random item selection (common > uncommon > rare)
	var item_ids = ITEMS.keys()
	var weighted_items: Array = []
	for item_id in item_ids:
		var item = ITEMS[item_id]
		var weight = 3  # common
		if item["rarity"] == "uncommon":
			weight = 2
		elif item["rarity"] == "rare":
			weight = 1
		for i in range(weight):
			weighted_items.append(item_id)

	if weighted_items.is_empty():
		return

	var item_id = weighted_items[randi() % weighted_items.size()]
	var position = Vector2(
		randf_range(_battlefield_min.x, _battlefield_max.x),
		randf_range(_battlefield_min.y, _battlefield_max.y)
	)

	# Create item sprite
	var item_sprite = _create_item_sprite(item_id, position)
	if item_sprite == null:
		return

	var item_instance_id = "%s_%d" % [item_id, Time.get_ticks_msec()]
	_active_items[item_instance_id] = {
		"item_id": item_id,
		"position": position,
		"sprite": item_sprite
	}

	item_spawned.emit(item_id, position)


## Create item sprite with icon from sheet
func _create_item_sprite(item_id: String, position: Vector2) -> Sprite2D:
	var item = ITEMS.get(item_id, null)
	if item == null:
		return null

	var sprite = Sprite2D.new()
	sprite.name = "Item_%s" % item_id
	sprite.position = position
	sprite.scale = Vector2(0.12, 0.12)
	sprite.z_index = 5

	# Set icon from sheet using AtlasTexture
	if _item_icon_sheet != null:
		var icon_idx = item.get("icon_index", 0)
		var row: int = icon_idx / 6
		var col: int = icon_idx % 6
		var cell_w: int = 170  # 1024 / 6
		var cell_h: int = 341  # 1024 / 3
		var atlas = AtlasTexture.new()
		atlas.atlas = _item_icon_sheet
		atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		sprite.texture = atlas
	else:
		# Fallback: colored circle
		var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for x in range(32):
			for y in range(32):
				var dx = x - 16
				var dy = y - 16
				if sqrt(dx * dx + dy * dy) < 14:
					image.set_pixel(x, y, Color(1.0, 0.85, 0.3, 0.9))
		sprite.texture = ImageTexture.create_from_image(image)

	# Add to scene tree (parent should be set by caller)
	if _item_parent != null:
		_item_parent.add_child(sprite)
	return sprite


## Check if units pick up items
func _check_pickups(player_unit, ai_unit) -> void:
	var items_to_remove: Array = []

	for item_instance_id in _active_items.keys():
		var item_data = _active_items[item_instance_id]
		var item_pos = item_data["position"]
		var pickup_range = 50.0

		# Check player pickup
		if player_unit != null and is_instance_valid(player_unit):
			var player_pos = player_unit.global_position
			if player_pos.distance_to(item_pos) < pickup_range:
				_apply_item_effect(item_data["item_id"], player_unit)
				items_to_remove.append(item_instance_id)
				item_picked_up.emit(item_data["item_id"], player_unit)
				continue

		# Check AI pickup
		if ai_unit != null and is_instance_valid(ai_unit):
			var ai_pos = ai_unit.global_position
			if ai_pos.distance_to(item_pos) < pickup_range:
				_apply_item_effect(item_data["item_id"], ai_unit)
				items_to_remove.append(item_instance_id)
				item_picked_up.emit(item_data["item_id"], ai_unit)

	# Remove picked up items
	for item_instance_id in items_to_remove:
		if _active_items.has(item_instance_id):
			var item_data = _active_items[item_instance_id]
			if item_data.has("sprite") and item_data["sprite"] != null:
				item_data["sprite"].queue_free()
			_active_items.erase(item_instance_id)


## Apply item effect to unit
func _apply_item_effect(item_id: String, unit) -> void:
	var item = ITEMS.get(item_id, null)
	if item == null or unit == null:
		return

	var effect = item["effect"]
	var value = item["value"]

	match effect:
		"heal_percent":
			var heal_amount = unit.max_hp * value
			unit.take_heal(heal_amount)
		"energy":
			unit.gain_energy(value)
		"attack_buff":
			var duration = item.get("duration", 10.0)
			unit.add_status_effect("attack_up", duration)
			unit.attack_damage_multiplier = unit.attack_damage_multiplier * (1.0 + value)
		"defense_buff":
			var duration = item.get("duration", 10.0)
			unit.add_status_effect("defense_up", duration)
		"speed_buff":
			var duration = item.get("duration", 10.0)
			unit.add_status_effect("speed_up", duration)
		"crit_buff":
			var duration = item.get("duration", 10.0)
			unit.add_status_effect("crit_up", duration)
		"regen_buff":
			var duration = item.get("duration", 10.0)
			unit.add_status_effect("regen", duration)
		"shield":
			var duration = item.get("duration", 15.0)
			unit.add_status_effect("shield", duration)
			# Set shield value to percentage of max HP (M2.14 balance)
			unit.shield_value = int(unit.max_hp * value)
			GameLog.info("ItemSystem: %s gains shield %d (%.0f%% of HP)" % [
				unit.soul_name, unit.shield_value, value * 100
			], "Item")
		"invisible":
			var duration = item.get("duration", 8.0)
			unit.add_status_effect("invisible", duration)
		"cleanse":
			unit.status_effects.clear()
		"teleport":
			# Teleport to random position
			unit.global_position = Vector2(
				randf_range(_battlefield_min.x, _battlefield_max.x),
				randf_range(_battlefield_min.y, _battlefield_max.y)
			)
		"revive":
			unit.has_revive = true
		_:
			# Unknown effect, ignore
			pass


## Get item definition
func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


## Get all item IDs
func get_all_item_ids() -> Array:
	return ITEMS.keys()


## Get active items count
func get_active_item_count() -> int:
	return _active_items.size()


## Set battlefield bounds for item spawning
func set_battlefield_bounds(min_pos: Vector2, max_pos: Vector2) -> void:
	_battlefield_min = min_pos
	_battlefield_max = max_pos


## Set item spawn interval
func set_spawn_interval(interval: float) -> void:
	_spawn_interval = interval


## Set parent node for item sprites
func set_item_parent(parent: Node) -> void:
	_item_parent = parent
