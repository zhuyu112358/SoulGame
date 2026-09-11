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

	# Apply game-level UI styles
	_setup_ui_styles()

	GameLog.info("TutorialMenu: Opened (game-level UI)", "UI")


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


## Create a level card (game-level UI: difficulty color border + hover effect)
func _create_level_card(level_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 96)

	# Difficulty-colored border style
	var difficulty_colors = {
		0: Color(0.3, 0.7, 0.4, 0.8),  # Basic - green
		1: Color(0.3, 0.5, 0.9, 0.8),  # Intermediate - blue
		2: Color(0.8, 0.5, 0.2, 0.8),  # Advanced - orange
		3: Color(0.8, 0.3, 0.3, 0.8)   # Expert - red
	}
	var level_type = level_data.get("type", 0)
	var diff_color = difficulty_colors.get(level_type, Color(0.5, 0.5, 0.5, 0.8))

	var card_style = StyleBoxFlat.new()
	if level_data.get("locked", false):
		card_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
		card_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	else:
		card_style.bg_color = Color(0.08, 0.05, 0.15, 0.92)
		card_style.border_color = diff_color
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)

	# Hover effect: scale up + brighter border
	card.mouse_entered.connect(func():
		var s = card.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_width_left = 3
			s.border_width_right = 3
			s.border_width_top = 3
			s.border_width_bottom = 3
			if not level_data.get("locked", false):
				s.border_color = diff_color.lightened(0.3)
		card.scale = Vector2(1.02, 1.02)
	)
	card.mouse_exited.connect(func():
		var s = card.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_width_left = 2
			s.border_width_right = 2
			s.border_width_top = 2
			s.border_width_bottom = 2
			if not level_data.get("locked", false):
				s.border_color = diff_color
		card.scale = Vector2(1.0, 1.0)
	)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(hbox)

	# Difficulty icon (colored square based on level type)
	var icon_container = VBoxContainer.new()
	icon_container.custom_minimum_size = Vector2(56, 0)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_container)

	var icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.color = diff_color
	icon_container.add_child(icon_rect)

	var type_names = ["基础", "进阶", "高级", "专家"]
	var type_label = Label.new()
	type_label.text = type_names[level_type] if level_type < type_names.size() else "基础"
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


## Apply game-level UI styles to panels and buttons
func _setup_ui_styles() -> void:
	# Title: large gold
	if _title_label:
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
		_title_label.add_theme_font_size_override("font_size", 28)

	# Progress label: gold
	if _progress_label:
		_progress_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
		_progress_label.add_theme_font_size_override("font_size", 16)

	# Back button: three-state style
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.08, 0.22, 0.95)
	btn_normal.border_color = Color(0.7, 0.55, 0.3, 0.8)
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.18, 0.12, 0.3, 0.98)
	btn_hover.border_color = Color(0.95, 0.78, 0.45, 1.0)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.08, 0.05, 0.15, 1.0)
	btn_pressed.border_color = Color(0.6, 0.48, 0.25, 0.9)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6

	_back_button.add_theme_stylebox_override("normal", btn_normal)
	_back_button.add_theme_stylebox_override("hover", btn_hover)
	_back_button.add_theme_stylebox_override("pressed", btn_pressed)
	_back_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))

	GameLog.info("TutorialMenu: Game-level UI styles applied", "UI")


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
