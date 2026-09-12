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
@onready var _video_player: VideoStreamPlayer = $VideoPlayer

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
	# Note: CanvasLayer does not have gui_input signal, use _input() instead for keyboard shortcuts
	visible = true

	# Setup button hover
	_setup_button_hover(_skip_button)

	# Auto-play opening CG video if available
	var video_path = "res://assets/cg_video/opening_cg_final.mp4"
	if ResourceLoader.exists(video_path):
		var video_stream = load(video_path)
		if video_stream:
			_video_player.stream = video_stream
			_video_player.play()
			_video_player.finished.connect(_on_video_finished)
			GameLog.info("CGSystem: Playing opening CG video", "CG")
		else:
			_show_fallback_text()
	else:
		_show_fallback_text()

	# Apply game-level UI styles
	_setup_ui_styles()

	GameLog.info("CGSystem: Ready (game-level UI)", "CG")
	_animate_entrance()


## Animate UI entrance with staggered fade-in + scale (game-level UI)
func _animate_entrance() -> void:
	# Skip button fade-in
	if _skip_button and _skip_button is CanvasItem:
		_skip_button.modulate.a = 0.0
		var skip_tween = create_tween()
		skip_tween.set_ease(Tween.EASE_OUT)
		skip_tween.tween_interval(0.5)
		skip_tween.tween_property(_skip_button, "modulate:a", 1.0, 0.4)
	# Text panel fade-in + scale
	if _text_panel and _text_panel is CanvasItem:
		_text_panel.modulate.a = 0.0
		_text_panel.scale = Vector2(0.95, 0.95)
		var panel_tween = create_tween()
		panel_tween.set_ease(Tween.EASE_OUT)
		panel_tween.set_trans(Tween.TRANS_BACK)
		panel_tween.tween_interval(0.8)
		panel_tween.tween_property(_text_panel, "modulate:a", 1.0, 0.5)
		panel_tween.parallel().tween_property(_text_panel, "scale", Vector2(1.0, 1.0), 0.5)
	# Title label fade-in
	if _title_label and _title_label is CanvasItem:
		_title_label.modulate.a = 0.0
		var title_tween = create_tween()
		title_tween.set_ease(Tween.EASE_OUT)
		title_tween.tween_interval(1.0)
		title_tween.tween_property(_title_label, "modulate:a", 1.0, 0.4)
	# Text label fade-in
	if _text_label and _text_label is CanvasItem:
		_text_label.modulate.a = 0.0
		var text_tween = create_tween()
		text_tween.set_ease(Tween.EASE_OUT)
		text_tween.tween_interval(1.2)
		text_tween.tween_property(_text_label, "modulate:a", 1.0, 0.4)


## Show fallback text when video not available
func _show_fallback_text() -> void:
	_title_label.text = "战策 Battleplan"
	_text_label.text = "Opening CG\n\n灵魂指挥官·RTS对战竞技场\n\n点击任意位置或按跳过返回主菜单"
	_text_panel.visible = true


## Video finished callback
func _on_video_finished() -> void:
	_return_to_menu()


## Return to main menu
func _return_to_menu() -> void:
	if _video_player.playing:
		_video_player.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
	_return_to_menu()
## Apply game-level UI styles to panels, buttons, and progress bar
func _setup_ui_styles() -> void:
	# Skip button three-state style
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.08, 0.22, 0.9)
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
	btn_hover.bg_color = Color(0.18, 0.12, 0.3, 0.95)
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

	if _skip_button:
		_skip_button.add_theme_stylebox_override("normal", btn_normal)
		_skip_button.add_theme_stylebox_override("hover", btn_hover)
		_skip_button.add_theme_stylebox_override("pressed", btn_pressed)
		_skip_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
		_skip_button.add_theme_font_size_override("font_size", 16)

	# Text panel style: dark purple bg + gold border + rounded corners
	if _text_panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.92)
		panel_style.border_color = Color(0.83, 0.66, 0.36, 0.9)
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 10
		panel_style.corner_radius_top_right = 10
		panel_style.corner_radius_bottom_left = 10
		panel_style.corner_radius_bottom_right = 10
		_text_panel.add_theme_stylebox_override("panel", panel_style)

	# Title label: large gold
	if _title_label:
		_title_label.add_theme_font_size_override("font_size", 36)
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))

	# Text label: gray-white
	if _text_label:
		_text_label.add_theme_font_size_override("font_size", 16)
		_text_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))

	# Progress bar style: gold fill
	if _progress_bar:
		var bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.1, 0.07, 0.18, 0.8)
		bar_bg.border_color = Color(0.6, 0.5, 0.3, 0.6)
		bar_bg.border_width_left = 1
		bar_bg.border_width_right = 1
		bar_bg.border_width_top = 1
		bar_bg.border_width_bottom = 1
		bar_bg.corner_radius_top_left = 3
		bar_bg.corner_radius_top_right = 3
		bar_bg.corner_radius_bottom_left = 3
		bar_bg.corner_radius_bottom_right = 3
		_progress_bar.add_theme_stylebox_override("background", bar_bg)

		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.9, 0.7, 0.35, 0.9)
		bar_fill.corner_radius_top_left = 2
		bar_fill.corner_radius_top_right = 2
		bar_fill.corner_radius_bottom_left = 2
		bar_fill.corner_radius_bottom_right = 2
		_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	GameLog.info("CGSystem: Game-level UI styles applied", "CG")


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
