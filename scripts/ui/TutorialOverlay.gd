extends CanvasLayer
## TutorialOverlay - In-battle tutorial step display UI
## Follows GDD v2.0 Chapter 15: Tutorial and Story Mode
## M2.10 Tutorial & Story - Tutorial Step Display
##
## Shows current tutorial step, objective, and hints during battle.
## Can be toggled, minimized, and dismissed.

## TutorialSystem preload
const TutorialSystem = preload("res://scripts/game/TutorialSystem.gd")

## UI node references
@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _step_label: Label = $Panel/VBox/StepLabel
@onready var _objective_label: Label = $Panel/VBox/ObjectiveLabel
@onready var _hint_label: Label = $Panel/VBox/HintLabel
@onready var _progress_bar: ProgressBar = $Panel/VBox/ProgressBar
@onready var _close_button: Button = $Panel/CloseButton
@onready var _minimize_button: Button = $Panel/MinimizeButton
@onready var _next_button: Button = $Panel/VBox/NextButton

## Tutorial system instance
var _tutorial_system: TutorialSystem = null

## Current level and step
var _current_level: int = -1
var _current_step: int = -1

## Whether overlay is minimized
var _is_minimized: bool = false

## Whether tutorial is active
var _is_tutorial_active: bool = false


func _ready() -> void:
	# Initialize tutorial system
	_tutorial_system = TutorialSystem.new()
	add_child(_tutorial_system)

	# Connect signals
	_close_button.pressed.connect(_on_close_pressed)
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_next_button.pressed.connect(_on_next_pressed)

	# Setup button hover effects
	_setup_button_hover(_close_button)
	_setup_button_hover(_minimize_button)
	_setup_button_hover(_next_button)

	# Check if tutorial is active
	if GameState and GameState.has("tutorial", "is_tutorial"):
		_is_tutorial_active = GameState.get_value("tutorial", "is_tutorial", false)
		_current_level = GameState.get_value("tutorial", "active_level", -1)

	if _is_tutorial_active and _current_level >= 0:
		start_tutorial(_current_level)
	else:
		visible = false

	GameLog.info("TutorialOverlay: Ready, active=%s, level=%d" % [_is_tutorial_active, _current_level], "UI")


## Start a tutorial level
func start_tutorial(p_level_id: int) -> void:
	_current_level = p_level_id
	_is_tutorial_active = true
	_tutorial_system.start_tutorial(p_level_id)
	_current_step = 0
	_update_display()
	visible = true
	GameLog.info("TutorialOverlay: Starting tutorial %d" % p_level_id, "UI")


## Update display with current step info
func _update_display() -> void:
	if not _is_tutorial_active or _current_level < 0:
		return

	var level_data = _tutorial_system.get_level_data(_current_level)
	if level_data == null:
		return

	var steps = level_data.get("steps", [])
	if _current_step < 0 or _current_step >= steps.size():
		return

	var step = steps[_current_step]

	# Update title
	_title_label.text = level_data.get("name", "教学")

	# Update step label
	_step_label.text = "步骤 %d/%d" % [_current_step + 1, steps.size()]

	# Update objective
	var step_type = step.get("type", "INFO")
	var objective = step.get("objective", step.get("text", ""))
	_objective_label.text = "目标: " + objective

	# Update hint
	var hint = step.get("hint", "")
	if hint:
		_hint_label.text = "提示: " + hint
		_hint_label.visible = true
	else:
		_hint_label.visible = false

	# Update progress
	_progress_bar.value = float(_current_step + 1) / float(steps.size()) * 100.0

	# Show next button for INFO steps
	_next_button.visible = (step_type == "INFO")


## Advance to next step
func next_step() -> void:
	if not _is_tutorial_active:
		return

	var level_data = _tutorial_system.get_level_data(_current_level)
	if level_data == null:
		return

	var steps = level_data.get("steps", [])
	_current_step += 1

	if _current_step >= steps.size():
		# Tutorial complete
		_complete_tutorial()
	else:
		_tutorial_system.next_step()
		_update_display()


## Complete current tutorial
func _complete_tutorial() -> void:
	_tutorial_system.complete_level(_current_level)
	_is_tutorial_active = false
	visible = false
	GameLog.info("TutorialOverlay: Tutorial %d completed" % _current_level, "UI")


## Close tutorial overlay
func _on_close_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_is_tutorial_active = false
	visible = false


## Minimize/maximize overlay
func _on_minimize_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_is_minimized = not _is_minimized
	if _is_minimized:
		_panel.visible = false
		_minimize_button.text = "展开"
	else:
		_panel.visible = true
		_minimize_button.text = "收起"


## Next step button pressed
func _on_next_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	next_step()


## Check objective completion (call from battle logic)
func check_objective(p_objective_id: String, p_progress: float = 1.0) -> void:
	if not _is_tutorial_active:
		return
	# Future: check if current step objective matches and advance
	pass


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
