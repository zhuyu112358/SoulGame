extends Control
## SoulSelect - Soul selection scene controller
##
## Displays available souls for the player to choose before entering battle.
## Shows soul cards with name, element, level, and stat preview.

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _soul_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SoulList
@onready var _back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var _selected_info: Label = $MarginContainer/VBoxContainer/SelectedInfo

var _souls: Array = []
var _selected_index: int = -1


func _ready() -> void:
	GameLog.info("SoulSelect initialized", "SoulSelect")
	_back_button.pressed.connect(_on_back_pressed)
	_setup_button_hover(_back_button)
	_load_available_souls()
	_populate_soul_list()
	_play_select_music()


## Setup button hover effects (audio + visual)
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


## Play hover sound and visual feedback
func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	p_button.modulate = Color(1.2, 1.2, 1.0)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	p_button.modulate = Color(1.0, 1.0, 1.0)


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
	if PlatformSDK:
		var soul_list = PlatformSDK.list_souls()
		if soul_list.size() > 0:
			for soul in soul_list:
				_souls.append(soul)

	# If no souls found, create default souls for testing
	if _souls.size() == 0:
		_souls = [
			{"id": "soul_fire_01", "name": "炎灵", "element": "fire", "level": 1, "hp": 100, "attack": 15, "defense": 8},
			{"id": "soul_water_01", "name": "水灵", "element": "water", "level": 1, "hp": 120, "attack": 12, "defense": 10},
			{"id": "soul_earth_01", "name": "岩灵", "element": "earth", "level": 1, "hp": 150, "attack": 10, "defense": 15},
			{"id": "soul_wind_01", "name": "风灵", "element": "wind", "level": 1, "hp": 90, "attack": 18, "defense": 6},
		]


func _populate_soul_list() -> void:
	# Clear existing children
	for child in _soul_list.get_children():
		child.queue_free()

	# Create soul cards
	for i in range(_souls.size()):
		var soul = _souls[i]
		var card = _create_soul_card(soul, i)
		_soul_list.add_child(card)


func _create_soul_card(soul: Dictionary, index: int) -> Button:
	var card = Button.new()
	card.custom_minimum_size = Vector2(0, 70)
	card.text = ""

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(15)
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	card.add_child(hbox)

	# Element color indicator
	var element_color = _get_element_color(soul["element"])
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(10, 0)
	color_rect.color = element_color
	color_rect.set_anchors_preset(15)
	color_rect.anchor_bottom = 1.0
	hbox.add_child(color_rect)

	# Soul info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "%s  [Lv.%d]" % [soul["name"], soul["level"]]
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)

	var stats_label = Label.new()
	stats_label.text = "元素: %s  HP: %d  攻击: %d  防御: %d" % [
		soul["element"], soul["hp"], soul["attack"], soul["defense"]
	]
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	info_vbox.add_child(stats_label)

	# Connect click
	card.pressed.connect(_on_soul_selected.bind(index))
	_setup_button_hover(card)

	return card


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
	GameLog.info("Starting battle with soul: %s" % soul["name"], "SoulSelect")

	# Create player soul data in RTSArenaManager expected format
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

	# Create AI opponent soul (random element, similar level)
	var ai_elements = ["fire", "water", "earth", "wind", "light", "dark"]
	var ai_element = ai_elements[randi() % ai_elements.size()]
	var ai_soul = {
		"id": "ai_soul_01",
		"name": "敌方灵魂",
		"element": ai_element,
		"level": soul["level"],
		"hp": 100 + soul["level"] * 10,
		"attack": 12 + soul["level"] * 2,
		"defense": 8 + soul["level"],
		"is_player": false
	}

	# Store battle config in GameState for RTSArenaController
	GameState.set_value("battle", "player_soul", player_soul)
	GameState.set_value("battle", "ai_soul", ai_soul)
	GameState.set_value("battle", "map_name", "default_arena")
	GameState.set_value("battle", "selected_soul", soul)

	# Play soul excited sound when entering battle
	if AudioManager:
		AudioManager.play_sfx("soul_excited")
		AudioManager.play_sfx("ui_soul_select_confirm")

	SceneManager.change_scene("res://scenes/rts_arena.tscn")


func _on_back_pressed() -> void:
	GameLog.info("Back to main menu", "SoulSelect")
	_play_button_sound()
	SceneManager.change_scene("res://scenes/main_menu.tscn")


func _play_button_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
