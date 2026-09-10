extends Node
## StorySystem - Manages story progression and dialogue triggers
## Follows GDD v2.0 Chapter 15: Tutorial and Story Mode
## M2.10 Tutorial & Story - Story System
##
## Manages story chapters, dialogue sequences, and progress saving.
## Integrates with DialogueSystem for actual dialogue display.

## DialogueSystem preload
const DialogueSystem = preload("res://scripts/game/DialogueSystem.gd")

## Story progress file path
const STORY_FILE := "user://story_progress.cfg"

## Story chapters definition
var _chapters: Dictionary = {
	"prologue": {
		"name": "序章：灵界的呼唤",
		"name_en": "Prologue: Call of the Aether",
		"description": "你被召唤到灵界，成为灵魂指挥官",
		"dialogue_file": "res://data/dialogue/prologue.json",
		"unlocked": true,
		"completed": false
	},
	"chapter1": {
		"name": "第一章：初遇灵魂",
		"name_en": "Chapter 1: First Soul",
		"description": "遇见你的第一个灵魂伙伴，学习基础战斗",
		"dialogue_file": "res://data/dialogue/chapter1.json",
		"unlocked": false,
		"completed": false
	},
	"chapter2": {
		"name": "第二章：竞技场之路",
		"name_en": "Chapter 2: Path to the Arena",
		"description": "进入竞技场，参与你的第一场正式战斗",
		"dialogue_file": "",
		"unlocked": false,
		"completed": false
	}
}

## Current active chapter
var _current_chapter: String = ""

## Current dialogue index
var _current_dialogue_index: int = 0

## Dialogue system instance
var _dialogue_system: DialogueSystem = null

## Story progress
var _story_progress: Dictionary = {
	"current_chapter": "prologue",
	"completed_chapters": [],
	"dialogue_progress": {}
}

## Signals
signal chapter_started(chapter_id)
signal chapter_completed(chapter_id)
signal dialogue_started(dialogue_id)
signal dialogue_completed(dialogue_id)
signal story_progress_changed


func _ready() -> void:
	# Initialize dialogue system
	_dialogue_system = DialogueSystem.new()
	add_child(_dialogue_system)

	# Load saved progress
	load_progress()

	GameLog.info("StorySystem: Ready, current chapter: %s" % _story_progress["current_chapter"], "Story")


## Start a chapter
func start_chapter(p_chapter_id: String) -> bool:
	if not _chapters.has(p_chapter_id):
		GameLog.warning("StorySystem: Chapter not found: %s" % p_chapter_id, "Story")
		return false

	var chapter = _chapters[p_chapter_id]
	if not chapter["unlocked"]:
		GameLog.warning("StorySystem: Chapter not unlocked: %s" % p_chapter_id, "Story")
		return false

	_current_chapter = p_chapter_id
	_current_dialogue_index = 0

	# Load dialogue file if available
	var dialogue_file = chapter["dialogue_file"]
	if dialogue_file != "" and ResourceLoader.exists(dialogue_file):
		_dialogue_system.load_dialogue_from_file(dialogue_file)

	chapter_started.emit(p_chapter_id)
	GameLog.info("StorySystem: Started chapter: %s" % p_chapter_id, "Story")
	return true


## Get current dialogue data
func get_current_dialogue() -> Dictionary:
	if _current_chapter == "":
		return {}

	var chapter = _chapters[_current_chapter]
	var dialogues = chapter.get("dialogues", [])

	if _current_dialogue_index < 0 or _current_dialogue_index >= dialogues.size():
		return {}

	return dialogues[_current_dialogue_index]


## Advance to next dialogue
func next_dialogue() -> void:
	if _current_chapter == "":
		return

	var chapter = _chapters[_current_chapter]
	var dialogues = chapter.get("dialogues", [])

	_current_dialogue_index += 1

	if _current_dialogue_index >= dialogues.size():
		# Chapter complete
		_complete_chapter(_current_chapter)
	else:
		dialogue_started.emit(_current_dialogue_index)


## Complete current chapter
func _complete_chapter(p_chapter_id: String) -> void:
	var chapter = _chapters[p_chapter_id]
	chapter["completed"] = true

	# Add to completed list
	if not _story_progress["completed_chapters"].has(p_chapter_id):
		_story_progress["completed_chapters"].append(p_chapter_id)

	# Unlock next chapter
	var chapter_order = ["prologue", "chapter1", "chapter2"]
	var current_index = chapter_order.find(p_chapter_id)
	if current_index >= 0 and current_index + 1 < chapter_order.size():
		var next_chapter = chapter_order[current_index + 1]
		if _chapters.has(next_chapter):
			_chapters[next_chapter]["unlocked"] = true
			_story_progress["current_chapter"] = next_chapter

	chapter_completed.emit(p_chapter_id)
	story_progress_changed.emit()
	save_progress()

	GameLog.info("StorySystem: Chapter completed: %s" % p_chapter_id, "Story")


## Get chapter list for UI
func get_chapter_list() -> Array:
	var result = []
	for chapter_id in ["prologue", "chapter1", "chapter2"]:
		var chapter = _chapters[chapter_id]
		result.append({
			"id": chapter_id,
			"name": chapter["name"],
			"name_en": chapter["name_en"],
			"description": chapter["description"],
			"unlocked": chapter["unlocked"],
			"completed": chapter["completed"]
		})
	return result


## Get chapter data
func get_chapter_data(p_chapter_id: String) -> Dictionary:
	return _chapters.get(p_chapter_id, {})


## Get story progress
func get_progress() -> Dictionary:
	return _story_progress.duplicate(true)


## Get overall completion percentage
func get_completion_percentage() -> float:
	var total = _chapters.size()
	var completed = _story_progress["completed_chapters"].size()
	if total == 0:
		return 0.0
	return float(completed) / float(total) * 100.0


## Check if prologue has been seen
func has_seen_prologue() -> bool:
	return _story_progress["completed_chapters"].has("prologue")


## Reset all story progress
func reset_progress() -> void:
	_story_progress = {
		"current_chapter": "prologue",
		"completed_chapters": [],
		"dialogue_progress": {}
	}
	for chapter_id in _chapters.keys():
		_chapters[chapter_id]["completed"] = false
		_chapters[chapter_id]["unlocked"] = (chapter_id == "prologue")
	save_progress()
	story_progress_changed.emit()
	GameLog.info("StorySystem: Progress reset", "Story")


## Save progress to file
func save_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("story", "current_chapter", _story_progress["current_chapter"])
	config.set_value("story", "completed_chapters", _story_progress["completed_chapters"])

	var err = config.save(STORY_FILE)
	if err != OK:
		GameLog.warning("StorySystem: Failed to save progress: %d" % err, "Story")


## Load progress from file
func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(STORY_FILE)
	if err != OK:
		GameLog.info("StorySystem: No saved progress found", "Story")
		return

	_story_progress["current_chapter"] = config.get_value("story", "current_chapter", "prologue")
	_story_progress["completed_chapters"] = config.get_value("story", "completed_chapters", [])

	# Update chapter states
	for chapter_id in _story_progress["completed_chapters"]:
		if _chapters.has(chapter_id):
			_chapters[chapter_id]["completed"] = true

	# Unlock chapters up to current
	var chapter_order = ["prologue", "chapter1", "chapter2"]
	var current_index = chapter_order.find(_story_progress["current_chapter"])
	for i in range(current_index + 1):
		if i < chapter_order.size() and _chapters.has(chapter_order[i]):
			_chapters[chapter_order[i]]["unlocked"] = true

	GameLog.info("StorySystem: Progress loaded, completed: %d chapters" % _story_progress["completed_chapters"].size(), "Story")
