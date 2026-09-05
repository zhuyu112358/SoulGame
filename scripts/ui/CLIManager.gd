extends Node
## CLIManager - Text-based command line interface for M1
##
## Provides a terminal-style interface for soul management, world management,
## and soul home interaction. This is the primary player interface for M1,
## to be replaced with GUI in later phases.

## Output lines for display
var output_lines: Array = []

## Maximum lines to keep in buffer
var max_lines: int = 100

## Command history for up/down navigation
var command_history: Array = []
var history_index: int = -1

## Whether CLI is active
var is_active: bool = false

## Reference to UI nodes (set by scene)
var output_label: Label = null
var input_line: LineEdit = null


func _ready() -> void:
	GameLog.info("CLIManager: Initialized", "CLI")
	add_line("=== Soul Game CLI v0.3.0 ===")
	add_line("Type 'help' for available commands.")
	add_line("")


## Toggle CLI visibility
func toggle() -> void:
	is_active = not is_active
	if is_active:
		GameLog.info("CLIManager: Activated", "CLI")
	else:
		GameLog.info("CLIManager: Deactivated", "CLI")


## Add a line to output
func add_line(text: String) -> void:
	output_lines.append(text)
	if output_lines.size() > max_lines:
		output_lines.pop_front()
	_update_display()


## Process a command
func process_command(command: String) -> void:
	if command.strip_edges() == "":
		return

	add_line("> " + command)
	command_history.append(command)
	history_index = command_history.size()

	var parts: Array = command.strip_edges().split(" ")
	var cmd: String = parts[0].to_lower()

	match cmd:
		"help":
			_show_help()
		"status":
			_show_status()
		"create_soul":
			_create_soul(parts)
		"list_souls":
			_list_souls()
		"select_soul":
			_select_soul(parts)
		"soul_home":
			_enter_soul_home()
		"train":
			_train_soul(parts)
		"deploy":
			_deploy_soul(parts)
		"create_world":
			_create_world(parts)
		"list_worlds":
			_list_worlds()
		"start_world":
			_start_world(parts)
		"stop_world":
			_stop_world()
		"growth":
			_open_growth_visualizer()
		"save":
			_save_game()
		"load":
			_load_game()
		"clear":
			output_lines.clear()
			_update_display()
		"quit":
			add_line("Goodbye!")
			get_tree().quit()
		_:
			add_line("Unknown command: '%s'. Type 'help' for available commands." % cmd)

	add_line("")


## Show help text
func _show_help() -> void:
	add_line("=== Available Commands ===")
	add_line("  help              - Show this help")
	add_line("  status            - Show current game status")
	add_line("  create_soul       - Create a new soul")
	add_line("  list_souls        - List all souls")
	add_line("  select_soul <id>  - Select active soul")
	add_line("  soul_home         - Enter soul home")
	add_line("  train <task>      - Train soul (perception/memory/reasoning/social/creativity)")
	add_line("  deploy <world_id> - Deploy soul to world")
	add_line("  create_world      - Create a new world")
	add_line("  list_worlds       - List all worlds")
	add_line("  start_world <id>  - Start world simulation")
	add_line("  stop_world        - Stop current world simulation")
	add_line("  save              - Save game state")
	add_line("  load              - Load game state")
	add_line("  clear             - Clear screen")
	add_line("  quit              - Quit game")


## Show current status
func _show_status() -> void:
	add_line("=== Game Status ===")
	if SoulManager.active_soul:
		var soul = SoulManager.active_soul
		add_line("Active soul: %s" % soul.soul_name)
		add_line("  Level: %d (XP: %d/%d)" % [soul.level, soul.experience, soul.experience_to_next])
		add_line("  Cognitive: Lv.%d" % soul.cognitive["level"])
		add_line("  Emotional: Lv.%d" % soul.emotional["level"])
		add_line("  Skills: Lv.%d (%d unlocked)" % [soul.skills.get("level", 1), soul.skills["unlocked"].size()])
	else:
		add_line("Active soul: None")
	add_line("Total souls: %d" % SoulManager.soul_list.size())
	add_line("Total worlds: %d" % WorldManager.world_list.size())
	var running_worlds = 0
	for w in WorldManager.world_list:
		if w.get("running", false):
			running_worlds += 1
	add_line("Running worlds: %d" % running_worlds)


## Create a new soul
func _create_soul(parts: Array) -> void:
	if parts.size() < 2:
		add_line("Usage: create_soul <name> [description]")
		add_line("Example: create_soul Luna brave and curious")
		return
	var name = parts[1]
	var description = " ".join(parts.slice(2)) if parts.size() > 2 else "a mysterious soul"
	SoulManager.start_creation(description)
	var soul = SoulManager.complete_creation(name)
	if soul:
		add_line("Soul '%s' created!" % name)
		add_line("  ID: %s" % soul.soul_id)
		add_line("  Personality: %s" % soul.get_personality_summary())
		add_line("Type 'soul_home' to enter soul home.")
	else:
		add_line("Failed to create soul.")


## List all souls
func _list_souls() -> void:
	if SoulManager.soul_list.is_empty():
		add_line("No souls created yet. Use 'create_soul' to create one.")
		return
	add_line("=== Soul List ===")
	for s in SoulManager.soul_list:
		var active_mark = "*" if SoulManager.active_soul and SoulManager.active_soul.soul_id == s.get("id", "") else " "
		add_line(" [%s] %s - Lv.%d (%s)" % [active_mark, s.get("name", "Unknown"), s.get("level", 1), s.get("id", "")])


## Select active soul
func _select_soul(parts: Array) -> void:
	if parts.size() < 2:
		add_line("Usage: select_soul <id>")
		return
	var soul_id = parts[1]
	var success = SoulManager.set_active_soul(soul_id)
	if success and SoulManager.active_soul:
		add_line("Selected soul: %s" % SoulManager.active_soul.soul_name)
	else:
		add_line("Soul not found: %s" % soul_id)


## Enter soul home
func _enter_soul_home() -> void:
	if not SoulManager.active_soul:
		add_line("No active soul. Use 'create_soul' or 'select_soul' first.")
		return
	add_line("Entering soul home for %s..." % SoulManager.active_soul.soul_name)
	SceneManager.change_scene("res://scenes/soul_home.tscn")


## Train soul
func _train_soul(parts: Array) -> void:
	if not SoulManager.active_soul:
		add_line("No active soul. Use 'select_soul' first.")
		return
	if parts.size() < 2:
		add_line("Usage: train <task>")
		add_line("Tasks: perception, memory, reasoning, social, creativity")
		return
	var task = parts[1].to_lower()
	var valid_tasks = ["perception", "memory", "reasoning", "social", "creativity"]
	if task not in valid_tasks:
		add_line("Invalid task: %s" % task)
		add_line("Valid tasks: %s" % ", ".join(valid_tasks))
		return
	var success = SoulManager.start_training(task)
	if success:
		add_line("Training '%s' started for %s" % [task, SoulManager.active_soul.soul_name])
		add_line("  Use 'status' to check progress.")
	else:
		add_line("Failed to start training. Another training may be in progress.")


## Deploy soul to world
func _deploy_soul(parts: Array) -> void:
	if not SoulManager.active_soul:
		add_line("No active soul. Use 'select_soul' first.")
		return
	if parts.size() < 2:
		add_line("Usage: deploy <world_id>")
		return
	var world_id = parts[1]
	var world_details = WorldManager.get_world_details(world_id)
	if world_details.is_empty():
		add_line("World not found: %s" % world_id)
		return
	var world_name = world_details.get("name", "Unknown")
	var success = SoulManager.deploy_soul(SoulManager.active_soul.soul_id, world_id, world_name)
	if success:
		add_line("Deployed %s to world '%s'" % [SoulManager.active_soul.soul_name, world_name])
	else:
		add_line("Deployment failed.")


## Create a new world
func _create_world(parts: Array) -> void:
	if parts.size() < 2:
		add_line("Usage: create_world <template> [name]")
		add_line("Templates: training_arena, exploration_forest, social_plaza, challenge_maze")
		return
	var template = parts[1]
	var name = parts[2] if parts.size() > 2 else "%s_%d" % [template, randi() % 1000]
	var started = WorldManager.start_creation(template)
	if not started:
		add_line("Failed to create world. Invalid template: %s" % template)
		add_line("Valid templates: training_arena, exploration_forest, social_plaza, challenge_maze")
		return
	var world = WorldManager.complete_creation(name)
	if world:
		add_line("World '%s' created from template '%s'" % [name, template])
		add_line("  ID: %s" % world.get("id", ""))
	else:
		add_line("Failed to complete world creation.")


## List all worlds
func _list_worlds() -> void:
	if WorldManager.world_list.is_empty():
		add_line("No worlds created yet. Use 'create_world' to create one.")
		return
	add_line("=== World List ===")
	for w in WorldManager.world_list:
		var status = "RUNNING" if w.get("running", false) else "STOPPED"
		add_line(" [%s] %s (template: %s) - %s" % [status, w.get("name", "Unknown"), w.get("template", "?"), w.get("id", "")])


## Start world simulation
func _start_world(parts: Array) -> void:
	if parts.size() < 2:
		add_line("Usage: start_world <id>")
		return
	var world_id = parts[1]
	var success = WorldManager.start_simulation(world_id)
	if success:
		add_line("World simulation started: %s" % world_id)
	else:
		add_line("Failed to start world: %s" % world_id)


## Stop world simulation
func _stop_world() -> void:
	WorldManager.stop_simulation()
	add_line("World simulation stopped.")


## Open growth visualizer scene
func _open_growth_visualizer() -> void:
	if not SoulManager.active_soul:
		add_line("No active soul. Use create_soul or select_soul first.")
		return
	add_line("Opening growth visualizer for %s..." % SoulManager.active_soul.soul_name)
	SceneManager.change_scene("res://scenes/growth_visualizer.tscn")


## Save game
func _save_game() -> void:
	if SoulManager.active_soul:
		SoulManager._save_soul(SoulManager.active_soul)
	SoulManager._save_soul_list()
	WorldManager._save_world_list()
	add_line("Game saved.")


## Load game
func _load_game() -> void:
	SoulManager._load_soul_list()
	WorldManager._load_world_list()
	add_line("Game loaded.")
	add_line("  Souls: %d" % SoulManager.soul_list.size())
	add_line("  Worlds: %d" % WorldManager.world_list.size())


## Update display label
func _update_display() -> void:
	if output_label:
		output_label.text = "\n".join(output_lines)


## Handle input from LineEdit
func _on_input_submitted(text: String) -> void:
	process_command(text)
	if input_line:
		input_line.text = ""
