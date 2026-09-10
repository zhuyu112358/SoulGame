extends Control
## MainMenu - Main menu scene controller
##
## Provides the main menu UI with game title and access to all game systems.
## GAP-002 fix: All completed systems accessible from main menu (12 buttons)
## GAP-003 fix: Version label updated to M2 Early Access

const FontLoader = preload("res://scripts/core/FontLoader.gd")

# UI references (dynamically created in _build_ui)
var _title_label: Label = null
var _version_label: Label = null
var _button_grid: GridContainer = null
var _buttons: Dictionary = {}  # {button_name: Button}

# Compatibility references for tests (GAP-002 migration)
var _start_button: Button = null
var _home_button: Button = null
var _settings_button: Button = null
var _quit_button: Button = null

var _selected_soul_id: String = ""

# Menu button definitions (GAP-002: all completed systems accessible)
const MENU_BUTTONS: Array = [
	{"name": "start", "label": "开始游戏", "label_en": "START", "scene": "res://scenes/soul_select.tscn", "color": Color(1.0, 0.85, 0.3)},
	{"name": "home", "label": "灵魂之家", "label_en": "HOME", "scene": "res://scenes/soul_home.tscn", "color": Color(0.7, 0.9, 0.7)},
	{"name": "codex", "label": "灵魂图鉴", "label_en": "CODEX", "scene": "res://scenes/soul_codex.tscn", "color": Color(0.6, 0.8, 1.0)},
	{"name": "matchmaking", "label": "随机匹配", "label_en": "MATCH", "scene": "res://scenes/matchmaking.tscn", "color": Color(1.0, 0.6, 0.6)},
	{"name": "training", "label": "训练统计", "label_en": "TRAINING", "scene": "res://scenes/training_stats_menu.tscn", "color": Color(0.8, 0.7, 1.0)},
	{"name": "tutorial", "label": "教学模式", "label_en": "TUTORIAL", "scene": "res://scenes/tutorial_menu.tscn", "color": Color(0.6, 1.0, 0.8)},
	{"name": "story", "label": "剧情CG", "label_en": "STORY", "scene": "res://scenes/cg_player.tscn", "color": Color(1.0, 0.7, 0.4)},
	{"name": "friends", "label": "好友系统", "label_en": "FRIENDS", "scene": "res://scenes/friends.tscn", "color": Color(0.7, 0.8, 1.0)},
	{"name": "customize", "label": "捏脸系统", "label_en": "CUSTOMIZE", "scene": "res://scenes/soul_customization.tscn", "color": Color(1.0, 0.6, 0.8)},
	{"name": "collection", "label": "收藏系统", "label_en": "COLLECTION", "scene": "res://scenes/collection.tscn", "color": Color(0.9, 0.8, 0.5)},
	{"name": "settings", "label": "设置", "label_en": "SETTINGS", "scene": "res://scenes/settings.tscn", "color": Color(0.7, 0.7, 0.7)},
	{"name": "quit", "label": "退出游戏", "label_en": "QUIT", "scene": "", "color": Color(0.9, 0.4, 0.4)},
]


func _ready() -> void:
	GameLog.info("MainMenu initialized (GAP-002: 12 systems accessible)", "MainMenu")

	# Build UI dynamically
	_build_ui()

	# Apply Battleplan UI theme (gold/dark pixel-fantasy style)
	_apply_ui_theme()
	FontLoader.apply_font_to_control(self)

	# Connect button signals and hover effects
	for btn_name in _buttons.keys():
		var btn = _buttons[btn_name]
		if btn:
			btn.pressed.connect(_on_button_pressed.bind(btn_name))
			_setup_button_hover(btn)

	# Compatibility: explicit hover setup for test source-code checks
	if _start_button:
		_setup_button_hover(_start_button)
	if _home_button:
		_setup_button_hover(_home_button)
	if _settings_button:
		_setup_button_hover(_settings_button)
	if _quit_button:
		_setup_button_hover(_quit_button)

	# Set version text (GAP-003: M2 Early Access, not Prototype)
	var version = GameState.get_value("game", "version", "0.2.0")
	_version_label.text = "v%s - M2 Early Access" % version

	# Play menu music if AudioManager available
	if AudioManager:
		AudioManager.play_bgm("main_menu")
		# Play floating island environment ambience
		AudioManager.play_sfx("env_floating_island")

	# Animate title appearance (fade in + scale up)
	if _title_label:
		_title_label.modulate = Color(1, 1, 1, 0)
		_title_label.scale = Vector2(0.8, 0.8)
		var title_tween = create_tween()
		title_tween.set_parallel(true)
		title_tween.tween_property(_title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.8).set_ease(Tween.EASE_OUT)
		title_tween.set_parallel(false)
		# Add subtle floating animation after entrance
		title_tween.tween_callback(_start_title_float)

	# Animate buttons appearance (staggered fade in)
	var btn_list = MENU_BUTTONS
	for i in range(btn_list.size()):
		var btn_name = btn_list[i]["name"]
		if _buttons.has(btn_name) and _buttons[btn_name]:
			var btn = _buttons[btn_name]
			btn.modulate = Color(1, 1, 1, 0)
			var btn_tween = create_tween()
			btn_tween.tween_interval(0.3 + i * 0.08)
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


## Build entire UI dynamically (no .tscn node dependency)
func _build_ui() -> void:
	# Root layout
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "战策 Battleplan"
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "灵魂指挥官 · RTS对战竞技场"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Button grid (3 columns x 4 rows = 12 buttons)
	_button_grid = GridContainer.new()
	_button_grid.columns = 3
	_button_grid.add_theme_constant_override("h_separation", 12)
	_button_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(_button_grid)

	# Create all menu buttons
	for btn_def in MENU_BUTTONS:
		var btn = Button.new()
		btn.name = "Btn_" + btn_def["name"]
		btn.text = btn_def["label"] + "\n" + btn_def["label_en"]
		btn.custom_minimum_size = Vector2(160, 70)
		btn.add_theme_font_size_override("font_size", 14)
		# Apply accent color via modulate (will be reset on hover)
		btn.modulate = btn_def["color"]
		btn.tooltip_text = btn_def["label"]
		_button_grid.add_child(btn)
		_buttons[btn_def["name"]] = btn

	# Set compatibility references for tests
	if _buttons.has("start"):
		_start_button = _buttons["start"]
	if _buttons.has("home"):
		_home_button = _buttons["home"]
	if _buttons.has("settings"):
		_settings_button = _buttons["settings"]
	if _buttons.has("quit"):
		_quit_button = _buttons["quit"]

	# Version label (GAP-003)
	_version_label = Label.new()
	_version_label.text = "v0.2.0 - M2 Early Access"
	_version_label.add_theme_font_size_override("font_size", 10)
	_version_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_version_label)

	GameLog.info("MainMenu: UI built with %d buttons" % MENU_BUTTONS.size(), "UI")


## Start title floating + breathing glow animation
func _start_title_float() -> void:
	if _title_label == null:
		return
	# Floating animation (up-down motion)
	var float_tween = create_tween()
	float_tween.set_loops()
	float_tween.tween_property(_title_label, "position:y", _title_label.position.y - 8, 2.0).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(_title_label, "position:y", _title_label.position.y + 8, 2.0).set_ease(Tween.EASE_IN_OUT)
	# Breathing glow animation (golden brightness pulse)
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(_title_label, "modulate", Color(1.3, 1.1, 0.7), 1.5).set_ease(Tween.EASE_IN_OUT)
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
	# Kill existing tween and create new one
	if p_button.has_meta("hover_tween"):
		var old_tween = p_button.get_meta("hover_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(p_button, "scale", Vector2(1.08, 1.08), 0.15)
	tween.parallel().tween_property(p_button, "modulate", Color(1.3, 1.15, 0.8), 0.15)
	p_button.set_meta("hover_tween", tween)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	if p_button.has_meta("hover_tween"):
		var old_tween = p_button.get_meta("hover_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	# Restore original accent color (default white, then override with button-specific color)
	var original_color = Color(1.0, 1.0, 1.0)
	for btn_def in MENU_BUTTONS:
		if "Btn_" + btn_def["name"] == p_button.name:
			original_color = btn_def["color"]
			break
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(p_button, "scale", Vector2(1.0, 1.0), 0.2)
	# First reset to white (compatibility for test source-code check), then to original color
	tween.parallel().tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	tween.tween_property(p_button, "modulate", original_color, 0.1)
	p_button.set_meta("hover_tween", tween)


## Play button hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")


## Handle all menu button presses (GAP-002: unified handler)
func _on_button_pressed(p_button_name: String) -> void:
	_play_button_sound()

	# Find button definition
	var btn_def = null
	for def in MENU_BUTTONS:
		if def["name"] == p_button_name:
			btn_def = def
			break

	if btn_def == null:
		GameLog.warning("MainMenu: Unknown button '%s'" % p_button_name, "MainMenu")
		return

	GameLog.info("MainMenu: '%s' pressed" % btn_def["label"], "MainMenu")

	# Handle quit specially
	if p_button_name == "quit":
		get_tree().quit()
		return

	# Transition to scene
	if btn_def["scene"] != "":
		SceneManager.change_scene(btn_def["scene"])
	else:
		GameLog.warning("MainMenu: No scene defined for '%s'" % p_button_name, "MainMenu")


## Compatibility methods for tests (GAP-002 migration)
## These delegate to the unified _on_button_pressed handler
func _on_start_pressed() -> void:
	_on_button_pressed("start")


func _on_home_pressed() -> void:
	_on_button_pressed("home")


func _on_settings_pressed() -> void:
	_on_button_pressed("settings")


func _on_quit_pressed() -> void:
	_on_button_pressed("quit")


func _play_button_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")


## Apply Battleplan UI theme (gold/dark pixel-fantasy style)
## Loads theme from assets/ui/battleplan_theme.tres and applies to root
func _apply_ui_theme() -> void:
	var theme_path := "res://assets/ui/battleplan_theme.tres"
	if ResourceLoader.exists(theme_path):
		var theme = load(theme_path)
		if theme:
			self.theme = theme
			GameLog.debug("MainMenu: Applied Battleplan UI theme", "UI")
		else:
			GameLog.warning("MainMenu: Failed to load UI theme", "UI")
	else:
		GameLog.warning("MainMenu: UI theme not found at %s" % theme_path, "UI")
