extends Node
## DialogueSystem - Manages dialogue conversations for tutorials and story
## Follows GDD v2.0 Chapter 10: Tutorial and Story
## M2.10 Tutorial & Story - Dialogue System
##
## Handles dialogue data loading, conversation flow, text display, and choices.
## Used by tutorial levels and story sequences.

## Dialogue line structure
## {
##   "id": "line_id",
##   "speaker": "speaker_name",
##   "speaker_portrait": "element_name",  # optional
##   "text": "dialogue text",
##   "choices": [  # optional, if present, player must choose
##     {"text": "choice text", "next": "next_line_id"}
##   ],
##   "next": "next_line_id",  # optional, auto-advance if no choices
##   "event": "event_name"  # optional, emitted when line shown
## }

## Current dialogue lines
var _dialogue_lines: Dictionary = {}

## Current line ID
var _current_line_id: String = ""

## Dialogue active state
var _dialogue_active: bool = false

## Text display state
var _text_displayed: bool = false
var _text_progress: int = 0
var _text_speed: float = 0.03  # seconds per character
var _text_timer: float = 0.0

## Full text of current line
var _current_full_text: String = ""

## Signal emitted when dialogue starts
signal dialogue_started(dialogue_id)

## Signal emitted when dialogue ends
signal dialogue_ended(dialogue_id)

## Signal emitted when a new line is shown
signal line_shown(line_id, speaker, text)

## Signal emitted when text is fully displayed
signal text_complete(line_id)

## Signal emitted when a choice is made
signal choice_made(choice_index, choice_text)

## Signal emitted when a dialogue event is triggered
signal dialogue_event(event_name)


func _process(delta: float) -> void:
	if _dialogue_active and not _text_displayed:
		_text_timer += delta
		if _text_timer >= _text_speed:
			_text_timer = 0.0
			_text_progress += 1
			if _text_progress >= _current_full_text.length():
				_text_displayed = true
				text_complete.emit(_current_line_id)


## Start a dialogue from a dictionary of lines
func start_dialogue(lines: Dictionary, start_line_id: String = "") -> bool:
	if lines.is_empty():
		return false
	_dialogue_lines = lines.duplicate(true)
	_dialogue_active = true
	# Find start line
	if start_line_id != "" and lines.has(start_line_id):
		_current_line_id = start_line_id
	else:
		# Use first line
		_current_line_id = lines.keys()[0]
	_show_line(_current_line_id)
	dialogue_started.emit(_current_line_id)
	return true


## Show a specific line
func _show_line(line_id: String) -> void:
	if not _dialogue_lines.has(line_id):
		_end_dialogue()
		return
	var line = _dialogue_lines[line_id]
	_current_line_id = line_id
	_current_full_text = line.get("text", "")
	_text_progress = 0
	_text_displayed = false
	_text_timer = 0.0
	var speaker = line.get("speaker", "")
	line_shown.emit(line_id, speaker, _current_full_text)
	# Emit event if present
	if line.has("event"):
		dialogue_event.emit(line["event"])


## Advance to next line (or skip text animation)
func advance() -> void:
	if not _dialogue_active:
		return
	# If text not fully displayed, skip animation
	if not _text_displayed:
		_text_progress = _current_full_text.length()
		_text_displayed = true
		text_complete.emit(_current_line_id)
		return
	# Get current line
	var line = _dialogue_lines.get(_current_line_id, null)
	if line == null:
		_end_dialogue()
		return
	# If line has choices, don't auto-advance
	if line.has("choices") and line["choices"].size() > 0:
		return
	# Advance to next line
	if line.has("next") and line["next"] != "":
		_show_line(line["next"])
	else:
		_end_dialogue()


## Make a choice
func make_choice(choice_index: int) -> void:
	if not _dialogue_active:
		return
	var line = _dialogue_lines.get(_current_line_id, null)
	if line == null or not line.has("choices"):
		return
	if choice_index < 0 or choice_index >= line["choices"].size():
		return
	var choice = line["choices"][choice_index]
	choice_made.emit(choice_index, choice.get("text", ""))
	# Advance to next line
	if choice.has("next") and choice["next"] != "":
		_show_line(choice["next"])
	else:
		_end_dialogue()


## End current dialogue
func _end_dialogue() -> void:
	_dialogue_active = false
	_current_line_id = ""
	_current_full_text = ""
	_text_displayed = false
	_text_progress = 0
	dialogue_ended.emit("")


## Get current displayed text (may be partial during animation)
func get_displayed_text() -> String:
	if not _dialogue_active:
		return ""
	return _current_full_text.substr(0, _text_progress)


## Get full text of current line
func get_full_text() -> String:
	return _current_full_text


## Get current speaker
func get_speaker() -> String:
	if not _dialogue_active:
		return ""
	var line = _dialogue_lines.get(_current_line_id, null)
	if line == null:
		return ""
	return line.get("speaker", "")


## Get current speaker portrait element
func get_speaker_portrait() -> String:
	if not _dialogue_active:
		return ""
	var line = _dialogue_lines.get(_current_line_id, null)
	if line == null:
		return ""
	return line.get("speaker_portrait", "")


## Get current choices
func get_choices() -> Array:
	if not _dialogue_active or not _text_displayed:
		return []
	var line = _dialogue_lines.get(_current_line_id, null)
	if line == null or not line.has("choices"):
		return []
	return line["choices"]


## Is dialogue active
func is_dialogue_active() -> bool:
	return _dialogue_active


## Is text fully displayed
func is_text_complete() -> bool:
	return _text_displayed


## Set text speed (characters per second)
func set_text_speed(speed: float) -> void:
	if speed > 0:
		_text_speed = 1.0 / speed


## Get current line ID
func get_current_line_id() -> String:
	return _current_line_id


## Load dialogue from JSON file
func load_dialogue_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		GameLog.error("DialogueSystem: File not found: %s" % path, "Dialogue")
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		GameLog.error("DialogueSystem: Cannot open file: %s" % path, "Dialogue")
		return {}
	var json_string = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(json_string)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		GameLog.error("DialogueSystem: Invalid JSON in file: %s" % path, "Dialogue")
		return {}
	return parsed


## Create a simple linear dialogue (convenience function)
func create_linear_dialogue(speaker: String, texts: Array) -> Dictionary:
	var lines = {}
	for i in range(texts.size()):
		var line_id = "line_%d" % i
		var line = {
			"id": line_id,
			"speaker": speaker,
			"text": texts[i]
		}
		if i < texts.size() - 1:
			line["next"] = "line_%d" % (i + 1)
		lines[line_id] = line
	return lines


## Reset (for testing)
func reset() -> void:
	_dialogue_lines = {}
	_current_line_id = ""
	_dialogue_active = false
	_text_displayed = false
	_text_progress = 0
	_current_full_text = ""
