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

	# Apply game-level UI styles
	_setup_ui_styles()

	GameLog.info("MatchmakingUI: Ready (game-level UI)", "UI")


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
	var dot_count = int(elapsed) % 4
	var dots = ""
	for i in range(dot_count):
		dots += "."
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

	# Apply element color border to opponent panel
	var opponent_style = StyleBoxFlat.new()
	opponent_style.bg_color = Color(0.08, 0.05, 0.15, 0.95)
	opponent_style.border_color = element_color
	opponent_style.border_width_left = 3
	opponent_style.border_width_right = 3
	opponent_style.border_width_top = 3
	opponent_style.border_width_bottom = 3
	opponent_style.corner_radius_top_left = 8
	opponent_style.corner_radius_top_right = 8
	opponent_style.corner_radius_bottom_left = 8
	opponent_style.corner_radius_bottom_right = 8
	_opponent_panel.add_theme_stylebox_override("panel", opponent_style)

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


## Apply game-level UI styles to panels, buttons, and progress bar
func _setup_ui_styles() -> void:
	# Three-state button style
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

	for btn in [_cancel_button, _start_button]:
		if btn:
			btn.add_theme_stylebox_override("normal", btn_normal)
			btn.add_theme_stylebox_override("hover", btn_hover)
			btn.add_theme_stylebox_override("pressed", btn_pressed)
			btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
			btn.add_theme_font_size_override("font_size", 16)

	# Progress bar style: gold fill with dark bg
	if _progress_bar:
		var bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.1, 0.07, 0.18, 0.9)
		bar_bg.border_color = Color(0.6, 0.5, 0.3, 0.7)
		bar_bg.border_width_left = 1
		bar_bg.border_width_right = 1
		bar_bg.border_width_top = 1
		bar_bg.border_width_bottom = 1
		bar_bg.corner_radius_top_left = 4
		bar_bg.corner_radius_top_right = 4
		bar_bg.corner_radius_bottom_left = 4
		bar_bg.corner_radius_bottom_right = 4
		_progress_bar.add_theme_stylebox_override("background", bar_bg)

		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.9, 0.7, 0.35, 0.9)
		bar_fill.corner_radius_top_left = 3
		bar_fill.corner_radius_top_right = 3
		bar_fill.corner_radius_bottom_left = 3
		bar_fill.corner_radius_bottom_right = 3
		_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	# Status label: larger gold
	if _status_label:
		_status_label.add_theme_font_size_override("font_size", 24)

	# Timer label: gold
	if _timer_label:
		_timer_label.add_theme_font_size_override("font_size", 18)
		_timer_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))

	GameLog.info("MatchmakingUI: Game-level UI styles applied", "UI")


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
