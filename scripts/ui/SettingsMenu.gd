extends Control
## SettingsMenu - Game settings interface
## Follows GDD v2.0 Chapter 9: UI System
## M2.9 UI System - Settings Menu
##
## Provides display, audio, input, and game settings with persistence.

const FontLoader = preload("res://scripts/core/FontLoader.gd")

@onready var _title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var _tab_container: TabContainer = $MarginContainer/VBox/TabContainer
@onready var _back_button: Button = $MarginContainer/VBox/BackButton
@onready var _save_button: Button = $MarginContainer/VBox/ButtonRow/SaveButton
@onready var _reset_button: Button = $MarginContainer/VBox/ButtonRow/ResetButton

# Display settings
@onready var _resolution_option: OptionButton = $MarginContainer/VBox/TabContainer/Display/VBox/ResolutionRow/Option
@onready var _fullscreen_check: CheckButton = $MarginContainer/VBox/TabContainer/Display/VBox/FullscreenRow/Check
@onready var _quality_option: OptionButton = $MarginContainer/VBox/TabContainer/Display/VBox/QualityRow/Option
@onready var _vsync_check: CheckButton = $MarginContainer/VBox/TabContainer/Display/VBox/VsyncRow/Check

# Audio settings
@onready var _master_slider: HSlider = $MarginContainer/VBox/TabContainer/Audio/VBox/MasterRow/Slider
@onready var _master_value: Label = $MarginContainer/VBox/TabContainer/Audio/VBox/MasterRow/Value
@onready var _bgm_slider: HSlider = $MarginContainer/VBox/TabContainer/Audio/VBox/BgmRow/Slider
@onready var _bgm_value: Label = $MarginContainer/VBox/TabContainer/Audio/VBox/BgmRow/Value
@onready var _sfx_slider: HSlider = $MarginContainer/VBox/TabContainer/Audio/VBox/SfxRow/Slider
@onready var _sfx_value: Label = $MarginContainer/VBox/TabContainer/Audio/VBox/SfxRow/Value

# Game settings
@onready var _language_option: OptionButton = $MarginContainer/VBox/TabContainer/Game/VBox/LanguageRow/Option
@onready var _difficulty_option: OptionButton = $MarginContainer/VBox/TabContainer/Game/VBox/DifficultyRow/Option
@onready var _autosave_check: CheckButton = $MarginContainer/VBox/TabContainer/Game/VBox/AutosaveRow/Check
@onready var _show_fps_check: CheckButton = $MarginContainer/VBox/TabContainer/Game/VBox/ShowFpsRow/Check

## Settings data
var _settings: Dictionary = {}

## Default settings
const DEFAULT_SETTINGS := {
	"display": {
		"resolution": "1920x1080",
		"fullscreen": false,
		"quality": "medium",
		"vsync": true
	},
	"audio": {
		"master": 80,
		"bgm": 70,
		"sfx": 90
	},
	"game": {
		"language": "zh_CN",
		"difficulty": "normal",
		"autosave": true,
		"show_fps": false
	}
}

## Config file path
const CONFIG_PATH := "user://settings.cfg"


func _ready() -> void:
	GameLog.info("SettingsMenu initialized", "Settings")
	_apply_ui_theme()
	FontLoader.apply_font_to_control(self)
	_load_settings()
	_populate_options()
	_apply_settings_to_ui()
	_connect_signals()
	_animate_entrance()


## Animate entrance
func _animate_entrance() -> void:
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)


## Apply UI theme
func _apply_ui_theme() -> void:
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))


## Populate option buttons
func _populate_options() -> void:
	# Resolution options
	_resolution_option.clear()
	_resolution_option.add_item("1280x720")
	_resolution_option.add_item("1920x1080")
	_resolution_option.add_item("2560x1440")
	_resolution_option.add_item("3840x2160")
	# Quality options
	_quality_option.clear()
	_quality_option.add_item("低")
	_quality_option.add_item("中")
	_quality_option.add_item("高")
	_quality_option.add_item("极致")
	# Language options
	_language_option.clear()
	_language_option.add_item("简体中文")
	_language_option.add_item("English")
	_language_option.add_item("日本語")
	# Difficulty options
	_difficulty_option.clear()
	_difficulty_option.add_item("简单")
	_difficulty_option.add_item("普通")
	_difficulty_option.add_item("困难")
	_difficulty_option.add_item("噩梦")


## Connect UI signals
func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	# Setup button hover effects
	_setup_button_hover(_back_button)
	_setup_button_hover(_save_button)
	_setup_button_hover(_reset_button)
	# Audio sliders
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)


## Load settings from config file
func _load_settings() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	if FileAccess.file_exists(CONFIG_PATH):
		var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f:
			var json_string = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(json_string)
			if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
				# Merge with defaults
				for key in parsed.keys():
					if _settings.has(key) and typeof(parsed[key]) == TYPE_DICTIONARY:
						for subkey in parsed[key].keys():
							_settings[key][subkey] = parsed[key][subkey]
					else:
						_settings[key] = parsed[key]
	GameLog.info("SettingsMenu: Settings loaded", "Settings")


## Save settings to config file
func _save_settings() -> void:
	var f = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_settings))
		f.close()
		GameLog.info("SettingsMenu: Settings saved", "Settings")


## Apply settings to UI controls
func _apply_settings_to_ui() -> void:
	# Display
	var resolutions = ["1280x720", "1920x1080", "2560x1440", "3840x2160"]
	_resolution_option.select(max(0, resolutions.find(_settings["display"]["resolution"])))
	_fullscreen_check.button_pressed = _settings["display"]["fullscreen"]
	var qualities = ["low", "medium", "high", "ultra"]
	_quality_option.select(max(0, qualities.find(_settings["display"]["quality"])))
	_vsync_check.button_pressed = _settings["display"]["vsync"]
	# Audio
	_master_slider.value = _settings["audio"]["master"]
	_bgm_slider.value = _settings["audio"]["bgm"]
	_sfx_slider.value = _settings["audio"]["sfx"]
	_update_labels()
	# Game
	var languages = ["zh_CN", "en", "ja"]
	_language_option.select(max(0, languages.find(_settings["game"]["language"])))
	var difficulties = ["easy", "normal", "hard", "nightmare"]
	_difficulty_option.select(max(0, difficulties.find(_settings["game"]["difficulty"])))
	_autosave_check.button_pressed = _settings["game"]["autosave"]
	_show_fps_check.button_pressed = _settings["game"]["show_fps"]


## Read settings from UI controls
func _read_settings_from_ui() -> void:
	# Display
	var resolutions = ["1280x720", "1920x1080", "2560x1440", "3840x2160"]
	_settings["display"]["resolution"] = resolutions[_resolution_option.selected]
	_settings["display"]["fullscreen"] = _fullscreen_check.button_pressed
	var qualities = ["low", "medium", "high", "ultra"]
	_settings["display"]["quality"] = qualities[_quality_option.selected]
	_settings["display"]["vsync"] = _vsync_check.button_pressed
	# Audio
	_settings["audio"]["master"] = int(_master_slider.value)
	_settings["audio"]["bgm"] = int(_bgm_slider.value)
	_settings["audio"]["sfx"] = int(_sfx_slider.value)
	# Game
	var languages = ["zh_CN", "en", "ja"]
	_settings["game"]["language"] = languages[_language_option.selected]
	var difficulties = ["easy", "normal", "hard", "nightmare"]
	_settings["game"]["difficulty"] = difficulties[_difficulty_option.selected]
	_settings["game"]["autosave"] = _autosave_check.button_pressed
	_settings["game"]["show_fps"] = _show_fps_check.button_pressed


## Apply settings to game
func _apply_settings_to_game() -> void:
	# Display
	var resolution = _settings["display"]["resolution"].split("x")
	if resolution.size() == 2:
		var width = int(resolution[0])
		var height = int(resolution[1])
		DisplayServer.window_set_size(Vector2i(width, height))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _settings["display"]["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	# VSync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _settings["display"]["vsync"] else DisplayServer.VSYNC_DISABLED)
	# Audio
	if AudioManager:
		AudioManager.set_master_volume(_settings["audio"]["master"] / 100.0)
		AudioManager.set_bgm_volume(_settings["audio"]["bgm"] / 100.0)
		AudioManager.set_sfx_volume(_settings["audio"]["sfx"] / 100.0)
	GameLog.info("SettingsMenu: Settings applied to game", "Settings")


## Update audio value labels
func _update_labels() -> void:
	_master_value.text = "%d%%" % int(_master_slider.value)
	_bgm_value.text = "%d%%" % int(_bgm_slider.value)
	_sfx_value.text = "%d%%" % int(_sfx_slider.value)


## Get current settings
func get_settings() -> Dictionary:
	return _settings.duplicate(true)


## Get a specific setting value
func get_setting(category: String, key: String, default_value = null):
	if _settings.has(category) and _settings[category].has(key):
		return _settings[category][key]
	return default_value


## Set a specific setting value
func set_setting(category: String, key: String, value) -> void:
	if not _settings.has(category):
		_settings[category] = {}
	_settings[category][key] = value


## Setup button hover effects
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


## Play hover sound and visual feedback
func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.25, 1.1, 0.75), 0.15)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)


## Play hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")


## Handle back button
func _on_back_pressed() -> void:
	# Play close sound
	if AudioManager:
		AudioManager.play_sfx("ui_settings_close")
	# Apply and save before leaving
	_read_settings_from_ui()
	_apply_settings_to_game()
	_save_settings()
	# Return to previous scene
	if get_tree().previous_scene != "":
		get_tree().change_scene_to_file(get_tree().previous_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Handle save button
func _on_save_pressed() -> void:
	_read_settings_from_ui()
	_apply_settings_to_game()
	_save_settings()
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	GameLog.info("SettingsMenu: Settings saved", "Settings")


## Handle reset button
func _on_reset_pressed() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	_apply_settings_to_ui()
	_apply_settings_to_game()
	_save_settings()
	GameLog.info("SettingsMenu: Settings reset to defaults", "Settings")


## Handle master volume change
func _on_master_volume_changed(value: float) -> void:
	_update_labels()
	if AudioManager:
		AudioManager.set_master_volume(value / 100.0)


## Handle BGM volume change
func _on_bgm_volume_changed(value: float) -> void:
	_update_labels()
	if AudioManager:
		AudioManager.set_bgm_volume(value / 100.0)


## Handle SFX volume change
func _on_sfx_volume_changed(value: float) -> void:
	_update_labels()
	if AudioManager:
		AudioManager.set_sfx_volume(value / 100.0)
