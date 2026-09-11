extends Control
## SoulSelect - Soul selection scene controller
##
## Displays available souls for the player to choose before entering battle.
## Shows soul cards with name, element, level, and stat preview.

const FontLoader = preload("res://scripts/core/FontLoader.gd")

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _soul_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SoulList
@onready var _back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var _selected_info: Label = $MarginContainer/VBoxContainer/SelectedInfo

var _souls: Array = []
var _selected_index: int = -1

## Portrait atlas texture (8 element portraits, 2 rows x 4 cols)
var _portrait_atlas: Texture2D = null
const PORTRAIT_ATLAS_PATH := "res://assets/art/character_portrait_sheet_v1.png"
const PORTRAIT_COLS := 4
const PORTRAIT_ROWS := 2

## Individual portrait textures (UI-2 redesign: use separate portrait files)
var _portrait_textures: Dictionary = {}  # {element: Texture2D}
const PORTRAIT_PATH_TEMPLATE := "res://assets/art/characters/character_%s_soul_portrait.png"

## Element to portrait index mapping
const ELEMENT_PORTRAIT_INDEX := {
	"fire": 0,
	"water": 1,
	"earth": 2,
	"wind": 3,
	"thunder": 4,
	"ice": 5,
	"dark": 6,
	"light": 7
}

## Element name mapping for portrait files (shadow = dark)
const ELEMENT_FILE_NAMES := {
	"fire": "fire",
	"water": "water",
	"earth": "earth",
	"wind": "wind",
	"thunder": "thunder",
	"ice": "ice",
	"dark": "shadow",
	"light": "light"
}


func _ready() -> void:
	GameLog.info("SoulSelect initialized", "SoulSelect")
	_apply_ui_theme()
	FontLoader.apply_font_to_control(self)
	_back_button.pressed.connect(_on_back_pressed)
	_setup_button_hover(_back_button)
	_load_portrait_atlas()
	_load_available_souls()
	_populate_soul_list()
	_play_select_music()
	# Animate title and back button
	_animate_entrance()


## Load portrait atlas texture and individual portrait files
func _load_portrait_atlas() -> void:
	# Try atlas first (legacy)
	if ResourceLoader.exists(PORTRAIT_ATLAS_PATH):
		_portrait_atlas = load(PORTRAIT_ATLAS_PATH)
		GameLog.info("SoulSelect: Portrait atlas loaded", "SoulSelect")
	else:
		GameLog.warning("SoulSelect: Portrait atlas not found at %s" % PORTRAIT_ATLAS_PATH, "SoulSelect")

	# UI-2: Load individual portrait files (higher quality, separate per element)
	for element in ELEMENT_FILE_NAMES.keys():
		var file_name = ELEMENT_FILE_NAMES[element]
		var path = PORTRAIT_PATH_TEMPLATE % file_name
		if ResourceLoader.exists(path):
			_portrait_textures[element] = load(path)
			GameLog.info("SoulSelect: Loaded portrait for %s" % element, "SoulSelect")
		else:
			GameLog.warning("SoulSelect: Portrait not found for %s at %s" % [element, path], "SoulSelect")


## Get portrait texture for a specific element
## UI-2: Prefer individual high-quality portrait files, fall back to atlas
func _get_portrait_texture(element: String) -> Texture2D:
	# UI-2: Try individual portrait first (higher quality)
	if _portrait_textures.has(element):
		return _portrait_textures[element]

	# Fallback: atlas texture
	if _portrait_atlas == null:
		return null
	var index = ELEMENT_PORTRAIT_INDEX.get(element, -1)
	if index < 0:
		return null
	var atlas = AtlasTexture.new()
	atlas.atlas = _portrait_atlas
	var atlas_size = _portrait_atlas.get_size()
	var cell_w = atlas_size.x / PORTRAIT_COLS
	var cell_h = atlas_size.y / PORTRAIT_ROWS
	var col = index % PORTRAIT_COLS
	var row = index / PORTRAIT_COLS
	atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	return atlas


## Animate entrance (title fade in + scale, back button fade in)
func _animate_entrance() -> void:
	# Title animation
	if _title_label:
		_title_label.modulate = Color(1, 1, 1, 0)
		_title_label.scale = Vector2(0.8, 0.8)
		var title_tween = create_tween()
		title_tween.set_parallel(true)
		title_tween.tween_property(_title_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_OUT)
		title_tween.set_parallel(false)
		title_tween.tween_callback(_start_title_glow)
	# Back button animation
	if _back_button:
		_back_button.modulate = Color(1, 1, 1, 0)
		var back_tween = create_tween()
		back_tween.tween_interval(0.3)
		back_tween.tween_property(_back_button, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


## Start title breathing glow animation
func _start_title_glow() -> void:
	if _title_label == null:
		return
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(_title_label, "modulate", Color(1.25, 1.05, 0.65), 1.5).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(_title_label, "modulate", Color(1.0, 0.95, 0.8), 1.5).set_ease(Tween.EASE_IN_OUT)


## Setup button hover effects (audio + visual)
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


## Play hover sound and visual feedback (scale + gold glow)
func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	# Apply visual effect to card root, not the transparent button
	var target = p_button.get_meta("card_root", p_button) as Control
	if p_button.has_meta("hover_tween"):
		var old_tween = p_button.get_meta("hover_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(target, "scale", Vector2(1.04, 1.04), 0.15)
	tween.parallel().tween_property(target, "modulate", Color(1.2, 1.1, 0.8), 0.15)
	p_button.set_meta("hover_tween", tween)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	var target = p_button.get_meta("card_root", p_button) as Control
	if p_button.has_meta("hover_tween"):
		var old_tween = p_button.get_meta("hover_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(target, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	p_button.set_meta("hover_tween", tween)


## Play button hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_soul_select_hover")


## Play soul select background music
func _play_select_music() -> void:
	if AudioManager:
		AudioManager.play_bgm("menu")
		# Play aurora icefield environment ambience
		AudioManager.play_sfx("env_aurora_icefield")
		GameLog.info("SoulSelect: Playing menu BGM", "SoulSelect")


func _load_available_souls() -> void:
	# Load souls from PlatformSDK or create default souls
	_souls = []
	# Scene names that should never be treated as soul names (mock mode artifacts)
	var invalid_names := ["main_menu", "rts_arena", "soul_select", "home", "battle", "menu"]
	if PlatformSDK:
		var soul_list = PlatformSDK.list_souls()
		if soul_list.size() > 0:
			for soul in soul_list:
				var soul_name: String = soul.get("name", "")
				# Filter out invalid souls created by mock mode accidents
				if soul_name == "" or invalid_names.has(soul_name.to_lower()):
					GameLog.warning("SoulSelect: Skipping invalid soul '%s'" % soul_name, "SoulSelect")
					continue
				# Ensure battle stats exist (PlatformSDK summary may not include them)
				if not soul.has("hp"):
					soul["hp"] = 100 + soul.get("level", 1) * 10
				if not soul.has("attack"):
					soul["attack"] = 12 + soul.get("level", 1) * 2
				if not soul.has("defense"):
					soul["defense"] = 8 + soul.get("level", 1)
				_souls.append(soul)

	# If no valid souls found, create default souls for testing
	if _souls.size() == 0:
		_souls = [
			{"id": "soul_light_01", "name": "光灵", "element": "light", "level": 1, "hp": 110, "attack": 14, "defense": 9},
				{"id": "soul_dark_01", "name": "暗灵", "element": "dark", "level": 1, "hp": 100, "attack": 16, "defense": 8},
				{"id": "soul_fire_01", "name": "炎灵", "element": "fire", "level": 1, "hp": 100, "attack": 15, "defense": 8},
			{"id": "soul_water_01", "name": "水灵", "element": "water", "level": 1, "hp": 120, "attack": 12, "defense": 10},
			{"id": "soul_earth_01", "name": "岩灵", "element": "earth", "level": 1, "hp": 150, "attack": 10, "defense": 15},
			{"id": "soul_wind_01", "name": "风灵", "element": "wind", "level": 1, "hp": 90, "attack": 18, "defense": 6},
		]


func _populate_soul_list() -> void:
	# Clear existing children
	for child in _soul_list.get_children():
		child.queue_free()

	# Create soul cards with staggered entrance animation
	for i in range(_souls.size()):
		var soul = _souls[i]
		var card = _create_soul_card(soul, i)
		card.modulate = Color(1, 1, 1, 0)
		_soul_list.add_child(card)
		# Staggered fade in animation
		var card_tween = create_tween()
		card_tween.tween_interval(0.4 + i * 0.15)
		card_tween.tween_property(card, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


func _create_soul_card(soul: Dictionary, index: int) -> Control:
	# Root control for the card
	var card_root = Control.new()
	card_root.custom_minimum_size = Vector2(0, 120)

	# Background panel with custom style
	var bg_panel = PanelContainer.new()
	bg_panel.set_anchors_preset(15)
	bg_panel.offset_left = 0
	bg_panel.offset_top = 0
	bg_panel.offset_right = 0
	bg_panel.offset_bottom = 0
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.08, 0.22, 0.9)
	card_style.border_color = Color(0.83, 0.66, 0.36)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	bg_panel.add_theme_stylebox_override("panel", card_style)
	card_root.add_child(bg_panel)

	# Content layout inside panel
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	bg_panel.add_child(hbox)

	# Element color indicator
	var element_color = _get_element_color(soul["element"])
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(14, 0)
	color_rect.color = element_color
	color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(color_rect)

	# Soul portrait (M2.6 - character portrait display)
	var portrait_texture = _get_portrait_texture(soul["element"])
	if portrait_texture:
		var portrait_rect = TextureRect.new()
		portrait_rect.custom_minimum_size = Vector2(80, 80)
		portrait_rect.texture = portrait_texture
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Add subtle glow border around portrait
		var portrait_border = PanelContainer.new()
		portrait_border.custom_minimum_size = Vector2(84, 84)
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color(0.05, 0.03, 0.1, 0.8)
		border_style.border_color = element_color
		border_style.border_width_left = 2
		border_style.border_width_right = 2
		border_style.border_width_top = 2
		border_style.border_width_bottom = 2
		border_style.corner_radius_top_left = 6
		border_style.corner_radius_top_right = 6
		border_style.corner_radius_bottom_left = 6
		border_style.corner_radius_bottom_right = 6
		portrait_border.add_theme_stylebox_override("panel", border_style)
		portrait_border.add_child(portrait_rect)
		hbox.add_child(portrait_border)
	else:
		# Fallback: colored circle if no portrait
		var fallback_portrait = ColorRect.new()
		fallback_portrait.custom_minimum_size = Vector2(80, 80)
		fallback_portrait.color = element_color
		fallback_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(fallback_portrait)

	# Soul info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "%s  [Lv.%d]" % [soul["name"], soul["level"]]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	info_vbox.add_child(name_label)

	var stats_label = Label.new()
	stats_label.text = "元素: %s    HP: %d    攻击: %d    防御: %d" % [
		soul["element"], soul["hp"], soul["attack"], soul["defense"]
	]
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	info_vbox.add_child(stats_label)

	# Spacer to vertically center content
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(spacer)

	# Transparent button overlay for click + hover
	var click_button = Button.new()
	click_button.set_anchors_preset(15)
	click_button.offset_left = 0
	click_button.offset_top = 0
	click_button.offset_right = 0
	click_button.offset_bottom = 0
	click_button.text = ""
	# Make button transparent - only for input
	var transparent_style = StyleBoxEmpty.new()
	click_button.add_theme_stylebox_override("normal", transparent_style)
	click_button.add_theme_stylebox_override("hover", transparent_style)
	click_button.add_theme_stylebox_override("pressed", transparent_style)
	click_button.add_theme_stylebox_override("focus", transparent_style)
	click_button.modulate = Color(1, 1, 1, 0.01)
	card_root.add_child(click_button)

	# Connect click
	click_button.pressed.connect(_on_soul_selected.bind(index))
	_setup_button_hover(click_button)

	# Store reference to root for hover effects
	click_button.set_meta("card_root", card_root)

	return card_root


func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.2, 0.5, 1.0)
		"earth": return Color(0.6, 0.5, 0.3)
		"wind": return Color(0.3, 0.9, 0.5)
		"light": return Color(1.0, 0.9, 0.5)
		"dark": return Color(0.5, 0.3, 0.7)
		_: return Color(0.7, 0.7, 0.7)


func _on_soul_selected(index: int) -> void:
	_selected_index = index
	var soul = _souls[index]
	_selected_info.text = "已选择: %s - 点击下方按钮进入对战" % soul["name"]
	_play_soul_select_sound(soul["element"])

	# Click pulse feedback on the card
	var card = _soul_list.get_child(index) as Control
	if card:
		var pulse_tween = create_tween()
		pulse_tween.set_ease(Tween.EASE_OUT)
		pulse_tween.set_trans(Tween.TRANS_BACK)
		pulse_tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.1)
		pulse_tween.parallel().tween_property(card, "modulate", Color(1.3, 1.15, 0.7), 0.1)
		pulse_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15)
		pulse_tween.parallel().tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.15)

	# Store selected soul in GameState
	GameState.set_value("battle", "selected_soul", soul)

	# Start battle with selected soul
	_start_battle(soul)


## Play soul selection sound based on element type
func _play_soul_select_sound(p_element: String) -> void:
	if not AudioManager:
		return
	match p_element:
		"fire":
			AudioManager.play_sfx("soul_angry_roar")
		"water":
			AudioManager.play_sfx("soul_calm_meditation")
		"earth":
			AudioManager.play_sfx("soul_brave_courage")
		"wind":
			AudioManager.play_sfx("soul_joyful")
		"light":
			AudioManager.play_sfx("soul_confident")
		"dark":
			AudioManager.play_sfx("soul_serene")
		_:
			AudioManager.play_sfx("ui_button_click")


func _start_battle(soul: Dictionary) -> void:
	GameLog.info("Soul selected: %s, entering battle config" % soul["name"], "SoulSelect")

	# Create player soul data in battle config expected format
	var player_soul = {
		"id": soul["id"],
		"name": soul["name"],
		"element": soul["element"],
		"level": soul["level"],
		"hp": soul["hp"],
		"attack": soul["attack"],
		"defense": soul["defense"],
		"is_player": true
	}

	# Store selected soul for battle config scene
	GameState.set_value("battle", "selected_soul", soul)
	GameState.set("selected_soul", player_soul)
	# Also store as team array for M2.1 multi-soul support
	GameState.set("battle_config", {"player_souls": [player_soul]})

	# Play soul excited sound
	if AudioManager:
		AudioManager.play_sfx("soul_excited")
		AudioManager.play_sfx("ui_soul_select_confirm")

	# M2.1: Go to battle config scene instead of direct battle
	SceneManager.change_scene("res://scenes/battle_config.tscn")


func _on_back_pressed() -> void:
	GameLog.info("Back to main menu", "SoulSelect")
	_play_button_sound()
	SceneManager.change_scene("res://scenes/main_menu.tscn")


func _play_button_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")


## Apply Battleplan UI theme (gold/dark pixel-fantasy style)
func _apply_ui_theme() -> void:
	var theme_path := "res://assets/ui/battleplan_theme.tres"
	if ResourceLoader.exists(theme_path):
		var theme = load(theme_path)
		if theme:
			self.theme = theme
			GameLog.debug("SoulSelect: Applied Battleplan UI theme", "UI")
		else:
			GameLog.warning("SoulSelect: Failed to load UI theme", "UI")
	else:
		GameLog.warning("SoulSelect: UI theme not found at %s" % theme_path, "UI")
