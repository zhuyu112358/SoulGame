extends Node2D
## RTSArenaController - Controller for the RTS arena battle scene
##
## Manages the RTS arena UI: unit displays, HP/energy bars, skill buttons,
## battle log, and real-time battle visualization. Connects to RTSArenaManager.
##
## This is game-specific UI for RTS combat, not SDK kernel code.

## Arena background generator (procedural pixel art)
const ArenaBackgroundGenerator = preload("res://scripts/game/ArenaBackgroundGenerator.gd")

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
var minimap = null

## SoulUnit preload
const SoulUnit = preload("res://scripts/game/SoulUnit.gd")
const Minimap = preload("res://scripts/ui/Minimap.gd")

## Visual unit nodes
var _player_visual = null
var _ai_visual = null

## Battle active flag
var _battle_active = false

## Macro command UI (design doc: coach-style RTS, player issues limited commands)
var _command_panel = null
var _command_buttons = {}
var _command_cooldown_label = null
var _command_cooldown_timer = 0.0


func _ready() -> void:
	GameLog.info("RTSArenaController: RTS Arena scene ready", "Arena")
	_setup_ui_refs()
	_setup_arena_background()
	_connect_signals()
	_setup_skill_buttons()
	_setup_macro_commands()

	# Auto-start battle if config is set in GameState
	_try_auto_start_battle()


## Setup procedural pixel art arena background
func _setup_arena_background() -> void:
	var bg_node = get_node_or_null("Background")
	if bg_node == null:
		return

	# Get arena type from map config (default grass)
	var map_name = GameState.get_value("battle", "map_name", "default_arena")
	var arena_type = "grass"
	match map_name:
		"stone_arena":
			arena_type = "stone"
		"sand_arena":
			arena_type = "sand"
		"crystal_arena":
			arena_type = "crystal"
		"lava_arena":
			arena_type = "lava"

	# Generate background texture
	var generator = ArenaBackgroundGenerator.new()
	var texture = generator.generate_background(arena_type, hash(map_name))

	# Replace ColorRect with TextureRect
	var texture_rect = TextureRect.new()
	texture_rect.texture = texture
	texture_rect.position = Vector2(0, 80)  # Below top bar
	texture_rect.size = Vector2(1280, 640)
	texture_rect.name = "ArenaBackground"
	add_child(texture_rect)

	# Hide original ColorRect
	bg_node.visible = false

	GameLog.info("RTSArenaController: Arena background generated (%s)" % arena_type, "Arena")


## Try to auto-start battle from GameState configuration
func _try_auto_start_battle() -> void:
	var player_soul = GameState.get_value("battle", "player_soul", null)
	var ai_soul = GameState.get_value("battle", "ai_soul", null)
	var map_name = GameState.get_value("battle", "map_name", "default_arena")

	if player_soul != null and ai_soul != null:
		GameLog.info("RTSArenaController: Auto-starting battle with config from GameState", "Arena")
		RTSArenaManager.start_battle(player_soul, ai_soul, map_name)
		# Clear battle config after use
		GameState.set_value("battle", "player_soul", null)
		GameState.set_value("battle", "ai_soul", null)
	else:
		_add_log("No battle config found. Use CLI 'rts_battle' to set up a battle.")
		_add_log("Or call start_test_battle() for a quick test.")


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
	minimap = get_node_or_null("Minimap")

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


## Setup macro command UI (design doc: coach-style RTS)
## Player can issue one macro command per 30 seconds
## Commands: gather, retreat, attack, defend
func _setup_macro_commands() -> void:
	# Create command panel at bottom center
	_command_panel = Panel.new()
	_command_panel.position = Vector2(380, 640)
	_command_panel.size = Vector2(520, 70)
	_command_panel.name = "MacroCommandPanel"
	add_child(_command_panel)

	# Title label
	var title = Label.new()
	title.text = "教练指令 (30秒冷却)"
	title.position = Vector2(10, 5)
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(0.8, 0.8, 0.9)
	_command_panel.add_child(title)

	# Cooldown label
	_command_cooldown_label = Label.new()
	_command_cooldown_label.text = "就绪"
	_command_cooldown_label.position = Vector2(400, 5)
	_command_cooldown_label.add_theme_font_size_override("font_size", 11)
	_command_cooldown_label.modulate = Color(0.4, 0.9, 0.5)
	_command_panel.add_child(_command_cooldown_label)

	# Create command buttons
	var commands = [
		{"name": "gather", "label": "集合", "color": Color(0.3, 0.6, 0.9)},
		{"name": "attack", "label": "进攻", "color": Color(0.9, 0.4, 0.3)},
		{"name": "defend", "label": "防守", "color": Color(0.4, 0.8, 0.4)},
		{"name": "retreat", "label": "撤退", "color": Color(0.8, 0.7, 0.3)}
	]

	var btn_x = 15
	for cmd in commands:
		var btn = Button.new()
		btn.text = cmd["label"]
		btn.position = Vector2(btn_x, 30)
		btn.size = Vector2(115, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.modulate = cmd["color"]
		btn.name = "Cmd_%s" % cmd["name"]
		btn.pressed.connect(_on_macro_command.bind(cmd["name"]))
		_command_panel.add_child(btn)
		_command_buttons[cmd["name"]] = btn
		btn_x += 125

	GameLog.info("RTSArenaController: Macro command UI setup complete", "Arena")


## Update macro command cooldown display
func _update_command_cooldown(delta: float) -> void:
	if _command_cooldown_timer > 0:
		_command_cooldown_timer -= delta
		if _command_cooldown_timer < 0:
			_command_cooldown_timer = 0

	if _command_cooldown_label:
		if _command_cooldown_timer > 0:
			_command_cooldown_label.text = "冷却: %d秒" % ceil(_command_cooldown_timer)
			_command_cooldown_label.modulate = Color(0.9, 0.6, 0.3)
			_set_commands_enabled(false)
		else:
			_command_cooldown_label.text = "就绪"
			_command_cooldown_label.modulate = Color(0.4, 0.9, 0.5)
			_set_commands_enabled(true)


## Set all command buttons enabled/disabled
func _set_commands_enabled(p_enabled: bool) -> void:
	for btn_name in _command_buttons.keys():
		if _command_buttons[btn_name]:
			_command_buttons[btn_name].disabled = not p_enabled


## Handle macro command button press
func _on_macro_command(p_command: String) -> void:
	if not _battle_active:
		return
	if _command_cooldown_timer > 0:
		return

	var result = RTSArenaManager.issue_player_command(p_command)
	if result.get("success", false):
		_command_cooldown_timer = 30.0
		AudioManager.play_sfx("ui_button_click")
		_add_log("教练指令: %s" % p_command)
		GameLog.info("RTSArenaController: Player issued command %s" % p_command, "Arena")
	else:
		AudioManager.play_sfx("ui_error")
		_add_log("指令失败: %s" % result.get("error", "unknown"))


## Process real-time UI updates
func _process(delta: float) -> void:
	if not _battle_active:
		return
	_update_unit_display()
	_update_skill_cooldowns()
	_update_command_cooldown(delta)
	if minimap:
		minimap.update_minimap()


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

	# Play battle start sound and BGM
	if AudioManager:
		AudioManager.play_sfx("ui_battle_start")
		AudioManager.play_bgm("battle")

	# Add ArenaMap to scene for rendering
	if ArenaMap and not is_instance_valid(ArenaMap.get_parent()):
		ArenaMap.position = Vector2(20, 90)
		add_child(ArenaMap)
	elif ArenaMap and ArenaMap.get_parent() != self:
		ArenaMap.get_parent().remove_child(ArenaMap)
		ArenaMap.position = Vector2(20, 90)
		add_child(ArenaMap)

	# Setup minimap
	if minimap:
		minimap.set_player_unit(RTSArenaManager.player_unit)
		minimap.set_ai_unit(RTSArenaManager.ai_unit)
		minimap.set_arena_map(ArenaMap)
		minimap.set_arena_size(Vector2(1280, 600))

	GameLog.info("RTSArenaController: Battle started", "Arena")


## Handle battle finished
func _on_battle_finished(p_result: String, p_winner_id: String, p_loser_id: String) -> void:
	_battle_active = false

	# Get battle result info
	var stats = BattleResultManager.get_stats()
	var history = BattleResultManager.get_history(1)
	var exp_gained = 0
	if history.size() > 0:
		exp_gained = history[history.size() - 1].get("experience_gained", 0)

	# Display result
	var result_text = ""
	match p_result:
		"victory":
			result_text = "VICTORY! +%d EXP" % exp_gained
			if AudioManager:
				AudioManager.play_sfx("bat_victory")
		"defeat":
			result_text = "DEFEAT... +%d EXP" % exp_gained
			if AudioManager:
				AudioManager.play_sfx("bat_defeat")
		"draw":
			result_text = "DRAW. +%d EXP" % exp_gained

	# Stop battle BGM
	if AudioManager:
		AudioManager.stop_bgm()

	_add_log("=== %s ===" % result_text)
	_add_log("Win Rate: %.1f%% (%d/%d)" % [stats.get("win_rate", 0), stats.get("victories", 0), stats.get("total_battles", 0)])
	_add_log("Streak: %d (Best: %d)" % [stats.get("current_streak", 0), stats.get("best_streak", 0)])

	# Disable all skill buttons
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			skill_buttons[skill_name].disabled = true

	GameLog.info("RTSArenaController: Battle finished - %s, EXP: +%d" % [p_result, exp_gained], "Arena")


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
	if AudioManager:
		AudioManager.play_sfx("bat_skill_cast")

func _on_quick_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("quick_strike")
	if AudioManager:
		AudioManager.play_sfx("bat_skill_cast")

func _on_heal_pressed() -> void:
	RTSArenaManager.player_use_skill("heal")
	if AudioManager:
		AudioManager.play_sfx("bat_skill_cast")

func _on_defend_pressed() -> void:
	RTSArenaManager.player_use_skill("defend")
	if AudioManager:
		AudioManager.play_sfx("bat_defend")


## Handle back button
func _on_back_pressed() -> void:
	RTSArenaManager.cleanup_battle()
	if AudioManager:
		AudioManager.play_sfx("ui_cancel")
		AudioManager.stop_bgm()
	# Remove ArenaMap from scene (keep as autoload)
	if ArenaMap and ArenaMap.get_parent() == self:
		remove_child(ArenaMap)
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
