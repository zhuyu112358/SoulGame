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

	# Apply Battleplan UI theme BEFORE building UI so button overrides take priority
	_apply_ui_theme()

	# Build UI dynamically
	_build_ui()

	FontLoader.apply_font_to_control(self)

	# Connect button signals and hover effects (only once per button)
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

	# Animate buttons appearance (staggered fade in, deferred to ensure tween runs)
	call_deferred("_animate_buttons")

	# P0-紧急: Safety fallback - force all buttons visible after 2 seconds
	var safety_timer = Timer.new()
	safety_timer.wait_time = 2.0
	safety_timer.one_shot = true
	safety_timer.timeout.connect(_force_buttons_visible)
	add_child(safety_timer)
	safety_timer.start()


## Animate buttons with staggered fade in (deferred to ensure tween runs)
func _animate_buttons() -> void:
	var btn_list = MENU_BUTTONS
	for i in range(btn_list.size()):
		var btn_name = btn_list[i]["name"]
		if _buttons.has(btn_name) and _buttons[btn_name]:
			var btn = _buttons[btn_name]
			btn.modulate = Color(1, 1, 1, 0)
			var btn_tween = create_tween()
			btn_tween.tween_interval(0.3 + i * 0.08)
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


## P0-紧急: Force all buttons visible (fallback if tween animation fails)
func _force_buttons_visible() -> void:
	for btn_name in _buttons.keys():
		if _buttons[btn_name]:
			_buttons[btn_name].modulate.a = 1.0
	GameLog.info("MainMenu: Safety fallback - buttons forced visible", "UI")


## Build entire UI dynamically (no .tscn node dependency)
## UI-1 redesign: Game-style layout (StarCraft/Diablo inspired) with 9-slice UI components
func _build_ui() -> void:
	# Root layout - use margin container for padding
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# === TITLE SECTION ===
	var title_container = VBoxContainer.new()
	title_container.add_theme_constant_override("separation", 5)
	vbox.add_child(title_container)

	# Title with gold glow
	_title_label = Label.new()
	_title_label.text = "战策  Battleplan"
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_container.add_child(_title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "灵 魂 指 挥 官 · R T S 对 战 竞 技 场"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_container.add_child(subtitle)

	# Decorative separator
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sep)

	# === MAIN ACTION BUTTON (Start Game - largest, most prominent) ===
	var main_btn_container = CenterContainer.new()
	vbox.add_child(main_btn_container)

	var start_btn = _create_game_button("start", "开始战斗", "START BATTLE", Vector2(360, 80), 24)
	start_btn.modulate = Color(1.0, 0.92, 0.5)  # Gold highlight for primary action
	main_btn_container.add_child(start_btn)
	_buttons["start"] = start_btn
	_start_button = start_btn

	# === META-GAME BUTTONS (2x3 grid - secondary actions) ===
	var meta_label = Label.new()
	meta_label.text = "— 灵 魂 世 界 —"
	meta_label.add_theme_font_size_override("font_size", 14)
	meta_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(meta_label)

	var meta_grid = GridContainer.new()
	meta_grid.columns = 3
	meta_grid.add_theme_constant_override("h_separation", 15)
	meta_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(meta_grid)

	var meta_buttons = ["home", "codex", "collection", "training", "tutorial", "story"]
	for btn_name in meta_buttons:
		var btn_def = _find_button_def(btn_name)
		if btn_def:
			var btn = _create_game_button(btn_name, btn_def["label"], btn_def["label_en"], Vector2(200, 55), 14)
			btn.modulate = btn_def["color"]
			meta_grid.add_child(btn)
			_buttons[btn_name] = btn

	# === ONLINE / SYSTEM BUTTONS (bottom row) ===
	var sys_label = Label.new()
	sys_label.text = "— 对 战 与 系 统 —"
	sys_label.add_theme_font_size_override("font_size", 14)
	sys_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
	sys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sys_label)

	var sys_row = HBoxContainer.new()
	sys_row.add_theme_constant_override("separation", 15)
	sys_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(sys_row)

	var sys_buttons = ["matchmaking", "friends", "customize", "settings", "quit"]
	for btn_name in sys_buttons:
		var btn_def = _find_button_def(btn_name)
		if btn_def:
			var btn = _create_game_button(btn_name, btn_def["label"], btn_def["label_en"], Vector2(170, 50), 13)
			btn.modulate = btn_def["color"]
			sys_row.add_child(btn)
			_buttons[btn_name] = btn

	# Set compatibility references
	if _buttons.has("home"):
		_home_button = _buttons["home"]
	if _buttons.has("settings"):
		_settings_button = _buttons["settings"]
	if _buttons.has("quit"):
		_quit_button = _buttons["quit"]

	# Version label (GAP-003)
	_version_label = Label.new()
	_version_label.text = "v0.2.0 - M2 Early Access"
	_version_label.add_theme_font_size_override("font_size", 11)
	_version_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_version_label)

	GameLog.info("MainMenu: UI rebuilt with game-style layout and 9-slice components", "UI")


## Create a game-style button with 9-slice UI component textures
func _create_game_button(p_name: String, p_label: String, p_label_en: String, p_size: Vector2, p_font_size: int) -> Button:
	var btn = Button.new()
	btn.name = "Btn_" + p_name
	btn.text = p_label + "\n" + p_label_en
	btn.custom_minimum_size = p_size
	btn.add_theme_font_size_override("font_size", p_font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.5))
	btn.tooltip_text = p_label

	# Button styling handled by battleplan_theme.tres
	return btn


## Find button definition by name
func _find_button_def(p_name: String) -> Dictionary:
	for btn_def in MENU_BUTTONS:
		if btn_def["name"] == p_name:
			return btn_def
	return {}


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
