extends CanvasLayer
## CGSystem - CG animation player system
## Follows GDD v2.0 Chapter 15: Tutorial and Story Mode
## M2.10 Tutorial & Story - CG Animation Base
##
## Plays CG sequences with images, text, and fade transitions.
## Supports: opening CG, transition CG, victory/defeat CG, evolution CG.

## CG types
enum CGType {
	OPENING,    # Opening CG (60-90 seconds)
	TRANSITION, # Scene transition CG
	VICTORY,    # Victory CG
	DEFEAT,     # Defeat CG
	EVOLUTION   # Soul evolution CG (simplified)
}

## UI node references
@onready var _background: TextureRect = $Background
@onready var _text_panel: Panel = $TextPanel
@onready var _title_label: Label = $TextPanel/VBox/TitleLabel
@onready var _text_label: Label = $TextPanel/VBox/TextLabel
@onready var _skip_button: Button = $SkipButton
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _fade_layer: ColorRect = $FadeLayer

## Current CG data
var _current_cg: Dictionary = {}

## Current slide index
var _current_slide: int = 0

## Whether CG is playing
var _is_playing: bool = false

## Whether auto-play is enabled
var _auto_play: bool = true

## Auto-play interval (seconds)
var _auto_play_interval: float = 4.0

## Auto-play timer
var _auto_timer: float = 0.0

## Fade duration (seconds)
var _fade_duration: float = 0.8

## Whether currently fading
var _is_fading: bool = false

## CG completed signal
signal cg_started(cg_type)
signal cg_slide_changed(slide_index)
signal cg_completed(cg_type)
signal cg_skipped(cg_type)


func _ready() -> void:
	# Connect signals
	_skip_button.pressed.connect(_on_skip_pressed)
	gui_input.connect(_on_gui_input)
	visible = false

	# Setup button hover
	_setup_button_hover(_skip_button)

	GameLog.info("CGSystem: Ready", "CG")


## Play a CG sequence
func play_cg(p_cg_data: Dictionary) -> void:
	_current_cg = p_cg_data
	_current_slide = 0
	_is_playing = true
	_auto_play = p_cg_data.get("auto_play", true)
	_auto_play_interval = p_cg_data.get("slide_duration", 4.0)

	visible = true
	_fade_in()
	_show_slide(0)

	var cg_type = p_cg_data.get("type", "opening")
	cg_started.emit(cg_type)
	GameLog.info("CGSystem: Playing CG - %s, %d slides" % [cg_type, _current_cg.get("slides", []).size()], "CG")


## Play CG from JSON file
func play_cg_from_file(p_file_path: String) -> void:
	if not ResourceLoader.exists(p_file_path):
		GameLog.warning("CGSystem: CG file not found: %s" % p_file_path, "CG")
		return

	var file = FileAccess.open(p_file_path, FileAccess.READ)
	if file == null:
		GameLog.warning("CGSystem: Cannot open CG file: %s" % p_file_path, "CG")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		GameLog.warning("CGSystem: JSON parse error: %s" % json.get_error_message(), "CG")
		return

	play_cg(json.data)


## Show current slide
func _show_slide(p_index: int) -> void:
	var slides = _current_cg.get("slides", [])
	if p_index < 0 or p_index >= slides.size():
		return

	_current_slide = p_index
	var slide = slides[p_index]

	# Set background image
	var image_path = slide.get("image", "")
	if image_path != "" and ResourceLoader.exists(image_path):
		_background.texture = load(image_path)
		_background.visible = true
	else:
		_background.visible = false

	# Set title
	var title = slide.get("title", "")
	_title_label.text = title
	_title_label.visible = (title != "")

	# Set text
	var text = slide.get("text", "")
	_text_label.text = text
	_text_panel.visible = (text != "" or title != "")

	# Update progress
	_progress_bar.value = float(p_index + 1) / float(slides.size()) * 100.0

	cg_slide_changed.emit(p_index)


## Advance to next slide
func next_slide() -> void:
	if not _is_playing or _is_fading:
		return

	var slides = _current_cg.get("slides", [])
	if _current_slide + 1 >= slides.size():
		_complete_cg()
		return

	_fade_out()
	await get_tree().create_timer(_fade_duration).timeout
	_show_slide(_current_slide + 1)
	_fade_in()
	_auto_timer = 0.0


## Complete current CG
func _complete_cg() -> void:
	_is_playing = false
	var cg_type = _current_cg.get("type", "opening")
	cg_completed.emit(cg_type)
	_fade_out()
	await get_tree().create_timer(_fade_duration).timeout
	visible = false
	GameLog.info("CGSystem: CG completed - %s" % cg_type, "CG")


## Skip current CG
func skip_cg() -> void:
	if not _is_playing:
		return
	_is_playing = false
	var cg_type = _current_cg.get("type", "opening")
	cg_skipped.emit(cg_type)
	visible = false
	GameLog.info("CGSystem: CG skipped - %s" % cg_type, "CG")


## Fade in
func _fade_in() -> void:
	_is_fading = true
	_fade_layer.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(_fade_layer, "color:a", 0.0, _fade_duration)
	tween.finished.connect(func(): _is_fading = false)


## Fade out
func _fade_out() -> void:
	_is_fading = true
	_fade_layer.color.a = 0.0
	var tween = create_tween()
	tween.tween_property(_fade_layer, "color:a", 1.0, _fade_duration)
	tween.finished.connect(func(): _is_fading = false)


## Process auto-play
func _process(delta: float) -> void:
	if not _is_playing or not _auto_play or _is_fading:
		return

	_auto_timer += delta
	if _auto_timer >= _auto_play_interval:
		_auto_timer = 0.0
		next_slide()


## Handle GUI input (click to advance)
func _on_gui_input(event: InputEvent) -> void:
	if not _is_playing:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			next_slide()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			next_slide()
		elif event.keycode == KEY_ESCAPE:
			skip_cg()


## Skip button pressed
func _on_skip_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	skip_cg()


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


## Check if CG is playing
func is_playing() -> bool:
	return _is_playing
