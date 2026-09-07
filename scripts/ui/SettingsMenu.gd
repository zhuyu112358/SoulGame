extends Control
## SettingsMenu - Settings scene controller
##
## Provides volume controls (master, SFX, BGM) and back to main menu.
## Follows pixel art UI style consistent with v1.1 design.

@onready var _master_slider: HSlider = $CenterContainer/VBoxContainer/MasterVolume/Slider
@onready var _master_label: Label = $CenterContainer/VBoxContainer/MasterVolume/ValueLabel
@onready var _sfx_slider: HSlider = $CenterContainer/VBoxContainer/SfxVolume/Slider
@onready var _sfx_label: Label = $CenterContainer/VBoxContainer/SfxVolume/ValueLabel
@onready var _bgm_slider: HSlider = $CenterContainer/VBoxContainer/BgmVolume/Slider
@onready var _bgm_label: Label = $CenterContainer/VBoxContainer/BgmVolume/ValueLabel
@onready var _back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	GameLog.info("SettingsMenu initialized", "Settings")

	# Load current volume values
	if AudioManager:
		_master_slider.value = AudioManager.get_volume("master") * 100.0
		_sfx_slider.value = AudioManager.get_volume("sfx") * 100.0
		_bgm_slider.value = AudioManager.get_volume("bgm") * 100.0
		_update_labels()

	# Connect signals
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	_back_button.pressed.connect(_on_back_pressed)

	# Setup button hover effects for audio + visual feedback
	_setup_button_hover(_back_button)


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


## Update volume value labels
func _update_labels() -> void:
	_master_label.text = "%d%%" % int(_master_slider.value)
	_sfx_label.text = "%d%%" % int(_sfx_slider.value)
	_bgm_label.text = "%d%%" % int(_bgm_slider.value)


## Handle master volume change
func _on_master_volume_changed(p_value: float) -> void:
	if AudioManager:
		AudioManager.set_master_volume(p_value / 100.0)
	_master_label.text = "%d%%" % int(p_value)


## Handle SFX volume change
func _on_sfx_volume_changed(p_value: float) -> void:
	if AudioManager:
		AudioManager.set_sfx_volume(p_value / 100.0)
	_sfx_label.text = "%d%%" % int(p_value)
	# Play a test sound
	if AudioManager and p_value > 0:
		AudioManager.play_sfx("ui_button_click")


## Handle BGM volume change
func _on_bgm_volume_changed(p_value: float) -> void:
	if AudioManager:
		AudioManager.set_bgm_volume(p_value / 100.0)
	_bgm_label.text = "%d%%" % int(p_value)


## Handle back button - return to main menu
func _on_back_pressed() -> void:
	GameLog.info("Settings: Back to main menu", "Settings")
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
		AudioManager.play_sfx("ui_settings_close")
	SceneManager.change_scene("res://scenes/main_menu.tscn")
