extends Control
## MatchmakingUI - Random battle matchmaking UI
## Follows GDD v2.0 Chapter 11: Battle Modes
## M2.11 Battle Modes - Matchmaking UI
##
## Displays matchmaking status, opponent info, and battle start.

## MatchmakingSystem preload
const MatchmakingSystem = preload("res://scripts/game/MatchmakingSystem.gd")

## UI node references
@onready var _status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var _timer_label: Label = $MarginContainer/VBox/TimerLabel
@onready var _progress_bar: ProgressBar = $MarginContainer/VBox/ProgressBar
@onready var _opponent_panel: Panel = $MarginContainer/VBox/OpponentPanel
@onready var _opponent_name: Label = $MarginContainer/VBox/OpponentPanel/VBox/OpponentName
@onready var _opponent_info: Label = $MarginContainer/VBox/OpponentPanel/VBox/OpponentInfo
@onready var _cancel_button: Button = $MarginContainer/VBox/ButtonRow/CancelButton
@onready var _start_button: Button = $MarginContainer/VBox/ButtonRow/StartButton

## Matchmaking system instance
var _matchmaking: MatchmakingSystem = null

## Element colors
var _element_colors: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.2, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.9, 0.6),
	"thunder": Color(0.8, 0.6, 1.0),
	"ice": Color(0.5, 0.9, 1.0),
	"dark": Color(0.5, 0.3, 0.7),
	"light": Color(1.0, 0.9, 0.4)
}

## Difficulty names
var _difficulty_names: Dictionary = {
	"easy": "简单",
	"normal": "普通",
	"hard": "困难",
	"nightmare": "噩梦"
}


func _ready() -> void:
	# Initialize matchmaking system
	_matchmaking = MatchmakingSystem.new()
	add_child(_matchmaking)

	# Connect signals
	_matchmaking.matchmaking_started.connect(_on_matchmaking_started)
	_matchmaking.matchmaking_progress.connect(_on_matchmaking_progress)
	_matchmaking.opponent_found.connect(_on_opponent_found)
	_matchmaking.matchmaking_cancelled.connect(_on_matchmaking_cancelled)
	# Apply 9-slice panel style to all Panel nodes
	var panel_style_path = "res://assets/ui/ui_character_select_panel_style.tres"
	var panel_style_to_apply = null
	if ResourceLoader.exists(panel_style_path):
		panel_style_to_apply = load(panel_style_path)
	else:
		panel_style_to_apply = StyleBoxFlat.new()
		panel_style_to_apply.bg_color = Color(0.08, 0.05, 0.15, 0.9)
		panel_style_to_apply.border_color = Color(0.83, 0.66, 0.36)
		panel_style_to_apply.border_width_left = 2
		panel_style_to_apply.border_width_right = 2
		panel_style_to_apply.border_width_top = 2
		panel_style_to_apply.border_width_bottom = 2
		panel_style_to_apply.corner_radius_top_left = 8
		panel_style_to_apply.corner_radius_top_right = 8
		panel_style_to_apply.corner_radius_bottom_left = 8
		panel_style_to_apply.corner_radius_bottom_right = 8
	if panel_style_to_apply:
		for child in get_children():
			if child is Panel or child is PanelContainer:
				child.add_theme_stylebox_override("panel", panel_style_to_apply)
			for grandchild in child.get_children():
				if grandchild is Panel or grandchild is PanelContainer:
					grandchild.add_theme_stylebox_override("panel", panel_style_to_apply)


	_cancel_button.pressed.connect(_on_cancel_pressed)
	_start_button.pressed.connect(_on_start_pressed)

	# Setup button hover
	_setup_button_hover(_cancel_button)
	_setup_button_hover(_start_button)

	# Start matchmaking automatically
	_matchmaking.start_matchmaking()

	GameLog.info("MatchmakingUI: Ready", "UI")


## Matchmaking started
func _on_matchmaking_started() -> void:
	_status_label.text = "正在寻找对手..."
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35))
	_timer_label.text = "0.0秒"
	_progress_bar.value = 0
	_opponent_panel.visible = false
	_start_button.visible = false
	_cancel_button.visible = true


## Matchmaking progress update
func _on_matchmaking_progress(progress: float, elapsed: float) -> void:
	_progress_bar.value = progress * 100.0
	_timer_label.text = "%.1f秒" % elapsed

	# Update status text with searching animation
	var dots = "." * (int(elapsed) % 4)
	_status_label.text = "正在寻找对手%s" % dots


## Opponent found
func _on_opponent_found(opponent_data: Dictionary) -> void:
	_status_label.text = "对手已找到！"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

	# Show opponent info
	var element = opponent_data.get("element", "fire")
	var element_color = _element_colors.get(element, Color.WHITE)

	_opponent_name.text = opponent_data.get("name", "未知对手")
	_opponent_name.add_theme_color_override("font_color", element_color)

	var difficulty = opponent_data.get("difficulty", "normal")
	var difficulty_name = _difficulty_names.get(difficulty, "普通")

	_opponent_info.text = "元素: %s · 等级: %d · 难度: %s" % [
		element, opponent_data.get("level", 1), difficulty_name
	]

	_opponent_panel.visible = true
	_start_button.visible = true
	_cancel_button.visible = false

	if AudioManager:
		AudioManager.play_sfx("battle_ui_victory")

	GameLog.info("MatchmakingUI: Opponent found - %s" % opponent_data.get("name", ""), "UI")


## Matchmaking cancelled
func _on_matchmaking_cancelled() -> void:
	_status_label.text = "匹配已取消"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_cancel_button.visible = false
	_start_button.visible = false


## Cancel button pressed
func _on_cancel_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_matchmaking.cancel_matchmaking()
	# Return to main menu after short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Start battle button pressed
func _on_start_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_matchmaking.start_battle_with_opponent()
	# Go to soul select for battle
	get_tree().change_scene_to_file("res://scenes/soul_select.tscn")


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
