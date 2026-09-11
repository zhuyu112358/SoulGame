extends Control
## TutorialMenu - Tutorial level selection UI
## Follows GDD v2.0 Chapter 15: Tutorial and Story Mode
## M2.10 Tutorial & Story - Tutorial Menu UI
##
## Displays 6 tutorial levels with completion status, estimated time, and progress.

## TutorialSystem preload
const TutorialSystem = preload("res://scripts/game/TutorialSystem.gd")

## UI node references
@onready var _title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var _progress_label: Label = $MarginContainer/VBox/ProgressLabel
@onready var _level_container: VBoxContainer = $MarginContainer/VBox/LevelScroll/LevelContainer
@onready var _back_button: Button = $MarginContainer/VBox/BackButton

## Tutorial system instance
var _tutorial_system: TutorialSystem = null


func _ready() -> void:
	# Initialize tutorial system
	_tutorial_system = TutorialSystem.new()
	add_child(_tutorial_system)

	# Build level list
	_build_level_list()

	# Connect signals
	_back_button.pressed.connect(_on_back_pressed)

	# Setup button hover effects
	_setup_button_hover(_back_button)

	GameLog.info("TutorialMenu: Opened", "UI")


## Build tutorial level list
func _build_level_list() -> void:
	# Clear existing
	for child in _level_container.get_children():
		child.queue_free()

	# Get level list
	var levels = _tutorial_system.get_level_list()
	var progress = _tutorial_system.get_progress()

	# Update progress label
	_progress_label.text = "教学进度: %d/%d (%.0f%%)" % [
		_tutorial_system.get_completed_levels().size(),
		levels.size(),
		progress * 100.0
	]

	# Create level cards
	for level_data in levels:
		var card = _create_level_card(level_data)
		_level_container.add_child(card)


## Create a level card
func _create_level_card(level_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Difficulty icon (colored square based on level type)
	var icon_container = VBoxContainer.new()
	icon_container.custom_minimum_size = Vector2(56, 0)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_container)

	var icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	var difficulty_colors = {
		0: Color(0.3, 0.7, 0.4, 0.9),  # Basic - green
		1: Color(0.3, 0.5, 0.9, 0.9),  # Intermediate - blue
		2: Color(0.8, 0.5, 0.2, 0.9),  # Advanced - orange
		3: Color(0.8, 0.3, 0.3, 0.9)   # Expert - red
	}
	var level_type = level_data.get("type", 0)
	icon_rect.color = difficulty_colors.get(level_type, Color(0.5, 0.5, 0.5, 0.9))
	icon_container.add_child(icon_rect)

	var type_names = ["基础", "进阶", "高级", "专家"]
	var type_label = Label.new()
	type_label.text = type_names.get(level_type, "基础")
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_container.add_child(type_label)

	# Level number
	var number_label = Label.new()
	number_label.text = "%d." % (level_data["id"] + 1)
	number_label.add_theme_font_size_override("font_size", 22)
	number_label.custom_minimum_size = Vector2(36, 0)
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	hbox.add_child(number_label)

	# Level info (name + description)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = level_data["name"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = level_data["description"]
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_label)

	var meta_label = Label.new()
	meta_label.text = "预计%d秒 · %d步骤" % [level_data["estimated_time"], level_data["step_count"]]
	meta_label.add_theme_font_size_override("font_size", 11)
	meta_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info_vbox.add_child(meta_label)

	# Status (completed or start button)
	var status_container = VBoxContainer.new()
	status_container.custom_minimum_size = Vector2(120, 0)
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(status_container)

	if level_data["completed"]:
		var completed_label = Label.new()
		completed_label.text = "✓ 已完成"
		completed_label.add_theme_font_size_override("font_size", 14)
		completed_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		completed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_container.add_child(completed_label)

		var replay_button = Button.new()
		replay_button.text = "重新学习"
		replay_button.custom_minimum_size = Vector2(100, 32)
		replay_button.pressed.connect(_on_start_tutorial.bind(level_data["id"]))
		status_container.add_child(replay_button)
		_setup_button_hover(replay_button)
	else:
		var start_button = Button.new()
		start_button.text = "开始学习"
		start_button.custom_minimum_size = Vector2(100, 36)
		start_button.pressed.connect(_on_start_tutorial.bind(level_data["id"]))
		status_container.add_child(start_button)
		_setup_button_hover(start_button)

	return card

func _on_start_tutorial(level_id: int) -> void:
	GameLog.info("TutorialMenu: Starting tutorial %d" % level_id, "UI")
	# Store selected tutorial in GameState for battle scene
	if GameState:
		GameState.set_value("tutorial", "active_level", level_id)
		GameState.set_value("tutorial", "is_tutorial", true)
	# Start tutorial
	_tutorial_system.start_tutorial(level_id)
	# For now, go to soul select (tutorial battle will be integrated later)
	get_tree().change_scene_to_file("res://scenes/soul_select.tscn")


## Back to main menu
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
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)
