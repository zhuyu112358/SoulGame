extends Node
## SceneManager - Scene switching, loading, and transition management
##
## Handles scene lifecycle with fade transitions, loading screens,
## and scene stack management.
##
## Usage:
##   SceneManager.change_scene("res://scenes/main.tscn")
##   SceneManager.push_scene("res://scenes/settings.tscn")
##   SceneManager.pop_scene()

## Current scene path
var _current_scene: String = ""

## Previous scene path
var _previous_scene: String = ""

## Total scene changes
var _scene_change_count: int = 0

## Scene stack for push/pop navigation
var _scene_stack: Array = []

## Whether a scene transition is in progress
var _transitioning: bool = false

## Transition duration in seconds
var _transition_duration: float = 0.3

## Loading scene path (shown during heavy scene loads)
var _loading_scene: String = "res://scenes/loading.tscn"

## Whether to use loading screen for scene changes
var _use_loading_screen: bool = false

## Registered scene aliases: { alias: path }
var _scene_aliases: Dictionary = {}

## Scene cache: { path: PackedScene }
var _scene_cache: Dictionary = {}

## Maximum cached scenes
var _max_cache_size: int = 10


func _ready() -> void:
	_register_default_aliases()
	GameLog.info("SceneManager initialized", "Scene")


## Register a scene alias for convenient referencing
func register_alias(alias: String, scene_path: String) -> void:
	_scene_aliases[alias] = scene_path


## Change to a new scene (replaces current)
func change_scene(scene_path: String, use_transition: bool = true) -> void:
	if _transitioning:
		GameLog.warning("SceneManager: Already transitioning, ignoring", "Scene")
		return

	var resolved_path := _resolve_path(scene_path)
	if resolved_path.is_empty():
		GameLog.error("SceneManager: Unknown scene: %s" % scene_path, "Scene")
		return

	_transitioning = true
	GameState.set_value("game", "current_scene", resolved_path)

	if use_transition:
		_play_transition(resolved_path, false)
	else:
		_change_scene_immediate(resolved_path)


## Push a scene onto the stack (current scene stays loaded)
func push_scene(scene_path: String) -> void:
	var resolved_path := _resolve_path(scene_path)
	if resolved_path.is_empty():
		GameLog.error("SceneManager: Unknown scene: %s" % scene_path, "Scene")
		return

	_scene_stack.append(_current_scene)
	change_scene(resolved_path, true)


## Pop back to previous scene in stack
func pop_scene() -> void:
	if _scene_stack.is_empty():
		GameLog.warning("SceneManager: Scene stack is empty", "Scene")
		return

	var previous_scene: String = _scene_stack.pop_back()
	change_scene(previous_scene, true)


## Get current scene path
func get_current_scene() -> String:
	return _current_scene


## Get scene stack depth
func get_stack_depth() -> int:
	return _scene_stack.size()


## Preload a scene into cache
func preload_scene(scene_path: String) -> bool:
	var resolved_path := _resolve_path(scene_path)
	if resolved_path.is_empty():
		return false

	if _scene_cache.has(resolved_path):
		return true

	var packed_scene: PackedScene = load(resolved_path)
	if packed_scene == null:
		GameLog.error("SceneManager: Failed to load scene: %s" % resolved_path, "Scene")
		return false

	_scene_cache[resolved_path] = packed_scene
	_trim_cache()
	GameLog.debug("SceneManager: Cached scene: %s" % resolved_path, "Scene")
	return true


## Clear scene cache
func clear_cache() -> void:
	_scene_cache.clear()


## Reload current scene
func reload_current_scene() -> void:
	if not _current_scene.is_empty():
		change_scene(_current_scene, false)


func _change_scene_immediate(scene_path: String) -> void:
	var packed_scene := _get_cached_or_load(scene_path)
	if packed_scene == null:
		_transitioning = false
		return

	get_tree().change_scene_to_packed(packed_scene)
	_previous_scene = _current_scene
	_current_scene = scene_path
	_scene_change_count += 1
	_transitioning = false
	EventBus.emit("scene_changed", {"scene": scene_path, "previous": _previous_scene})
	GameLog.info("SceneManager: Changed to %s" % scene_path, "Scene")


func _play_transition(scene_path: String, is_push: bool) -> void:
	# Simple fade transition using a ColorRect overlay
	var transition_layer := ColorRect.new()
	transition_layer.color = Color.BLACK
	transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.z_index = 1000
	transition_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(transition_layer)

	# Fade out
	var tween := create_tween()
	tween.tween_property(transition_layer, "modulate:a", 1.0, _transition_duration)
	tween.tween_callback(_change_scene_immediate.bind(scene_path))
	tween.tween_property(transition_layer, "modulate:a", 0.0, _transition_duration)
	tween.tween_callback(transition_layer.queue_free)
	tween.tween_callback(func(): _transitioning = false)


func _get_cached_or_load(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path]

	var packed_scene: PackedScene = load(scene_path)
	if packed_scene:
		_scene_cache[scene_path] = packed_scene
		_trim_cache()
	return packed_scene


func _resolve_path(scene_path: String) -> String:
	if _scene_aliases.has(scene_path):
		return _scene_aliases[scene_path]
	if ResourceLoader.exists(scene_path):
		return scene_path
	return ""


func _trim_cache() -> void:
	while _scene_cache.size() > _max_cache_size:
		var oldest_key = _scene_cache.keys()[0]
		_scene_cache.erase(oldest_key)


func _register_default_aliases() -> void:
	_scene_aliases = {
		"main": "res://scenes/main.tscn",
		"loading": "res://scenes/loading.tscn",
		"bootstrap": "res://scenes/bootstrap.tscn"
	}


## Get scene manager statistics
func get_stats() -> Dictionary:
	return {
		"current_scene": _current_scene,
		"previous_scene": _previous_scene,
		"cached_scenes": _scene_cache.size(),
		"max_cache_size": _max_cache_size,
		"registered_aliases": _scene_aliases.size(),
		"transitioning": _transitioning,
		"transition_duration": _transition_duration,
		"scene_changes": _scene_change_count
	}
