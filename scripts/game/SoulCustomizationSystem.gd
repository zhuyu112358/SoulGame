extends Node
## SoulCustomizationSystem - 7-layer soul customization (face sculpting)
## Follows GDD v2.0 Chapter 6: Soul Character System (Customization)
## M2.6 Soul Character - 7-Layer Customization
##
## Manages soul appearance customization across 7 layers:
## body shape, eyes, mouth, hair, accessory, primary color, special effect.
## Each layer has multiple options that can be freely combined.

## 7 customization layers
enum CustomizationLayer {
	BODY,       # Layer 0: body shape
	EYES,       # Layer 1: eye style
	MOUTH,      # Layer 2: mouth style
	HAIR,       # Layer 3: hair style
	ACCESSORY,  # Layer 4: accessory
	COLOR,      # Layer 5: primary color tint
	EFFECT      # Layer 6: special visual effect
}

## Layer definitions with options
var _layers: Dictionary = {
	CustomizationLayer.BODY: {
		"name": "身体形状",
		"description": "灵魂的身体轮廓",
		"options": [
			{"id": "round", "name": "圆润", "description": "可爱的圆形身体"},
			{"id": "oval", "name": "椭圆", "description": "优雅的椭圆身体"},
			{"id": "slim", "name": "修长", "description": "纤细的修长身体"},
			{"id": "angular", "name": "棱角", "description": "有棱角的几何身体"},
			{"id": "fluffy", "name": "蓬松", "description": "蓬松的云朵状身体"}
		]
	},
	CustomizationLayer.EYES: {
		"name": "眼睛样式",
		"description": "灵魂的眼睛形状",
		"options": [
			{"id": "round", "name": "圆眼", "description": "天真的圆眼睛"},
			{"id": "almond", "name": "杏眼", "description": "温柔的杏形眼"},
			{"id": "sharp", "name": "锐眼", "description": "锐利的细长眼"},
			{"id": "closed", "name": "眯眼", "description": "笑眯眯的眼睛"},
			{"id": "star", "name": "星眼", "description": "星星形状的眼睛"}
		]
	},
	CustomizationLayer.MOUTH: {
		"name": "嘴巴样式",
		"description": "灵魂的嘴巴形状",
		"options": [
			{"id": "smile", "name": "微笑", "description": "温暖的微笑"},
			{"id": "grin", "name": "咧嘴", "description": "开心的咧嘴笑"},
			{"id": "small", "name": "小嘴", "description": "小巧的嘴巴"},
			{"id": "serious", "name": "严肃", "description": "严肃的直线嘴"},
			{"id": "open", "name": "张嘴", "description": "张开的嘴巴"}
		]
	},
	CustomizationLayer.HAIR: {
		"name": "发型",
		"description": "灵魂的发型",
		"options": [
			{"id": "none", "name": "无", "description": "没有头发"},
			{"id": "short", "name": "短发", "description": "利落的短发"},
			{"id": "long", "name": "长发", "description": "飘逸的长发"},
			{"id": "spiky", "name": "刺头", "description": "尖锐的刺头"},
			{"id": "curly", "name": "卷发", "description": "卷曲的头发"},
			{"id": "twin_tails", "name": "双马尾", "description": "可爱的双马尾"}
		]
	},
	CustomizationLayer.ACCESSORY: {
		"name": "配饰",
		"description": "灵魂的配饰",
		"options": [
			{"id": "none", "name": "无", "description": "没有配饰"},
			{"id": "crown", "name": "皇冠", "description": "金色的小皇冠"},
			{"id": "ribbon", "name": "蝴蝶结", "description": "可爱的蝴蝶结"},
			{"id": "glasses", "name": "眼镜", "description": "斯文的圆眼镜"},
			{"id": "scarf", "name": "围巾", "description": "温暖的围巾"},
			{"id": "earrings", "name": "耳环", "description": "闪亮的耳环"}
		]
	},
	CustomizationLayer.COLOR: {
		"name": "主色调",
		"description": "灵魂的主色调",
		"options": [
			{"id": "default", "name": "原色", "description": "元素原色"},
			{"id": "golden", "name": "金色", "description": "闪耀的金色"},
			{"id": "pastel", "name": "粉彩", "description": "柔和的粉彩色"},
			{"id": "dark", "name": "暗色", "description": "深邃的暗色调"},
			{"id": "rainbow", "name": "彩虹", "description": "绚丽的彩虹色"}
		]
	},
	CustomizationLayer.EFFECT: {
		"name": "特效",
		"description": "灵魂的特殊视觉效果",
		"options": [
			{"id": "none", "name": "无", "description": "没有特效"},
			{"id": "sparkle", "name": "星光", "description": "周围闪烁星光"},
			{"id": "aura", "name": "光环", "description": "身体周围发光"},
			{"id": "trail", "name": "拖尾", "description": "移动时留下光迹"},
			{"id": "particles", "name": "粒子", "description": "环绕的粒子效果"}
		]
	}
}

## Default customization
var _default_customization: Dictionary = {
	"body": "round",
	"eyes": "round",
	"mouth": "smile",
	"hair": "none",
	"accessory": "none",
	"color": "default",
	"effect": "none"
}

## Saved customizations per soul (persistent)
var _saved_customizations: Dictionary = {}

## Signals
signal customization_changed(soul_id, layer, new_option)
signal customization_saved(soul_id)
signal customization_reset(soul_id)


func _ready() -> void:
	_load_customizations()
	GameLog.info("SoulCustomizationSystem: Ready with %d layers" % _layers.size(), "Customization")


## Get layer definition
func get_layer(p_layer: int) -> Dictionary:
	if not _layers.has(p_layer):
		GameLog.warning("SoulCustomizationSystem: Unknown layer: %d" % p_layer, "Customization")
		return {}
	return _layers[p_layer].duplicate()


## Get layer name
func get_layer_name(p_layer: int) -> String:
	var layer = get_layer(p_layer)
	return layer.get("name", "未知")


## Get layer options
func get_layer_options(p_layer: int) -> Array:
	var layer = get_layer(p_layer)
	return layer.get("options", []).duplicate()


## Get option by id
func get_option(p_layer: int, p_option_id: String) -> Dictionary:
	var options = get_layer_options(p_layer)
	for option in options:
		if option["id"] == p_option_id:
			return option.duplicate()
	return {}


## Get all layers (for UI display)
func get_all_layers() -> Array:
	var result: Array = []
	for layer in _layers.keys():
		var data = get_layer(layer)
		data["layer"] = layer
		result.append(data)
	result.sort_custom(func(a, b): return a["layer"] < b["layer"])
	return result


## Get customization for soul
func get_customization(p_soul_id: String) -> Dictionary:
	if _saved_customizations.has(p_soul_id):
		return _saved_customizations[p_soul_id].duplicate()
	return _default_customization.duplicate()


## Set customization option for a layer
func set_customization(p_soul_id: String, p_layer: int, p_option_id: String) -> bool:
	var layer = get_layer(p_layer)
	if layer.is_empty():
		return false

	# Validate option exists
	var valid = false
	for option in layer.get("options", []):
		if option["id"] == p_option_id:
			valid = true
			break

	if not valid:
		GameLog.warning("SoulCustomizationSystem: Invalid option '%s' for layer %d" % [p_option_id, p_layer], "Customization")
		return false

	# Ensure soul has customization dict
	if not _saved_customizations.has(p_soul_id):
		_saved_customizations[p_soul_id] = _default_customization.duplicate()

	# Map layer enum to key
	var layer_key = _layer_to_key(p_layer)
	if layer_key == "":
		return false

	_saved_customizations[p_soul_id][layer_key] = p_option_id
	customization_changed.emit(p_soul_id, p_layer, p_option_id)
	return true


## Get current option for a layer
func get_current_option(p_soul_id: String, p_layer: int) -> Dictionary:
	var customization = get_customization(p_soul_id)
	var layer_key = _layer_to_key(p_layer)
	if layer_key == "" or not customization.has(layer_key):
		return {}
	return get_option(p_layer, customization[layer_key])


## Reset customization to default
func reset_customization(p_soul_id: String) -> void:
	_saved_customizations[p_soul_id] = _default_customization.duplicate()
	customization_reset.emit(p_soul_id)


## Randomize customization
func randomize_customization(p_soul_id: String) -> Dictionary:
	var result: Dictionary = {}
	for layer in _layers.keys():
		var options = get_layer_options(layer)
		if options.size() > 0:
			var random_option = options[randi() % options.size()]
			var layer_key = _layer_to_key(layer)
			if layer_key != "":
				result[layer_key] = random_option["id"]
				set_customization(p_soul_id, layer, random_option["id"])
	return result


## Save customizations to file
func save_customizations() -> void:
	var config = ConfigFile.new()
	for soul_id in _saved_customizations.keys():
		var customization = _saved_customizations[soul_id]
		for key in customization.keys():
			config.set_value("customization_%s" % soul_id, key, customization[key])
	var err = config.save("user://soul_customization.cfg")
	if err == OK:
		GameLog.info("SoulCustomizationSystem: Saved %d customizations" % _saved_customizations.size(), "Customization")
		customization_saved.emit("all")
	else:
		GameLog.warning("SoulCustomizationSystem: Failed to save (error %d)" % err, "Customization")


## Load customizations from file
func _load_customizations() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://soul_customization.cfg")
	if err != OK:
		GameLog.info("SoulCustomizationSystem: No saved customizations", "Customization")
		return

	var sections = config.get_sections()
	for section in sections:
		if section.begins_with("customization_"):
			var soul_id = section.substr(14)  # len("customization_") = 14
			var customization: Dictionary = {}
			for key in config.get_section_keys(section):
				customization[key] = config.get_value(section, key)
			_saved_customizations[soul_id] = customization

	GameLog.info("SoulCustomizationSystem: Loaded %d customizations" % _saved_customizations.size(), "Customization")


## Convert layer enum to dictionary key
func _layer_to_key(p_layer: int) -> String:
	match p_layer:
		CustomizationLayer.BODY: return "body"
		CustomizationLayer.EYES: return "eyes"
		CustomizationLayer.MOUTH: return "mouth"
		CustomizationLayer.HAIR: return "hair"
		CustomizationLayer.ACCESSORY: return "accessory"
		CustomizationLayer.COLOR: return "color"
		CustomizationLayer.EFFECT: return "effect"
	return ""


## Apply customization to soul unit visual
func apply_customization(p_soul_unit, p_soul_id: String) -> void:
	if p_soul_unit == null:
		return

	var customization = get_customization(p_soul_id)

	# Apply color tint
	if customization.has("color") and p_soul_unit.has_method("set_modulate"):
		var color_id = customization["color"]
		var tint = Color.WHITE
		match color_id:
			"golden": tint = Color(1.2, 1.0, 0.6)
			"pastel": tint = Color(1.1, 0.95, 1.05)
			"dark": tint = Color(0.7, 0.7, 0.8)
			"rainbow": tint = Color(1.0, 0.9, 0.95)
		if color_id != "default":
			p_soul_unit.modulate = tint

	GameLog.info("SoulCustomizationSystem: Applied customization to %s" % p_soul_id, "Customization")


## Get customization summary (for display)
func get_customization_summary(p_soul_id: String) -> String:
	var customization = get_customization(p_soul_id)
	var parts: Array = []
	for layer in _layers.keys():
		var layer_key = _layer_to_key(layer)
		if customization.has(layer_key):
			var option = get_option(layer, customization[layer_key])
			if not option.is_empty():
				parts.append("%s:%s" % [get_layer_name(layer), option["name"]])
	return ", ".join(parts)
