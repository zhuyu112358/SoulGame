extends Node
## InputManager - Centralized input handling with action binding and contexts
##
## Manages input actions, key rebinding, input contexts (for modal UI),
## and provides a unified event system for input. Supports both action-based
## and direct key-based input.
##
## Usage:
##   InputManager.bind_action("jump", [KEY_SPACE, KEY_W])
##   InputManager.subscribe("jump", self, "_on_jump")
##   InputManager.push_context("menu")  # disables game input
##   InputManager.pop_context()

## Action bindings: { action_name: [keycodes] }
var _action_bindings: Dictionary = {}

## Action subscribers: { action_name: [{target, method}] }
var _action_subscribers: Dictionary = {}

## Input context stack (top context is active)
var _context_stack: Array = []

## Context-specific action allowlists: { context: [allowed_actions] }
var _context_actions: Dictionary = {}

## Whether input is globally enabled
var _input_enabled: bool = true

## Mouse state
var _mouse_position: Vector2 = Vector2.ZERO
var _mouse_delta: Vector2 = Vector2.ZERO
var _mouse_buttons: Dictionary = {}

## Currently pressed keys (for held state)
var _pressed_keys: Dictionary = {}

## Input statistics
var _stats: Dictionary = {
	"total_actions": 0,
	"total_key_events": 0,
	"context_switches": 0
}


func _ready() -> void:
	_register_default_actions()
	Logger.info("InputManager initialized", "Input")


func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return

	_stats["total_key_events"] += 1

	# Track mouse
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative
		_mouse_position = event.position
		EventBus.emit("mouse_motion", {"position": _mouse_position, "delta": _mouse_delta})
		return

	if event is InputEventMouseButton:
		_mouse_buttons[event.button_index] = event.pressed
		EventBus.emit("mouse_button", {
			"button": event.button_index,
			"pressed": event.pressed,
			"position": event.position
		})
		return

	# Track keyboard
	if event is InputEventKey and not event.echo:
		if event.pressed:
			_pressed_keys[event.keycode] = true
		else:
			_pressed_keys.erase(event.keycode)

		# Check action bindings
		if event.pressed:
			_check_action_bindings(event.keycode)


func _process(delta: float) -> void:
	# Reset mouse delta each frame
	_mouse_delta = Vector2.ZERO

	# Check held keys for continuous actions
	for action_name in _action_bindings:
		if _is_action_allowed(action_name):
			var keys: Array = _action_bindings[action_name]
			for key in keys:
				if _pressed_keys.has(key):
					EventBus.emit("action_held", {"action": action_name, "delta": delta})
					break


## Bind keys to an action
func bind_action(action_name: String, keycodes: Array) -> void:
	_action_bindings[action_name] = keycodes.duplicate()
	Logger.debug("InputManager: Bound '%s' to %d keys" % [action_name, keycodes.size()], "Input")


## Add a key to an existing action
func add_action_key(action_name: String, keycode: int) -> void:
	if not _action_bindings.has(action_name):
		_action_bindings[action_name] = []
	if not _action_bindings[action_name].has(keycode):
		_action_bindings[action_name].append(keycode)


## Remove a key from an action
func remove_action_key(action_name: String, keycode: int) -> void:
	if _action_bindings.has(action_name):
		_action_bindings[action_name].erase(keycode)


## Get keys bound to an action
func get_action_keys(action_name: String) -> Array:
	if _action_bindings.has(action_name):
		return _action_bindings[action_name].duplicate()
	return []


## Check if an action is currently pressed
func is_action_pressed(action_name: String) -> bool:
	if not _action_bindings.has(action_name):
		return false
	if not _is_action_allowed(action_name):
		return false
	for key in _action_bindings[action_name]:
		if _pressed_keys.has(key):
			return true
	return false


## Subscribe to action press events
## callback receives { "action": action_name, "keycode": key }
func subscribe(action_name: String, target: Object, method: String) -> void:
	if not _action_subscribers.has(action_name):
		_action_subscribers[action_name] = []

	for sub in _action_subscribers[action_name]:
		if sub.target == target and sub.method == StringName(method):
			return

	_action_subscribers[action_name].append({
		"target": target,
		"method": StringName(method)
	})


## Unsubscribe from action events
func unsubscribe(action_name: String, target: Object, method: String) -> void:
	if not _action_subscribers.has(action_name):
		return
	var subscribers = _action_subscribers[action_name]
	for i in range(subscribers.size() - 1, -1, -1):
		if subscribers[i].target == target and subscribers[i].method == StringName(method):
			subscribers.remove_at(i)


## --- Input Contexts ---

## Push an input context (e.g., "menu", "dialog", "game")
## Actions not in the context's allowlist are ignored
func push_context(context_name: String) -> void:
	_context_stack.append(context_name)
	_stats["context_switches"] += 1
	Logger.info("InputManager: Pushed context '%s' (stack: %s)" % [context_name, _context_stack], "Input")
	EventBus.emit("context_changed", {"context": context_name, "stack": _context_stack.duplicate()})


## Pop the current input context
func pop_context() -> String:
	if _context_stack.is_empty():
		return ""
	var context: String = _context_stack.pop_back()
	_stats["context_switches"] += 1
	Logger.info("InputManager: Popped context '%s' (stack: %s)" % [context, _context_stack], "Input")
	EventBus.emit("context_changed", {"context": "", "stack": _context_stack.duplicate()})
	return context


## Get current context
func get_current_context() -> String:
	if _context_stack.is_empty():
		return "default"
	return _context_stack[_context_stack.size() - 1]


## Set allowed actions for a context
func set_context_actions(context_name: String, allowed_actions: Array) -> void:
	_context_actions[context_name] = allowed_actions.duplicate()


## Get the context stack
func get_context_stack() -> Array:
	return _context_stack.duplicate()


## --- Global Input Control ---

## Enable/disable all input
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_pressed_keys.clear()
	Logger.info("InputManager: Input %s" % ["disabled", "enabled"][enabled], "Input")


## Check if input is enabled
func is_input_enabled() -> bool:
	return _input_enabled


## --- Mouse ---

## Get current mouse position
func get_mouse_position() -> Vector2:
	return _mouse_position


## Get mouse delta this frame
func get_mouse_delta() -> Vector2:
	return _mouse_delta


## Check if a mouse button is pressed
func is_mouse_button_pressed(button: int) -> bool:
	return _mouse_buttons.get(button, false)


## --- Rebinding ---

## Start listening for the next key press to rebind an action
## Returns the keycode, or -1 if cancelled
func listen_for_key() -> int:
	# Simple implementation: wait for next key press
	# In production, this would show a UI prompt
	Logger.info("InputManager: Listening for key press...", "Input")
	return -1  # Placeholder - requires UI integration


## --- Save/Load ---

## Export current bindings to a dictionary (for saving)
func export_bindings() -> Dictionary:
	var result := {}
	for action_name in _action_bindings:
		result[action_name] = _action_bindings[action_name].duplicate()
	return result


## Import bindings from a dictionary
func import_bindings(bindings: Dictionary) -> void:
	for action_name in bindings:
		_action_bindings[action_name] = bindings[action_name].duplicate()
	Logger.info("InputManager: Imported %d action bindings" % bindings.size(), "Input")


## Get statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Reset all bindings to defaults
func reset_to_defaults() -> void:
	_action_bindings.clear()
	_register_default_actions()
	Logger.info("InputManager: Reset to default bindings", "Input")


## --- Internal ---

func _check_action_bindings(keycode: int) -> void:
	for action_name in _action_bindings:
		if not _is_action_allowed(action_name):
			continue

		var keys: Array = _action_bindings[action_name]
		if keys.has(keycode):
			_stats["total_actions"] += 1

			# Notify subscribers
			if _action_subscribers.has(action_name):
				var data := {"action": action_name, "keycode": keycode}
				for sub in _action_subscribers[action_name]:
					if is_instance_valid(sub.target):
						sub.target.call(sub.method, data)

			# Emit global event
			EventBus.emit("action_pressed", {"action": action_name, "keycode": keycode})


func _is_action_allowed(action_name: String) -> bool:
	if _context_stack.is_empty():
		return true

	var current_context = _context_stack[_context_stack.size() - 1]
	if _context_actions.has(current_context):
		return _context_actions[current_context].has(action_name)

	return true  # No restrictions defined for this context


func _register_default_actions() -> void:
	# Default navigation actions (not game-specific)
	_action_bindings = {
		"ui_up": [KEY_W, KEY_UP],
		"ui_down": [KEY_S, KEY_DOWN],
		"ui_left": [KEY_A, KEY_LEFT],
		"ui_right": [KEY_D, KEY_RIGHT],
		"ui_accept": [KEY_SPACE, KEY_ENTER],
		"ui_cancel": [KEY_ESCAPE],
		"toggle_debug": [KEY_QUOTELEFT],  # ` key
		"pause": [KEY_P]
	}
