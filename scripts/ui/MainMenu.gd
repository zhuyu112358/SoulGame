extends Control
## MainMenu - Main menu scene controller
##
## Provides the main menu UI with game title, start game, soul home,
## settings, and quit buttons. Handles scene transitions and button sounds.

const FontLoader = preload("res://scripts/core/FontLoader.gd")

@onready var _title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _home_button: Button = $CenterContainer/VBoxContainer/HomeButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var _version_label: Label = $CenterContainer/VBoxContainer/VersionLabel

var _selected_soul_id: String = ""


func _ready() -> void:
	GameLog.info("MainMenu initialized", "MainMenu")

	# Apply Battleplan UI theme (gold/dark pixel-fantasy style)
	_apply_ui_theme()
	FontLoader.apply_font_to_control(self)

	# Connect button signals
	_start_button.pressed.connect(_on_start_pressed)
	_home_button.pressed.connect(_on_home_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# Connect hover signals for audio feedback
	_setup_button_hover(_start_button)
	_setup_button_hover(_home_button)
	_setup_button_hover(_settings_button)
	_setup_button_hover(_quit_button)

	# Set version text
	var version = GameState.get_value("game", "version", "0.2.0")
	_version_label.text = "v%s - M2 Prototype" % version

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
	var buttons = [_start_button, _home_button, _settings_button, _quit_button]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn:
			btn.modulate = Color(1, 1, 1, 0)
			var btn_tween = create_tween()
			btn_tween.tween_interval(0.3 + i * 0.15)
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


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
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(p_button, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	p_button.set_meta("hover_tween", tween)


## Play button hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")


func _on_start_pressed() -> void:
	GameLog.info("Start game pressed - transitioning to soul select", "MainMenu")
	_play_button_sound()
	SceneManager.change_scene("res://scenes/soul_select.tscn")


func _on_home_pressed() -> void:
	GameLog.info("Soul home pressed - transitioning to soul home", "MainMenu")
	_play_button_sound()
	SceneManager.change_scene("res://scenes/soul_home.tscn")


func _on_settings_pressed() -> void:
	GameLog.info("Settings pressed - transitioning to settings", "MainMenu")
	_play_button_sound()
	SceneManager.change_scene("res://scenes/settings.tscn")


func _on_quit_pressed() -> void:
	GameLog.info("Quit game pressed", "MainMenu")
	_play_button_sound()
	get_tree().quit()


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
