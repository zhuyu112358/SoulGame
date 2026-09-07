extends Control
## MainMenu - Main menu scene controller
##
## Provides the main menu UI with game title, start game, soul home,
## settings, and quit buttons. Handles scene transitions and button sounds.

@onready var _title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _home_button: Button = $CenterContainer/VBoxContainer/HomeButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var _version_label: Label = $CenterContainer/VBoxContainer/VersionLabel

var _selected_soul_id: String = ""


func _ready() -> void:
	GameLog.info("MainMenu initialized", "MainMenu")

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
