extends Control
## SoulCodexUI - Soul codex (bestiary) UI interface
## Follows GDD v2.0 Chapter 13: Achievements and Meta Game
## M2.13 Achievements & Meta Game - Soul Codex UI
##
## Displays all 8 element souls with detailed information.
## Locked souls show as question marks.

## SoulCodexSystem preload
const SoulCodexSystem = preload("res://scripts/game/SoulCodexSystem.gd")

## UI node references
@onready var _progress_label: Label = $MarginContainer/VBox/Header/ProgressLabel
@onready var _progress_bar: ProgressBar = $MarginContainer/VBox/Header/ProgressBar
@onready var _soul_list: VBoxContainer = $MarginContainer/VBox/Body/SoulList/ScrollContainer/VBox
@onready var _detail_panel: Panel = $MarginContainer/VBox/Body/DetailPanel
@onready var _detail_name: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/NameLabel
@onready var _detail_rarity: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/RarityLabel
@onready var _detail_element: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/ElementLabel
@onready var _detail_personality: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/PersonalityLabel
@onready var _detail_description: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/DescriptionLabel
@onready var _detail_stats: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/StatsLabel
@onready var _detail_skills: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/SkillsLabel
@onready var _detail_lore: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/LoreLabel
@onready var _back_button: Button = $MarginContainer/VBox/Footer/BackButton

## Codex system instance
var _codex: SoulCodexSystem = null

## Selected soul element
var _selected_element: String = ""

## Soul button references
var _soul_buttons: Dictionary = {}


func _ready() -> void:
	# Initialize codex system
	_codex = SoulCodexSystem.new()
	add_child(_codex)

	# Connect signals
	_codex.codex_updated.connect(_on_codex_updated)
	_back_button.pressed.connect(_on_back_pressed)

	# Setup button hover
	_setup_button_hover(_back_button)

	# Build soul list
	_build_soul_list()
	_update_progress()

	# Auto-select first unlocked soul
	var unlocked = _codex.get_unlocked_souls()
	if not unlocked.is_empty():
		_select_soul(unlocked[0])

	GameLog.info("SoulCodexUI: Ready", "UI")


## Build soul list buttons
func _build_soul_list() -> void:
	# Clear existing
	for child in _soul_list.get_children():
		child.queue_free()
	_soul_buttons.clear()

	var souls = _codex.get_all_souls()
	for soul in souls:
		var element = soul["element"]
		var is_unlocked = soul["unlocked"]

		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if is_unlocked:
			button.text = "%s  [%s]" % [soul["name"], soul["element_name"]]
			button.add_theme_color_override("font_color", soul["color"])
		else:
			button.text = "???  [未发现]"
			button.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

		button.pressed.connect(_on_soul_selected.bind(element))
		_setup_button_hover(button)

		_soul_list.add_child(button)
		_soul_buttons[element] = button


## Select a soul
func _select_soul(p_element: String) -> void:
	_selected_element = p_element

	# Update button styles
	for element in _soul_buttons.keys():
		var button = _soul_buttons[element]
		if element == p_element:
			button.modulate = Color(1.3, 1.2, 0.8)
		else:
			button.modulate = Color(1.0, 1.0, 1.0)

	# Update detail panel
	_update_detail_panel(p_element)


## Update detail panel
func _update_detail_panel(p_element: String) -> void:
	var soul = _codex.get_soul_data(p_element)
	if soul.is_empty():
		return

	var is_unlocked = _codex.is_soul_unlocked(p_element)

	if not is_unlocked:
		_detail_name.text = "???"
		_detail_rarity.text = "稀有度: ???"
		_detail_element.text = "元素: ???"
		_detail_personality.text = "个性: ???"
		_detail_description.text = "尚未发现这个灵魂。在战斗中遇到它即可解锁图鉴。"
		_detail_stats.text = ""
		_detail_skills.text = ""
		_detail_lore.text = ""
		return

	_detail_name.text = soul["name"]
	_detail_name.add_theme_color_override("font_color", soul["color"])

	var rarity_name = _codex.get_rarity_name(soul["rarity"])
	var rarity_color = _codex.get_rarity_color(soul["rarity"])
	_detail_rarity.text = "稀有度: %s" % rarity_name
	_detail_rarity.add_theme_color_override("font_color", rarity_color)

	_detail_element.text = "元素: %s" % soul["element_name"]
	_detail_personality.text = "个性: %s" % soul["personality"]
	_detail_description.text = soul["description"]

	# Stats
	var stats = soul["base_stats"]
	_detail_stats.text = "基础属性:\n  生命: %d  攻击: %d  防御: %d\n  速度: %d  暴击: %.0f%%  暴伤: %.1fx" % [
		stats["hp"], stats["attack"], stats["defense"],
		stats["speed"], stats["crit_rate"] * 100, stats["crit_multiplier"]
	]

	# Skills
	_detail_skills.text = "技能: " + ", ".join(soul["skills"])

	# Lore
	_detail_lore.text = "背景故事:\n" + soul["lore"]


## Update progress display
func _update_progress() -> void:
	var progress = _codex.get_discovery_progress()
	_progress_label.text = "图鉴进度: %d/%d (%.0f%%)" % [
		progress["discovered"], progress["total"], progress["percentage"]
	]
	_progress_bar.value = progress["percentage"]


## Soul selected callback
func _on_soul_selected(p_element: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_select_soul(p_element)


## Codex updated callback
func _on_codex_updated() -> void:
	_build_soul_list()
	_update_progress()


## Back button pressed
func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Setup button hover effects
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


## Button hover visual feedback
func _on_button_hover(p_button: Button) -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.25, 1.1, 0.75), 0.15)


## Button exit visual reset
func _on_button_exit(p_button: Button) -> void:
	if p_button.text == _selected_element:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)
