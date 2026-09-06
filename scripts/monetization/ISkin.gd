extends RefCounted
## ISkin - Soul skin interface (cosmetic only)
##
## Skins change the visual appearance of a soul but NEVER affect stats.
## This is the core monetization interface for soul cosmetics.
## All items are cosmetic only - never affect gameplay stats.

## Item ID (unique identifier)
var item_id: String = ""

## Item display name
var item_name: String = ""

## Item description
var description: String = ""

## Item type: "skin" | "emote" | "trail" | "frame" | "bundle"
var item_type: String = "skin"

## Item rarity: "common" | "rare" | "epic" | "legendary"
var rarity: String = "common"

## Price in game currency (0 = free)
var price: int = 0

## Price in real currency (empty = not for sale)
var real_price: String = ""

## Resource path for visual asset
var resource_path: String = ""

## Whether item is currently owned
var owned: bool = false

## Whether item is currently equipped
var equipped: bool = false

## Season pass exclusive (empty = not season pass)
var season_pass_id: String = ""

## Release timestamp
var release_time: int = 0

## Expiration timestamp (0 = never expires)
var expiration_time: int = 0

## Skin element type (for element-specific skins)
var skin_element: String = ""

## Sprite texture resource ID
var sprite_resource_id: String = ""

## Animation set resource ID
var animation_resource_id: String = ""

## Particle effect resource ID
var particle_resource_id: String = ""

## Color palette override (for tintable skins)
var color_palette: Dictionary = {}

## Compatible soul elements (empty = all)
var compatible_elements: Array = []

## Skin tier: "base" | "premium" | "legendary" | "mythic"
var skin_tier: String = "base"

## Preview image path
var preview_path: String = ""


## Initialize skin
func _init(p_skin_id: String = "", p_skin_name: String = "") -> void:
	item_id = p_skin_id
	item_name = p_skin_name


## Get item info dictionary
func get_info() -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"description": description,
		"type": item_type,
		"rarity": rarity,
		"price": price,
		"real_price": real_price,
		"owned": owned,
		"equipped": equipped,
		"season_pass": season_pass_id != "",
		"skin_element": skin_element,
		"skin_tier": skin_tier,
		"compatible_elements": compatible_elements,
		"cosmetic_only": true
	}


## Check if item affects stats (should always be false)
func affects_stats() -> bool:
	return false


## Equip item (returns success)
func equip() -> bool:
	if not owned:
		return false
	equipped = true
	return true


## Unequip item
func unequip() -> void:
	equipped = false


## Check if item is available (not expired, released)
func is_available() -> bool:
	var now: int = Time.get_unix_time_from_system()
	if release_time > 0 and now < release_time:
		return false
	if expiration_time > 0 and now > expiration_time:
		return false
	return true


## Get skin visual resources (all cosmetic, no stats)
func get_visual_resources() -> Dictionary:
	return {
		"sprite": sprite_resource_id,
		"animation": animation_resource_id,
		"particle": particle_resource_id,
		"color_palette": color_palette,
		"preview": preview_path
	}


## Check if skin is compatible with soul element
func is_compatible(p_element: String) -> bool:
	if compatible_elements.is_empty():
		return true
	return compatible_elements.has(p_element)


## Apply skin to a soul visual (cosmetic only)
## Returns resource paths to load, does NOT modify soul stats
func apply_to_soul(p_soul_id: String) -> Dictionary:
	if not owned:
		return {"error": "Skin not owned"}

	if skin_element != "" and not is_compatible(skin_element):
		return {"error": "Skin not compatible with soul element"}

	# Return visual resources only - never touch stats
	return {
		"status": "applied",
		"soul_id": p_soul_id,
		"skin_id": item_id,
		"visual": get_visual_resources(),
		"stats_affected": false
	}


## Serialize to dictionary
func to_dict() -> Dictionary:
	return get_info()


## Deserialize from dictionary
func from_dict(p_data: Dictionary) -> void:
	item_id = p_data.get("id", "")
	item_name = p_data.get("name", "")
	description = p_data.get("description", "")
	item_type = p_data.get("type", "skin")
	rarity = p_data.get("rarity", "common")
	price = p_data.get("price", 0)
	real_price = p_data.get("real_price", "")
	resource_path = p_data.get("resource_path", "")
	owned = p_data.get("owned", false)
	equipped = p_data.get("equipped", false)
	season_pass_id = p_data.get("season_pass_id", "")
	release_time = p_data.get("release_time", 0)
	expiration_time = p_data.get("expiration_time", 0)
	skin_element = p_data.get("skin_element", "")
	sprite_resource_id = p_data.get("sprite_resource_id", "")
	animation_resource_id = p_data.get("animation_resource_id", "")
	particle_resource_id = p_data.get("particle_resource_id", "")
	color_palette = p_data.get("color_palette", {})
	compatible_elements = p_data.get("compatible_elements", [])
	skin_tier = p_data.get("skin_tier", "base")
	preview_path = p_data.get("preview_path", "")
