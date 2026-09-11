extends Node2D

## SoulGrowthData preload (class_name may not be registered in all contexts)
const SoulGrowthData = preload("res://scripts/game/SoulGrowthData.gd")
const FurnitureSystem = preload("res://scripts/game/FurnitureSystem.gd")
const TrainingSystem = preload("res://scripts/game/TrainingSystem.gd")
const SoulDailyBehaviorAI = preload("res://scripts/game/SoulDailyBehaviorAI.gd")

## SoulHomeController - Controller for the Soul Home scene
##
## Manages the soul home environment, soul display, room switching,
## and basic interactions. M2.8 upgrade: 8 rooms + furniture customization.
##
## Rooms (M2.8 - 8 areas):
## - main: Main hall, daily interaction
## - bedroom: Rest and sleep
## - living: Relaxation and social
## - kitchen: Cooking and eating
## - study: Learning and cognitive training
## - training: Combat training
## - garden: Emotional interaction and nature
## - bathroom: Cleaning and relaxation

## Current room
var current_room: String = "main"

## Available rooms (M2.8 - 8 areas, GDD v2.0 Chapter 8)
var rooms: Dictionary = {
	"main": {"name": "主厅", "unlocked": true, "icon_index": 0, "description": "灵魂之家的中心，日常互动和交流"},
	"bedroom": {"name": "卧室", "unlocked": true, "icon_index": 1, "description": "休息和睡眠的私密空间"},
	"living": {"name": "客厅", "unlocked": true, "icon_index": 2, "description": "放松和社交的舒适空间"},
	"kitchen": {"name": "厨房", "unlocked": true, "icon_index": 3, "description": "烹饪和享用灵魂食物"},
	"study": {"name": "书房", "unlocked": true, "icon_index": 4, "description": "学习和认知训练的场所"},
	"training": {"name": "训练场", "unlocked": true, "icon_index": 5, "description": "战斗技能训练场地"},
	"garden": {"name": "花园", "unlocked": true, "icon_index": 6, "description": "情感互动和自然疗愈"},
	"bathroom": {"name": "浴室", "unlocked": true, "icon_index": 7, "description": "清洁和放松的空间"}
}

## Soul growth data reference
var soul_growth: Resource = null

## Soul display node (placeholder for M1)
var soul_display: Node2D = null

## Current soul element for portrait and glow color
var _current_soul_element: String = "fire"

## Soul world ID for SoulArena API
var soul_world_id: String = ""

## Soul ID for SoulArena API
var soul_id: String = ""

## Whether soul is currently in world
var soul_in_world: bool = false

## Interaction cooldown (prevent spam)
var _interaction_cooldown: float = 0.0

## Room switch cooldown
var _room_switch_cooldown: float = 0.0

## Soul home state
var home_state: Dictionary = {
	"entered": false,
	"visit_count": 0,
	"total_time": 0.0
}

## Furniture system (M2.8 - furniture customization)
var _furniture_system = null

## Training system (M2.8 - training ground)
var _training_system = null

## Daily behavior AI (M2.8 - soul autonomous behavior)
var _daily_behavior_ai = null


func _ready() -> void:
	GameLog.info("SoulHome: Scene initialized", "SoulHome")
	_setup_soul_display()
	_setup_ui_styles()
	_setup_button_hovers()
	_init_furniture_system()
	_init_training_system()
	_init_daily_behavior_ai()
	_enter_home()
	_play_home_ambience()


## Apply game-level UI styles to all panels and buttons
func _setup_ui_styles() -> void:
	# Panel style: dark purple bg + gold border + rounded corners
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.92)
	panel_style.border_color = Color(0.83, 0.66, 0.36, 0.7)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8

	# Apply to all panels
	var panel_paths = ["StatusPanel", "GrowthPanel", "InteractionPanel", "ChatPanel"]
	for path in panel_paths:
		var panel = get_node_or_null(path)
		if panel and panel is Panel:
			panel.add_theme_stylebox_override("panel", panel_style)

	# Button normal style
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.08, 0.22, 0.95)
	btn_normal.border_color = Color(0.7, 0.55, 0.3, 0.8)
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6

	# Button hover style (brighter)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.18, 0.12, 0.3, 0.98)
	btn_hover.border_color = Color(0.95, 0.78, 0.45, 1.0)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6

	# Button pressed style (darker)
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

	# Apply button styles to all buttons
	var button_paths = [
		"InteractionPanel/ChatButton", "InteractionPanel/PetButton",
		"InteractionPanel/FeedButton", "InteractionPanel/PlayButton",
		"InteractionPanel/TrainButton", "ChatPanel/ChatSend",
		"ChatPanel/ChatClose", "BackButton", "BattleButton"
	]
	for path in button_paths:
		var btn = get_node_or_null(path)
		if btn and btn is Button:
			btn.add_theme_stylebox_override("normal", btn_normal)
			btn.add_theme_stylebox_override("hover", btn_hover)
			btn.add_theme_stylebox_override("pressed", btn_pressed)
			# Gold text color
			btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))

	# Title labels: gold color, larger font
	var title_paths = ["StatusPanel/StatusTitle", "GrowthPanel/GrowthTitle", "RoomLabel", "SoulDisplayArea/SoulNameLabel"]
	for path in title_paths:
		var label = get_node_or_null(path)
		if label and label is Label:
			label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
			label.add_theme_font_size_override("font_size", 18)

	# Body labels: gray-white color
	var body_paths = ["StatusPanel/StatusLabel", "GrowthPanel/GrowthLabel", "EventLog"]
	for path in body_paths:
		var label = get_node_or_null(path)
		if label and label is Label:
			label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))

	GameLog.info("SoulHome: Game-level UI styles applied", "SoulHome")


## Setup hover effects for all buttons in the scene
func _setup_button_hovers() -> void:
	var button_paths = [
		"InteractionPanel/ChatButton",
		"InteractionPanel/PetButton",
		"InteractionPanel/FeedButton",
		"InteractionPanel/PlayButton",
		"InteractionPanel/TrainButton",
		"ChatPanel/ChatSend",
		"ChatPanel/ChatClose",
		"BackButton",
		"BattleButton"
	]
	for path in button_paths:
		var btn = get_node_or_null(path)
		if btn and btn is Button:
			_setup_button_hover(btn)


## Setup button hover effects (audio + visual)
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


## Play hover sound and visual feedback (scale + gold glow)
func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	if p_button.has_meta("hover_tween"):
		var old_tween = p_button.get_meta("hover_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(p_button, "scale", Vector2(1.06, 1.06), 0.15)
	tween.parallel().tween_property(p_button, "modulate", Color(1.25, 1.1, 0.75), 0.15)
	p_button.set_meta("hover_tween", tween)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	if p_button.has_meta("hover_tween"):
		var old_tween = p_button.get_meta("hover_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(p_button, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	p_button.set_meta("hover_tween", tween)


## Play button hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")


## Play home background music and ambient sounds
func _play_home_ambience() -> void:
	if AudioManager:
		AudioManager.play_bgm("soul_home_day")
		# Play home indoor environment ambience
		AudioManager.play_sfx("env_soul_home")
		# Play soul home interaction ambience (design task round 25)
		AudioManager.play_sfx("soul_home_ambience")
		GameLog.info("SoulHome: Playing home BGM", "SoulHome")


## --- Furniture System (M2.8) ---

## Initialize furniture system
func _init_furniture_system() -> void:
	_furniture_system = FurnitureSystem.new()
	_furniture_system.name = "FurnitureSystem"
	add_child(_furniture_system)
	_furniture_system.furniture_placed.connect(_on_furniture_placed)
	_furniture_system.furniture_removed.connect(_on_furniture_removed)
	GameLog.info("SoulHome: Furniture system initialized", "SoulHome")


## Place furniture in current room
func place_furniture(furniture_id: String, position: Vector2) -> bool:
	if _furniture_system == null:
		return false
	var result = _furniture_system.place_furniture(furniture_id, current_room, position)
	if result:
		_spawn_furniture_sprite(furniture_id, position)
	return result


## Remove furniture from current room
func remove_furniture(furniture_id: String) -> bool:
	if _furniture_system == null:
		return false
	return _furniture_system.remove_furniture(furniture_id, current_room)


## Get placed furniture in current room
func get_placed_furniture() -> Array:
	if _furniture_system == null:
		return []
	return _furniture_system.get_placed_furniture(current_room)


## Get furniture system
func get_furniture_system() -> Node:
	return _furniture_system


## Spawn furniture sprite in the scene
func _spawn_furniture_sprite(furniture_id: String, position: Vector2) -> void:
	var furniture = _furniture_system.get_furniture(furniture_id) if _furniture_system else {}
	if furniture.is_empty():
		return
	# Try to load furniture sprite
	var sprite_path = "res://assets/art/furniture/furniture_%s.png" % furniture_id
	var texture = load(sprite_path)
	if texture == null:
		# Fallback: use colored rectangle
		var rect := ColorRect.new()
		rect.size = Vector2(64, 64)
		rect.color = Color(0.6, 0.5, 0.3, 0.8)
		rect.position = position - Vector2(32, 32)
		rect.name = "Furniture_%s" % furniture_id
		add_child(rect)
	else:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = position
		sprite.name = "Furniture_%s" % furniture_id
		sprite.scale = Vector2(0.5, 0.5)
		add_child(sprite)


## Handle furniture placed
func _on_furniture_placed(furniture_id: String, room: String, position: Vector2) -> void:
	var furniture = _furniture_system.get_furniture(furniture_id) if _furniture_system else {}
	var furniture_name = furniture.get("name", furniture_id)
	GameLog.info("SoulHome: Placed %s in %s" % [furniture_name, room], "SoulHome")


## Handle furniture removed
func _on_furniture_removed(furniture_id: String, room: String) -> void:
	GameLog.info("SoulHome: Removed %s from %s" % [furniture_id, room], "SoulHome")
	# Remove furniture sprite from scene
	var furniture_node = get_node_or_null("Furniture_%s" % furniture_id)
	if furniture_node:
		furniture_node.queue_free()


## --- Training System (M2.8) ---

## Initialize training system
func _init_training_system() -> void:
	_training_system = TrainingSystem.new()
	_training_system.name = "TrainingSystem"
	add_child(_training_system)
	_training_system.training_started.connect(_on_training_started)
	_training_system.training_completed.connect(_on_training_completed)
	GameLog.info("SoulHome: Training system initialized", "SoulHome")


## Start a training session
func start_training(training_type: String) -> bool:
	if _training_system == null:
		return false
	if current_room != "training":
		GameLog.warning("SoulHome: Must be in training room to train", "SoulHome")
		return false
	return _training_system.start_training(training_type)


## Cancel current training
func cancel_training() -> void:
	if _training_system:
		_training_system.cancel_training()


## Get current training type
func get_current_training() -> String:
	if _training_system == null:
		return ""
	return _training_system.get_current_training()


## Get training progress (0.0 - 1.0)
func get_training_progress() -> float:
	if _training_system == null:
		return 0.0
	return _training_system.get_training_progress()


## Get time remaining for current training
func get_training_time_remaining() -> float:
	if _training_system == null:
		return 0.0
	return _training_system.get_time_remaining()


## Is training active
func is_training_active() -> bool:
	if _training_system == null:
		return false
	return _training_system.is_training_active()


## Get training system
func get_training_system() -> Node:
	return _training_system


## Handle training started
func _on_training_started(training_type: String) -> void:
	var training = _training_system.get_training_type(training_type) if _training_system else {}
	var training_name = training.get("name", training_type)
	GameLog.info("SoulHome: Started %s" % training_name, "SoulHome")
	if AudioManager:
		AudioManager.play_sfx("training_start")


## Handle training completed
func _on_training_completed(training_type: String, rewards: Dictionary) -> void:
	var training = _training_system.get_training_type(training_type) if _training_system else {}
	var training_name = training.get("name", training_type)
	var exp = rewards.get("exp", 0)
	GameLog.info("SoulHome: Completed %s (+%d exp)" % [training_name, exp], "SoulHome")
	# Show training completion notification
	if AudioManager:
		AudioManager.play_sfx("training_complete")
	# Apply stat bonuses to soul growth if available
	if soul_growth:
		var stat_boost = rewards.get("stat_boost", {})
		for stat in stat_boost.keys():
			GameLog.info("SoulHome: +%.2f %s from training" % [stat_boost[stat], stat], "SoulHome")


## --- Daily Behavior AI (M2.8) ---

## Initialize daily behavior AI
func _init_daily_behavior_ai() -> void:
	_daily_behavior_ai = SoulDailyBehaviorAI.new()
	_daily_behavior_ai.name = "DailyBehaviorAI"
	add_child(_daily_behavior_ai)
	_daily_behavior_ai.behavior_changed.connect(_on_behavior_changed)
	_daily_behavior_ai.behavior_completed.connect(_on_behavior_completed)
	_daily_behavior_ai.set_room(current_room)
	GameLog.info("SoulHome: Daily behavior AI initialized", "SoulHome")


## Get current soul behavior
func get_soul_behavior() -> String:
	if _daily_behavior_ai == null:
		return "idle"
	return _daily_behavior_ai.get_current_behavior_name()


## Get soul needs
func get_soul_needs() -> Dictionary:
	if _daily_behavior_ai == null:
		return {}
	return _daily_behavior_ai.get_needs()


## Force soul to do a specific behavior
func force_soul_behavior(behavior_name: String) -> bool:
	if _daily_behavior_ai == null:
		return false
	# Map behavior name to enum
	var behavior_map = {
		"idle": 0,
		"sleeping": 1,
		"eating": 2,
		"reading": 3,
		"training": 4,
		"playing": 5,
		"meditating": 6,
		"walking": 7,
		"interacting": 8
	}
	if not behavior_map.has(behavior_name):
		return false
	return _daily_behavior_ai.force_behavior(behavior_map[behavior_name])


## Handle behavior changed
func _on_behavior_changed(old_behavior: int, new_behavior: int) -> void:
	var behavior_names = ["发呆", "睡觉", "进食", "阅读", "训练", "玩耍", "冥想", "漫步", "互动"]
	var new_name = behavior_names[new_behavior] if new_behavior < behavior_names.size() else "未知"
	GameLog.debug("SoulHome: Soul is now %s" % new_name, "SoulHome")
	# Update soul display animation based on behavior
	_update_soul_behavior_display(new_behavior)


## Handle behavior completed
func _on_behavior_completed(behavior: int, rewards: Dictionary) -> void:
	var behavior_names = ["发呆", "睡觉", "进食", "阅读", "训练", "玩耍", "冥想", "漫步", "互动"]
	var behavior_name = behavior_names[behavior] if behavior < behavior_names.size() else "未知"
	var exp = rewards.get("exp", 0)
	if exp > 0:
		GameLog.info("SoulHome: Soul finished %s (+%d exp)" % [behavior_name, exp], "SoulHome")


## Update soul display based on behavior
func _update_soul_behavior_display(behavior: int) -> void:
	if soul_display == null:
		return
	# Animate soul based on behavior
	var tween = create_tween()
	match behavior:
		1:  # SLEEPING
			tween.tween_property(soul_display, "modulate", Color(0.7, 0.7, 1.0), 0.5)
			tween.parallel().tween_property(soul_display, "scale", Vector2(0.9, 0.9), 0.5)
		4:  # TRAINING
			tween.tween_property(soul_display, "modulate", Color(1.2, 0.8, 0.8), 0.3)
			tween.parallel().tween_property(soul_display, "scale", Vector2(1.1, 1.1), 0.3)
		5:  # PLAYING
			tween.tween_property(soul_display, "modulate", Color(1.0, 1.1, 1.0), 0.3)
			tween.parallel().tween_property(soul_display, "scale", Vector2(1.05, 1.05), 0.3)
		_:  # IDLE and others
			tween.tween_property(soul_display, "modulate", Color(1.0, 1.0, 1.0), 0.5)
			tween.parallel().tween_property(soul_display, "scale", Vector2(1.0, 1.0), 0.5)


func _process(delta: float) -> void:
	if _interaction_cooldown > 0:
		_interaction_cooldown -= delta
	if _room_switch_cooldown > 0:
		_room_switch_cooldown -= delta
	# Update training system cooldowns
	if _training_system:
		_training_system.update_cooldowns(delta)

	# Track home time
	if home_state["entered"]:
		home_state["total_time"] += delta


## --- Home Entry/Exit ---

## Enter the soul home
func _enter_home() -> void:
	home_state["entered"] = true
	home_state["visit_count"] += 1

	# Load or create soul growth data
	_load_soul_growth()

	# Enter soul world via SoulArena API
	_enter_soul_world()

	GameLog.info("SoulHome: Entered (visit #%d)" % home_state["visit_count"], "SoulHome")
	EventBus.emit("soul_home_entered", {"room": current_room, "visit": home_state["visit_count"]})


## Exit the soul home
func exit_home() -> void:
	home_state["entered"] = false

	# Save soul growth data
	_save_soul_growth()

	# Exit soul world
	_exit_soul_world()

	GameLog.info("SoulHome: Exited (total time: %.1fs)" % home_state["total_time"], "SoulHome")
	EventBus.emit("soul_home_exited", {"total_time": home_state["total_time"]})


## --- Soul Display ---

## Setup soul display with game-level UI: large portrait + element glow + gold frame
func _setup_soul_display() -> void:
	# Create soul display node (centered, larger)
	soul_display = Node2D.new()
	soul_display.name = "SoulDisplay"
	soul_display.position = Vector2(420, 300)
	add_child(soul_display)

	# Element color map for glow
	var element_colors = {
		"fire": Color(1.0, 0.4, 0.15, 0.25),
		"water": Color(0.2, 0.5, 1.0, 0.25),
		"earth": Color(0.4, 0.7, 0.3, 0.25),
		"wind": Color(0.3, 0.9, 0.8, 0.25),
		"light": Color(1.0, 0.85, 0.3, 0.3),
		"dark": Color(0.6, 0.3, 0.9, 0.25),
		"thunder": Color(0.9, 0.8, 0.2, 0.25),
		"ice": Color(0.5, 0.85, 1.0, 0.25)
	}

	# Load portrait based on current soul element
	var element = _current_soul_element if _current_soul_element else "fire"
	var element_file_map = {
		"fire": "fire", "water": "water", "earth": "earth", "wind": "wind",
		"light": "light", "dark": "shadow", "thunder": "thunder", "ice": "ice"
	}
	var file_name = element_file_map.get(element, element)
	var glow_color = element_colors.get(element, Color(0.5, 0.5, 0.5, 0.2))

	# Element glow background (larger than portrait, soft radial effect)
	var glow = ColorRect.new()
	glow.name = "ElementGlow"
	glow.size = Vector2(300, 360)
	glow.position = Vector2(-150, -180)
	glow.color = glow_color
	soul_display.add_child(glow)

	# Gold decorative frame around portrait
	var frame = Panel.new()
	frame.name = "GoldFrame"
	frame.custom_minimum_size = Vector2(260, 320)
	frame.position = Vector2(-130, -160)
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = Color(0.83, 0.66, 0.36, 0.9)
	frame_style.border_width_left = 3
	frame_style.border_width_right = 3
	frame_style.border_width_top = 3
	frame_style.border_width_bottom = 3
	frame_style.corner_radius_top_left = 8
	frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_left = 8
	frame_style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", frame_style)
	soul_display.add_child(frame)

	# Add soul portrait texture (larger: 240x300)
	var soul_sprite := TextureRect.new()
	soul_sprite.name = "SoulPortrait"
	soul_sprite.size = Vector2(240, 300)
	soul_sprite.position = Vector2(-120, -150)
	soul_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	soul_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var portrait_path = "res://assets/art/characters/character_%s_soul_portrait.png" % file_name
	if ResourceLoader.exists(portrait_path):
		soul_sprite.texture = load(portrait_path)
		GameLog.info("SoulHome: Loaded portrait for %s" % element, "SoulHome")
	else:
		# Fallback: colored rectangle with element color
		soul_sprite.queue_free()
		var fallback := ColorRect.new()
		fallback.size = Vector2(200, 240)
		fallback.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.6)
		fallback.position = Vector2(-100, -120)
		soul_display.add_child(fallback)
		GameLog.warning("SoulHome: Portrait not found, using fallback", "SoulHome")
		return

	soul_display.add_child(soul_sprite)

	# Floating animation (up/down)
	var float_tween = create_tween()
	float_tween.set_loops()
	float_tween.tween_property(soul_display, "position:y", 310.0, 1.8).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(soul_display, "position:y", 300.0, 1.8).set_ease(Tween.EASE_IN_OUT)

	# Breathing animation (subtle scale)
	var breath_tween = create_tween()
	breath_tween.set_loops()
	breath_tween.tween_property(soul_sprite, "scale", Vector2(1.03, 1.03), 2.0).set_ease(Tween.EASE_IN_OUT)
	breath_tween.tween_property(soul_sprite, "scale", Vector2(1.0, 1.0), 2.0).set_ease(Tween.EASE_IN_OUT)

	# Glow pulse animation
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "color:a", glow_color.a * 1.5, 2.0).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(glow, "color:a", glow_color.a * 0.7, 2.0).set_ease(Tween.EASE_IN_OUT)

	GameLog.info("SoulHome: Game-level soul display created (portrait + glow + gold frame)", "SoulHome")


## --- Room Management ---

## Switch to a different room
func switch_room(room_name: String) -> bool:
	if _room_switch_cooldown > 0:
		GameLog.debug("SoulHome: Room switch on cooldown", "SoulHome")
		return false

	if not rooms.has(room_name):
		GameLog.warning("SoulHome: Unknown room: %s" % room_name, "SoulHome")
		return false

	if not rooms[room_name]["unlocked"]:
		GameLog.warning("SoulHome: Room locked: %s" % room_name, "SoulHome")
		return false

	var old_room = current_room
	current_room = room_name
	_room_switch_cooldown = 0.3
	# Update daily behavior AI room
	if _daily_behavior_ai:
		_daily_behavior_ai.set_room(room_name)

	GameLog.info("SoulHome: Switched from %s to %s" % [old_room, room_name], "SoulHome")
	EventBus.emit("soul_home_room_changed", {"from": old_room, "to": room_name})
	return true


## Get current room info
func get_current_room() -> Dictionary:
	if rooms.has(current_room):
		return rooms[current_room].duplicate()
	return {}


## --- SoulArena API Integration ---

## Enter soul world via SoulArena API
func _enter_soul_world() -> void:
	if soul_id.is_empty():
		GameLog.warning("SoulHome: No soul_id set, skipping world enter", "SoulHome")
		return

	soul_world_id = "soul_home_%s_%d" % [soul_id, Time.get_unix_time_from_system()]

	var body := {
		"worldId": soul_world_id,
		"worldName": "Soul Home",
		"communicationMedium": "direct_api"
	}

	SoulArenaClient.enter_world(soul_id, soul_world_id, "", self, "_on_world_entered")


## Callback for world enter
func _on_world_entered(status_code: int, response: Dictionary) -> void:
	if status_code == 200:
		soul_in_world = true
		GameLog.info("SoulHome: Soul entered world %s" % soul_world_id, "SoulHome")
	else:
		GameLog.error("SoulHome: Failed to enter world: %d" % status_code, "SoulHome")
		ErrorHandler.track_error("SoulHome", "Failed to enter soul world", {"status": status_code, "response": response}, "error")


## Exit soul world
func _exit_soul_world() -> void:
	if not soul_in_world or soul_id.is_empty():
		return

	SoulArenaClient.exit_world(soul_id, "left_home", self, "_on_world_exited")
	soul_in_world = false


## Callback for world exit
func _on_world_exited(status_code: int, response: Dictionary) -> void:
	if status_code == 200:
		GameLog.info("SoulHome: Soul exited world", "SoulHome")
	else:
		GameLog.warning("SoulHome: World exit returned %d" % status_code, "SoulHome")


## Send a message to the soul (chat)
func send_message(message: String) -> void:
	if _interaction_cooldown > 0:
		return
	if not soul_in_world:
		GameLog.warning("SoulHome: Soul not in world, cannot send message", "SoulHome")
		return

	_interaction_cooldown = 0.5

	# Perceive the situation first (message)
	var body := {
		"tick": Time.get_ticks_msec() / 1000,
		"situation": "Player says: %s" % message
	}
	SoulArenaClient.perceive(soul_id, body, self, "_on_perceive_response")

	# Add cognitive/emotional experience from interaction
	if soul_growth:
		soul_growth.add_dimension_experience("cognitive", 5, "language")
		soul_growth.add_dimension_experience("emotional", 3, "emotion_expression")
		soul_growth.add_memory("Player said: %s" % message, "interaction", 1)

	EventBus.emit("soul_chat_sent", {"message": message})


## Callback for perceive response (soul's reaction)
func _on_perceive_response(status_code: int, response: Dictionary) -> void:
	if status_code == 200:
		GameLog.debug("SoulHome: Soul perceived: %s" % str(response).substr(0, 100), "SoulHome")
		EventBus.emit("soul_chat_received", {"response": response})
	else:
		GameLog.error("SoulHome: Perceive failed: %d" % status_code, "SoulHome")


## --- Interactions (M1 basics) ---

## Pet/caress the soul
func interact_pet() -> void:
	if _interaction_cooldown > 0:
		return
	_interaction_cooldown = 1.0

	if soul_growth:
		soul_growth.add_dimension_experience("emotional", 8, "attachment")
		soul_growth.add_memory("Player petted me", "emotional", 2)

	GameLog.info("SoulHome: Player petted soul", "SoulHome")
	EventBus.emit("soul_interaction", {"type": "pet", "soul_id": soul_id})


## Feed the soul
func interact_feed() -> void:
	if _interaction_cooldown > 0:
		return
	_interaction_cooldown = 2.0

	if soul_growth:
		soul_growth.emotional["energy"] = min(soul_growth.emotional["energy"] + 20, 100)
		soul_growth.add_dimension_experience("emotional", 5, "emotion_perception")
		soul_growth.add_memory("Player fed me", "care", 2)

	GameLog.info("SoulHome: Player fed soul", "SoulHome")
	EventBus.emit("soul_interaction", {"type": "feed", "soul_id": soul_id})


## Play with the soul
func interact_play() -> void:
	if _interaction_cooldown > 0:
		return
	_interaction_cooldown = 3.0

	if soul_growth:
		soul_growth.add_dimension_experience("skill", 10)
		soul_growth.add_dimension_experience("emotional", 5, "emotion_expression")
		soul_growth.add_memory("Player played with me", "play", 2)

	GameLog.info("SoulHome: Player played with soul", "SoulHome")
	EventBus.emit("soul_interaction", {"type": "play", "soul_id": soul_id})


## --- Soul Growth Data ---

## Load soul growth data from save
func _load_soul_growth() -> void:
	var save_data = SaveSystem.load_game(0)
	if save_data.has("soul_growth"):
		soul_growth = SoulGrowthData.new()
		soul_growth.from_dict(save_data["soul_growth"])
		GameLog.info("SoulHome: Loaded soul growth data (Lv.%d)" % soul_growth.level, "SoulHome")
	else:
		# Create new soul growth data
		soul_growth = SoulGrowthData.new()
		soul_growth.soul_id = soul_id
		soul_growth.soul_name = "Soul"
		GameLog.info("SoulHome: Created new soul growth data", "SoulHome")

	soul_growth.start_session()


## Save soul growth data
func _save_soul_growth() -> void:
	if soul_growth == null:
		return

	soul_growth.end_session()

	var save_data := {"soul_growth": soul_growth.to_dict()}
	SaveSystem.save_game(0, save_data, "Soul Home Auto Save")
	GameLog.info("SoulHome: Saved soul growth data", "SoulHome")


## Get soul growth summary for UI
func get_soul_summary() -> Dictionary:
	if soul_growth:
		return soul_growth.get_summary()
	return {}


## --- Cleanup ---

func _exit_tree() -> void:
	if home_state["entered"]:
		exit_home()


## --- UI Button Handlers ---

## Handle back button - return to main menu
func _on_back_button() -> void:
	GameLog.info("SoulHome: Back to main menu", "SoulHome")
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	exit_home()
	SceneManager.change_scene("res://scenes/main_menu.tscn")


## Handle battle button - enter RTS battle
func _on_battle_button() -> void:
	GameLog.info("SoulHome: Enter battle", "SoulHome")
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	exit_home()
	SceneManager.change_scene("res://scenes/soul_select.tscn")


## Handle chat button - toggle chat panel
func _on_chat_button() -> void:
	GameLog.info("SoulHome: Chat toggled", "SoulHome")
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
		AudioManager.play_sfx("soul_home_dialogue")
	var chat_panel = get_node_or_null("ChatPanel")
	if chat_panel:
		chat_panel.visible = not chat_panel.visible


## Handle pet button
func _on_pet_button() -> void:
	interact_pet()
	_update_event_log("You petted the soul. It feels happy.")
	if AudioManager:
		AudioManager.play_sfx("soul_happy")
		AudioManager.play_sfx("soul_home_interaction")


## Handle feed button
func _on_feed_button() -> void:
	interact_feed()
	_update_event_log("You fed the soul. Energy restored.")
	if AudioManager:
		AudioManager.play_sfx("soul_content_smile")
		AudioManager.play_sfx("soul_home_interaction")


## Handle play button
func _on_play_button() -> void:
	interact_play()
	_update_event_log("You played with the soul. Skills improved.")
	if AudioManager:
		AudioManager.play_sfx("soul_joyful")
		AudioManager.play_sfx("soul_home_interaction")


## Handle train button
func _on_train_button() -> void:
	if _interaction_cooldown > 0:
		return
	_interaction_cooldown = 3.0
	if soul_growth:
		soul_growth.add_dimension_experience("skill", 15)
		soul_growth.add_memory("Player trained me", "training", 2)
	GameLog.info("SoulHome: Player trained soul", "SoulHome")
	_update_event_log("You trained the soul. Skills increased.")
	if AudioManager:
		AudioManager.play_sfx("soul_chivalrous")
		AudioManager.play_sfx("soul_home_training")
		AudioManager.play_sfx("soul_training_start")
		AudioManager.play_sfx("soul_training_complete")
		AudioManager.play_sfx("soul_training_success")


## Handle chat send
func _on_chat_send(message: String = "") -> void:
	var chat_input = get_node_or_null("ChatPanel/ChatInput")
	if chat_input and message.is_empty():
		message = chat_input.text
	if not message.is_empty():
		send_message(message)
		_update_chat_history("You: " + message)
		if chat_input:
			chat_input.text = ""
		# Play soul chat sound when soul responds
		if AudioManager:
			AudioManager.play_sfx("soul_chat")


## Handle chat close
func _on_chat_close() -> void:
	var chat_panel = get_node_or_null("ChatPanel")
	if chat_panel:
		chat_panel.visible = false


## Update event log label
func _update_event_log(text: String) -> void:
	var event_log = get_node_or_null("EventLog")
	if event_log:
		event_log.text = text


## Update chat history
func _update_chat_history(text: String) -> void:
	var chat_history = get_node_or_null("ChatPanel/ChatHistory")
	if chat_history:
		chat_history.append_text("\n" + text)
