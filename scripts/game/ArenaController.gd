extends Node2D
## ArenaController - Controller for the arena battle scene
##
## Manages the arena UI: soul displays, HP/energy bars, skill buttons,
## battle log, and turn information. Connects to ArenaManager for battle logic.
##
## This is game-specific UI, not SDK kernel code.

## UI node references
var soul1_name_label = null
var soul2_name_label = null
var soul1_hp_bar = null
var soul2_hp_bar = null
var soul1_energy_bar = null
var soul2_energy_bar = null
var soul1_sprite = null
var soul2_sprite = null
var turn_label = null
var battle_log = null
var skill_buttons = {}
var back_button = null

## SoulSprite preload
const SoulSprite = preload("res://scripts/ui/SoulSprite.gd")


func _ready() -> void:
	GameLog.info("ArenaController: Arena scene ready", "Arena")
	_setup_ui_refs()
	_update_battle_display()

	# Subscribe to battle events
	EventBus.subscribe("arena_battle_started", self, "_on_battle_started")
	EventBus.subscribe("arena_battle_finished", self, "_on_battle_finished")


func _setup_ui_refs() -> void:
	soul1_name_label = get_node_or_null("Soul1Panel/NameLabel")
	soul2_name_label = get_node_or_null("Soul2Panel/NameLabel")
	soul1_hp_bar = get_node_or_null("Soul1Panel/HPBar")
	soul2_hp_bar = get_node_or_null("Soul2Panel/HPBar")
	soul1_energy_bar = get_node_or_null("Soul1Panel/EnergyBar")
	soul2_energy_bar = get_node_or_null("Soul2Panel/EnergyBar")
	soul1_sprite = get_node_or_null("Soul1Panel/SoulSprite")
	soul2_sprite = get_node_or_null("Soul2Panel/SoulSprite")
	turn_label = get_node_or_null("TopBar/TurnLabel")
	battle_log = get_node_or_null("BattleLog/LogText")
	back_button = get_node_or_null("BottomBar/BackButton")

	# Skill buttons
	skill_buttons["basic_attack"] = get_node_or_null("BottomBar/SkillButtons/BasicAttack")
	skill_buttons["heavy_strike"] = get_node_or_null("BottomBar/SkillButtons/HeavyStrike")
	skill_buttons["quick_strike"] = get_node_or_null("BottomBar/SkillButtons/QuickStrike")
	skill_buttons["heal"] = get_node_or_null("BottomBar/SkillButtons/Heal")
	skill_buttons["defend"] = get_node_or_null("BottomBar/SkillButtons/Defend")

	GameLog.debug("ArenaController: UI refs setup", "Arena")


## Update all battle display elements
func _update_battle_display() -> void:
	var battle = ArenaManager.get_current_battle()
	if battle == null or battle.status == "idle":
		if turn_label:
			turn_label.text = "No active battle"
		return

	# Turn info
	if turn_label:
		turn_label.text = "Turn %d | Round %d | %s" % [
			battle.turn, battle.round, battle.status.to_upper()
		]

	# Participant info
	if battle.participants.size() >= 2:
		var p1 = battle.participants[0]
		var p2 = battle.participants[1]

		# Names
		if soul1_name_label:
			soul1_name_label.text = "%s [%s] Lv.%d" % [p1["name"], p1["element"], p1["level"]]
		if soul2_name_label:
			soul2_name_label.text = "%s [%s] Lv.%d" % [p2["name"], p2["element"], p2["level"]]

		# HP bars
		if soul1_hp_bar:
			soul1_hp_bar.value = float(p1["current_hp"]) / float(p1["max_hp"]) * 100
		if soul2_hp_bar:
			soul2_hp_bar.value = float(p2["current_hp"]) / float(p2["max_hp"]) * 100

		# Energy bars
		if soul1_energy_bar:
			soul1_energy_bar.value = float(p1["current_energy"]) / float(p1["max_energy"]) * 100
		if soul2_energy_bar:
			soul2_energy_bar.value = float(p2["current_energy"]) / float(p2["max_energy"]) * 100

		# Soul sprites
		if soul1_sprite:
			soul1_sprite.set_soul_properties(p1["element"], "neutral", p1["level"])
		if soul2_sprite:
			soul2_sprite.set_soul_properties(p2["element"], "neutral", p2["level"])

	# Battle log
	if battle_log:
		battle_log.text = ArenaManager.get_battle_log_text(15)

	# Update skill button states
	_update_skill_buttons()


## Update skill button enabled states based on current actor and energy
func _update_skill_buttons() -> void:
	var battle = ArenaManager.get_current_battle()
	if battle == null or battle.status != "active":
		for btn in skill_buttons.values():
			if btn:
				btn.disabled = true
		return

	var current_actor = battle.get_current_actor()
	if current_actor.is_empty():
		for btn in skill_buttons.values():
			if btn:
				btn.disabled = true
		return

	var energy = current_actor["current_energy"]
	var energy_costs = {
		"basic_attack": 5,
		"heavy_strike": 15,
		"quick_strike": 3,
		"heal": 10,
		"defend": 2
	}

	for skill_name in skill_buttons.keys():
		var btn = skill_buttons[skill_name]
		if btn:
			var cost = energy_costs.get(skill_name, 5)
			btn.disabled = energy < cost


## Handle skill button press
func _on_skill_pressed(p_skill_name: String) -> void:
	var battle = ArenaManager.get_current_battle()
	if battle == null or battle.status != "active":
		return

	var current_actor = battle.get_current_actor()
	if current_actor.is_empty():
		return

	# Find target (the other participant)
	var target_id = ""
	for p in battle.participants:
		if p["id"] != current_actor["id"] and p["is_alive"]:
			target_id = p["id"]
			break

	if target_id.is_empty():
		return

	# Process action
	var result = ArenaManager.process_attack(current_actor["id"], target_id, p_skill_name)

	if result.get("success", false):
		GameLog.info("ArenaController: %s used %s" % [current_actor["name"], p_skill_name], "Arena")

	_update_battle_display()

	# If battle not finished, simulate opponent turn after short delay
	if battle.status == "active":
		await get_tree().create_timer(0.5).timeout
		_simulate_opponent_turn()


## Simulate opponent AI turn (simplified)
func _simulate_opponent_turn() -> void:
	var battle = ArenaManager.get_current_battle()
	if battle == null or battle.status != "active":
		return

	var current_actor = battle.get_current_actor()
	if current_actor.is_empty():
		return

	# Simple AI: choose random skill based on energy
	var skills = ["basic_attack", "quick_strike", "heavy_strike", "heal", "defend"]
	var available_skills = []
	var energy_costs = {"basic_attack": 5, "heavy_strike": 15, "quick_strike": 3, "heal": 10, "defend": 2}

	for skill in skills:
		if current_actor["current_energy"] >= energy_costs[skill]:
			available_skills.append(skill)

	if available_skills.size() == 0:
		available_skills.append("defend")

	var chosen_skill = available_skills[randi() % available_skills.size()]

	# Find target
	var target_id = ""
	for p in battle.participants:
		if p["id"] != current_actor["id"] and p["is_alive"]:
			target_id = p["id"]
			break

	if not target_id.is_empty():
		ArenaManager.process_attack(current_actor["id"], target_id, chosen_skill)
		GameLog.info("ArenaController: %s (AI) used %s" % [current_actor["name"], chosen_skill], "Arena")

	_update_battle_display()


## Start a quick test battle
func start_test_battle() -> void:
	ArenaManager.start_battle(
		"player_soul", "PlayerSoul", "fire", 10,
		"enemy_soul", "EnemySoul", "water", 8
	)
	_update_battle_display()


## Battle started event handler
func _on_battle_started(p_data: Dictionary) -> void:
	GameLog.info("ArenaController: Battle started - %s" % str(p_data.get("participants", [])), "Arena")
	_update_battle_display()


## Battle finished event handler
func _on_battle_finished(p_data: Dictionary) -> void:
	GameLog.info("ArenaController: Battle finished - %s" % p_data.get("result", "unknown"), "Arena")
	_update_battle_display()

	# Disable all skill buttons
	for btn in skill_buttons.values():
		if btn:
			btn.disabled = true


## Back to CLI
func _on_back_pressed() -> void:
	SceneManager.change_scene("res://scenes/cli.tscn")
