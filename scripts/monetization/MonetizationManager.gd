extends Node
## MonetizationManager - Payment and cosmetic system manager
##
## Manages player purchase state, inventory, and equipped cosmetics.
## M2: Mock implementation with no real payment processing.
## All items are cosmetic only - never affect gameplay stats.
##
## Key interfaces:
## - is_subscriber(): Check if player has active subscription
## - has_skin(id): Check if player owns a skin
## - get_owned_items(): List all owned items
## - equip_item(id): Equip a cosmetic item
## - get_shop_items(): List available shop items

# Preload skin class (no class_name to avoid autoload conflict)
const ISkin = preload("res://scripts/monetization/ISkin.gd")

## Whether player is a subscriber (M2: mock)
var _is_subscriber: bool = false

## Subscription tier: "none" | "basic" | "premium" | "elite"
var _subscription_tier: String = "none"

## Subscription expiration timestamp (0 = never)
var _subscription_expiry: int = 0

## Owned items (item_id -> IItem)
var _owned_items: Dictionary = {}

## Equipped items (slot -> item_id)
var _equipped_items: Dictionary = {}

## Shop inventory (item_id -> IItem)
var _shop_items: Dictionary = {}

## Season pass data (reserved)
var _season_pass: Dictionary = {
	"active": false,
	"tier": 0,
	"xp": 0,
	"rewards_claimed": []
}

## Currency balances
var _currency: Dictionary = {
	"soft": 0,      # Earned in-game
	"hard": 0,      # Purchased with real money
	"premium": 0    # Subscriber-only currency
}


func _ready() -> void:
	GameLog.info("MonetizationManager: Initialized (mock mode)", "Monetization")
	_init_mock_shop()


## Initialize mock shop items (M2)
func _init_mock_shop() -> void:
	# Create some sample skins (cosmetic only)
	var sample_skins: Array = [
		{"id": "skin_fire_default", "name": "Default Fire", "element": "fire", "tier": "base", "price": 0},
		{"id": "skin_fire_inferno", "name": "Inferno Flame", "element": "fire", "tier": "premium", "price": 500},
		{"id": "skin_water_default", "name": "Default Water", "element": "water", "tier": "base", "price": 0},
		{"id": "skin_water_tidal", "name": "Tidal Wave", "element": "water", "tier": "premium", "price": 500},
		{"id": "skin_legendary_cosmic", "name": "Cosmic Soul", "element": "", "tier": "legendary", "price": 2000}
	]

	for skin_data in sample_skins:
		var skin = ISkin.new(skin_data["id"], skin_data["name"])
		skin.skin_element = skin_data["element"]
		skin.skin_tier = skin_data["tier"]
		skin.price = skin_data["price"]
		skin.rarity = skin_data["tier"]
		_shop_items[skin_data["id"]] = skin

	GameLog.info("MonetizationManager: Mock shop initialized with %d items" % _shop_items.size(), "Monetization")


## Check if player is a subscriber
func is_subscriber() -> bool:
	if _subscription_expiry > 0:
		var now: int = Time.get_unix_time_from_system()
		return now < _subscription_expiry
	return _is_subscriber


## Get subscription tier
func get_subscription_tier() -> String:
	if not is_subscriber():
		return "none"
	return _subscription_tier


## Check if player owns a specific item/skin
func has_item(p_item_id: String) -> bool:
	return _owned_items.has(p_item_id)


## Check if player owns a specific skin (convenience)
func has_skin(p_skin_id: String) -> bool:
	return has_item(p_skin_id)


## Get all owned items
func get_owned_items() -> Array:
	var result: Array = []
	for item_id in _owned_items.keys():
		result.append(_owned_items[item_id].get_info())
	return result


## Get all shop items
func get_shop_items() -> Array:
	var result: Array = []
	for item_id in _shop_items.keys():
		result.append(_shop_items[item_id].get_info())
	return result


## Purchase an item (M2: mock, uses soft currency)
func purchase_item(p_item_id: String) -> Dictionary:
	if not _shop_items.has(p_item_id):
		return {"success": false, "error": "Item not found in shop"}

	var item = _shop_items[p_item_id]
	if has_item(p_item_id):
		return {"success": false, "error": "Item already owned"}

	if _currency["soft"] < item.price:
		return {"success": false, "error": "Insufficient currency", "required": item.price, "have": _currency["soft"]}

	# M2: mock purchase
	_currency["soft"] -= item.price
	item.owned = true
	_owned_items[p_item_id] = item

	GameLog.info("MonetizationManager: Purchased item %s for %d" % [p_item_id, item.price], "Monetization")
	return {"success": true, "item": item.get_info(), "balance": _currency["soft"]}


## Equip an item
func equip_item(p_item_id: String, p_slot: String = "skin") -> Dictionary:
	if not has_item(p_item_id):
		return {"success": false, "error": "Item not owned"}

	var item = _owned_items[p_item_id]

	# Unequip current item in slot
	if _equipped_items.has(p_slot):
		var old_item = _owned_items.get(_equipped_items[p_slot], null)
		if old_item:
			old_item.unequip()

	# Equip new item
	item.equip()
	_equipped_items[p_slot] = p_item_id

	return {"success": true, "slot": p_slot, "item": item.get_info()}


## Get equipped item for slot
func get_equipped_item(p_slot: String = "skin") -> Dictionary:
	if not _equipped_items.has(p_slot):
		return {}
	var item_id = _equipped_items[p_slot]
	if _owned_items.has(item_id):
		return _owned_items[item_id].get_info()
	return {}


## Get currency balance
func get_currency(p_type: String = "soft") -> int:
	return _currency.get(p_type, 0)


## Add currency (for testing/earning)
func add_currency(p_amount: int, p_type: String = "soft") -> void:
	_currency[p_type] = (_currency.get(p_type, 0) + p_amount)


## Get season pass info (reserved)
func get_season_pass_info() -> Dictionary:
	return _season_pass.duplicate()


## Get monetization info
func get_info() -> Dictionary:
	return {
		"subscriber": is_subscriber(),
		"subscription_tier": _subscription_tier,
		"owned_items": _owned_items.size(),
		"shop_items": _shop_items.size(),
		"equipped": _equipped_items.duplicate(),
		"currency": _currency.duplicate(),
		"season_pass_active": _season_pass["active"],
		"cosmetic_only": true,  # Critical: all items cosmetic
		"mock_mode": true        # M2: no real payments
	}
