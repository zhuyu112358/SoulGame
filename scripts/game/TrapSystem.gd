extends Node
## TrapSystem - Manages battlefield traps, placement, and trigger logic
## Follows GDD v2.0 Chapter 7: Item & Trap System
## M2.4 Item & Trap System (Traps)

## Trap definitions (12 traps: 8 ground + 4 air)
const TRAPS := {
	# Ground traps (8)
	"fire_trap": {
		"name": "火焰陷阱",
		"description": "触发后造成持续火焰伤害",
		"type": "ground",
		"effect": "burn",
		"damage": 15.0,
		"duration": 3.0,
		"dot_damage": 5.0,
		"icon_index": 0,
		"rarity": "common",
		"trigger_radius": 40.0
	},
	"frost_trap": {
		"name": "冰霜陷阱",
		"description": "触发后减速并造成冰霜伤害",
		"type": "ground",
		"effect": "slow",
		"damage": 10.0,
		"duration": 4.0,
		"slow_amount": 0.4,
		"icon_index": 1,
		"rarity": "common",
		"trigger_radius": 40.0
	},
	"thunder_trap": {
		"name": "雷电陷阱",
		"description": "触发后造成高额雷电伤害并眩晕",
		"type": "ground",
		"effect": "stun",
		"damage": 25.0,
		"duration": 1.5,
		"icon_index": 2,
		"rarity": "uncommon",
		"trigger_radius": 45.0
	},
	"poison_trap": {
		"name": "毒素陷阱",
		"description": "触发后造成持续毒素伤害",
		"type": "ground",
		"effect": "poison",
		"damage": 8.0,
		"duration": 5.0,
		"dot_damage": 4.0,
		"icon_index": 3,
		"rarity": "common",
		"trigger_radius": 40.0
	},
	"spike_trap": {
		"name": "地刺陷阱",
		"description": "触发后造成高额物理伤害",
		"type": "ground",
		"effect": "physical",
		"damage": 30.0,
		"duration": 0.0,
		"icon_index": 4,
		"rarity": "uncommon",
		"trigger_radius": 35.0
	},
	"slow_trap": {
		"name": "减速陷阱",
		"description": "触发后大幅减速",
		"type": "ground",
		"effect": "slow",
		"damage": 5.0,
		"duration": 5.0,
		"slow_amount": 0.6,
		"icon_index": 5,
		"rarity": "common",
		"trigger_radius": 50.0
	},
	"silence_trap": {
		"name": "沉默陷阱",
		"description": "触发后禁止使用技能",
		"type": "ground",
		"effect": "silence",
		"damage": 5.0,
		"duration": 4.0,
		"icon_index": 6,
		"rarity": "rare",
		"trigger_radius": 40.0
	},
	"explosion_trap": {
		"name": "爆炸陷阱",
		"description": "触发后造成范围爆炸伤害",
		"type": "ground",
		"effect": "explosion",
		"damage": 35.0,
		"duration": 0.0,
		"explosion_radius": 80.0,
		"icon_index": 7,
		"rarity": "rare",
		"trigger_radius": 40.0
	},
	# Air traps (4)
	"rockfall_trap": {
		"name": "落石陷阱",
		"description": "空中落石造成高额伤害",
		"type": "air",
		"effect": "physical",
		"damage": 28.0,
		"duration": 0.0,
		"icon_index": 8,
		"rarity": "uncommon",
		"trigger_radius": 45.0
	},
	"windblade_trap": {
		"name": "风刃陷阱",
		"description": "风刃切割造成持续伤害",
		"type": "air",
		"effect": "bleed",
		"damage": 12.0,
		"duration": 4.0,
		"dot_damage": 3.0,
		"icon_index": 9,
		"rarity": "common",
		"trigger_radius": 40.0
	},
	"shadow_trap": {
		"name": "暗影陷阱",
		"description": "暗影侵蚀降低攻击力",
		"type": "air",
		"effect": "weaken",
		"damage": 10.0,
		"duration": 5.0,
		"attack_reduction": 0.3,
		"icon_index": 10,
		"rarity": "uncommon",
		"trigger_radius": 40.0
	},
	"holy_trap": {
		"name": "圣光陷阱",
		"description": "圣光审判造成真实伤害",
		"type": "air",
		"effect": "true_damage",
		"damage": 20.0,
		"duration": 0.0,
		"icon_index": 11,
		"rarity": "rare",
		"trigger_radius": 45.0
	}
}

## Active traps on battlefield (id -> {trap_id, position, sprite, triggered})
var _active_traps: Dictionary = {}

## Trap spawn timer
var _spawn_timer: float = 0.0
var _spawn_interval: float = 20.0  # Spawn trap every 20 seconds
var _max_active_traps: int = 3  # Max 3 traps on battlefield

## Battlefield bounds for trap placement
var _battlefield_min: Vector2 = Vector2(250, 200)
var _battlefield_max: Vector2 = Vector2(1030, 450)

## Parent node for trap sprites
var _trap_parent: Node = null

## Trap icon sheet (3 rows x 4 cols, 1024x1024, 12 icons)
var _trap_icon_sheet: Texture2D = null

## Signal emitted when trap is triggered
signal trap_triggered(trap_id, unit, damage)

## Signal emitted when trap spawns
signal trap_spawned(trap_id, position)


func _ready() -> void:
	# Load trap icon sheet
	var sheet_path := "res://assets/art/trap_icon_sheet_v1.png"
	if ResourceLoader.exists(sheet_path):
		_trap_icon_sheet = load(sheet_path)
	else:
		push_warning("TrapSystem: trap_icon_sheet_v1.png not found, traps will have no icons")


## Start trap system
func start_trap_system() -> void:
	_spawn_timer = 0.0
	_clear_all_traps()


## Stop trap system and clear all traps
func stop_trap_system() -> void:
	_clear_all_traps()


## Clear all active traps
func _clear_all_traps() -> void:
	for trap_id in _active_traps.keys():
		var trap_data = _active_traps[trap_id]
		if trap_data.has("sprite") and trap_data["sprite"] != null:
			trap_data["sprite"].queue_free()
	_active_traps.clear()


## Update trap system (called every frame)
func update(delta: float, player_unit, ai_unit) -> void:
	# Spawn traps
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval and _active_traps.size() < _max_active_traps:
		_spawn_timer = 0.0
		_spawn_random_trap()

	# Check triggers
	_check_triggers(player_unit, ai_unit)


## Spawn a random trap at random position
func _spawn_random_trap() -> void:
	# Weighted random trap selection (common > uncommon > rare)
	var trap_ids = TRAPS.keys()
	var weighted_traps: Array = []
	for trap_id in trap_ids:
		var trap = TRAPS[trap_id]
		var weight = 3  # common
		if trap["rarity"] == "uncommon":
			weight = 2
		elif trap["rarity"] == "rare":
			weight = 1
		for i in range(weight):
			weighted_traps.append(trap_id)

	if weighted_traps.is_empty():
		return

	var trap_id = weighted_traps[randi() % weighted_traps.size()]
	var position = Vector2(
		randf_range(_battlefield_min.x, _battlefield_max.x),
		randf_range(_battlefield_min.y, _battlefield_max.y)
	)

	# Create trap sprite
	var trap_sprite = _create_trap_sprite(trap_id, position)
	if trap_sprite == null:
		return

	var trap_instance_id = "%s_%d" % [trap_id, Time.get_ticks_msec()]
	_active_traps[trap_instance_id] = {
		"trap_id": trap_id,
		"position": position,
		"sprite": trap_sprite,
		"triggered": false
	}

	trap_spawned.emit(trap_id, position)


## Create trap sprite with icon from sheet
func _create_trap_sprite(trap_id: String, position: Vector2) -> Sprite2D:
	var trap = TRAPS.get(trap_id, null)
	if trap == null:
		return null

	var sprite = Sprite2D.new()
	sprite.name = "Trap_%s" % trap_id
	sprite.position = position
	sprite.scale = Vector2(0.15, 0.15)
	sprite.z_index = 4
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)  # Semi-transparent to indicate trap

	# Set icon from sheet using AtlasTexture
	if _trap_icon_sheet != null:
		var icon_idx = trap.get("icon_index", 0)
		var row: int = icon_idx / 4
		var col: int = icon_idx % 4
		var cell_w: int = 256  # 1024 / 4
		var cell_h: int = 341  # 1024 / 3
		var atlas = AtlasTexture.new()
		atlas.atlas = _trap_icon_sheet
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
					image.set_pixel(x, y, Color(0.8, 0.2, 0.2, 0.6))
		sprite.texture = ImageTexture.create_from_image(image)

	# Add to scene tree
	if _trap_parent != null:
		_trap_parent.add_child(sprite)
	return sprite


## Check if units trigger traps
func _check_triggers(player_unit, ai_unit) -> void:
	var traps_to_remove: Array = []

	for trap_instance_id in _active_traps.keys():
		var trap_data = _active_traps[trap_instance_id]
		if trap_data["triggered"]:
			continue
		var trap_pos = trap_data["position"]
		var trap = TRAPS[trap_data["trap_id"]]
		var trigger_radius = trap.get("trigger_radius", 40.0)

		# Check player trigger
		if player_unit != null and is_instance_valid(player_unit):
			var player_pos = player_unit.global_position
			if player_pos.distance_to(trap_pos) < trigger_radius:
				_trigger_trap(trap_instance_id, player_unit)
				traps_to_remove.append(trap_instance_id)
				continue

		# Check AI trigger
		if ai_unit != null and is_instance_valid(ai_unit):
			var ai_pos = ai_unit.global_position
			if ai_pos.distance_to(trap_pos) < trigger_radius:
				_trigger_trap(trap_instance_id, ai_unit)
				traps_to_remove.append(trap_instance_id)

	# Remove triggered traps after delay
	for trap_instance_id in traps_to_remove:
		if _active_traps.has(trap_instance_id):
			var trap_data = _active_traps[trap_instance_id]
			# Fade out then remove
			if trap_data.has("sprite") and trap_data["sprite"] != null:
				var sprite = trap_data["sprite"]
				var tween = create_tween()
				tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
				tween.tween_callback(sprite.queue_free)
			_active_traps.erase(trap_instance_id)


## Trigger a trap on a unit
func _trigger_trap(trap_instance_id: String, unit) -> void:
	var trap_data = _active_traps[trap_instance_id]
	var trap = TRAPS[trap_data["trap_id"]]
	var damage = trap.get("damage", 0.0)
	var effect = trap["effect"]
	var duration = trap.get("duration", 0.0)

	# Apply immediate damage
	if damage > 0 and unit != null:
		if effect == "true_damage":
			# True damage ignores defense
			unit.current_hp -= damage
		else:
			unit.take_damage(damage)

	# Apply status effects
	match effect:
		"burn", "poison", "bleed":
			if duration > 0 and unit != null:
				unit.add_status_effect(effect, duration)
		"slow":
			if duration > 0 and unit != null:
				unit.add_status_effect("slow", duration)
		"stun":
			if duration > 0 and unit != null:
				unit.add_status_effect("stun", duration)
		"silence":
			if duration > 0 and unit != null:
				unit.add_status_effect("silence", duration)
		"weaken":
			if duration > 0 and unit != null:
				unit.add_status_effect("weaken", duration)
		"explosion":
			# Area damage handled separately
			pass

	# Mark as triggered
	trap_data["triggered"] = true

	# Emit signal
	trap_triggered.emit(trap_data["trap_id"], unit, damage)


## Get trap definition
func get_trap(trap_id: String) -> Dictionary:
	return TRAPS.get(trap_id, {})


## Get all trap IDs
func get_all_trap_ids() -> Array:
	return TRAPS.keys()


## Get active traps count
func get_active_trap_count() -> int:
	return _active_traps.size()


## Set battlefield bounds for trap placement
func set_battlefield_bounds(min_pos: Vector2, max_pos: Vector2) -> void:
	_battlefield_min = min_pos
	_battlefield_max = max_pos


## Set trap spawn interval
func set_spawn_interval(interval: float) -> void:
	_spawn_interval = interval


## Set parent node for trap sprites
func set_trap_parent(parent: Node) -> void:
	_trap_parent = parent
