extends RefCounted
## IItem - Item interface for monetization system (base class reference)
##
## All purchasable items implement this interface.
## Items are purely cosmetic - they never affect gameplay stats.
## This enforces "外观与数值完全分离" (cosmetics and stats fully separated).
##
## M2: Mock implementation, real purchase flow added later.

## Item ID (unique identifier)
var item_id: String = ""

## Item display name
var item_name: String = ""

## Item description
var description: String = ""

## Item type: "skin" | "emote" | "trail" | "frame" | "bundle"
var item_type: String = ""

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

## Season pass exclusive (null = not season pass)
var season_pass_id: String = ""

## Release timestamp
var release_time: int = 0

## Expiration timestamp (0 = never expires)
var expiration_time: int = 0


## Initialize item
func _init(p_item_id: String = "", p_item_name: String = "") -> void:
	item_id = p_item_id
	item_name = p_item_name


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
		"cosmetic_only": true  # Critical: all items are cosmetic only
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


## Serialize to dictionary
func to_dict() -> Dictionary:
	return get_info()


## Deserialize from dictionary
func from_dict(p_data: Dictionary) -> void:
	item_id = p_data.get("id", "")
	item_name = p_data.get("name", "")
	description = p_data.get("description", "")
	item_type = p_data.get("type", "")
	rarity = p_data.get("rarity", "common")
	price = p_data.get("price", 0)
	real_price = p_data.get("real_price", "")
	resource_path = p_data.get("resource_path", "")
	owned = p_data.get("owned", false)
	equipped = p_data.get("equipped", false)
	season_pass_id = p_data.get("season_pass_id", "")
	release_time = p_data.get("release_time", 0)
	expiration_time = p_data.get("expiration_time", 0)
