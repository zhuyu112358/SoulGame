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

## Saved battle config for rematch
var _battle_config = {
	"player_soul": null,
	"ai_soul": null,
	"map_name": "default_arena"
}

## Macro command UI (design doc: coach-style RTS, player issues limited commands)
var _command_panel = null
var _command_buttons = {}
var _command_cooldown_label = null
var _command_cooldown_timer = 0.0
var _was_on_cooldown = false

## Weather/environment display
var _weather_label = null
var _weather_icon = null


func _ready() -> void:
	GameLog.info("RTSArenaController: RTS Arena scene ready", "Arena")
	_setup_ui_refs()
	_setup_arena_background()
	_connect_signals()
	_setup_skill_buttons()
	_setup_macro_commands()
	_setup_weather_display()
	_setup_button_hovers()

	# Auto-start battle if config is set in GameState
	_try_auto_start_battle()


## Setup hover effects for all buttons in the arena
func _setup_button_hovers() -> void:
	# Back button
	if back_button:
		_setup_button_hover(back_button)
	# Skill buttons
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			_setup_button_hover(skill_buttons[skill_name])
	# Macro command buttons
	for cmd_name in _command_buttons.keys():
		if _command_buttons[cmd_name]:
			_setup_button_hover(_command_buttons[cmd_name])


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
		# Save config for rematch
		_battle_config["player_soul"] = player_soul
		_battle_config["ai_soul"] = ai_soul
		_battle_config["map_name"] = map_name
		RTSArenaManager.start_battle(player_soul, ai_soul, map_name)
		_battle_active = true
		# Play game start sound
		if AudioManager:
			AudioManager.play_sfx("ui_game_start")
			AudioManager.play_sfx("battle_countdown")
		# Clear battle config from GameState after use (keep local copy for rematch)
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
			_was_on_cooldown = true
		else:
			_command_cooldown_label.text = "就绪"
			_command_cooldown_label.modulate = Color(0.4, 0.9, 0.5)
			_set_commands_enabled(true)
			# Play notification sound when cooldown finishes
			if _was_on_cooldown:
				_was_on_cooldown = false
				if AudioManager:
					AudioManager.play_sfx("ui_notification")
				_add_log("教练指令已就绪")


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
		# Play command-specific sound
		match p_command:
			"gather":
				AudioManager.play_sfx("battle_gather")
			"attack":
				AudioManager.play_sfx("battle_unit_attack")
			"defend":
				AudioManager.play_sfx("battle_shield")
			"retreat":
				AudioManager.play_sfx("battle_unit_move")
			_:
				AudioManager.play_sfx("ui_button_click")
		_add_log("教练指令: %s" % p_command)
		GameLog.info("RTSArenaController: Player issued command %s" % p_command, "Arena")
	else:
		AudioManager.play_sfx("ui_error")
		_add_log("指令失败: %s" % result.get("error", "unknown"))


## Setup weather/environment display UI
func _setup_weather_display() -> void:
	# Weather label (top-right, below battle time)
	_weather_label = Label.new()
	_weather_label.position = Vector2(1050, 50)
	_weather_label.size = Vector2(200, 30)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weather_label.add_theme_font_size_override("font_size", 14)
	_weather_label.modulate = Color(0.8, 0.9, 1.0)
	_weather_label.text = "Weather: --"
	add_child(_weather_label)

	# Weather effect indicators (small labels below weather name)
	var effect_label = Label.new()
	effect_label.name = "WeatherEffects"
	effect_label.position = Vector2(1050, 75)
	effect_label.size = Vector2(200, 50)
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.modulate = Color(0.7, 0.7, 0.8)
	effect_label.text = ""
	add_child(effect_label)

	GameLog.info("RTSArenaController: Weather display setup", "Arena")


## Update weather display from RTSArenaManager environment
func _update_weather_display() -> void:
	if _weather_label == null:
		return

	var env_info = RTSArenaManager.get_environment_info()
	var weather_name = env_info.get("weather", "Clear")
	_weather_label.text = "Weather: %s" % weather_name

	# Weather color coding
	match weather_name:
		"Clear":
			_weather_label.modulate = Color(1.0, 0.95, 0.7)
		"Rain":
			_weather_label.modulate = Color(0.6, 0.8, 1.0)
		"Fog":
			_weather_label.modulate = Color(0.75, 0.75, 0.8)
		"Snow":
			_weather_label.modulate = Color(0.85, 0.95, 1.0)
		"Storm":
			_weather_label.modulate = Color(1.0, 0.6, 0.5)
		_:
			_weather_label.modulate = Color(0.8, 0.9, 1.0)

	# Update effect indicators
	var effect_label = get_node_or_null("WeatherEffects")
	if effect_label:
		var move_mod = env_info.get("movement_mod", 1.0)
		var acc_mod = env_info.get("accuracy_mod", 1.0)
		var effects = []
		if move_mod < 1.0:
			effects.append("SPD %.0f%%" % (move_mod * 100))
		if acc_mod < 1.0:
			effects.append("ACC %.0f%%" % (acc_mod * 100))
		if weather_name == "Storm":
			effects.append("⚡ Lightning")
		if weather_name == "Snow":
			effects.append("DEF +10%")
		effect_label.text = "  ".join(effects)


## Process real-time UI updates
func _process(delta: float) -> void:
	if not _battle_active:
		return
	_update_unit_display()
	_update_skill_cooldowns()
	_update_command_cooldown(delta)
	_update_weather_display()
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
	var result_color = Color.WHITE
	match p_result:
		"victory":
			result_text = "VICTORY!"
			result_color = Color(0.4, 0.9, 0.5)
			if AudioManager:
				AudioManager.play_sfx("bat_victory")
				AudioManager.play_bgm("victory_celebration")
		"defeat":
			result_text = "DEFEAT..."
			result_color = Color(0.9, 0.4, 0.4)
			if AudioManager:
				AudioManager.play_sfx("bat_defeat")
		"draw":
			result_text = "DRAW"
			result_color = Color(0.8, 0.8, 0.4)

	# Stop battle BGM (except victory celebration)
	if AudioManager and p_result != "victory":
		AudioManager.stop_bgm()

	_add_log("=== %s +%d EXP ===" % [result_text, exp_gained])
	_add_log("Win Rate: %.1f%% (%d/%d)" % [stats.get("win_rate", 0), stats.get("victories", 0), stats.get("total_battles", 0)])
	_add_log("Streak: %d (Best: %d)" % [stats.get("current_streak", 0), stats.get("best_streak", 0)])

	# Disable all skill buttons
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			skill_buttons[skill_name].disabled = true

	# Disable macro command buttons
	_set_commands_enabled(false)

	# Show battle result modal
	_show_result_modal(p_result, result_text, result_color, exp_gained, stats)

	GameLog.info("RTSArenaController: Battle finished - %s, EXP: +%d" % [p_result, exp_gained], "Arena")


## Show battle result modal dialog
func _show_result_modal(p_result: String, p_title: String, p_title_color: Color, p_exp: int, p_stats: Dictionary) -> void:
	# Play EXP gain sound
	if AudioManager:
		AudioManager.play_sfx("ui_exp_gain")

	# Create modal background (semi-transparent dark overlay)
	var modal_bg = ColorRect.new()
	modal_bg.color = Color(0, 0, 0, 0.75)
	modal_bg.size = Vector2(1280, 720)
	modal_bg.name = "ResultModalBG"
	add_child(modal_bg)

	# Create result panel
	var panel = Panel.new()
	panel.position = Vector2(390, 180)
	panel.size = Vector2(500, 360)
	panel.name = "ResultModal"
	add_child(panel)

	# Title
	var title = Label.new()
	title.text = p_title
	title.position = Vector2(0, 25)
	title.size = Vector2(500, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = p_title_color
	panel.add_child(title)

	# EXP gained
	var exp_label = Label.new()
	exp_label.text = "Experience Gained: +%d" % p_exp
	exp_label.position = Vector2(0, 85)
	exp_label.size = Vector2(500, 30)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 18)
	exp_label.modulate = Color(0.9, 0.8, 0.4)
	panel.add_child(exp_label)

	# Separator
	var sep = HSeparator.new()
	sep.position = Vector2(50, 125)
	sep.size = Vector2(400, 10)
	panel.add_child(sep)

	# Stats
	var stats_text = "Win Rate: %.1f%%  (%d/%d)\n" % [
		p_stats.get("win_rate", 0),
		p_stats.get("victories", 0),
		p_stats.get("total_battles", 0)
	]
	stats_text += "Current Streak: %d  (Best: %d)\n" % [
		p_stats.get("current_streak", 0),
		p_stats.get("best_streak", 0)
	]
	stats_text += "Total EXP: %d" % p_stats.get("total_experience_gained", 0)

	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(50, 145)
	stats_label.size = Vector2(400, 100)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.modulate = Color(0.85, 0.85, 0.9)
	panel.add_child(stats_label)

	# Buttons
	var btn_y = 280

	# Rematch button
	var rematch_btn = Button.new()
	rematch_btn.text = "再战一局"
	rematch_btn.position = Vector2(80, btn_y)
	rematch_btn.size = Vector2(150, 45)
	rematch_btn.add_theme_font_size_override("font_size", 16)
	rematch_btn.modulate = Color(0.4, 0.7, 0.9)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	_setup_button_hover(rematch_btn)
	panel.add_child(rematch_btn)

	# Back to menu button
	var back_btn = Button.new()
	back_btn.text = "返回主菜单"
	back_btn.position = Vector2(270, btn_y)
	back_btn.size = Vector2(150, 45)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.modulate = Color(0.7, 0.7, 0.7)
	back_btn.pressed.connect(_on_back_to_menu_pressed)
	_setup_button_hover(back_btn)
	panel.add_child(back_btn)

	GameLog.info("RTSArenaController: Result modal shown", "Arena")


## Handle rematch button press
func _on_rematch_pressed() -> void:
	AudioManager.play_sfx("ui_button_click")
	# Remove modal
	var modal = get_node_or_null("ResultModal")
	var modal_bg = get_node_or_null("ResultModalBG")
	if modal:
		modal.queue_free()
	if modal_bg:
		modal_bg.queue_free()

	# Restart battle with saved config
	var player_soul = _battle_config["player_soul"]
	var ai_soul = _battle_config["ai_soul"]
	var map_name = _battle_config["map_name"]

	if player_soul != null and ai_soul != null:
		# Reset and restart battle
		RTSArenaManager.reset_battle()
		RTSArenaManager.start_battle(player_soul, ai_soul, map_name)
		_battle_active = true
		# Re-enable skill buttons
		for skill_name in skill_buttons.keys():
			if skill_buttons[skill_name]:
				skill_buttons[skill_name].disabled = false
	else:
		_add_log("No battle config found for rematch")


## Handle back to menu button press
func _on_back_to_menu_pressed() -> void:
	AudioManager.play_sfx("ui_button_click")
	# Return to main menu
	RTSArenaManager.reset_battle()
	SceneManager.change_scene("res://scenes/main_menu.tscn")


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
		AudioManager.play_sfx("battle_skill_hit")

func _on_quick_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("quick_strike")
	if AudioManager:
		AudioManager.play_sfx("battle_skill_hit")

func _on_heal_pressed() -> void:
	RTSArenaManager.player_use_skill("heal")
	if AudioManager:
		AudioManager.play_sfx("battle_heal")

func _on_defend_pressed() -> void:
	RTSArenaManager.player_use_skill("defend")
	if AudioManager:
		AudioManager.play_sfx("battle_shield")


## Handle back button - return to main menu
func _on_back_pressed() -> void:
	RTSArenaManager.cleanup_battle()
	if AudioManager:
		AudioManager.play_sfx("ui_cancel")
		AudioManager.stop_bgm()
	# Remove ArenaMap from scene (keep as autoload)
	if ArenaMap and ArenaMap.get_parent() == self:
		remove_child(ArenaMap)
	SceneManager.change_scene("res://scenes/main_menu.tscn")


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
	_battle_config["player_soul"] = player_soul
	_battle_config["ai_soul"] = ai_soul
	_battle_config["map_name"] = "default_arena"
	RTSArenaManager.start_battle(player_soul, ai_soul)
	_battle_active = true
