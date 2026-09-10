extends CanvasLayer
## DialogueBox - UI controller for dialogue display
## Follows GDD v2.0 Chapter 10: Tutorial and Story
## M2.10 Tutorial & Story - Dialogue UI
##
## Displays dialogue text, speaker name, portrait, and choice buttons.
## Connects to DialogueSystem for conversation flow.

const DialogueSystem = preload("res://scripts/game/DialogueSystem.gd")
const FontLoader = preload("res://scripts/core/FontLoader.gd")

@onready var _dialogue_panel: PanelContainer = $DialoguePanel
@onready var _speaker_label: Label = $DialoguePanel/MarginContainer/VBox/SpeakerLabel
@onready var _text_label: Label = $DialoguePanel/MarginContainer/VBox/TextLabel
@onready var _portrait_rect: TextureRect = $DialoguePanel/MarginContainer/HBox/Portrait
@onready var _choices_container: VBoxContainer = $DialoguePanel/MarginContainer/VBox/ChoicesContainer
@onready var _continue_hint: Label = $DialoguePanel/MarginContainer/VBox/ContinueHint

## Dialogue system instance
var _dialogue_system: Node = null

## Portrait atlas
var _portrait_atlas: Texture2D = null
const PORTRAIT_ATLAS_PATH := "res://assets/art/character_portrait_sheet_v1.png"
const ELEMENT_PORTRAIT_INDEX := {
	"fire": 0, "water": 1, "earth": 2, "wind": 3,
	"thunder": 4, "ice": 5, "dark": 6, "light": 7
}


func _ready() -> void:
	_init_dialogue_system()
	_load_portrait_atlas()
	_apply_ui_theme()
	FontLoader.apply_font_to_control(self)
	hide()


## Initialize dialogue system
func _init_dialogue_system() -> void:
	_dialogue_system = DialogueSystem.new()
	_dialogue_system.name = "DialogueSystem"
	add_child(_dialogue_system)
	# Connect signals
	_dialogue_system.line_shown.connect(_on_line_shown)
	_dialogue_system.text_complete.connect(_on_text_complete)
	_dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	_dialogue_system.dialogue_event.connect(_on_dialogue_event)


## Load portrait atlas
func _load_portrait_atlas() -> void:
	if ResourceLoader.exists(PORTRAIT_ATLAS_PATH):
		_portrait_atlas = load(PORTRAIT_ATLAS_PATH)


## Apply UI theme
func _apply_ui_theme() -> void:
	# Panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.05, 0.15, 0.95)
	panel_style.border_color = Color(0.83, 0.66, 0.36)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	_dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	# Speaker label
	_speaker_label.add_theme_font_size_override("font_size", 24)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	# Text label
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Continue hint
	_continue_hint.add_theme_font_size_override("font_size", 14)
	_continue_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_continue_hint.text = "▼ 点击继续"


## Start a dialogue
func start_dialogue(lines: Dictionary, start_line_id: String = "") -> void:
	if _dialogue_system == null:
		return
	show()
	_dialogue_system.start_dialogue(lines, start_line_id)


## Start a simple linear dialogue
func start_linear_dialogue(speaker: String, texts: Array) -> void:
	if _dialogue_system == null:
		return
	var lines = _dialogue_system.create_linear_dialogue(speaker, texts)
	start_dialogue(lines)


## Handle input (click to advance)
func _input(event: InputEvent) -> void:
	if not visible or _dialogue_system == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dialogue_system.advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_dialogue_system.advance()
		get_viewport().set_input_as_handled()


## Handle line shown
func _on_line_shown(line_id: String, speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_text_label.text = ""
	_continue_hint.visible = false
	_clear_choices()
	# Update portrait
	_update_portrait(_dialogue_system.get_speaker_portrait())


## Handle text complete
func _on_text_complete(line_id: String) -> void:
	_text_label.text = _dialogue_system.get_full_text()
	# Show choices if any
	var choices = _dialogue_system.get_choices()
	if choices.size() > 0:
		_show_choices(choices)
		_continue_hint.visible = false
	else:
		_continue_hint.visible = true


## Handle dialogue ended
func _on_dialogue_ended(dialogue_id: String) -> void:
	hide()


## Handle dialogue event
func _on_dialogue_event(event_name: String) -> void:
	GameLog.info("DialogueBox: Event triggered: %s" % event_name, "Dialogue")


## Update portrait display
func _update_portrait(element: String) -> void:
	if _portrait_rect == null:
		return
	if element == "" or _portrait_atlas == null:
		_portrait_rect.visible = false
		return
	var index = ELEMENT_PORTRAIT_INDEX.get(element, -1)
	if index < 0:
		_portrait_rect.visible = false
		return
	var atlas = AtlasTexture.new()
	atlas.atlas = _portrait_atlas
	var atlas_size = _portrait_atlas.get_size()
	var cell_w = atlas_size.x / 4
	var cell_h = atlas_size.y / 2
	var col = index % 4
	var row = index / 4
	atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	_portrait_rect.texture = atlas
	_portrait_rect.visible = true


## Show choice buttons
func _show_choices(choices: Array) -> void:
	_clear_choices()
	for i in range(choices.size()):
		var choice = choices[i]
		var button = Button.new()
		button.text = choice.get("text", "选项 %d" % (i + 1))
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 16)
		# Button style
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.1, 0.25, 0.9)
		btn_style.border_color = Color(0.83, 0.66, 0.36)
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2
		btn_style.border_width_top = 2
		btn_style.border_width_bottom = 2
		btn_style.corner_radius_top_left = 6
		btn_style.corner_radius_top_right = 6
		btn_style.corner_radius_bottom_left = 6
		btn_style.corner_radius_bottom_right = 6
		button.add_theme_stylebox_override("normal", btn_style)
		button.add_theme_stylebox_override("hover", btn_style)
		button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6))
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choices_container.add_child(button)


## Clear choice buttons
func _clear_choices() -> void:
	for child in _choices_container.get_children():
		child.queue_free()


## Handle choice pressed
func _on_choice_pressed(index: int) -> void:
	if _dialogue_system:
		_dialogue_system.make_choice(index)


## Is dialogue active
func is_dialogue_active() -> bool:
	if _dialogue_system == null:
		return false
	return _dialogue_system.is_dialogue_active()


## Get dialogue system
func get_dialogue_system() -> Node:
	return _dialogue_system
