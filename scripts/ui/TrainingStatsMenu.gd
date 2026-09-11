extends Control
## TrainingStatsMenu - Training battle statistics display UI
## Follows GDD v2.0 Chapter 11: Battle Modes
## M2.11 Battle Modes - Training Statistics UI
##
## Displays overall stats, per-difficulty stats, rank, and battle history.

## TrainingBattleSystem preload
const TrainingBattleSystem = preload("res://scripts/game/TrainingBattleSystem.gd")

## UI node references
@onready var _rank_label: Label = $MarginContainer/VBox/RankSection/RankLabel
@onready var _rank_desc_label: Label = $MarginContainer/VBox/RankSection/RankDescLabel
@onready var _overall_grid: GridContainer = $MarginContainer/VBox/OverallSection/OverallGrid
@onready var _difficulty_grid: GridContainer = $MarginContainer/VBox/DifficultySection/DifficultyGrid
@onready var _history_container: VBoxContainer = $MarginContainer/VBox/HistorySection/HistoryScroll/HistoryContainer
@onready var _back_button: Button = $MarginContainer/VBox/BackButton
@onready var _reset_button: Button = $MarginContainer/VBox/ButtonRow/ResetButton

## Training system instance
var _training_system: TrainingBattleSystem = null


func _ready() -> void:
	# Initialize training system
	_training_system = TrainingBattleSystem.new()
	_training_system.load_stats()
	add_child(_training_system)

	# Build UI
	_build_rank_section()
	_build_overall_stats()
	_build_difficulty_stats()
	_build_history()

	# Connect signals
	_back_button.pressed.connect(_on_back_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)

	# Setup button hover effects
	_setup_button_hover(_back_button)
	_setup_button_hover(_reset_button)

	# Wrap content in PanelContainer with 9-slice style
	var margin = get_node_or_null("MarginContainer")
	var vbox = get_node_or_null("MarginContainer/VBox")
	if margin and vbox:
		var panel = PanelContainer.new()
		panel.name = "MainPanel"
		var panel_style_path = "res://assets/ui/ui_character_select_panel_style.tres"
		if ResourceLoader.exists(panel_style_path):
			var panel_style = load(panel_style_path)
			if panel_style:
				panel.add_theme_stylebox_override("panel", panel_style)
		else:
			var fallback_style = StyleBoxFlat.new()
			fallback_style.bg_color = Color(0.08, 0.05, 0.15, 0.9)
			fallback_style.border_color = Color(0.83, 0.66, 0.36)
			fallback_style.border_width_left = 3
			fallback_style.border_width_right = 3
			fallback_style.border_width_top = 3
			fallback_style.border_width_bottom = 3
			fallback_style.corner_radius_top_left = 10
			fallback_style.corner_radius_top_right = 10
			fallback_style.corner_radius_bottom_left = 10
			fallback_style.corner_radius_bottom_right = 10
			panel.add_theme_stylebox_override("panel", fallback_style)
		margin.remove_child(vbox)
		panel.add_child(vbox)
		margin.add_child(panel)

	# Apply game-level UI styles
	_setup_ui_styles()

	GameLog.info("TrainingStatsMenu: Opened (game-level UI)", "UI")


## Build rank section
func _build_rank_section() -> void:
	var rank = _training_system.get_rank()
	_rank_label.text = "段位: " + rank["name"]
	_rank_label.add_theme_color_override("font_color", rank["color"])
	_rank_desc_label.text = "胜率: %.1f%% · 场次: %d" % [rank["win_rate"], rank["battles"]]


## Build overall statistics
func _build_overall_stats() -> void:
	var stats = _training_system.get_overall_stats()

	# Clear existing
	for child in _overall_grid.get_children():
		child.queue_free()

	# Add stat items
	var items = [
		["总场次", str(stats["total_battles"])],
		["胜利", str(stats["total_wins"])],
		["失败", str(stats["total_losses"])],
		["胜率", "%.1f%%" % stats["win_rate"]],
		["当前连胜", str(stats["current_streak"])],
		["最高连胜", str(stats["best_streak"])],
		["总战斗时间", _format_time(stats["total_battle_time"])],
		["平均时长", _format_time(stats["avg_battle_time"])]
	]

	for item_data in items:
		var label = item_data[0]
		var value = item_data[1]
		var item = _create_stat_item(label, value)
		_overall_grid.add_child(item)


## Build per-difficulty statistics
func _build_difficulty_stats() -> void:
	var diff_stats = _training_system.get_difficulty_stats()
	var difficulty_names = {"easy": "简单", "normal": "普通", "hard": "困难", "nightmare": "噩梦"}

	# Clear existing
	for child in _difficulty_grid.get_children():
		child.queue_free()

	# Header
	var header_name = Label.new()
	header_name.text = "难度"
	header_name.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35))
	_difficulty_grid.add_child(header_name)

	var header_battles = Label.new()
	header_battles.text = "场次"
	header_battles.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35))
	_difficulty_grid.add_child(header_battles)

	var header_wins = Label.new()
	header_wins.text = "胜利"
	header_wins.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35))
	_difficulty_grid.add_child(header_wins)

	var header_winrate = Label.new()
	header_winrate.text = "胜率"
	header_winrate.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35))
	_difficulty_grid.add_child(header_winrate)

	# Difficulty rows
	for diff in ["easy", "normal", "hard", "nightmare"]:
		var data = diff_stats.get(diff, {"battles": 0, "wins": 0, "losses": 0})
		var win_rate = 0.0
		if data["battles"] > 0:
			win_rate = float(data["wins"]) / float(data["battles"]) * 100.0

		var name_label = Label.new()
		name_label.text = difficulty_names.get(diff, diff)
		_difficulty_grid.add_child(name_label)

		var battles_label = Label.new()
		battles_label.text = str(data["battles"])
		_difficulty_grid.add_child(battles_label)

		var wins_label = Label.new()
		wins_label.text = str(data["wins"])
		_difficulty_grid.add_child(wins_label)

		var winrate_label = Label.new()
		winrate_label.text = "%.1f%%" % win_rate
		if win_rate >= 60:
			winrate_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		elif win_rate >= 40:
			winrate_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		else:
			winrate_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		_difficulty_grid.add_child(winrate_label)


## Build battle history
func _build_history() -> void:
	var history = _training_system.get_battle_history(10)

	# Clear existing
	for child in _history_container.get_children():
		child.queue_free()

	if history.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无战斗记录"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_history_container.add_child(empty_label)
		return

	for entry in history:
		var item = _create_history_item(entry)
		_history_container.add_child(item)


## Create a stat item (label + value + optional progress bar)
func _create_stat_item(label_text: String, value_text: String, progress: float = -1.0) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(140, 0)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	vbox.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	vbox.add_child(value)

	# Add progress bar if progress is provided (0-100)
	if progress >= 0.0:
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = 100.0
		bar.value = progress
		bar.show_percentage = false
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.1, 0.08, 0.15, 0.8)
		bar_style.corner_radius_top_left = 3
		bar_style.corner_radius_top_right = 3
		bar_style.corner_radius_bottom_left = 3
		bar_style.corner_radius_bottom_right = 3
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.83, 0.66, 0.36, 0.9)
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_left = 3
		fill_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", bar_style)
		bar.add_theme_stylebox_override("fill", fill_style)
		vbox.add_child(bar)

	return vbox


## Create a history item (card style with result color border)
func _create_history_item(entry: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	hbox.custom_minimum_size = Vector2(0, 36)

	# Card background panel
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 36)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style = StyleBoxFlat.new()
	if entry.get("won", false):
		card_style.bg_color = Color(0.06, 0.1, 0.08, 0.85)
		card_style.border_color = Color(0.3, 0.7, 0.4, 0.5)
	else:
		card_style.bg_color = Color(0.1, 0.06, 0.06, 0.85)
		card_style.border_color = Color(0.7, 0.35, 0.35, 0.5)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", card_style)

	# Result
	var result_label = Label.new()
	result_label.text = "胜利" if entry.get("won", false) else "失败"
	result_label.custom_minimum_size = Vector2(50, 0)
	if entry.get("won", false):
		result_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		result_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	hbox.add_child(result_label)

	# Difficulty
	var diff_names = {"easy": "简单", "normal": "普通", "hard": "困难", "nightmare": "噩梦"}
	var diff_label = Label.new()
	diff_label.text = diff_names.get(entry.get("difficulty", "normal"), "普通")
	diff_label.custom_minimum_size = Vector2(50, 0)
	diff_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(diff_label)

	# Elements
	var elem_label = Label.new()
	elem_label.text = "%s vs %s" % [entry.get("player_element", "?"), entry.get("ai_element", "?")]
	elem_label.custom_minimum_size = Vector2(100, 0)
	elem_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(elem_label)

	# Time
	var time_label = Label.new()
	time_label.text = _format_time(entry.get("battle_time", 0.0))
	time_label.custom_minimum_size = Vector2(70, 0)
	time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(time_label)

	# Date
	var date_label = Label.new()
	date_label.text = entry.get("timestamp", "")
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	hbox.add_child(date_label)

	card.add_child(hbox)
	return card


## Format time (seconds to MM:SS)
func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]


## Apply game-level UI styles to panels and buttons
func _setup_ui_styles() -> void:
	# Main panel: dark purple + gold border
	var main_panel = get_node_or_null("MarginContainer/MainPanel")
	if main_panel and main_panel is PanelContainer:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.92)
		panel_style.border_color = Color(0.83, 0.66, 0.36, 0.7)
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 12
		panel_style.corner_radius_top_right = 12
		panel_style.corner_radius_bottom_left = 12
		panel_style.corner_radius_bottom_right = 12
		main_panel.add_theme_stylebox_override("panel", panel_style)

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

	if _reset_button:
		_reset_button.add_theme_stylebox_override("normal", btn_normal)
		_reset_button.add_theme_stylebox_override("hover", btn_hover)
		_reset_button.add_theme_stylebox_override("pressed", btn_pressed)
		_reset_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))

	# Rank label: larger gold
	if _rank_label:
		_rank_label.add_theme_font_size_override("font_size", 28)

	GameLog.info("TrainingStatsMenu: Game-level UI styles applied", "UI")


## Back to main menu
func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Reset statistics
func _on_reset_pressed() -> void:
	_training_system.reset_stats()
	# Rebuild UI
	_build_rank_section()
	_build_overall_stats()
	_build_difficulty_stats()
	_build_history()
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")


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
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.25, 1.1, 0.75), 0.15)
	tween.tween_property(p_button, "scale", Vector2(1.05, 1.05), 0.15)


## Button exit visual reset
func _on_button_exit(p_button: Button) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	tween.tween_property(p_button, "scale", Vector2(1.0, 1.0), 0.2)
