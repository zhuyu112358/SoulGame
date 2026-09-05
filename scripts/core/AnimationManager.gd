extends Node
## AnimationManager - Centralized animation and tween management
##
## Manages tweens, animation players, fade transitions, and sequenced
## animations. Provides convenience methods for common UI animations.
## Infrastructure only - no game-specific animations.
##
## Usage:
##   AnimationManager.fade_in(node, 0.5)
##   AnimationManager.fade_out(node, 0.5)
##   var tween = AnimationManager.create_tween()
##   AnimationManager.animate_property(node, "position", target, 1.0, "elastic_out")

## Active tweens: { id: Tween }
var _active_tweens: Dictionary = {}

## Next tween ID
var _next_tween_id: int = 1

## Animation players registry: { name: AnimationPlayer }
var _animation_players: Dictionary = {}

## Easing function map
var _easing_map: Dictionary = {
	"linear": Tween.EASE_IN,
	"ease_in": Tween.EASE_IN,
	"ease_out": Tween.EASE_OUT,
	"ease_in_out": Tween.EASE_IN_OUT,
	"elastic_out": Tween.EASE_OUT,
	"bounce_out": Tween.EASE_OUT,
	"back_out": Tween.EASE_OUT
}

## Transition type map
var _trans_map: Dictionary = {
	"linear": Tween.TRANS_LINEAR,
	"sine": Tween.TRANS_SINE,
	"quad": Tween.TRANS_QUAD,
	"cubic": Tween.TRANS_CUBIC,
	"quart": Tween.TRANS_QUART,
	"quint": Tween.TRANS_QUINT,
	"elastic": Tween.TRANS_ELASTIC,
	"bounce": Tween.TRANS_BOUNCE,
	"back": Tween.TRANS_BACK,
	"circ": Tween.TRANS_CIRC,
	"expo": Tween.TRANS_EXPO
}

## Statistics
var _stats: Dictionary = {
	"tweens_created": 0,
	"tweens_completed": 0,
	"animations_played": 0,
	"active_tweens": 0
}


func _ready() -> void:
	Logger.info("AnimationManager initialized", "Anim")


## --- Tween Management ---

## Create a new tween with default settings
func create_tween(parallel: bool = false) -> Tween:
	var tween := create_tween()
	tween.set_parallel(parallel)

	var id := _next_tween_id
	_next_tween_id += 1
	_active_tweens[id] = tween
	_stats["tweens_created"] += 1
	_stats["active_tweens"] = _active_tweens.size()

	tween.finished.connect(_on_tween_finished.bind(id))
	return tween


## Animate a property to a target value
## easing: "linear", "ease_in", "ease_out", "ease_in_out", "elastic_out", "bounce_out"
## transition: "linear", "sine", "quad", "cubic", "quart", "quint", "elastic", "bounce", "back"
func animate_property(target: Object, property: String, final_value: Variant, duration: float, transition: String = "sine", easing: String = "ease_out") -> Tween:
	var tween := create_tween()
	var trans_type := _trans_map.get(transition, Tween.TRANS_SINE)
	var ease_type := _easing_map.get(easing, Tween.EASE_OUT)

	tween.tween_property(target, property, final_value, duration).set_trans(trans_type).set_ease(ease_type)
	return tween


## Animate position (convenience)
func animate_position(node: Node2D, target_pos: Vector2, duration: float, transition: String = "sine") -> Tween:
	return animate_property(node, "position", target_pos, duration, transition)


## Animate scale (convenience)
func animate_scale(node: Node2D, target_scale: Vector2, duration: float, transition: String = "sine") -> Tween:
	return animate_property(node, "scale", target_scale, duration, transition)


## Animate rotation (convenience)
func animate_rotation(node: Node2D, target_rotation: float, duration: float, transition: String = "sine") -> Tween:
	return animate_property(node, "rotation", target_rotation, duration, transition)


## Animate modulate/alpha (convenience)
func animate_modulate(node: CanvasItem, target_modulate: Color, duration: float, transition: String = "sine") -> Tween:
	return animate_property(node, "modulate", target_modulate, duration, transition)


## --- Fade Animations ---

## Fade in a node (alpha 0 -> 1)
func fade_in(node: CanvasItem, duration: float = 0.3, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	node.visible = true
	var tween := create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## Fade out a node (alpha 1 -> 0)
func fade_out(node: CanvasItem, duration: float = 0.3, hide_on_complete: bool = true) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if hide_on_complete:
		tween.tween_callback(node.set_visible.bind(false))
	return tween


## Fade to a specific alpha
func fade_to(node: CanvasItem, alpha: float, duration: float = 0.3) -> Tween:
	return animate_property(node, "modulate:a", alpha, duration, "sine", "ease_out")


## --- UI Animations ---

## Pop in animation (scale 0 -> 1 with bounce)
func pop_in(node: Node2D, duration: float = 0.4) -> Tween:
	node.scale = Vector2.ZERO
	node.visible = true
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## Pop out animation (scale 1 -> 0)
func pop_out(node: Node2D, duration: float = 0.3) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.set_visible.bind(false))
	return tween


## Slide in from a direction
## direction: "left", "right", "top", "bottom"
func slide_in(node: Control, direction: String = "left", duration: float = 0.4, distance: float = 100.0) -> Tween:
	var original_pos := node.position
	var offset := Vector2.ZERO
	match direction:
		"left": offset = Vector2(-distance, 0)
		"right": offset = Vector2(distance, 0)
		"top": offset = Vector2(0, -distance)
		"bottom": offset = Vector2(0, distance)

	node.position = original_pos + offset
	node.visible = true
	var tween := create_tween()
	tween.tween_property(node, "position", original_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


## Shake animation (for impact feedback)
func shake(node: Node2D, intensity: float = 10.0, duration: float = 0.3) -> Tween:
	var original_pos := node.position
	var tween := create_tween()
	tween.set_parallel(true)

	var steps := 6
	for i in range(steps):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		var step_duration := duration / steps
		tween.tween_property(node, "position", original_pos + offset, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(node, "position", original_pos, duration / steps).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## Pulse animation (scale up and down)
func pulse(node: Node2D, scale_amount: float = 1.1, duration: float = 0.5) -> Tween:
	var original_scale := node.scale
	var tween := create_tween()
	tween.tween_property(node, "scale", original_scale * scale_amount, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", original_scale, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tween


## --- Animation Player Management ---

## Register an animation player
func register_animation_player(name: String, player: AnimationPlayer) -> void:
	_animation_players[name] = player
	Logger.debug("AnimationManager: Registered player '%s'" % name, "Anim")


## Play an animation on a registered player
func play_animation(player_name: String, animation_name: String, custom_blend: float = -1.0, custom_speed: float = 1.0, from_end: bool = false) -> bool:
	if not _animation_players.has(player_name):
		Logger.warning("AnimationManager: Player not found: %s" % player_name, "Anim")
		return false

	var player: AnimationPlayer = _animation_players[player_name]
	if not player.has_animation(animation_name):
		Logger.warning("AnimationManager: Animation not found: %s/%s" % [player_name, animation_name], "Anim")
		return false

	player.play(animation_name, custom_blend, custom_speed, from_end)
	_stats["animations_played"] += 1
	return true


## Stop all animations on a player
func stop_animation(player_name: String) -> void:
	if _animation_players.has(player_name):
		_animation_players[player_name].stop()


## Check if an animation is playing
func is_playing(player_name: String) -> bool:
	if _animation_players.has(player_name):
		return _animation_players[player_name].is_playing()
	return false


## --- Sequence Management ---

## Run animations in sequence with callbacks
func run_sequence(animations: Array, on_complete_target: Object = null, on_complete_method: String = "") -> void:
	# animations: [{target, property, final_value, duration, transition}, ...]
	if animations.is_empty():
		return

	var tween := create_tween()
	for anim in animations:
		var target: Object = anim["target"]
		var property: String = anim["property"]
		var final_value = anim["final_value"]
		var duration: float = anim.get("duration", 0.3)
		var transition: String = anim.get("transition", "sine")
		var trans_type := _trans_map.get(transition, Tween.TRANS_SINE)
		tween.tween_property(target, property, final_value, duration).set_trans(trans_type).set_ease(Tween.EASE_OUT)

	if on_complete_target and is_instance_valid(on_complete_target) and not on_complete_method.is_empty():
		tween.tween_callback(on_complete_target.call.bind(on_complete_method))


## --- Cleanup ---

## Kill all active tweens
func kill_all_tweens() -> void:
	for id in _active_tweens:
		var tween: Tween = _active_tweens[id]
		if is_instance_valid(tween):
			tween.kill()
	_active_tweens.clear()
	_stats["active_tweens"] = 0
	Logger.info("AnimationManager: Killed all tweens", "Anim")


## Get statistics
func get_stats() -> Dictionary:
	_stats["active_tweens"] = _active_tweens.size()
	return _stats.duplicate()


## --- Internal ---

func _on_tween_finished(tween_id: int) -> void:
	_active_tweens.erase(tween_id)
	_stats["tweens_completed"] += 1
	_stats["active_tweens"] = _active_tweens.size()
