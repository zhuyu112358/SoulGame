extends Node2D
## RTSArenaController - Controller for the RTS arena battle scene
##
## Manages the RTS arena UI: unit displays, HP/energy bars, skill buttons,
## battle log, and real-time battle visualization. Connects to RTSArenaManager.
##
## This is game-specific UI for RTS combat, not SDK kernel code.

## UI node references
var player_hp_bar = null
var player_energy_bar = null
var player_name_label = null
var ai_hp_bar = null
var ai_energy_bar = null
var ai_name_label = null
var battle_time_label = null
var battle_log = null
var skill_buttons = {}
var back_button = null
var arena_viewport = null

## SoulUnit preload
const SoulUnit = preload("res://scripts/game/SoulUnit.gd")

## Visual unit nodes
var _player_visual = null
var _ai_visual = null

## Battle active flag
var _battle_active = false


func _ready() -> void:
	GameLog.info("RTSArenaController: RTS Arena scene ready", "Arena")
	_setup_ui_refs()
	_connect_signals()
	_setup_skill_buttons()


## Setup UI node references
func _setup_ui_refs() -> void:
	player_name_label = get_node_or_null("TopBar/PlayerPanel/NameLabel")
	player_hp_bar = get_node_or_null("TopBar/PlayerPanel/HPBar")
	player_energy_bar = get_node_or_null("TopBar/PlayerPanel/EnergyBar")
	ai_name_label = get_node_or_null("TopBar/AIPanel/NameLabel")
	ai_hp_bar = get_node_or_null("TopBar/AIPanel/HPBar")
	ai_energy_bar = get_node_or_null("TopBar/AIPanel/EnergyBar")
	battle_time_label = get_node_or_null("TopBar/TimeLabel")
	battle_log = get_node_or_null("BattleLog/LogText")
	back_button = get_node_or_null("BottomBar/BackButton")
	arena_viewport = get_node_or_null("ArenaViewport")

	# Skill buttons
	skill_buttons["heavy_strike"] = get_node_or_null("BottomBar/SkillButtons/HeavyStrike")
	skill_buttons["quick_strike"] = get_node_or_null("BottomBar/SkillButtons/QuickStrike")
	skill_buttons["heal"] = get_node_or_null("BottomBar/SkillButtons/Heal")
	skill_buttons["defend"] = get_node_or_null("BottomBar/SkillButtons/Defend")

	GameLog.debug("RTSArenaController: UI refs setup", "Arena")


## Connect to RTSArenaManager signals
func _connect_signals() -> void:
	RTSArenaManager.battle_started.connect(_on_battle_started)
	RTSArenaManager.battle_finished.connect(_on_battle_finished)
	RTSArenaManager.battle_time_updated.connect(_on_battle_time_updated)
	RTSArenaManager.unit_spawned.connect(_on_unit_spawned)
	RTSArenaManager.log_added.connect(_on_log_added)


## Setup skill button signals
func _setup_skill_buttons() -> void:
	if skill_buttons["heavy_strike"]:
		skill_buttons["heavy_strike"].pressed.connect(_on_heavy_strike_pressed)
	if skill_buttons["quick_strike"]:
		skill_buttons["quick_strike"].pressed.connect(_on_quick_strike_pressed)
	if skill_buttons["heal"]:
		skill_buttons["heal"].pressed.connect(_on_heal_pressed)
	if skill_buttons["defend"]:
		skill_buttons["defend"].pressed.connect(_on_defend_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


## Process real-time UI updates
func _process(delta: float) -> void:
	if not _battle_active:
		return
	_update_unit_display()
	_update_skill_cooldowns()


## Update unit HP/energy display
func _update_unit_display() -> void:
	var info = RTSArenaManager.get_battle_info()

	if info.has("player") and player_hp_bar:
		var p = info["player"]
		player_hp_bar.value = float(p.get("hp", 0)) / float(p.get("max_hp", 100)) * 100.0
		if player_energy_bar:
			player_energy_bar.value = float(p.get("energy", 0)) / float(p.get("max_energy", 50)) * 100.0

	if info.has("ai") and ai_hp_bar:
		var a = info["ai"]
		ai_hp_bar.value = float(a.get("hp", 0)) / float(a.get("max_hp", 100)) * 100.0
		if ai_energy_bar:
			ai_energy_bar.value = float(a.get("energy", 0)) / float(a.get("max_energy", 50)) * 100.0


## Update skill cooldown display
func _update_skill_cooldowns() -> void:
	if RTSArenaManager.player_unit == null:
		return

	for skill_name in skill_buttons.keys():
		var button = skill_buttons[skill_name]
		if button == null:
			continue
		var cooldown = RTSArenaManager.player_unit.skill_cooldowns.get(skill_name, 0)
		button.disabled = cooldown > 0
		if cooldown > 0:
			button.text = "%s (%.1f)" % [skill_name.capitalize(), cooldown]
		else:
			button.text = skill_name.capitalize()


## Handle battle started
func _on_battle_started(p_battle_info: Dictionary) -> void:
	_battle_active = true
	_add_log("Battle started!")
	GameLog.info("RTSArenaController: Battle started", "Arena")


## Handle battle finished
func _on_battle_finished(p_result: String, p_winner_id: String, p_loser_id: String) -> void:
	_battle_active = false
	_add_log("Battle finished: %s!" % p_result.to_upper())

	# Disable all skill buttons
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			skill_buttons[skill_name].disabled = true

	GameLog.info("RTSArenaController: Battle finished - %s" % p_result, "Arena")


## Handle battle time update
func _on_battle_time_updated(p_time: float) -> void:
	if battle_time_label:
		var minutes = int(p_time) / 60
		var seconds = int(p_time) % 60
		battle_time_label.text = "%02d:%02d" % [minutes, seconds]


## Handle unit spawned
func _on_unit_spawned(p_unit: SoulUnit, p_is_player: bool) -> void:
	GameLog.info("RTSArenaController: Unit spawned - %s (player: %s)" % [p_unit.soul_name, str(p_is_player)], "Arena")

	# Create visual representation
	var visual = ColorRect.new()
	visual.size = Vector2(64, 64)
	visual.position = p_unit.position - Vector2(32, 32)
	if p_is_player:
		visual.color = Color(0.2, 0.6, 1.0)  # Blue for player
		_player_visual = visual
	else:
		visual.color = Color(1.0, 0.3, 0.3)  # Red for AI
		_ai_visual = visual
	add_child(visual)

	# Connect position update
	p_unit.position_changed.connect(func(pos):
		visual.position = pos - Vector2(32, 32)
	)


## Handle log added
func _on_log_added(p_message: String) -> void:
	_add_log(p_message)


## Add message to battle log
func _add_log(p_message: String) -> void:
	if battle_log:
		battle_log.text += p_message + "\n"
		# Scroll to bottom
		battle_log.caret_position = battle_log.text.length()


## Skill button handlers
func _on_heavy_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("heavy_strike")

func _on_quick_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("quick_strike")

func _on_heal_pressed() -> void:
	RTSArenaManager.player_use_skill("heal")

func _on_defend_pressed() -> void:
	RTSArenaManager.player_use_skill("defend")


## Handle back button
func _on_back_pressed() -> void:
	RTSArenaManager.cleanup_battle()
	SceneManager.change_scene("res://scenes/cli.tscn")


## Start a test battle
func start_test_battle() -> void:
	var player_soul = {
		"id": "test_player",
		"name": "Player Soul",
		"element": "fire",
		"level": 5
	}
	var ai_soul = {
		"id": "test_ai",
		"name": "AI Soul",
		"element": "water",
		"level": 5
	}
	RTSArenaManager.start_battle(player_soul, ai_soul)
