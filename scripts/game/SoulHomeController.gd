extends Node2D

## SoulGrowthData preload (class_name may not be registered in all contexts)
const SoulGrowthData = preload("res://scripts/game/SoulGrowthData.gd")

## SoulHomeController - Controller for the Soul Home scene
##
## Manages the soul home environment, soul display, room switching,
## and basic interactions. This is the M1 foundation - full interaction
## systems will be built on top of this.
##
## Rooms (M1 implements Main Room only):
## - main: Daily interaction, communication, customization
## - training: Skill training (M2)
## - study: Knowledge transfer, cognitive training (M2)
## - garden: Emotional interaction, mini-games (M2)

## Current room
var current_room: String = "main"

## Available rooms
var rooms: Dictionary = {
	"main": {"name": "Main Room", "unlocked": true, "m1": true},
	"training": {"name": "Training Room", "unlocked": false, "m1": false},
	"study": {"name": "Study", "unlocked": false, "m1": false},
	"garden": {"name": "Garden", "unlocked": false, "m1": false}
}

## Soul growth data reference
var soul_growth: Resource = null

## Soul display node (placeholder for M1)
var soul_display: Node2D = null

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


func _ready() -> void:
	GameLog.info("SoulHome: Scene initialized", "SoulHome")
	_setup_soul_display()
	_setup_button_hovers()
	_enter_home()
	_play_home_ambience()


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


## Play hover sound and visual feedback
func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	p_button.modulate = Color(1.2, 1.2, 1.0)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	p_button.modulate = Color(1.0, 1.0, 1.0)


## Play button hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")


## Play home background music and ambient sounds
func _play_home_ambience() -> void:
	if AudioManager:
		AudioManager.play_bgm("soul_home_day")
		# Play home indoor environment ambience
		AudioManager.play_sfx("env_home_indoor")
		GameLog.info("SoulHome: Playing home BGM", "SoulHome")


func _process(delta: float) -> void:
	if _interaction_cooldown > 0:
		_interaction_cooldown -= delta
	if _room_switch_cooldown > 0:
		_room_switch_cooldown -= delta

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

## Setup soul display (placeholder for M1 - will be replaced with actual sprite)
func _setup_soul_display() -> void:
	# Create a placeholder soul display
	soul_display = Node2D.new()
	soul_display.name = "SoulDisplay"
	soul_display.position = Vector2(400, 300)
	add_child(soul_display)

	# Add a placeholder sprite (colored circle)
	var sprite := ColorRect.new()
	sprite.size = Vector2(64, 64)
	sprite.color = Color(0.4, 0.4, 1.0, 0.8)
	sprite.position = Vector2(-32, -32)
	soul_display.add_child(sprite)

	GameLog.debug("SoulHome: Soul display created (placeholder)", "SoulHome")


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
		AudioManager.play_ui("ui_button_click_01")
	exit_home()
	SceneManager.change_scene("res://scenes/main_menu.tscn")


## Handle battle button - enter RTS battle
func _on_battle_button() -> void:
	GameLog.info("SoulHome: Enter battle", "SoulHome")
	if AudioManager:
		AudioManager.play_ui("ui_button_click_01")
	exit_home()
	SceneManager.change_scene("res://scenes/soul_select.tscn")


## Handle chat button - toggle chat panel
func _on_chat_button() -> void:
	GameLog.info("SoulHome: Chat toggled", "SoulHome")
	if AudioManager:
		AudioManager.play_ui("ui_button_click_01")
	var chat_panel = get_node_or_null("ChatPanel")
	if chat_panel:
		chat_panel.visible = not chat_panel.visible


## Handle pet button
func _on_pet_button() -> void:
	interact_pet()
	_update_event_log("You petted the soul. It feels happy.")
	if AudioManager:
		AudioManager.play_sfx("soul_happy")


## Handle feed button
func _on_feed_button() -> void:
	interact_feed()
	_update_event_log("You fed the soul. Energy restored.")
	if AudioManager:
		AudioManager.play_sfx("soul_content_smile")


## Handle play button
func _on_play_button() -> void:
	interact_play()
	_update_event_log("You played with the soul. Skills improved.")
	if AudioManager:
		AudioManager.play_sfx("soul_joyful")


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
		AudioManager.play_sfx("soul_determined_resolve")


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
