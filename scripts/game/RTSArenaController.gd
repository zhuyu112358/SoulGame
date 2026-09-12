extends Node2D
## RTSArenaController - Controller for the RTS arena battle scene
##
## Manages the RTS arena UI: unit displays, HP/energy bars, skill buttons,
## battle log, and real-time battle visualization. Connects to RTSArenaManager.
##
## This is game-specific UI for RTS combat, not SDK kernel code.

## Write debug log to file (user://debug_controller.log)
static func _dlog(msg: String) -> void:
	var f = FileAccess.open("user://debug_controller.log", FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line(Time.get_datetime_string_from_system() + " " + msg)
		f.close()

## Arena background generator (procedural pixel art)
const ArenaBackgroundGenerator = preload("res://scripts/game/ArenaBackgroundGenerator.gd")
const FontLoader = preload("res://scripts/core/FontLoader.gd")
const PixelSpriteGenerator = preload("res://scripts/game/PixelSpriteGenerator.gd")
const TacticalCommandSystem = preload("res://scripts/game/TacticalCommandSystem.gd")

## UI node references
var player_hp_bar = null
var player_energy_bar = null
var player_name_label = null
var ai_hp_bar = null
var ai_energy_bar = null
var ai_name_label = null
var battle_time_label = null
var battle_log = null
var _player_hp_value_label = null
var _player_energy_value_label = null
var _ai_hp_value_label = null
var _ai_energy_value_label = null
var skill_buttons = {}

## Energy bar smooth transition
var _target_player_energy: float = 0.0
var _current_player_energy: float = 0.0
var _target_ai_energy: float = 0.0
var _current_ai_energy: float = 0.0
var _energy_bar_smooth_speed: float = 5.0
var back_button = null
var arena_viewport = null
var minimap = null

## SoulUnit preload
const SoulUnit = preload("res://scripts/game/SoulUnit.gd")
const Minimap = preload("res://scripts/ui/Minimap.gd")
const TalentSystem = preload("res://scripts/game/TalentSystem.gd")
const ItemSystem = preload("res://scripts/game/ItemSystem.gd")
const AchievementSystem = preload("res://scripts/game/AchievementSystem.gd")
const TrapSystem = preload("res://scripts/game/TrapSystem.gd")
const SoulUpgradeSystem = preload("res://scripts/game/SoulUpgradeSystem.gd")
const IntelligenceUpgradeSystem = preload("res://scripts/game/IntelligenceUpgradeSystem.gd")
const TrainingBattleSystem = preload("res://scripts/game/TrainingBattleSystem.gd")

## Visual unit nodes
var _player_visual = null  # Sprite2D proxy (SoulUnit is child of autoload, not in visible scene)
var _ai_visual = null
var _player_light = null
var _ai_light = null

## GAP-001: Team battle visual proxies (4v4)
var _player_visuals: Array = []  # Array of Sprite2D proxies for player team
var _ai_visuals: Array = []      # Array of Sprite2D proxies for AI team
var _player_lights: Array = []   # Array of PointLight2D for player team
var _ai_lights: Array = []       # Array of PointLight2D for AI team
var _team_hp_container = null    # Container for team HP bars
var _player_team_hp_bars: Array = []  # HP bars for player team units
var _ai_team_hp_bars: Array = []      # HP bars for AI team units
var _player_unit_containers: Array = []  # Clickable containers for player unit selection
var _selection_indicator = null  # Gold circle indicator for selected unit
var _selected_unit_panel = null  # Info panel for selected unit
var _selected_unit_index: int = 0     # Currently selected player unit (for tactical commands)

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
var _skill_was_on_cooldown = {}

## Screen shake effect (combat feedback)
var _screen_shake_timer = 0.0
var _screen_shake_intensity = 0.0
var _screen_shake_max_duration = 0.2
var _base_position = Vector2.ZERO

## Hit flash effect (combat feedback)
var _hit_flash = null
var _hit_flash_timer = 0.0
var _hit_flash_duration = 0.0

## Skill particle effect (combat feedback)
var _skill_particles = []
var _skill_particle_timer = 0.0

## Cached particle textures from particle_texture_sheet.png (2x4 atlas)
var _particle_textures = {}  # {skill_name: Texture2D}
var _particle_textures_loaded = false

## Skill cooldown overlays (visual cooldown indicator)
var _skill_cooldown_overlays = {}
## Skill cooldown number labels
var _skill_cooldown_labels = {}

## Weather/environment display
var _weather_label = null
var _weather_icon = null
var _last_weather = ""

## Battle start countdown
var _countdown_label = null
var _countdown_timer = 0.0
var _countdown_active = false
var _pending_battle_config = null
var _last_countdown_text = ""

## Battle pause system
var _pause_button = null
var _pause_overlay = null
var _pause_label = null
var _is_paused = false

## Battle speed control
var _speed_button = null
var _current_speed = 1.0
var _speed_options = [1.0, 1.5, 2.0]

## Tactical command system (GDD v2.0 Chapter 2.1.1)
var _tactical_system = null
var _tactical_buttons = {}
var _current_tactical_command = "free"
var _tactical_indicator = null

## In-battle talent upgrade system (GDD v2.0 Chapter 5)
var _talent_system = null
var _talent_panel = null
var _talent_buttons = []
var _talent_active = false

## Battle item system (GDD v2.0 Chapter 7)
var _item_system = null
var _item_container = null  # Node2D container for item sprites

## Achievement system (GDD v2.0 Chapter 13)
var _achievement_system = null
var _achievement_popup = null  # Achievement unlock notification

## Trap system (GDD v2.0 Chapter 7)
var _trap_system = null
var _trap_container = null  # Node2D container for trap sprites

## Soul upgrade system (GDD v2.0 Chapter 5 - Permanent cross-battle)
var _soul_upgrade_system = null

## Intelligence upgrade system (GDD v2.0 Chapter 5 - Ember core differentiator)
var _intelligence_upgrade_system = null

## Status effect display
var _player_status_label = null
var _ai_status_label = null
var _player_status_icons = null
var _ai_status_icons = null
var _status_icon_sheet = null

## Error/success message display
var _error_label = null
var _error_timer = 0.0
var _error_active = false
var _success_label = null
var _success_timer = 0.0
var _success_active = false

## Critical hit display
var _crit_label = null
var _crit_timer = 0.0
var _crit_active = false

## Dodge display
var _dodge_label = null
var _dodge_timer = 0.0
var _dodge_active = false

## Heal display
var _heal_label = null
var _heal_timer = 0.0
var _heal_active = false

## Defend display
var _defend_label = null
var _defend_timer = 0.0
var _defend_active = false

## Skill usage display
var _skill_label = null
var _skill_timer = 0.0
var _skill_active = false

## Damage floating text display (multiple labels for simultaneous damage)
var _damage_labels = []  # Array of {label, timer, duration, start_y}
var _damage_max_labels = 8

## Single damage label compatibility (for tests/simple API)
var _damage_label: Label = null
var _damage_timer: float = 0.0
var _damage_active: bool = false

## Atmosphere effects
var _ambient_particles = []  # Array of {particle, velocity, base_y, phase}
var _magic_dust = []  # Array of {particle, velocity, phase, base_x, base_y}
var _vignette_sprite: Sprite2D = null
var _chromatic_layer: CanvasLayer = null
var _chromatic_rect: ColorRect = null
var _chromatic_intensity: float = 0.0
var _chromatic_decay: float = 0.0
var _countdown_value: int = 3
var _ambient_time: float = 0.0


## Clean up all dynamically created resources to prevent memory leaks
func _exit_tree() -> void:
	_dlog("[DEBUG-EXIT] _exit_tree() start - cleaning up resources")

	# GAP-001: Clean up team battle visuals
	_clear_team_visuals()

	# Clean up damage labels
	for dmg_data in _damage_labels:
		if dmg_data and dmg_data.label and is_instance_valid(dmg_data.label):
			dmg_data.label.queue_free()
	_damage_labels.clear()
	if _damage_label and is_instance_valid(_damage_label):
		_damage_label.queue_free()
		_damage_label = null

	# Clean up skill particles
	for p_data in _skill_particles:
		if p_data and p_data.has("particle") and p_data["particle"] and is_instance_valid(p_data["particle"]):
			p_data["particle"].queue_free()
	_skill_particles.clear()

	# Clean up ambient particles
	for ap in _ambient_particles:
		if ap and ap.has("particle") and ap["particle"] and is_instance_valid(ap["particle"]):
			ap["particle"].queue_free()
	_ambient_particles.clear()

	# Clean up magic dust
	for md in _magic_dust:
		if md and md.has("particle") and md["particle"] and is_instance_valid(md["particle"]):
			md["particle"].queue_free()
	_magic_dust.clear()

	# Clean up visual units
	if _player_visual and is_instance_valid(_player_visual):
		_player_visual.queue_free()
		_player_visual = null
	if _ai_visual and is_instance_valid(_ai_visual):
		_ai_visual.queue_free()
		_ai_visual = null
	if _player_light and is_instance_valid(_player_light):
		_player_light.queue_free()
		_player_light = null
	if _ai_light and is_instance_valid(_ai_light):
		_ai_light.queue_free()
		_ai_light = null

	# Clean up systems (they are children, will be freed with parent, but explicit is safer)
	if _item_system and is_instance_valid(_item_system):
		_item_system.queue_free()
		_item_system = null
	if _trap_system and is_instance_valid(_trap_system):
		_trap_system.queue_free()
		_trap_system = null
	if _talent_system and is_instance_valid(_talent_system):
		_talent_system.queue_free()
		_talent_system = null
	if _achievement_system and is_instance_valid(_achievement_system):
		_achievement_system.queue_free()
		_achievement_system = null
	if _tactical_system and is_instance_valid(_tactical_system):
		_tactical_system.queue_free()
		_tactical_system = null

	# Clean up containers
	if _item_container and is_instance_valid(_item_container):
		_item_container.queue_free()
		_item_container = null
	if _trap_container and is_instance_valid(_trap_container):
		_trap_container.queue_free()
		_trap_container = null

	# Clean up UI panels
	if _command_panel and is_instance_valid(_command_panel):
		_command_panel.queue_free()
		_command_panel = null
	if _pause_overlay and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
		_pause_overlay = null
	if _talent_panel and is_instance_valid(_talent_panel):
		_talent_panel.queue_free()
		_talent_panel = null
	if _achievement_popup and is_instance_valid(_achievement_popup):
		_achievement_popup.queue_free()
		_achievement_popup = null
	if _countdown_label and is_instance_valid(_countdown_label):
		_countdown_label.queue_free()
		_countdown_label = null
	if _hit_flash and is_instance_valid(_hit_flash):
		_hit_flash.queue_free()
		_hit_flash = null
	if _vignette_sprite and is_instance_valid(_vignette_sprite):
		_vignette_sprite.queue_free()
		_vignette_sprite = null
	if _chromatic_layer and is_instance_valid(_chromatic_layer):
		_chromatic_layer.queue_free()
		_chromatic_layer = null
	if _chromatic_rect and is_instance_valid(_chromatic_rect):
		_chromatic_rect.queue_free()
		_chromatic_rect = null

	# Clean up status labels
	if _player_status_label and is_instance_valid(_player_status_label):
		_player_status_label.queue_free()
	if _ai_status_label and is_instance_valid(_ai_status_label):
		_ai_status_label.queue_free()
	if _player_status_icons and is_instance_valid(_player_status_icons):
		_player_status_icons.queue_free()
	if _ai_status_icons and is_instance_valid(_ai_status_icons):
		_ai_status_icons.queue_free()

	# Clean up combat feedback labels
	for label in [_error_label, _success_label, _crit_label, _dodge_label, _heal_label, _defend_label, _skill_label, _weather_label]:
		if label and is_instance_valid(label):
			label.queue_free()

	# Clean up button dictionaries
	_command_buttons.clear()
	skill_buttons.clear()
	_skill_cooldown_overlays.clear()
	_skill_cooldown_labels.clear()
	_tactical_buttons.clear()
	_talent_buttons.clear()

	# Clean up cached textures
	_particle_textures.clear()
	_particle_textures_loaded = false

	# Reset state
	_battle_active = false
	_is_paused = false
	_countdown_active = false
	_talent_active = false
	_error_active = false
	_success_active = false
	_crit_active = false
	_dodge_active = false
	_heal_active = false
	_defend_active = false
	_skill_active = false

	_dlog("[DEBUG-EXIT] _exit_tree() complete - all resources cleaned")
	GameLog.info("RTSArenaController: Scene exit, resources cleaned", "Arena")


func _ready() -> void:
	_dlog("[DEBUG-READY] _ready() start")
	GameLog.info("RTSArenaController: RTS Arena scene ready", "Arena")
	_base_position = position
	# Initialize achievement system (loads saved data)
	_init_achievement_system()
	# Initialize soul upgrade system (loads saved permanent upgrades)
	_init_soul_upgrade_system()
	# Initialize intelligence upgrade system (Ember core differentiator)
	_init_intelligence_upgrade_system()
	_dlog("[DEBUG-READY] before _setup_ui_refs")
	_setup_ui_refs()
	_dlog("[DEBUG-READY] after _setup_ui_refs, before _apply_ui_theme")
	_apply_ui_theme()
	_dlog("[DEBUG-READY] after _apply_ui_theme, before _apply_hp_energy_styles")
	_apply_hp_energy_styles()
	_setup_main_hp_energy_labels()
	_dlog("[DEBUG-READY] after _apply_hp_energy_styles, before _apply_hud_skin")
	_apply_hud_skin()
	_dlog("[DEBUG-READY] after _apply_hud_skin, before _load_particle_textures")
	_load_particle_textures()
	_dlog("[DEBUG-READY] after _load_particle_textures, before _setup_arena_background")
	# Font application temporarily disabled - causes static type parse error
	# for child in get_children():
	# 	if child is Control:
	# 		FontLoader.apply_font_to_control(child)
	_setup_arena_background()
	_dlog("[DEBUG-READY] after _setup_arena_background")
	_setup_atmosphere_effects()
	_setup_chromatic_aberration()
	_connect_signals()
	_setup_skill_buttons()
	_setup_macro_commands()
	_setup_weather_display()
	_setup_button_hovers()
	_animate_hud_entry()
	_setup_pause_button()
	_setup_speed_button()
	_setup_status_labels()
	_setup_crit_label()
	_setup_dodge_label()
	_setup_heal_label()
	_setup_defend_label()
	_setup_skill_label()
	_setup_damage_label()
	_setup_error_label()
	_setup_success_label()
	_setup_hit_flash()

	# Auto-start battle if config is set in GameState
	_try_auto_start_battle()


## Animate HUD entry with staggered fade-in + scale (game-level UI)
func _animate_hud_entry() -> void:
	# Collect HUD panels in order
	var hud_elements = [
		get_node_or_null("TopBar"),
		get_node_or_null("Minimap"),
		get_node_or_null("BattleLog"),
		get_node_or_null("BottomBar"),
	]
	var delay := 0.1
	for element in hud_elements:
		if element and element is CanvasItem:
			# Set initial state: invisible + scaled down
			element.modulate.a = 0.0
			element.scale = Vector2(0.95, 0.95)
			# Create tween for fade-in + scale-up
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_interval(delay)
			tween.parallel().tween_property(element, "modulate:a", 1.0, 0.4)
			tween.parallel().tween_property(element, "scale", Vector2(1.0, 1.0), 0.4)
			delay += 0.12
	# Animate team HP bars with extra delay
	await get_tree().create_timer(0.5).timeout
	for i in range(_player_unit_containers.size()):
		var container = _player_unit_containers[i]
		if container and is_instance_valid(container):
			container.modulate.a = 0.0
			container.scale = Vector2(0.9, 0.9)
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_interval(i * 0.08)
			tween.parallel().tween_property(container, "modulate:a", 1.0, 0.3)
			tween.parallel().tween_property(container, "scale", Vector2(1.0, 1.0), 0.3)


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


## Setup pause button UI
func _setup_pause_button() -> void:
	# Create pause button in top bar area
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = "暂停"
	_pause_button.position = Vector2(600, 10)
	_pause_button.size = Vector2(80, 35)
	_pause_button.add_theme_font_size_override("font_size", 14)
	# Game-level style: dark purple with gold border
	var pause_style = StyleBoxFlat.new()
	pause_style.bg_color = Color(0.12, 0.08, 0.22)
	pause_style.border_color = Color(0.83, 0.66, 0.36)
	pause_style.border_width_left = 2
	pause_style.border_width_right = 2
	pause_style.border_width_top = 2
	pause_style.border_width_bottom = 2
	pause_style.corner_radius_top_left = 6
	pause_style.corner_radius_top_right = 6
	pause_style.corner_radius_bottom_left = 6
	pause_style.corner_radius_bottom_right = 6
	_pause_button.add_theme_stylebox_override("normal", pause_style)
	# Hover style: brighter bg + lighter gold border
	var pause_hover = StyleBoxFlat.new()
	pause_hover.bg_color = Color(0.2, 0.14, 0.32)
	pause_hover.border_color = Color(1.0, 0.88, 0.5)
	pause_hover.border_width_left = 3
	pause_hover.border_width_right = 3
	pause_hover.border_width_top = 3
	pause_hover.border_width_bottom = 3
	pause_hover.corner_radius_top_left = 6
	pause_hover.corner_radius_top_right = 6
	pause_hover.corner_radius_bottom_left = 6
	pause_hover.corner_radius_bottom_right = 6
	_pause_button.add_theme_stylebox_override("hover", pause_hover)
	# Pressed style: darker bg
	var pause_pressed = StyleBoxFlat.new()
	pause_pressed.bg_color = Color(0.08, 0.05, 0.15)
	pause_pressed.border_color = Color(0.7, 0.55, 0.3)
	pause_pressed.border_width_left = 2
	pause_pressed.border_width_right = 2
	pause_pressed.border_width_top = 2
	pause_pressed.border_width_bottom = 2
	pause_pressed.corner_radius_top_left = 6
	pause_pressed.corner_radius_top_right = 6
	pause_pressed.corner_radius_bottom_left = 6
	pause_pressed.corner_radius_bottom_right = 6
	_pause_button.add_theme_stylebox_override("pressed", pause_pressed)
	_pause_button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_pause_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_setup_button_hover(_pause_button)
	add_child(_pause_button)


## Handle pause button press
func _on_pause_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	if _is_paused:
		_resume_battle()
	else:
		_pause_battle()


## Pause the battle
func _pause_battle() -> void:
	if not _battle_active or _is_paused:
		return
	_is_paused = true
	RTSArenaManager.pause_battle()
	_show_pause_overlay()
	# Play panel open sound
	if AudioManager:
		AudioManager.play_sfx("ui_panel_open")
	# Disable skill and command buttons during pause
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			skill_buttons[skill_name].disabled = true
	for cmd_name in _command_buttons.keys():
		if _command_buttons[cmd_name]:
			_command_buttons[cmd_name].disabled = true
	if _pause_button:
		_pause_button.text = "继续"
	_add_log("战斗已暂停")


## Resume the battle
func _resume_battle() -> void:
	if not _is_paused:
		return
	_is_paused = false
	RTSArenaManager.resume_battle()
	_hide_pause_overlay()
	# Play panel close sound
	if AudioManager:
		AudioManager.play_sfx("ui_panel_close")
	# Re-enable skill and command buttons
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			skill_buttons[skill_name].disabled = false
	for cmd_name in _command_buttons.keys():
		if _command_buttons[cmd_name]:
			_command_buttons[cmd_name].disabled = false
	if _pause_button:
		_pause_button.text = "暂停"
	_add_log("战斗已继续")


## Show pause overlay (beautified: dark purple panel + gold border + buttons)
func _show_pause_overlay() -> void:
	if _pause_overlay != null:
		return
	# Create semi-transparent dark purple overlay
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0.08, 0.05, 0.15, 0.75)
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_overlay)

	# Create pause panel (dark purple with gold border)
	var panel = Panel.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -150)
	panel.size = Vector2(400, 300)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.22, 0.95)
	panel_style.border_color = Color(0.83, 0.66, 0.36)  # Gold #d4a85c
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	_pause_overlay.add_child(panel)

	# Create pause title
	_pause_label = Label.new()
	_pause_label.name = "PauseLabel"
	_pause_label.text = "战斗暂停"
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.position = Vector2(-150, -120)
	_pause_label.size = Vector2(300, 60)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 42)
	_pause_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_pause_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_pause_label.add_theme_constant_override("outline_size", 4)
	panel.add_child(_pause_label)

	# Gold decorative line under title
	var title_line = ColorRect.new()
	title_line.name = "TitleLine"
	title_line.color = Color(0.83, 0.66, 0.36, 0.8)
	title_line.position = Vector2(80, -50)
	title_line.size = Vector2(240, 2)
	panel.add_child(title_line)

	# Resume button
	var resume_btn = Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.text = "▶ 继续战斗"
	resume_btn.position = Vector2(100, -20)
	resume_btn.size = Vector2(200, 50)
	resume_btn.add_theme_font_size_override("font_size", 18)
	var resume_style = StyleBoxFlat.new()
	resume_style.bg_color = Color(0.15, 0.1, 0.28)
	resume_style.border_color = Color(0.83, 0.66, 0.36)
	resume_style.border_width_left = 2
	resume_style.border_width_right = 2
	resume_style.border_width_top = 2
	resume_style.border_width_bottom = 2
	resume_style.corner_radius_top_left = 8
	resume_style.corner_radius_top_right = 8
	resume_style.corner_radius_bottom_left = 8
	resume_style.corner_radius_bottom_right = 8
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	# Hover style: brighter bg + lighter gold border
	var resume_hover = StyleBoxFlat.new()
	resume_hover.bg_color = Color(0.22, 0.15, 0.35)
	resume_hover.border_color = Color(1.0, 0.88, 0.5)
	resume_hover.border_width_left = 3
	resume_hover.border_width_right = 3
	resume_hover.border_width_top = 3
	resume_hover.border_width_bottom = 3
	resume_hover.corner_radius_top_left = 8
	resume_hover.corner_radius_top_right = 8
	resume_hover.corner_radius_bottom_left = 8
	resume_hover.corner_radius_bottom_right = 8
	resume_btn.add_theme_stylebox_override("hover", resume_hover)
	# Pressed style: darker bg
	var resume_pressed = StyleBoxFlat.new()
	resume_pressed.bg_color = Color(0.10, 0.07, 0.18)
	resume_pressed.border_color = Color(0.7, 0.55, 0.3)
	resume_pressed.border_width_left = 2
	resume_pressed.border_width_right = 2
	resume_pressed.border_width_top = 2
	resume_pressed.border_width_bottom = 2
	resume_pressed.corner_radius_top_left = 8
	resume_pressed.corner_radius_top_right = 8
	resume_pressed.corner_radius_bottom_left = 8
	resume_pressed.corner_radius_bottom_right = 8
	resume_btn.add_theme_stylebox_override("pressed", resume_pressed)
	resume_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	resume_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	resume_btn.pressed.connect(_resume_battle)
	panel.add_child(resume_btn)

	# Quit to menu button
	var quit_btn = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "🏠 返回主菜单"
	quit_btn.position = Vector2(100, 50)
	quit_btn.size = Vector2(200, 50)
	quit_btn.add_theme_font_size_override("font_size", 18)
	var quit_style = StyleBoxFlat.new()
	quit_style.bg_color = Color(0.15, 0.1, 0.28)
	quit_style.border_color = Color(0.7, 0.4, 0.4)
	quit_style.border_width_left = 2
	quit_style.border_width_right = 2
	quit_style.border_width_top = 2
	quit_style.border_width_bottom = 2
	quit_style.corner_radius_top_left = 8
	quit_style.corner_radius_top_right = 8
	quit_style.corner_radius_bottom_left = 8
	quit_style.corner_radius_bottom_right = 8
	quit_btn.add_theme_stylebox_override("normal", quit_style)
	# Hover style: brighter bg + lighter red border
	var quit_hover = StyleBoxFlat.new()
	quit_hover.bg_color = Color(0.22, 0.12, 0.18)
	quit_hover.border_color = Color(0.9, 0.55, 0.55)
	quit_hover.border_width_left = 3
	quit_hover.border_width_right = 3
	quit_hover.border_width_top = 3
	quit_hover.border_width_bottom = 3
	quit_hover.corner_radius_top_left = 8
	quit_hover.corner_radius_top_right = 8
	quit_hover.corner_radius_bottom_left = 8
	quit_hover.corner_radius_bottom_right = 8
	quit_btn.add_theme_stylebox_override("hover", quit_hover)
	# Pressed style: darker bg
	var quit_pressed = StyleBoxFlat.new()
	quit_pressed.bg_color = Color(0.10, 0.06, 0.10)
	quit_pressed.border_color = Color(0.55, 0.3, 0.3)
	quit_pressed.border_width_left = 2
	quit_pressed.border_width_right = 2
	quit_pressed.border_width_top = 2
	quit_pressed.border_width_bottom = 2
	quit_pressed.corner_radius_top_left = 8
	quit_pressed.corner_radius_top_right = 8
	quit_pressed.corner_radius_bottom_left = 8
	quit_pressed.corner_radius_bottom_right = 8
	quit_btn.add_theme_stylebox_override("pressed", quit_pressed)
	quit_btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.7))
	quit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.8))
	quit_btn.pressed.connect(_on_pause_quit_pressed)
	panel.add_child(quit_btn)

	# Hint text
	var hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "按 ESC 或 空格 继续"
	hint_label.position = Vector2(100, 120)
	hint_label.size = Vector2(200, 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	panel.add_child(hint_label)


## Hide pause overlay
func _hide_pause_overlay() -> void:
	if _pause_overlay != null:
		_pause_overlay.queue_free()
		_pause_overlay = null
		_pause_label = null


## Handle quit to main menu from pause overlay
func _on_pause_quit_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_resume_battle()
	# Return to main menu
	if get_tree().has_autoload("SceneManager"):
		SceneManager.change_scene("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Handle input: ESC/Space to pause, left-click to move, 1-4 for skills
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			if _battle_active:
				if _is_paused:
					_resume_battle()
				else:
					_pause_battle()
				get_viewport().set_input_as_handled()
		# Keyboard shortcuts for skills (1-4)
		if _battle_active and not _is_paused:
			match event.keycode:
				KEY_1:
					_on_heavy_strike_pressed()
					get_viewport().set_input_as_handled()
				KEY_2:
					_on_quick_strike_pressed()
					get_viewport().set_input_as_handled()
				KEY_3:
					_on_heal_pressed()
					get_viewport().set_input_as_handled()
				KEY_4:
					_on_defend_pressed()
					get_viewport().set_input_as_handled()
				KEY_S:
					# Stop command: stop selected unit or all units
					var is_team_s = GameState.get_value("battle", "is_team_battle", false)
					if is_team_s:
						if _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
							RTSArenaManager.stop_player_unit(_selected_unit_index)
						else:
							RTSArenaManager.stop_all_player_units()
					elif RTSArenaManager.player_unit:
						RTSArenaManager.player_unit.stop()
					if AudioManager:
						AudioManager.play_sfx("ui_button_click", 0.3)
					get_viewport().set_input_as_handled()
				KEY_TAB:
					# Cycle to next alive player unit (4v4 team battle)
					var is_team_tab = GameState.get_value("battle", "is_team_battle", false)
					if is_team_tab and RTSArenaManager.player_units.size() > 0:
						var next_idx = -1
						var start_idx = _selected_unit_index + 1
						if start_idx >= RTSArenaManager.player_units.size():
							start_idx = 0
						for i in range(RTSArenaManager.player_units.size()):
							var check_idx = (start_idx + i) % RTSArenaManager.player_units.size()
							var check_unit = RTSArenaManager.player_units[check_idx]
							if check_unit and check_unit.state != SoulUnit.UnitState.DEAD:
								next_idx = check_idx
								break
						if next_idx >= 0:
							_select_player_unit(next_idx)
							if AudioManager:
								AudioManager.play_sfx("ui_button_click", 0.3)
					get_viewport().set_input_as_handled()
	# Left-click on arena: move selected unit to clicked position (RTS control)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _battle_active and not _is_paused:
			var click_pos = get_global_mouse_position()
			var arena_rect = Rect2(20, 90, 1240, 470)
			if arena_rect.has_point(click_pos):
				# 4v4 team battle: move selected unit if one is selected, else move all units
				var is_team = GameState.get_value("battle", "is_team_battle", false)
				if is_team:
					if _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
						var sel_unit = RTSArenaManager.player_units[_selected_unit_index]
						if sel_unit and sel_unit.state != SoulUnit.UnitState.DEAD:
							RTSArenaManager.move_player_unit_to(_selected_unit_index, click_pos)
							_spawn_move_indicator(click_pos)
							if AudioManager:
								AudioManager.play_sfx("ui_button_click", 0.4)
							get_viewport().set_input_as_handled()
					else:
						# No unit selected: move all alive units in formation
						RTSArenaManager.move_all_player_units_to(click_pos)
						_spawn_move_indicator(click_pos)
						if AudioManager:
							AudioManager.play_sfx("ui_button_click", 0.4)
						get_viewport().set_input_as_handled()
				# 1v1 battle: move player unit
				elif RTSArenaManager.player_unit:
					RTSArenaManager.player_move_to(click_pos)
					_spawn_move_indicator(click_pos)
					if AudioManager:
						AudioManager.play_sfx("ui_button_click", 0.4)
					get_viewport().set_input_as_handled()
	# Right-click on arena: set attack target (4v4 team battle)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _battle_active and not _is_paused:
			var click_pos = get_global_mouse_position()
			var arena_rect = Rect2(20, 90, 1240, 470)
			if arena_rect.has_point(click_pos):
				var is_team = GameState.get_value("battle", "is_team_battle", false)
				if is_team:
					# Find nearest AI unit to click position
					var nearest_ai = null
					var nearest_dist = 9999.0
					for ai_u in RTSArenaManager.ai_units:
						if ai_u and ai_u.state != SoulUnit.UnitState.DEAD:
							var dist = ai_u.position.distance_to(click_pos)
							if dist < nearest_dist and dist < 100.0:
								nearest_dist = dist
								nearest_ai = ai_u
					if nearest_ai:
						if _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
							# Selected unit: set only selected unit's attack target
							RTSArenaManager.set_player_unit_attack_target(_selected_unit_index, nearest_ai)
						else:
							# No unit selected: set all alive units' attack target
							RTSArenaManager.set_all_player_units_attack_target(nearest_ai)
						_spawn_attack_indicator(nearest_ai.position)
						if AudioManager:
							AudioManager.play_sfx("ui_button_click", 0.4)
						get_viewport().set_input_as_handled()


## Setup battle speed button UI
func _setup_speed_button() -> void:
	# Create speed button next to pause button
	_speed_button = Button.new()
	_speed_button.name = "SpeedButton"
	_speed_button.text = "⚡ 1x"
	_speed_button.position = Vector2(690, 10)
	_speed_button.size = Vector2(70, 35)
	_speed_button.add_theme_font_size_override("font_size", 14)
	# Custom style: dark purple with gold border
	var speed_style = StyleBoxFlat.new()
	speed_style.bg_color = Color(0.12, 0.08, 0.22)
	speed_style.border_color = Color(0.83, 0.66, 0.36)
	speed_style.border_width_left = 2
	speed_style.border_width_right = 2
	speed_style.border_width_top = 2
	speed_style.border_width_bottom = 2
	speed_style.corner_radius_top_left = 6
	speed_style.corner_radius_top_right = 6
	speed_style.corner_radius_bottom_left = 6
	speed_style.corner_radius_bottom_right = 6
	_speed_button.add_theme_stylebox_override("normal", speed_style)
	_speed_button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_speed_button.pressed.connect(_on_speed_button_pressed)
	_setup_button_hover(_speed_button)
	add_child(_speed_button)


## Handle speed button press (cycle through speed options)
func _on_speed_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	# Find current speed index and cycle to next
	var current_index = _speed_options.find(_current_speed)
	if current_index < 0:
		current_index = 0
	var next_index = (current_index + 1) % _speed_options.size()
	_current_speed = _speed_options[next_index]
	# Apply speed to battle manager
	RTSArenaManager.set_battle_speed(_current_speed)
	# Update button text and color based on speed
	if _speed_button:
		_speed_button.text = "⚡ %.1fx" % _current_speed
		match _current_speed:
			1.0:
				_speed_button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
			2.0:
				_speed_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			3.0:
				_speed_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			_:
				_speed_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		# Pulse animation on speed change
		_speed_button.scale = Vector2(1.2, 1.2)
		var tween = create_tween()
		tween.tween_property(_speed_button, "scale", Vector2(1.0, 1.0), 0.2)
	_add_log("战斗速度: %.1fx" % _current_speed)


## Setup status effect labels for player and AI
func _setup_status_labels() -> void:
	# Player status icons container (next to player panel)
	_player_status_icons = HBoxContainer.new()
	_player_status_icons.name = "PlayerStatusIcons"
	_player_status_icons.position = Vector2(10, 50)
	_player_status_icons.size = Vector2(200, 30)
	_player_status_icons.add_theme_constant_override("separation", 4)
	add_child(_player_status_icons)

	# Player status label (next to player panel)
	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.text = ""
	_player_status_label.position = Vector2(10, 80)
	_player_status_label.add_theme_font_size_override("font_size", 10)
	_player_status_label.modulate = Color(0.4, 0.9, 0.6)
	add_child(_player_status_label)

	# AI status icons container (next to AI panel)
	_ai_status_icons = HBoxContainer.new()
	_ai_status_icons.name = "AIStatusIcons"
	_ai_status_icons.position = Vector2(1070, 50)
	_ai_status_icons.size = Vector2(200, 30)
	_ai_status_icons.add_theme_constant_override("separation", 4)
	add_child(_ai_status_icons)

	# AI status label (next to AI panel)
	_ai_status_label = Label.new()
	_ai_status_label.name = "AIStatusLabel"
	_ai_status_label.text = ""
	_ai_status_label.position = Vector2(1070, 80)
	_ai_status_label.add_theme_font_size_override("font_size", 10)
	_ai_status_label.modulate = Color(0.9, 0.4, 0.4)
	add_child(_ai_status_label)

	# Load status icon sheet (3 rows x 4 cols, 1024x1024, 12 icons)
	var sheet_path := "res://assets/art/status_icon_sheet_v1.png"
	if ResourceLoader.exists(sheet_path):
		_status_icon_sheet = load(sheet_path)


## Update status effect display for both units
func _update_status_display() -> void:
	if RTSArenaManager.player_unit and _player_status_label:
		var effects = RTSArenaManager.player_unit.status_effects
		if effects.size() > 0:
			var text = ""
			for effect_name in effects.keys():
				var remaining = effects[effect_name]
				var display_name = _get_status_display_name(effect_name)
				text += "%s(%.1fs) " % [display_name, remaining]
			_player_status_label.text = text
		else:
			_player_status_label.text = ""
		# Update status icons
		_update_status_icon_container(_player_status_icons, effects)

	if RTSArenaManager.ai_unit and _ai_status_label:
		var effects = RTSArenaManager.ai_unit.status_effects
		if effects.size() > 0:
			var text = ""
			for effect_name in effects.keys():
				var remaining = effects[effect_name]
				var display_name = _get_status_display_name(effect_name)
				text += "%s(%.1fs) " % [display_name, remaining]
			_ai_status_label.text = text
		else:
			_ai_status_label.text = ""
		# Update status icons
		_update_status_icon_container(_ai_status_icons, effects)


## Update status icon container with current effects
func _update_status_icon_container(container: HBoxContainer, effects: Dictionary) -> void:
	if container == null:
		return
	# Clear existing icons
	for child in container.get_children():
		child.queue_free()
	if not _status_icon_sheet:
		return
	# Status effect name -> icon index (3 rows x 4 cols)
	var status_icon_map := {
		"attack_up": 0,
		"defense_up": 1,
		"speed_up": 2,
		"heal": 3,
		"shield": 4,
		"invisible": 5,
		"regen": 6,
		"focus": 7,
		"poison": 8,
		"frozen": 9,
		"burn": 10,
		"stun": 11
	}
	var cell_w: int = 256  # 1024 / 4
	var cell_h: int = 341  # 1024 / 3
	for effect_name in effects.keys():
		var icon_idx = status_icon_map.get(effect_name, -1)
		if icon_idx < 0:
			continue
		var row: int = icon_idx / 4
		var col: int = icon_idx % 4
		var atlas = AtlasTexture.new()
		atlas.atlas = _status_icon_sheet
		atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.texture = atlas
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.tooltip_text = _get_status_display_name(effect_name)
		container.add_child(icon_rect)


## Get display name for status effect
func _get_status_display_name(effect_name: String) -> String:
	match effect_name:
		"defense_up":
			return "防御↑"
		"attack_up":
			return "攻击↑"
		"speed_up":
			return "速度↑"
		"stun":
			return "眩晕"
		"poison":
			return "中毒"
		"burn":
			return "燃烧"
		_:
			return effect_name.capitalize()


## Setup critical hit label
func _setup_crit_label() -> void:
	_crit_label = Label.new()
	_crit_label.name = "CritLabel"
	_crit_label.text = ""
	_crit_label.position = Vector2(540, 300)
	_crit_label.size = Vector2(200, 50)
	_crit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crit_label.add_theme_font_size_override("font_size", 32)
	_crit_label.modulate = Color(1.0, 0.8, 0.2)
	_crit_label.visible = false
	add_child(_crit_label)


## Update critical hit display
func _update_crit_display(delta: float) -> void:
	if _crit_active:
		_crit_timer -= delta
		if _crit_timer <= 0:
			_crit_active = false
			if _crit_label:
				_crit_label.visible = false
		else:
			# Animate: float upward and fade out
			if _crit_label:
				var progress = 1.0 - (_crit_timer / 1.0)
				_crit_label.position.y = 300 - progress * 30
				_crit_label.modulate.a = 1.0 - progress
		return

	# Check if player unit just landed a critical hit
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_attack_critical:
		_show_crit_hit()
		# Reset the flag to avoid repeated display
		RTSArenaManager.player_unit.last_attack_critical = false


## Show critical hit effect
func _show_crit_hit() -> void:
	if _crit_label == null:
		return
	_crit_label.text = "暴击！"
	_crit_label.visible = true
	_crit_label.position = Vector2(540, 300)
	_crit_label.modulate.a = 1.0
	_crit_active = true
	_crit_timer = 1.0
	# Trigger screen shake for critical hit
	_trigger_screen_shake(4.0, 0.25)
	# Trigger stronger hit flash for critical hit
	_trigger_hit_flash(Color(1.0, 0.8, 0.2, 0.35), 0.2)
	# Play critical hit sound
	if AudioManager:
		AudioManager.play_sfx("battle_critical")
	_add_log("暴击！")


## Setup dodge label
func _setup_dodge_label() -> void:
	_dodge_label = Label.new()
	_dodge_label.name = "DodgeLabel"
	_dodge_label.text = ""
	_dodge_label.position = Vector2(540, 360)
	_dodge_label.size = Vector2(200, 50)
	_dodge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dodge_label.add_theme_font_size_override("font_size", 28)
	_dodge_label.modulate = Color(0.4, 0.8, 1.0)
	_dodge_label.visible = false
	add_child(_dodge_label)


## Update dodge display
func _update_dodge_display(delta: float) -> void:
	if _dodge_active:
		_dodge_timer -= delta
		if _dodge_timer <= 0:
			_dodge_active = false
			if _dodge_label:
				_dodge_label.visible = false
		else:
			# Animate: float upward and fade out
			if _dodge_label:
				var progress = 1.0 - (_dodge_timer / 1.0)
				_dodge_label.position.y = 360 - progress * 30
				_dodge_label.modulate.a = 1.0 - progress
		return

	# Check if player unit just dodged an attack
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_damage_dodged:
		_show_dodge()
		# Reset the flag to avoid repeated display
		RTSArenaManager.player_unit.last_damage_dodged = false


## Show dodge effect
func _show_dodge() -> void:
	if _dodge_label == null:
		return
	_dodge_label.text = "闪避！"
	_dodge_label.visible = true
	_dodge_label.position = Vector2(540, 360)
	_dodge_label.modulate.a = 1.0
	_dodge_active = true
	_dodge_timer = 1.0
	# Play dodge sound
	if AudioManager:
		AudioManager.play_sfx("battle_dodge")
	_add_log("闪避！")


## Setup heal label
func _setup_heal_label() -> void:
	_heal_label = Label.new()
	_heal_label.name = "HealLabel"
	_heal_label.text = ""
	_heal_label.position = Vector2(540, 420)
	_heal_label.size = Vector2(200, 50)
	_heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heal_label.add_theme_font_size_override("font_size", 28)
	_heal_label.modulate = Color(0.3, 1.0, 0.4)
	_heal_label.visible = false
	add_child(_heal_label)


## Update heal display
func _update_heal_display(delta: float) -> void:
	if _heal_active:
		_heal_timer -= delta
		if _heal_timer <= 0:
			_heal_active = false
			if _heal_label:
				_heal_label.visible = false
		else:
			# Animate: float upward and fade out
			if _heal_label:
				var progress = 1.0 - (_heal_timer / 1.0)
				_heal_label.position.y = 420 - progress * 30
				_heal_label.modulate.a = 1.0 - progress
		return

	# Check if player unit just healed
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_heal_amount > 0:
		_show_heal(RTSArenaManager.player_unit.last_heal_amount)
		# Reset the flag to avoid repeated display
		RTSArenaManager.player_unit.last_heal_amount = 0


## Show heal effect
func _show_heal(heal_amount: int) -> void:
	if _heal_label == null:
		return
	_heal_label.text = "治疗 +%d" % heal_amount
	_heal_label.visible = true
	_heal_label.position = Vector2(540, 420)
	_heal_label.modulate.a = 1.0
	_heal_active = true
	_heal_timer = 1.0
	# Play heal sound
	if AudioManager:
		AudioManager.play_sfx("battle_heal")
	_add_log("治疗 +%d" % heal_amount)


## Setup defend label
func _setup_defend_label() -> void:
	_defend_label = Label.new()
	_defend_label.name = "DefendLabel"
	_defend_label.text = ""
	_defend_label.position = Vector2(540, 480)
	_defend_label.size = Vector2(200, 50)
	_defend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defend_label.add_theme_font_size_override("font_size", 28)
	_defend_label.modulate = Color(0.6, 0.6, 1.0)
	_defend_label.visible = false
	add_child(_defend_label)


## Update defend display
func _update_defend_display(delta: float) -> void:
	if _defend_active:
		_defend_timer -= delta
		if _defend_timer <= 0:
			_defend_active = false
			if _defend_label:
				_defend_label.visible = false
		else:
			# Animate: float upward and fade out
			if _defend_label:
				var progress = 1.0 - (_defend_timer / 1.0)
				_defend_label.position.y = 480 - progress * 30
				_defend_label.modulate.a = 1.0 - progress
		return

	# Check if player unit just used defend
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_defend_used:
		_show_defend()
		# Reset the flag to avoid repeated display
		RTSArenaManager.player_unit.last_defend_used = false


## Show defend effect
func _show_defend() -> void:
	if _defend_label == null:
		return
	_defend_label.text = "防御！"
	_defend_label.visible = true
	_defend_label.position = Vector2(540, 480)
	_defend_label.modulate.a = 1.0
	_defend_active = true
	_defend_timer = 1.0
	# Play defend sound
	if AudioManager:
		AudioManager.play_sfx("battle_shield")
	_add_log("防御！")


## Setup skill usage label
func _setup_skill_label() -> void:
	_skill_label = Label.new()
	_skill_label.name = "SkillLabel"
	_skill_label.text = ""
	_skill_label.position = Vector2(540, 540)
	_skill_label.size = Vector2(200, 50)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.add_theme_font_size_override("font_size", 24)
	_skill_label.modulate = Color(1.0, 0.6, 0.8)
	_skill_label.visible = false
	add_child(_skill_label)


## Update skill usage display
func _update_skill_display(delta: float) -> void:
	if _skill_active:
		_skill_timer -= delta
		if _skill_timer <= 0:
			_skill_active = false
			if _skill_label:
				_skill_label.visible = false
		else:
			# Animate: float upward and fade out
			if _skill_label:
				var progress = 1.0 - (_skill_timer / 1.0)
				_skill_label.position.y = 540 - progress * 30
				_skill_label.modulate.a = 1.0 - progress
		return

	# Check if player unit just used a skill
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_skill_used != "":
		_show_skill_used(RTSArenaManager.player_unit.last_skill_used)
		# Reset the flag to avoid repeated display
		RTSArenaManager.player_unit.last_skill_used = ""


## Show skill usage effect
func _show_skill_used(skill_name: String) -> void:
	if _skill_label == null:
		return
	var display_name = _get_skill_display_name(skill_name)
	_skill_label.text = display_name
	_skill_label.visible = true
	_skill_label.position = Vector2(540, 540)
	_skill_label.modulate.a = 1.0
	_skill_active = true
	_skill_timer = 1.0
	# Trigger screen shake for skill use
	_trigger_screen_shake(2.5, 0.15)
	# Trigger skill particle burst at arena center
	_trigger_skill_particles(Vector2(640, 300), Color(1.0, 0.6, 0.2))
	_add_log(display_name)


## Get display name for skill
func _get_skill_display_name(skill_name: String) -> String:
	match skill_name:
		"heavy_strike":
			return "重击！"
		"quick_strike":
			return "快击！"
		"heal":
			return "治疗！"
		"defend":
			return "防御！"
		_:
			return skill_name.capitalize()


## Setup damage floating text system (multiple labels for simultaneous damage)
func _setup_damage_label() -> void:
	_damage_labels = []
	# Single label compatibility (for tests/simple API)
	if _damage_label == null:
		_damage_label = Label.new()
		_damage_label.name = "DamageLabel"
		_damage_label.text = ""
		_damage_label.visible = false
		_damage_label.position = Vector2(600, 300)
		_damage_label.size = Vector2(80, 30)
		_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_damage_label.add_theme_font_size_override("font_size", 24)
		_damage_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_damage_label.add_theme_constant_override("outline_size", 3)
		_damage_label.z_index = 100
		add_child(_damage_label)
	GameLog.debug("RTSArena: Damage floating text system initialized", "UI")


## Update all damage floating text displays
func _update_damage_display(delta: float) -> void:
	# Update single label compatibility timer
	if _damage_active and _damage_label:
		_damage_timer -= delta
		if _damage_timer <= 0:
			_damage_active = false
			_damage_label.visible = false

	# Update existing damage labels
	var to_remove = []
	for dmg_data in _damage_labels:
		dmg_data.timer -= delta
		if dmg_data.timer <= 0:
			if dmg_data.label:
				dmg_data.label.queue_free()
			to_remove.append(dmg_data)
		else:
			if dmg_data.label:
				var progress = 1.0 - (dmg_data.timer / dmg_data.duration)
				dmg_data.label.position.y = dmg_data.start_y - progress * 50
				dmg_data.label.modulate.a = 1.0 - progress
	for dmg_data in to_remove:
		_damage_labels.erase(dmg_data)

	# Check if player unit just took damage
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_damage_taken > 0:
		var player_pos = RTSArenaManager.player_unit.position
		var player_dmg = RTSArenaManager.player_unit.last_damage_taken
		var is_crit = RTSArenaManager.ai_unit and RTSArenaManager.ai_unit.last_attack_critical
		if is_crit:
			_show_damage_at(player_dmg, player_pos, Color(1.0, 0.85, 0.2), "暴击!", 28)
			_trigger_screen_shake(5.0, 0.15)
			_trigger_chromatic_aberration(10.0, 0.3)
		else:
			_show_damage_at(player_dmg, player_pos, Color(1.0, 0.3, 0.3))
		RTSArenaManager.player_unit.last_damage_taken = 0
		# Trigger hit flash on player damage taken
		_trigger_hit_flash(Color(1.0, 0.2, 0.2, 0.2), 0.12)

	# Check if AI unit just took damage
	if RTSArenaManager.ai_unit and RTSArenaManager.ai_unit.last_damage_taken > 0:
		var ai_pos = RTSArenaManager.ai_unit.position
		var ai_dmg = RTSArenaManager.ai_unit.last_damage_taken
		var ai_is_crit = RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_attack_critical
		if ai_is_crit:
			_show_damage_at(ai_dmg, ai_pos, Color(1.0, 0.85, 0.2), "暴击!", 28)
			_trigger_chromatic_aberration(8.0, 0.25)
		else:
			_show_damage_at(ai_dmg, ai_pos, Color(1.0, 0.7, 0.2))
		RTSArenaManager.ai_unit.last_damage_taken = 0

	# Check if player unit just healed
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_heal_amount > 0:
		var player_heal_pos = RTSArenaManager.player_unit.position
		_show_damage_at(RTSArenaManager.player_unit.last_heal_amount, player_heal_pos, Color(0.3, 1.0, 0.4), "+", 24)
		RTSArenaManager.player_unit.last_heal_amount = 0

	# Check if AI unit just healed
	if RTSArenaManager.ai_unit and RTSArenaManager.ai_unit.last_heal_amount > 0:
		var ai_heal_pos = RTSArenaManager.ai_unit.position
		_show_damage_at(RTSArenaManager.ai_unit.last_heal_amount, ai_heal_pos, Color(0.3, 1.0, 0.4), "+", 24)
		RTSArenaManager.ai_unit.last_heal_amount = 0


## Show damage floating text at specific position
## p_color: red=player damage, orange=AI damage, green=heal, gold=crit
## p_prefix: text prefix before number (e.g. "暴击!", "+")
## p_font_size: font size override
func _show_damage_at(damage_amount: int, p_position: Vector2, p_color: Color = Color(1.0, 0.3, 0.3), p_prefix: String = "-", p_font_size: int = 24) -> void:
	# Limit max simultaneous labels
	if _damage_labels.size() >= _damage_max_labels:
		var oldest = _damage_labels[0]
		if oldest.label:
			oldest.label.queue_free()
		_damage_labels.pop_front()
	# Create new damage label
	var label = Label.new()
	label.name = "DamageText_%d" % Time.get_ticks_msec()
	label.text = "%s%d" % [p_prefix, damage_amount]
	label.position = Vector2(p_position.x - 40, p_position.y - 60)
	label.size = Vector2(80, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", p_font_size)
	label.add_theme_color_override("font_color", p_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 100
	add_child(label)
	_damage_labels.append({
		"label": label,
		"timer": 1.0,
		"duration": 1.0,
		"start_y": p_position.y - 60
	})


## Show damage on single label (compatibility API for tests)
func _show_damage(p_amount: int) -> void:
	_damage_active = true
	_damage_timer = 1.0
	if _damage_label:
		_damage_label.text = "-%d" % p_amount
		_damage_label.visible = true


## Trigger screen shake effect
func _trigger_screen_shake(p_intensity: float = 3.0, p_duration: float = 0.2) -> void:
	# Only override if new shake is stronger or previous is almost done
	if p_intensity > _screen_shake_intensity or _screen_shake_timer < 0.05:
		_screen_shake_intensity = p_intensity
		_screen_shake_timer = p_duration
		_screen_shake_max_duration = p_duration


## Update screen shake effect with decay and rotation
func _update_screen_shake(delta: float) -> void:
	if _screen_shake_timer > 0:
		_screen_shake_timer -= delta
		if _screen_shake_timer > 0:
			# Decay intensity over time (ease-out curve)
			var progress = _screen_shake_timer / _screen_shake_max_duration
			var decay = progress * progress  # Quadratic ease-out
			var current_intensity = _screen_shake_intensity * decay
			# Natural shake using layered sine waves (more organic than random)
			var t = Time.get_ticks_msec() / 1000.0
			var shake_x = sin(t * 45.0) * current_intensity * 0.6 + sin(t * 27.0) * current_intensity * 0.4
			var shake_y = cos(t * 38.0) * current_intensity * 0.5 + sin(t * 31.0) * current_intensity * 0.5
			position = _base_position + Vector2(shake_x, shake_y)
			# Subtle rotation for impact feel (max 1.5 degrees)
			rotation = deg_to_rad(sin(t * 20.0) * current_intensity * 0.3)
		else:
			# Reset to base position when shake ends
			position = _base_position
			rotation = 0.0
			_screen_shake_timer = 0.0
			_screen_shake_intensity = 0.0


## Spawn skill particle effect at position
## p_skill: heavy_strike=earth(brown), quick_strike=fire(orange), heal=green, defend=blue
## Load particle textures from particle_texture_sheet.png (2x4 atlas)
## Falls back to procedural circle textures if sheet not available
func _load_particle_textures() -> void:
	var sheet_path := "res://assets/art/particle_texture_sheet.png"
	if not ResourceLoader.exists(sheet_path):
		GameLog.warning("RTSArenaController: particle_texture_sheet.png not found, using procedural", "UI")
		return
	var sheet = load(sheet_path)
	if not sheet:
		GameLog.warning("RTSArenaController: Failed to load particle texture sheet", "UI")
		return
	# Sheet is 2 rows x 4 cols, each cell ~480x540 (1920x1080 total)
	var cell_w = 480
	var cell_h = 540
	# Map skills to atlas positions (col, row)
	var skill_atlas = {
		"heavy_strike": Vector2i(0, 0),  # Orange explosion
		"quick_strike": Vector2i(1, 1),  # Red fire
		"heal": Vector2i(1, 0),          # Gold starlight
		"defend": Vector2i(2, 0),        # Gray smoke
	}
	for skill_name in skill_atlas.keys():
		var pos = skill_atlas[skill_name]
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(pos.x * cell_w, pos.y * cell_h, cell_w, cell_h)
		_particle_textures[skill_name] = atlas
	_particle_textures_loaded = true
	GameLog.info("RTSArenaController: Loaded %d particle textures from sheet" % _particle_textures.size(), "UI")


func _spawn_skill_particle(p_skill: String, p_position: Vector2) -> void:
	var colors = {
		"heavy_strike": Color(0.7, 0.5, 0.3, 1.0),
		"quick_strike": Color(1.0, 0.5, 0.2, 1.0),
		"heal": Color(0.3, 0.9, 0.4, 1.0),
		"defend": Color(0.4, 0.6, 0.9, 1.0),
	}
	var particle_color = colors.get(p_skill, Color(1.0, 1.0, 1.0, 1.0))
	# Use design texture if available, otherwise procedural
	var use_design_texture = _particle_textures_loaded and _particle_textures.has(p_skill)
	var design_texture = _particle_textures.get(p_skill, null) if use_design_texture else null
	# Create 8 particle sprites radiating outward
	for i in range(8):
		var angle = (TAU / 8.0) * i
		var particle = Sprite2D.new()
		particle.name = "SkillParticle_%d" % Time.get_ticks_msec()
		particle.centered = true
		particle.position = p_position
		particle.modulate = particle_color
		particle.scale = Vector2(0.15, 0.15) if use_design_texture else Vector2(0.3, 0.3)
		particle.z_index = 50
		if use_design_texture and design_texture:
			particle.texture = design_texture
		else:
			# Procedural circle texture fallback
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			for x in range(16):
				for y in range(16):
					var dx = x - 8
					var dy = y - 8
					var dist = sqrt(dx * dx + dy * dy)
					if dist < 7:
						img.set_pixel(x, y, Color(1, 1, 1, 1.0 - dist / 7.0))
			particle.texture = ImageTexture.create_from_image(img)
		add_child(particle)
		_skill_particles.append({
			"particle": particle,
			"timer": 0.5,
			"duration": 0.5,
			"velocity": Vector2(cos(angle), sin(angle)) * 80.0,
			"start_pos": p_position
		})


## Update all skill particle effects
func _update_skill_particles(delta: float) -> void:
	var to_remove = []
	for p_data in _skill_particles:
		p_data["timer"] -= delta
		if p_data["timer"] <= 0:
			if p_data["particle"]:
				p_data["particle"].queue_free()
			to_remove.append(p_data)
		else:
			if p_data["particle"]:
				var progress = 1.0 - (p_data["timer"] / p_data["duration"])
				p_data["particle"].position = p_data["start_pos"] + p_data["velocity"] * progress
				p_data["particle"].modulate.a = 1.0 - progress
				p_data["particle"].scale = Vector2(0.3 + progress * 0.5, 0.3 + progress * 0.5)
	for p_data in to_remove:
		_skill_particles.erase(p_data)


## Setup error message label
func _setup_error_label() -> void:
	_error_label = Label.new()
	_error_label.name = "ErrorLabel"
	_error_label.text = ""
	_error_label.position = Vector2(540, 660)
	_error_label.size = Vector2(200, 40)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", 24)
	_error_label.modulate = Color(1.0, 0.3, 0.3)
	_error_label.visible = false
	add_child(_error_label)


## Setup success message label
func _setup_success_label() -> void:
	_success_label = Label.new()
	_success_label.name = "SuccessLabel"
	_success_label.text = ""
	_success_label.position = Vector2(540, 660)
	_success_label.size = Vector2(200, 40)
	_success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_label.add_theme_font_size_override("font_size", 24)
	_success_label.modulate = Color(0.3, 1.0, 0.4)
	_success_label.visible = false
	add_child(_success_label)


## Setup hit flash overlay (full screen color flash on damage)
func _setup_hit_flash() -> void:
	_hit_flash = ColorRect.new()
	_hit_flash.name = "HitFlash"
	_hit_flash.color = Color(1.0, 0.2, 0.2, 0.0)  # Red, transparent by default
	_hit_flash.size = Vector2(1280, 720)
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hit_flash)


## Trigger hit flash effect
func _trigger_hit_flash(p_color: Color = Color(1.0, 0.2, 0.2, 0.3), p_duration: float = 0.15) -> void:
	if _hit_flash == null:
		return
	_hit_flash.color = p_color
	_hit_flash_timer = p_duration
	_hit_flash_duration = p_duration


## Update hit flash effect (fade out)
func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer > 0 and _hit_flash != null:
		_hit_flash_timer -= delta
		if _hit_flash_timer > 0:
			var progress = 1.0 - (_hit_flash_timer / _hit_flash_duration)
			var current_color = _hit_flash.color
			current_color.a = _hit_flash.color.a * (1.0 - progress)
			_hit_flash.color = current_color
		else:
			_hit_flash.color.a = 0.0
			_hit_flash_timer = 0.0


## Trigger skill particle burst effect
func _trigger_skill_particles(p_position: Vector2, p_color: Color = Color(1.0, 0.5, 0.2)) -> void:
	# Create 8 particle squares radiating outward
	for i in range(8):
		var particle = ColorRect.new()
		particle.color = p_color
		particle.size = Vector2(8, 8)
		particle.position = p_position
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(particle)
		var angle = (i / 8.0) * TAU
		var speed = randf_range(80.0, 150.0)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		_skill_particles.append({
			"particle": particle,
			"timer": 0.5,
			"duration": 0.5,
			"velocity": velocity,
			"start_pos": p_position
		})
	_skill_particle_timer = 0.5


## Spawn a move indicator ring at clicked position (RTS feedback)
func _spawn_move_indicator(p_position: Vector2) -> void:
	var ring = ColorRect.new()
	ring.name = "MoveIndicator"
	ring.color = Color(0.4, 0.8, 1.0, 0.7)
	ring.size = Vector2(24, 24)
	ring.position = p_position - Vector2(12, 12)
	ring.z_index = 5
	add_child(ring)
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.4)
	tween.parallel().tween_property(ring, "color:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)


## Spawn red attack target indicator at position
func _spawn_attack_indicator(p_position: Vector2) -> void:
	var ring = ColorRect.new()
	ring.name = "AttackIndicator"
	ring.color = Color(1.0, 0.3, 0.2, 0.8)
	ring.size = Vector2(32, 32)
	ring.position = p_position - Vector2(16, 16)
	ring.z_index = 5
	add_child(ring)
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.5)
	tween.parallel().tween_property(ring, "color:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)


## Update error message display
func _update_error_display(delta: float) -> void:
	if _error_active:
		_error_timer -= delta
		if _error_timer <= 0:
			_error_active = false
			if _error_label:
				_error_label.visible = false


## Update success message display
func _update_success_display(delta: float) -> void:
	if _success_active:
		_success_timer -= delta
		if _success_timer <= 0:
			_success_active = false
			if _success_label:
				_success_label.visible = false


## Show error message
func _show_error_message(p_message: String) -> void:
	if _error_label == null:
		return
	# Hide success label if visible
	if _success_label:
		_success_label.visible = false
		_success_active = false
	_error_label.text = p_message
	_error_label.visible = true
	_error_active = true
	_error_timer = 1.5
	if AudioManager:
		AudioManager.play_sfx("ui_error")


## Show success message
func _show_success_message(p_message: String) -> void:
	if _success_label == null:
		return
	# Hide error label if visible
	if _error_label:
		_error_label.visible = false
		_error_active = false
	_success_label.text = p_message
	_success_label.visible = true
	_success_active = true
	_success_timer = 1.5
	if AudioManager:
		AudioManager.play_sfx("ui_success")


## Play button hover sound
func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")


## Setup procedural pixel art arena background
func _setup_arena_background() -> void:
	var bg_node = get_node_or_null("Background")
	_dlog("[DEBUG-BG] Background node found: " + str(bg_node != null))
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
	_dlog("[DEBUG-BG] map_name=" + str(map_name) + " arena_type=" + str(arena_type))

	# Try design map concept image first (1920x1080 full scene art)
	var design_bg_path := ""
	match arena_type:
		"lava":
			design_bg_path = "res://assets/art/new_map_lava_cave_concept.png"
		"crystal":
			design_bg_path = "res://assets/art/new_map_crystal_cave_concept.png"
		"stone":
			design_bg_path = "res://assets/art/new_map_ancient_ruins_concept.png"
		"sand":
			design_bg_path = "res://assets/art/new_map_golden_desert_concept.png"
		_:
			design_bg_path = "res://assets/art/new_map_dark_forest_concept.png"
	_dlog("[DEBUG-BG] design_bg_path=" + design_bg_path)
	_dlog("[DEBUG-BG] ResourceLoader.exists: " + str(ResourceLoader.exists(design_bg_path)))

	var design_texture: Texture2D = null
	if ResourceLoader.exists(design_bg_path):
		design_texture = load(design_bg_path)
	_dlog("[DEBUG-BG] design_texture loaded: " + str(design_texture != null))

	if design_texture != null:
		# Directly set Background node's texture (it's already a TextureRect covering full window)
		bg_node.texture = design_texture
		bg_node.stretch_mode = TextureRect.STRETCH_SCALE
		bg_node.visible = true
		_dlog("[DEBUG-BG] Background texture set, size=" + str(bg_node.size))
		# Make ArenaArea ColorRect transparent so background shows through
		var arena_area = get_node_or_null("ArenaArea")
		_dlog("[DEBUG-BG] ArenaArea found: " + str(arena_area != null))
		if arena_area != null and arena_area is ColorRect:
			_dlog("[DEBUG-BG] ArenaArea old color: " + str(arena_area.color))
			arena_area.color = Color(0, 0, 0, 0)
			_dlog("[DEBUG-BG] ArenaArea set to transparent")
		GameLog.info("RTSArenaController: Arena background from design asset (%s)" % arena_type, "Arena")
		return

	# Fallback: Generate background texture procedurally
	_dlog("[DEBUG-BG] Using procedural fallback")
	var generator = ArenaBackgroundGenerator.new()
	var texture = generator.generate_background(arena_type, hash(map_name))
	bg_node.texture = texture
	bg_node.stretch_mode = TextureRect.STRETCH_SCALE
	bg_node.visible = true
	# Make ArenaArea transparent
	var arena_area = get_node_or_null("ArenaArea")
	if arena_area != null and arena_area is ColorRect:
		arena_area.color = Color(0, 0, 0, 0)
	GameLog.info("RTSArenaController: Arena background generated (%s)" % arena_type, "Arena")


## Setup atmosphere effects: ambient floating particles + vignette
func _setup_atmosphere_effects() -> void:
	# Create vignette overlay (darkened edges for depth)
	_vignette_sprite = Sprite2D.new()
	_vignette_sprite.name = "Vignette"
	_vignette_sprite.centered = false
	_vignette_sprite.position = Vector2(0, 80)
	_vignette_sprite.z_index = 100  # Above arena, below UI
	_vignette_sprite.modulate = Color(1, 1, 1, 0.12)
	# Generate radial gradient vignette texture (1280x640)
	var img = Image.create(1280, 640, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(640, 320)
	var max_dist = sqrt(640 * 640 + 320 * 320)
	for x in range(1280):
		for y in range(640):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = clamp((dist / max_dist - 0.4) / 0.6, 0.0, 1.0) * 0.6
			if alpha > 0.01:
				img.set_pixel(x, y, Color(0.05, 0.02, 0.1, alpha))
	_vignette_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_vignette_sprite)

	# Create ambient floating particles (magical starlight)
	for i in range(20):
		var particle = Sprite2D.new()
		particle.name = "AmbientParticle_%d" % i
		particle.centered = true
		var start_x = randf_range(50, 1230)
		var start_y = randf_range(100, 700)
		particle.position = Vector2(start_x, start_y)
		particle.z_index = 5
		particle.modulate = Color(0.8, 0.7, 1.0, randf_range(0.3, 0.7))
		particle.scale = Vector2(randf_range(0.1, 0.25), randf_range(0.1, 0.25))
		# Procedural star texture
		var star_img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		star_img.fill(Color(0, 0, 0, 0))
		for sx in range(8):
			for sy in range(8):
				var dx = sx - 4
				var dy = sy - 4
				var d = sqrt(dx * dx + dy * dy)
				if d < 3:
					star_img.set_pixel(sx, sy, Color(1, 1, 1, 1.0 - d / 3.0))
		particle.texture = ImageTexture.create_from_image(star_img)
		add_child(particle)
		_ambient_particles.append({
			"particle": particle,
			"velocity": Vector2(randf_range(-5, 5), randf_range(-8, -3)),
			"base_y": start_y,
			"phase": randf() * TAU,
			"base_x": start_x
		})

	# Create magic dust particles (golden, slow drifting, weather effect)
	for i in range(30):
		var dust = Sprite2D.new()
		dust.name = "MagicDust_%d" % i
		dust.centered = true
		var dust_x = randf_range(0, 1280)
		var dust_y = randf_range(80, 720)
		dust.position = Vector2(dust_x, dust_y)
		dust.z_index = 3  # Below ambient particles, above background
		dust.modulate = Color(1.0, 0.85, 0.5, randf_range(0.2, 0.5))
		dust.scale = Vector2(randf_range(0.06, 0.15), randf_range(0.06, 0.15))
		# Procedural soft dust texture (small golden glow)
		var dust_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		dust_img.fill(Color(0, 0, 0, 0))
		for dx in range(16):
			for dy in range(16):
				var ddx = dx - 8.0
				var ddy = dy - 8.0
				var dd = sqrt(ddx * ddx + ddy * ddy) / 8.0
				if dd < 1.0:
					var d_alpha = pow(1.0 - dd, 2.0)
					dust_img.set_pixel(dx, dy, Color(1.0, 0.9, 0.6, d_alpha))
		dust.texture = ImageTexture.create_from_image(dust_img)
		add_child(dust)
		_magic_dust.append({
			"particle": dust,
			"velocity": Vector2(randf_range(-3, 3), randf_range(-4, -1)),
			"phase": randf() * TAU,
			"base_x": dust_x,
			"base_y": dust_y
		})
	GameLog.info("RTSArenaController: Atmosphere effects setup (20 ambient particles + 30 magic dust + vignette)", "Arena")


## Update atmosphere effects: floating particles drift and twinkle
func _update_atmosphere(delta: float) -> void:
	_ambient_time += delta
	for p_data in _ambient_particles:
		var particle = p_data.particle
		if not is_instance_valid(particle):
			continue
		# Slow upward drift with horizontal sway
		p_data.phase += delta * 0.5
		var sway = sin(p_data.phase) * 15.0
		particle.position.x = p_data.base_x + sway
		particle.position.y -= p_data.velocity.y * delta
		# Twinkle effect (opacity pulse)
		var twinkle = 0.5 + sin(_ambient_time * 2.0 + p_data.phase) * 0.3
		particle.modulate.a = twinkle
		# Reset when off screen top
		if particle.position.y < 90:
			particle.position.y = 710
			p_data.base_x = randf_range(50, 1230)
			particle.position.x = p_data.base_x

	# Update magic dust (golden, slower, wider sway)
	for d_data in _magic_dust:
		var dust = d_data.particle
		if not is_instance_valid(dust):
			continue
		d_data.phase += delta * 0.3
		# Slow drift with wide horizontal sway
		var dust_sway = sin(d_data.phase) * 25.0
		dust.position.x = d_data.base_x + dust_sway
		dust.position.y += d_data.velocity.y * delta
		# Gentle twinkle (slower, subtler)
		var dust_twinkle = 0.35 + sin(_ambient_time * 1.2 + d_data.phase * 2.0) * 0.25
		dust.modulate.a = dust_twinkle
		# Reset when off screen top or bottom
		if dust.position.y < 70:
			dust.position.y = 720
			d_data.base_x = randf_range(0, 1280)
			dust.position.x = d_data.base_x
		elif dust.position.y > 730:
			dust.position.y = 80
			d_data.base_x = randf_range(0, 1280)
			dust.position.x = d_data.base_x


## Setup chromatic aberration post-processing effect
## Full-screen ColorRect with shader that offsets RGB channels
## Triggered by crits/skills, intensity decays over time
func _setup_chromatic_aberration() -> void:
	_chromatic_layer = CanvasLayer.new()
	_chromatic_layer.layer = 100  # Above UI
	_chromatic_layer.name = "ChromaticAberrationLayer"
	add_child(_chromatic_layer)

	_chromatic_rect = ColorRect.new()
	_chromatic_rect.name = "ChromaticAberration"
	_chromatic_rect.anchors_preset = Control.PRESET_FULL_RECT
	_chromatic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chromatic_rect.color = Color(1, 1, 1, 1)

	# Create chromatic aberration shader (Godot 4.7: use hint_screen_texture)
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 20.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = vec2(intensity * 0.001, 0.0);
	// Sample RGB channels with horizontal offset
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	// Keep alpha from original
	float a = texture(screen_texture, uv).a;
	COLOR = vec4(r, g, b, a);
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("intensity", 0.0)
	_chromatic_rect.material = material
	_chromatic_layer.add_child(_chromatic_rect)
	GameLog.info("RTSArenaController: Chromatic aberration post-processing setup", "Arena")


## Trigger chromatic aberration effect
## p_intensity: peak intensity (0-20)
## p_duration: decay time in seconds
func _trigger_chromatic_aberration(p_intensity: float = 8.0, p_duration: float = 0.3) -> void:
	_chromatic_intensity = p_intensity
	_chromatic_decay = p_intensity / p_duration if p_duration > 0 else p_intensity


## Update chromatic aberration decay
func _update_chromatic_aberration(delta: float) -> void:
	if _chromatic_intensity > 0.01:
		_chromatic_intensity = max(0.0, _chromatic_intensity - _chromatic_decay * delta)
		if _chromatic_rect and _chromatic_rect.material:
			_chromatic_rect.material.set_shader_parameter("intensity", _chromatic_intensity)
	elif _chromatic_intensity > 0.0:
		_chromatic_intensity = 0.0
		if _chromatic_rect and _chromatic_rect.material:
			_chromatic_rect.material.set_shader_parameter("intensity", 0.0)


## Try to auto-start battle from GameState configuration
func _try_auto_start_battle() -> void:
	var player_soul = GameState.get_value("battle", "player_soul", null)
	var ai_soul = GameState.get_value("battle", "ai_soul", null)
	var map_name = GameState.get_value("battle", "map_name", "default_arena")

	# GAP-001: Check for team battle config (4v4)
	var player_souls = GameState.get_value("battle", "player_souls", null)
	var ai_souls = GameState.get_value("battle", "ai_souls", null)
	var is_team_battle = GameState.get_value("battle", "is_team_battle", false)

	if is_team_battle and player_souls != null and ai_souls != null and player_souls.size() > 0 and ai_souls.size() > 0:
		GameLog.info("RTSArenaController: Starting TEAM battle countdown (%dv%d)" % [player_souls.size(), ai_souls.size()], "Arena")
		# Save team config for rematch and pending start
		_battle_config["player_souls"] = player_souls
		_battle_config["ai_souls"] = ai_souls
		_battle_config["map_name"] = map_name
		_battle_config["is_team_battle"] = true
		_pending_battle_config = {
			"player_souls": player_souls,
			"ai_souls": ai_souls,
			"map_name": map_name,
			"is_team_battle": true
		}
		# Start countdown
		_start_countdown()
		# Clear battle config from GameState after use
		GameState.set_value("battle", "player_souls", null)
		GameState.set_value("battle", "ai_souls", null)
		GameState.set_value("battle", "is_team_battle", false)
	elif player_soul != null and ai_soul != null:
		GameLog.info("RTSArenaController: Starting 1v1 battle countdown with config from GameState", "Arena")
		# Save config for rematch and pending start
		_battle_config["player_soul"] = player_soul
		_battle_config["ai_soul"] = ai_soul
		_battle_config["map_name"] = map_name
		_pending_battle_config = {
			"player_soul": player_soul,
			"ai_soul": ai_soul,
			"map_name": map_name,
			"is_team_battle": false
		}
		# Start countdown
		_start_countdown()
		# Clear battle config from GameState after use (keep local copy for rematch)
		GameState.set_value("battle", "player_soul", null)
		GameState.set_value("battle", "ai_soul", null)
	else:
		_add_log("No battle config found. Use CLI 'rts_battle' to set up a battle.")
		_add_log("Or call start_test_battle() for a quick test.")


## Start battle countdown (3-2-1-GO!)
func _start_countdown() -> void:
	_countdown_active = true
	_countdown_timer = 3.0
	_setup_countdown_label()
	_update_countdown_display()
	# Play countdown start sound
	if AudioManager:
		AudioManager.play_sfx("battle_ui_countdown")


## Setup countdown label UI
func _setup_countdown_label() -> void:
	if _countdown_label != null:
		return
	_countdown_label = Label.new()
	_countdown_label.name = "CountdownLabel"
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.position = Vector2(-200, -100)
	_countdown_label.size = Vector2(400, 200)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_countdown_label.add_theme_constant_override("outline_size", 6)
	add_child(_countdown_label)


## Update countdown display with animation
func _update_countdown_display() -> void:
	if _countdown_label == null:
		return
	var new_text = ""
	if _countdown_timer > 2.0:
		new_text = "3"
	elif _countdown_timer > 1.0:
		new_text = "2"
	elif _countdown_timer > 0.0:
		new_text = "1"
	else:
		new_text = "GO!"
	# Animate when text changes
	if new_text != _last_countdown_text:
		_countdown_label.text = new_text
		_last_countdown_text = new_text
		# Scale up + fade in animation
		_countdown_label.scale = Vector2(1.5, 1.5)
		_countdown_label.modulate = Color(1, 1, 1, 0)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(_countdown_label, "modulate:a", 1.0, 0.3)
		tween.set_parallel(false)
		# GO! gets extra scale and color
		if new_text == "GO!":
			_countdown_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			_countdown_label.scale = Vector2(2.0, 2.0)
			var go_tween = create_tween()
			go_tween.tween_property(_countdown_label, "scale", Vector2(1.2, 1.2), 0.5).set_ease(Tween.EASE_OUT)


## Start actual battle after countdown
func _start_battle_after_countdown() -> void:
	if _pending_battle_config == null:
		return
	var map_name = _pending_battle_config["map_name"]
	var is_team = _pending_battle_config.get("is_team_battle", false)

	if is_team:
		# GAP-001: 4v4 team battle
		var player_team = _pending_battle_config["player_souls"]
		var ai_team = _pending_battle_config["ai_souls"]
		GameLog.info("RTSArenaController: Starting TEAM battle %dv%d" % [player_team.size(), ai_team.size()], "Arena")
		RTSArenaManager.start_team_battle(player_team, ai_team, map_name)
	else:
		# 1v1 battle (backward compatibility)
		var player_soul = _pending_battle_config["player_soul"]
		var ai_soul = _pending_battle_config["ai_soul"]
		RTSArenaManager.start_battle(player_soul, ai_soul, map_name)

	_battle_active = true
	# Play game start sound
	if AudioManager:
		AudioManager.play_sfx("ui_game_start")
	# Remove countdown label
	if _countdown_label != null:
		_countdown_label.queue_free()
		_countdown_label = null
	_pending_battle_config = null
	_countdown_active = false
	# Initialize item system
	_init_item_system()
	# Initialize trap system
	_init_trap_system()
	# Apply permanent soul upgrades to player unit
	_apply_soul_upgrades_to_player()
	# Apply cognitive upgrades to player AI controller
	_apply_cognitive_upgrades_to_ai()
	# Start achievement tracking
	_start_achievement_tracking()


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

	# Tactical command buttons (GDD v2.0: 6 commands)
	_tactical_buttons["aggressive"] = get_node_or_null("BottomBar/TacticalBar/Aggressive")
	_tactical_buttons["defensive"] = get_node_or_null("BottomBar/TacticalBar/Defensive")
	_tactical_buttons["focus"] = get_node_or_null("BottomBar/TacticalBar/Focus")
	_tactical_buttons["retreat"] = get_node_or_null("BottomBar/TacticalBar/Retreat")
	_tactical_buttons["follow"] = get_node_or_null("BottomBar/TacticalBar/Follow")
	_tactical_buttons["free"] = get_node_or_null("BottomBar/TacticalBar/Free")

	GameLog.debug("RTSArenaController: UI refs setup", "Arena")


## Apply Battleplan UI theme to all UI panels (gold/dark pixel-fantasy style)
## Since RTSArenaController is Node2D, apply theme to individual UI controls
func _apply_ui_theme() -> void:
	var theme_path := "res://assets/ui/battleplan_theme.tres"
	if not ResourceLoader.exists(theme_path):
		GameLog.warning("RTSArenaController: UI theme not found at %s" % theme_path, "UI")
		return
	var theme = load(theme_path)
	if not theme:
		GameLog.warning("RTSArenaController: Failed to load UI theme", "UI")
		return
	# Apply theme to top-level UI panels
	var ui_panels = [
		get_node_or_null("TopBar"),
		get_node_or_null("BattleLog"),
		get_node_or_null("BottomBar"),
	]
	var applied := 0
	for panel in ui_panels:
		if panel and panel is Control:
			panel.theme = theme
			applied += 1
	GameLog.debug("RTSArenaController: Applied UI theme to %d panels" % applied, "UI")


## Apply HUD skin based on ui_hud_skin.png design (dark purple + gold border)
func _apply_hud_skin() -> void:
	# HUD panel style: dark purple bg + gold border + rounded corners
	var hud_panel_style = StyleBoxFlat.new()
	hud_panel_style.bg_color = Color(0.12, 0.09, 0.20, 0.92)
	hud_panel_style.border_color = Color(0.83, 0.66, 0.36, 0.9)
	hud_panel_style.border_width_left = 2
	hud_panel_style.border_width_right = 2
	hud_panel_style.border_width_top = 2
	hud_panel_style.border_width_bottom = 2
	hud_panel_style.corner_radius_top_left = 8
	hud_panel_style.corner_radius_top_right = 8
	hud_panel_style.corner_radius_bottom_left = 8
	hud_panel_style.corner_radius_bottom_right = 8

	# Apply to TopBar, BottomBar, BattleLog
	var hud_panels = [
		get_node_or_null("TopBar"),
		get_node_or_null("BottomBar"),
		get_node_or_null("BattleLog"),
	]
	for panel in hud_panels:
		if panel and panel is Panel:
			panel.add_theme_stylebox_override("panel", hud_panel_style)
		elif panel and panel is PanelContainer:
			panel.add_theme_stylebox_override("panel", hud_panel_style)

	# Player/AI status card style (smaller, with colored accent border)
	var player_card_style = StyleBoxFlat.new()
	player_card_style.bg_color = Color(0.10, 0.12, 0.22, 0.95)
	player_card_style.border_color = Color(0.3, 0.5, 0.9, 0.8)
	player_card_style.border_width_left = 2
	player_card_style.border_width_right = 2
	player_card_style.border_width_top = 2
	player_card_style.border_width_bottom = 2
	player_card_style.corner_radius_top_left = 6
	player_card_style.corner_radius_top_right = 6
	player_card_style.corner_radius_bottom_left = 6
	player_card_style.corner_radius_bottom_right = 6

	var ai_card_style = StyleBoxFlat.new()
	ai_card_style.bg_color = Color(0.18, 0.10, 0.10, 0.95)
	ai_card_style.border_color = Color(0.9, 0.35, 0.3, 0.8)
	ai_card_style.border_width_left = 2
	ai_card_style.border_width_right = 2
	ai_card_style.border_width_top = 2
	ai_card_style.border_width_bottom = 2
	ai_card_style.corner_radius_top_left = 6
	ai_card_style.corner_radius_top_right = 6
	ai_card_style.corner_radius_bottom_left = 6
	ai_card_style.corner_radius_bottom_right = 6

	var player_panel = get_node_or_null("TopBar/PlayerPanel")
	if player_panel and (player_panel is Panel or player_panel is PanelContainer):
		player_panel.add_theme_stylebox_override("panel", player_card_style)
		player_panel.add_theme_stylebox_override("panel", player_card_style)
	var ai_panel = get_node_or_null("TopBar/AIPanel")
	if ai_panel and (ai_panel is Panel or ai_panel is PanelContainer):
		ai_panel.add_theme_stylebox_override("panel", ai_card_style)
		ai_panel.add_theme_stylebox_override("panel", ai_card_style)
	# Skill button style: per-skill element color borders for visual distinction
	# Attack skills: red/orange, Heal: green, Defend: blue
	var skill_element_colors = {
		"heavy_strike": Color(0.9, 0.3, 0.2),   # Red for heavy attack
		"quick_strike": Color(0.95, 0.55, 0.2),  # Orange for quick attack
		"heal": Color(0.3, 0.8, 0.4),             # Green for healing
		"defend": Color(0.3, 0.55, 0.9)           # Blue for defense
	}
	for skill_name in skill_buttons.keys():
		var btn = skill_buttons[skill_name]
		if btn and btn is Button:
			var elem_color = skill_element_colors.get(skill_name, Color(0.83, 0.66, 0.36))
			# Normal: dark bg + element color border
			var s_normal = StyleBoxFlat.new()
			s_normal.bg_color = Color(0.12, 0.08, 0.20, 0.95)
			s_normal.border_color = elem_color
			s_normal.border_width_left = 2
			s_normal.border_width_right = 2
			s_normal.border_width_top = 2
			s_normal.border_width_bottom = 2
			s_normal.corner_radius_top_left = 4
			s_normal.corner_radius_top_right = 4
			s_normal.corner_radius_bottom_left = 4
			s_normal.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", s_normal)
			# Hover: brighter bg + lighter element border
			var s_hover = StyleBoxFlat.new()
			s_hover.bg_color = Color(0.22, 0.15, 0.32, 0.98)
			s_hover.border_color = elem_color.lightened(0.3)
			s_hover.border_width_left = 3
			s_hover.border_width_right = 3
			s_hover.border_width_top = 3
			s_hover.border_width_bottom = 3
			s_hover.corner_radius_top_left = 4
			s_hover.corner_radius_top_right = 4
			s_hover.corner_radius_bottom_left = 4
			s_hover.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("hover", s_hover)
			# Pressed: darker bg
			var s_pressed = StyleBoxFlat.new()
			s_pressed.bg_color = Color(0.08, 0.05, 0.14, 1.0)
			s_pressed.border_color = elem_color.darkened(0.2)
			s_pressed.border_width_left = 2
			s_pressed.border_width_right = 2
			s_pressed.border_width_top = 2
			s_pressed.border_width_bottom = 2
			s_pressed.corner_radius_top_left = 4
			s_pressed.corner_radius_top_right = 4
			s_pressed.corner_radius_bottom_left = 4
			s_pressed.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("pressed", s_pressed)
			# Disabled: grayed out for cooldown
			var s_disabled = StyleBoxFlat.new()
			s_disabled.bg_color = Color(0.06, 0.05, 0.08, 0.9)
			s_disabled.border_color = Color(0.3, 0.28, 0.25, 0.6)
			s_disabled.border_width_left = 2
			s_disabled.border_width_right = 2
			s_disabled.border_width_top = 2
			s_disabled.border_width_bottom = 2
			s_disabled.corner_radius_top_left = 4
			s_disabled.corner_radius_top_right = 4
			s_disabled.corner_radius_bottom_left = 4
			s_disabled.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("disabled", s_disabled)

	# Back button style: red accent border (danger/exit)
	if back_button and back_button is Button:
		var back_normal = StyleBoxFlat.new()
		back_normal.bg_color = Color(0.15, 0.08, 0.10, 0.95)
		back_normal.border_color = Color(0.8, 0.3, 0.3)
		back_normal.border_width_left = 2
		back_normal.border_width_right = 2
		back_normal.border_width_top = 2
		back_normal.border_width_bottom = 2
		back_normal.corner_radius_top_left = 6
		back_normal.corner_radius_top_right = 6
		back_normal.corner_radius_bottom_left = 6
		back_normal.corner_radius_bottom_right = 6
		back_button.add_theme_stylebox_override("normal", back_normal)
		var back_hover = StyleBoxFlat.new()
		back_hover.bg_color = Color(0.25, 0.12, 0.15, 0.98)
		back_hover.border_color = Color(1.0, 0.45, 0.45)
		back_hover.border_width_left = 3
		back_hover.border_width_right = 3
		back_hover.border_width_top = 3
		back_hover.border_width_bottom = 3
		back_hover.corner_radius_top_left = 6
		back_hover.corner_radius_top_right = 6
		back_hover.corner_radius_bottom_left = 6
		back_hover.corner_radius_bottom_right = 6
		back_button.add_theme_stylebox_override("hover", back_hover)
		var back_pressed = StyleBoxFlat.new()
		back_pressed.bg_color = Color(0.10, 0.05, 0.08, 1.0)
		back_pressed.border_color = Color(0.6, 0.2, 0.2)
		back_pressed.border_width_left = 2
		back_pressed.border_width_right = 2
		back_pressed.border_width_top = 2
		back_pressed.border_width_bottom = 2
		back_pressed.corner_radius_top_left = 6
		back_pressed.corner_radius_top_right = 6
		back_pressed.corner_radius_bottom_left = 6
		back_pressed.corner_radius_bottom_right = 6
		back_button.add_theme_stylebox_override("pressed", back_pressed)
		back_button.add_theme_color_override("font_color", Color(0.95, 0.7, 0.7))

	# Tactical command buttons: each with its own color border (game-level UI)
	var tactical_colors = {
		"aggressive": Color(0.9, 0.3, 0.3),
		"defensive": Color(0.3, 0.5, 0.9),
		"focus": Color(0.9, 0.5, 0.2),
		"retreat": Color(0.7, 0.7, 0.3),
		"follow": Color(0.3, 0.8, 0.5),
		"free": Color(0.6, 0.6, 0.65)
	}
	for cmd_id in _tactical_buttons.keys():
		var tbtn = _tactical_buttons[cmd_id]
		if not tbtn or not (tbtn is Button):
			continue
		var cmd_color = tactical_colors.get(cmd_id, Color(0.6, 0.6, 0.65))
		# Normal: dark bg + colored border
		var t_normal = StyleBoxFlat.new()
		t_normal.bg_color = Color(0.08, 0.06, 0.15, 0.95)
		t_normal.border_color = cmd_color
		t_normal.border_width_left = 2
		t_normal.border_width_right = 2
		t_normal.border_width_top = 2
		t_normal.border_width_bottom = 2
		t_normal.corner_radius_top_left = 5
		t_normal.corner_radius_top_right = 5
		t_normal.corner_radius_bottom_right = 5
		t_normal.corner_radius_bottom_left = 5
		tbtn.add_theme_stylebox_override("normal", t_normal)
		# Hover: brighter bg + lighter border
		var t_hover = StyleBoxFlat.new()
		t_hover.bg_color = Color(0.14, 0.10, 0.22, 0.98)
		t_hover.border_color = cmd_color.lightened(0.35)
		t_hover.border_width_left = 3
		t_hover.border_width_right = 3
		t_hover.border_width_top = 3
		t_hover.border_width_bottom = 3
		t_hover.corner_radius_top_left = 5
		t_hover.corner_radius_top_right = 5
		t_hover.corner_radius_bottom_right = 5
		t_hover.corner_radius_bottom_left = 5
		tbtn.add_theme_stylebox_override("hover", t_hover)
		# Pressed: darker bg
		var t_pressed = StyleBoxFlat.new()
		t_pressed.bg_color = Color(0.05, 0.04, 0.1, 1.0)
		t_pressed.border_color = cmd_color
		t_pressed.border_width_left = 2
		t_pressed.border_width_right = 2
		t_pressed.border_width_top = 2
		t_pressed.border_width_bottom = 2
		t_pressed.corner_radius_top_left = 5
		t_pressed.corner_radius_top_right = 5
		t_pressed.corner_radius_bottom_right = 5
		t_pressed.corner_radius_bottom_left = 5
		tbtn.add_theme_stylebox_override("pressed", t_pressed)
		# Text colors
		tbtn.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
		tbtn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.88))
		tbtn.add_theme_font_size_override("font_size", 12)

	# Battle log text color adjustment
	if battle_log:
		battle_log.modulate = Color(0.9, 0.85, 0.75)

	# Battle time label: gold font with outline + subtle background
	if battle_time_label:
		battle_time_label.add_theme_font_size_override("font_size", 22)
		battle_time_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
		battle_time_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
		battle_time_label.add_theme_constant_override("outline_size", 4)
		battle_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		battle_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Player name label: blue font with outline
	if player_name_label:
		player_name_label.add_theme_font_size_override("font_size", 16)
		player_name_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
		player_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.15, 0.9))
		player_name_label.add_theme_constant_override("outline_size", 3)

	# AI name label: red font with outline
	if ai_name_label:
		ai_name_label.add_theme_font_size_override("font_size", 16)
		ai_name_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		ai_name_label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.0, 0.9))
		ai_name_label.add_theme_constant_override("outline_size", 3)

	GameLog.info("RTSArenaController: Applied HUD skin (dark purple + gold)", "UI")


## Apply custom styles to HP and energy bars (orb-like with gold border)
## Setup value labels for main HP/energy bars
func _setup_main_hp_energy_labels() -> void:
	# Player HP value label
	if player_hp_bar:
		var p_hp_label = Label.new()
		p_hp_label.name = "HPValueLabel"
		p_hp_label.text = "100/100"
		p_hp_label.anchors_preset = Control.PRESET_FULL_RECT
		p_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p_hp_label.add_theme_font_size_override("font_size", 11)
		p_hp_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		p_hp_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		p_hp_label.add_theme_constant_override("outline_size", 2)
		p_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_hp_label.z_index = 5
		player_hp_bar.add_child(p_hp_label)
		_player_hp_value_label = p_hp_label
	# Player energy value label
	if player_energy_bar:
		var p_en_label = Label.new()
		p_en_label.name = "EnergyValueLabel"
		p_en_label.text = "0/50"
		p_en_label.anchors_preset = Control.PRESET_FULL_RECT
		p_en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_en_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p_en_label.add_theme_font_size_override("font_size", 11)
		p_en_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		p_en_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		p_en_label.add_theme_constant_override("outline_size", 2)
		p_en_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_en_label.z_index = 5
		player_energy_bar.add_child(p_en_label)
		_player_energy_value_label = p_en_label
	# AI HP value label
	if ai_hp_bar:
		var a_hp_label = Label.new()
		a_hp_label.name = "HPValueLabel"
		a_hp_label.text = "100/100"
		a_hp_label.anchors_preset = Control.PRESET_FULL_RECT
		a_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		a_hp_label.add_theme_font_size_override("font_size", 11)
		a_hp_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))
		a_hp_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		a_hp_label.add_theme_constant_override("outline_size", 2)
		a_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a_hp_label.z_index = 5
		ai_hp_bar.add_child(a_hp_label)
		_ai_hp_value_label = a_hp_label
	# AI energy value label
	if ai_energy_bar:
		var a_en_label = Label.new()
		a_en_label.name = "EnergyValueLabel"
		a_en_label.text = "0/50"
		a_en_label.anchors_preset = Control.PRESET_FULL_RECT
		a_en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a_en_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		a_en_label.add_theme_font_size_override("font_size", 11)
		a_en_label.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
		a_en_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		a_en_label.add_theme_constant_override("outline_size", 2)
		a_en_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a_en_label.z_index = 5
		ai_energy_bar.add_child(a_en_label)
		_ai_energy_value_label = a_en_label


func _apply_hp_energy_styles() -> void:
	# HP bar style: red gradient fill with gold border
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.05, 0.05, 0.9)
	hp_bg.border_color = Color(0.8, 0.6, 0.2, 1.0)
	hp_bg.border_width_left = 2
	hp_bg.border_width_right = 2
	hp_bg.border_width_top = 2
	hp_bg.border_width_bottom = 2
	hp_bg.corner_radius_top_left = 6
	hp_bg.corner_radius_top_right = 6
	hp_bg.corner_radius_bottom_left = 6
	hp_bg.corner_radius_bottom_right = 6

	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	hp_fill.corner_radius_top_left = 4
	hp_fill.corner_radius_top_right = 4
	hp_fill.corner_radius_bottom_left = 4
	hp_fill.corner_radius_bottom_right = 4

	# Energy bar style: blue gradient fill with gold border
	var energy_bg = StyleBoxFlat.new()
	energy_bg.bg_color = Color(0.05, 0.08, 0.15, 0.9)
	energy_bg.border_color = Color(0.8, 0.6, 0.2, 1.0)
	energy_bg.border_width_left = 2
	energy_bg.border_width_right = 2
	energy_bg.border_width_top = 2
	energy_bg.border_width_bottom = 2
	energy_bg.corner_radius_top_left = 6
	energy_bg.corner_radius_top_right = 6
	energy_bg.corner_radius_bottom_left = 6
	energy_bg.corner_radius_bottom_right = 6

	var energy_fill = StyleBoxFlat.new()
	energy_fill.bg_color = Color(0.2, 0.5, 0.9, 1.0)
	energy_fill.corner_radius_top_left = 4
	energy_fill.corner_radius_top_right = 4
	energy_fill.corner_radius_bottom_left = 4
	energy_fill.corner_radius_bottom_right = 4

	# Apply to player bars
	if player_hp_bar:
		player_hp_bar.add_theme_stylebox_override("background", hp_bg)
		player_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	if player_energy_bar:
		player_energy_bar.add_theme_stylebox_override("background", energy_bg)
		player_energy_bar.add_theme_stylebox_override("fill", energy_fill)

	# Apply to AI bars
	if ai_hp_bar:
		ai_hp_bar.add_theme_stylebox_override("background", hp_bg)
		ai_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	if ai_energy_bar:
		ai_energy_bar.add_theme_stylebox_override("background", energy_bg)
		ai_energy_bar.add_theme_stylebox_override("fill", energy_fill)

	GameLog.debug("RTSArenaController: Applied HP/energy bar orb styles", "UI")


## Connect to RTSArenaManager signals
func _connect_signals() -> void:
	RTSArenaManager.battle_started.connect(_on_battle_started)
	RTSArenaManager.battle_finished.connect(_on_battle_finished)
	RTSArenaManager.battle_time_updated.connect(_on_battle_time_updated)
	RTSArenaManager.unit_spawned.connect(_on_unit_spawned)
	RTSArenaManager.log_added.connect(_on_log_added)


## Setup skill button signals
func _setup_skill_buttons() -> void:
	# Apply skill icons from design asset sheet
	_apply_skill_icons()
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

	# Initialize tactical command system (GDD v2.0 Chapter 2.1.1)
	_init_tactical_command_system()
	# Initialize talent upgrade system (GDD v2.0 Chapter 5)
	_init_talent_system()
	# Create cooldown overlays for each skill button
	for skill_name in skill_buttons.keys():
		var button = skill_buttons[skill_name]
		if button:
			# Cooldown overlay (gradient fill from bottom)
			var overlay = ColorRect.new()
			overlay.name = "CooldownOverlay"
			overlay.color = Color(0.1, 0.05, 0.2, 0.75)
			overlay.size = button.size
			overlay.position = Vector2(0, 0)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.visible = false
			button.add_child(overlay)
			_skill_cooldown_overlays[skill_name] = overlay
			# Cooldown number label
			var cd_label = Label.new()
			cd_label.name = "CooldownLabel"
			cd_label.anchors_preset = Control.PRESET_FULL_RECT
			cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cd_label.add_theme_font_size_override("font_size", 28)
			cd_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
			cd_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
			cd_label.add_theme_constant_override("outline_size", 3)
			cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cd_label.visible = false
			cd_label.z_index = 10
			button.add_child(cd_label)
			_skill_cooldown_labels[skill_name] = cd_label


## Apply skill icons from design asset sheet to all skill buttons
## Sprite sheet: 3 rows x 6 cols, 16 skill icons
## Mapping: heavy_strike->earthquake(10), quick_strike->fireball(0),
## heal->heal(4), defend->rock_shield(3)
func _apply_skill_icons() -> void:
	var sheet_path := "res://assets/art/skill_icon_sheet_v2.png"
	if not ResourceLoader.exists(sheet_path):
		GameLog.debug("RTSArena: Skill icon sheet not found, using text buttons", "UI")
		return
	var sheet = load(sheet_path)
	if sheet == null or not (sheet is Texture2D):
		GameLog.warning("RTSArena: Failed to load skill icon sheet", "UI")
		return
	# Sheet: 1920x1080, 3 rows x 6 cols, each cell 320x360
	var cell_w: int = 320
	var cell_h: int = 360
	# Skill name -> sheet index (row*6 + col)
	var skill_indices := {
		"heavy_strike": 10,  # 大地震击 (row 2, col 4)
		"quick_strike": 0,   # 火球术 (row 0, col 0)
		"heal": 4,           # 治疗术 (row 0, col 4)
		"defend": 3,         # 岩石护盾 (row 0, col 3)
	}
	for skill_name in skill_buttons.keys():
		var button = skill_buttons[skill_name]
		if button == null:
			continue
		var idx = skill_indices.get(skill_name, -1)
		if idx < 0:
			continue
		var row: int = idx / 6
		var col: int = idx % 6
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		button.icon = atlas
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = ""  # Clear text, icon only
		button.expand_icon = true
		# Set tooltip with skill name and energy cost (GDD v2.0: player skill release)
		var skill_names := {
			"heavy_strike": "重击",
			"quick_strike": "快击",
			"heal": "治疗",
			"defend": "防御"
		}
		var skill_costs := {
			"heavy_strike": 15,
			"quick_strike": 8,
			"heal": 20,
			"defend": 12
		}
		var s_name = skill_names.get(skill_name, skill_name)
		var s_cost = skill_costs.get(skill_name, 0)
		button.tooltip_text = "%s (能量: %d)" % [s_name, s_cost]
		GameLog.debug("RTSArena: Applied icon for %s (idx=%d)" % [skill_name, idx], "UI")


## Setup macro command UI (design doc: coach-style RTS)
## Player can issue one macro command per 30 seconds
## Commands: gather, retreat, attack, defend
func _setup_macro_commands() -> void:
	# Create command panel at bottom center with game-level UI
	_command_panel = Panel.new()
	_command_panel.position = Vector2(380, 490)
	_command_panel.size = Vector2(520, 75)
	_command_panel.name = "MacroCommandPanel"
	# Game-level panel style: dark purple + gold border + rounded corners
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.92)
	panel_style.border_color = Color(0.8, 0.7, 0.4)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	_command_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_command_panel)

	# Title label (gold, 14px)
	var title = Label.new()
	title.text = "教练指令"
	title.position = Vector2(12, 6)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	_command_panel.add_child(title)

	# Cooldown label (right-aligned)
	_command_cooldown_label = Label.new()
	_command_cooldown_label.text = "就绪"
	_command_cooldown_label.position = Vector2(420, 6)
	_command_cooldown_label.add_theme_font_size_override("font_size", 13)
	_command_cooldown_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	_command_panel.add_child(_command_cooldown_label)

	# Create command buttons with game-level three-state styles
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
		btn.position = Vector2(btn_x, 32)
		btn.size = Vector2(115, 34)
		btn.add_theme_font_size_override("font_size", 13)
		btn.name = "Cmd_%s" % cmd["name"]
		# Normal style: dark bg + element color border
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
		normal_style.border_color = cmd["color"]
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.corner_radius_top_left = 5
		normal_style.corner_radius_top_right = 5
		normal_style.corner_radius_bottom_right = 5
		normal_style.corner_radius_bottom_left = 5
		btn.add_theme_stylebox_override("normal", normal_style)
		# Hover style: brighter bg + lighter border
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.12, 0.09, 0.2, 0.98)
		hover_style.border_color = cmd["color"].lightened(0.3)
		hover_style.border_width_left = 3
		hover_style.border_width_right = 3
		hover_style.border_width_top = 3
		hover_style.border_width_bottom = 3
		hover_style.corner_radius_top_left = 5
		hover_style.corner_radius_top_right = 5
		hover_style.corner_radius_bottom_right = 5
		hover_style.corner_radius_bottom_left = 5
		btn.add_theme_stylebox_override("hover", hover_style)
		# Pressed style: darker bg
		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.05, 0.04, 0.1, 1.0)
		pressed_style.border_color = cmd["color"]
		pressed_style.border_width_left = 2
		pressed_style.border_width_right = 2
		pressed_style.border_width_top = 2
		pressed_style.border_width_bottom = 2
		pressed_style.corner_radius_top_left = 5
		pressed_style.corner_radius_top_right = 5
		pressed_style.corner_radius_bottom_right = 5
		pressed_style.corner_radius_bottom_left = 5
		btn.add_theme_stylebox_override("pressed", pressed_style)
		# Text color: light
		btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
		btn.pressed.connect(_on_macro_command.bind(cmd["name"]))
		_command_panel.add_child(btn)
		_command_buttons[cmd["name"]] = btn
		btn_x += 125

	GameLog.info("RTSArenaController: Macro command UI setup complete (game-level)", "Arena")


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
		_show_success_message("指令已下达")
	else:
		_show_error_message("指令失败")
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

	# Animate when weather changes
	if weather_name != _last_weather and _last_weather != "":
		_weather_label.scale = Vector2(1.3, 1.3)
		var weather_tween = create_tween()
		weather_tween.tween_property(_weather_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT)
	_last_weather = weather_name

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
	# Smoothly update energy bars (runs always for visual smoothness)
	_update_energy_bars_smooth(delta)
	# Update countdown if active
	if _countdown_active:
		_countdown_timer -= delta
		_update_countdown_display()
		if _countdown_timer <= 0.0:
			_start_battle_after_countdown()
		return
	if not _battle_active:
		return
	# Update screen shake effect (runs even when paused for visual feedback)
	_update_screen_shake(delta)
	# Update hit flash effect (runs even when paused)
	_update_hit_flash(delta)
	# Update skill particle effect (runs even when paused)
	_update_skill_particles(delta)
	# Update atmosphere effects (runs even when paused)
	_update_atmosphere(delta)
	# Update chromatic aberration decay
	_update_chromatic_aberration(delta)
	# Update battle countdown
	_update_countdown(delta)
	# Skip battle logic updates when paused (UI still renders)
	if _is_paused:
		_update_unit_display()
		return
	_update_unit_display()
	# Sync unit visual proxies to logical positions (SoulUnit is child of autoload, not in visible scene)
	if _player_visual and is_instance_valid(RTSArenaManager.player_unit):
		_player_visual.position = RTSArenaManager.player_unit.position
	if _ai_visual and is_instance_valid(RTSArenaManager.ai_unit):
		_ai_visual.position = RTSArenaManager.ai_unit.position
	# GAP-001: Sync team visual proxies
	for i in range(_player_visuals.size()):
		if i < RTSArenaManager.player_units.size():
			var p_unit = RTSArenaManager.player_units[i]
			if p_unit and is_instance_valid(p_unit) and p_unit.state != SoulUnit.UnitState.DEAD:
				_player_visuals[i].visible = true
				_player_visuals[i].position = p_unit.position
			else:
				_player_visuals[i].visible = false
	for i in range(_ai_visuals.size()):
		if i < RTSArenaManager.ai_units.size():
			var a_unit = RTSArenaManager.ai_units[i]
			if a_unit and is_instance_valid(a_unit) and a_unit.state != SoulUnit.UnitState.DEAD:
				_ai_visuals[i].visible = true
				_ai_visuals[i].position = a_unit.position
			else:
				_ai_visuals[i].visible = false
	# Sync dynamic lights to unit positions with subtle pulse
	if _player_light and is_instance_valid(RTSArenaManager.player_unit):
		_player_light.position = RTSArenaManager.player_unit.position
		var pulse = 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.15
		_player_light.energy = 1.2 * pulse
	if _ai_light and is_instance_valid(RTSArenaManager.ai_unit):
		_ai_light.position = RTSArenaManager.ai_unit.position
		var ai_pulse = 1.0 + sin(Time.get_ticks_msec() / 350.0 + 1.0) * 0.15
		_ai_light.energy = 1.2 * ai_pulse
	# GAP-001: Sync team lights
	for i in range(_player_lights.size()):
		if i < _player_visuals.size() and _player_visuals[i].visible:
			_player_lights[i].position = _player_visuals[i].position
			_player_lights[i].energy = 1.2 * (1.0 + sin(Time.get_ticks_msec() / 300.0 + i * 0.5) * 0.15)
		else:
			_player_lights[i].energy = 0.0
	for i in range(_ai_lights.size()):
		if i < _ai_visuals.size() and _ai_visuals[i].visible:
			_ai_lights[i].position = _ai_visuals[i].position
			_ai_lights[i].energy = 1.2 * (1.0 + sin(Time.get_ticks_msec() / 350.0 + i * 0.5 + 1.0) * 0.15)
		else:
			_ai_lights[i].energy = 0.0
	_update_skill_cooldowns()
	_update_command_cooldown(delta)
	_update_weather_display()
	_update_status_display()
	_update_talent_check(delta)
	if _item_system and _battle_active:
		_item_system.update(delta, RTSArenaManager.player_unit, RTSArenaManager.ai_unit)
	if _trap_system and _battle_active:
		_trap_system.update(delta, RTSArenaManager.player_unit, RTSArenaManager.ai_unit)
	_update_crit_display(delta)
	_update_dodge_display(delta)
	_update_heal_display(delta)
	_update_defend_display(delta)
	_update_skill_display(delta)
	_update_damage_display(delta)
	# Note: _update_skill_particles already called above (runs even when paused)
	_update_error_display(delta)
	_update_success_display(delta)
	if minimap:
		minimap.update_minimap()


## Update unit HP/energy display
func _update_unit_display() -> void:
	var info = RTSArenaManager.get_battle_info()

	if info.has("player") and player_hp_bar:
		var p = info["player"]
		player_hp_bar.value = float(p.get("hp", 0)) / float(p.get("max_hp", 100)) * 100.0
		if _player_hp_value_label:
			_player_hp_value_label.text = "%d/%d" % [int(p.get("hp", 0)), int(p.get("max_hp", 100))]
		if player_energy_bar:
			_target_player_energy = float(p.get("energy", 0)) / float(p.get("max_energy", 50)) * 100.0
			if _player_energy_value_label:
				_player_energy_value_label.text = "%d/%d" % [int(p.get("energy", 0)), int(p.get("max_energy", 50))]

	if info.has("ai") and ai_hp_bar:
		var a = info["ai"]
		ai_hp_bar.value = float(a.get("hp", 0)) / float(a.get("max_hp", 100)) * 100.0
		if _ai_hp_value_label:
			_ai_hp_value_label.text = "%d/%d" % [int(a.get("hp", 0)), int(a.get("max_hp", 100))]
		if ai_energy_bar:
			_target_ai_energy = float(a.get("energy", 0)) / float(a.get("max_energy", 50)) * 100.0
			if _ai_energy_value_label:
				_ai_energy_value_label.text = "%d/%d" % [int(a.get("energy", 0)), int(a.get("max_energy", 50))]

	# GAP-001: Update team HP bars
	if info.has("player_team"):
		var player_team = info["player_team"]
		for i in range(_player_team_hp_bars.size()):
			if i < player_team.size():
				var unit_info = player_team[i]
				var hp_pct = float(unit_info.get("hp", 0)) / float(unit_info.get("max_hp", 100)) * 100.0
				_player_team_hp_bars[i].value = hp_pct
				_player_team_hp_bars[i].visible = true
				# Update HP value label
				var p_hp_label = _player_team_hp_bars[i].get_node_or_null("HPValueLabel")
				if p_hp_label:
					p_hp_label.text = "%d/%d" % [int(unit_info.get("hp", 0)), int(unit_info.get("max_hp", 100))]
			else:
				_player_team_hp_bars[i].visible = false
	if info.has("ai_team"):
		var ai_team = info["ai_team"]
		for i in range(_ai_team_hp_bars.size()):
			if i < ai_team.size():
				var unit_info = ai_team[i]
				var hp_pct = float(unit_info.get("hp", 0)) / float(unit_info.get("max_hp", 100)) * 100.0
				_ai_team_hp_bars[i].value = hp_pct
				_ai_team_hp_bars[i].visible = true
				# Update HP value label
				var a_hp_label = _ai_team_hp_bars[i].get_node_or_null("HPValueLabel")
				if a_hp_label:
					a_hp_label.text = "%d/%d" % [int(unit_info.get("hp", 0)), int(unit_info.get("max_hp", 100))]
			else:
				_ai_team_hp_bars[i].visible = false


## Smoothly update energy bars towards target values
func _update_energy_bars_smooth(delta: float) -> void:
	if player_energy_bar:
		_current_player_energy = lerp(_current_player_energy, _target_player_energy, delta * _energy_bar_smooth_speed)
		player_energy_bar.value = _current_player_energy
	if ai_energy_bar:
		_current_ai_energy = lerp(_current_ai_energy, _target_ai_energy, delta * _energy_bar_smooth_speed)
		ai_energy_bar.value = _current_ai_energy


## Update skill cooldown display
func _update_skill_cooldowns() -> void:
	# Determine which unit to check cooldowns for
	var unit_for_cd = RTSArenaManager.player_unit
	var is_team = GameState.get_value("battle", "is_team_battle", false)
	if is_team and _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
		unit_for_cd = RTSArenaManager.player_units[_selected_unit_index]
	if unit_for_cd == null:
		return

	for skill_name in skill_buttons.keys():
		var button = skill_buttons[skill_name]
		if button == null:
			continue
		var cooldown = unit_for_cd.skill_cooldowns.get(skill_name, 0)
		var was_on_cd = _skill_was_on_cooldown.get(skill_name, false)
		button.disabled = cooldown > 0
		# Update cooldown overlay visual
		var overlay = _skill_cooldown_overlays.get(skill_name, null)
		var cd_label = _skill_cooldown_labels.get(skill_name, null)
		if overlay:
			if cooldown > 0:
				# Get max cooldown for this skill
				var max_cd = _get_skill_max_cooldown(skill_name)
				var progress = 1.0 - (cooldown / max_cd) if max_cd > 0 else 0.0
				overlay.visible = true
				overlay.size.y = button.size.y * (1.0 - progress)
				overlay.position.y = button.size.y * progress
			else:
				overlay.visible = false
				overlay.size.y = 0
		# Update cooldown number label
		if cd_label:
			if cooldown > 0:
				cd_label.visible = true
				cd_label.text = "%.1f" % cooldown
				# Pulse effect when cooldown is almost done (< 1 sec)
				if cooldown < 1.0:
					var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.15
					cd_label.scale = Vector2(pulse, pulse)
					cd_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				else:
					cd_label.scale = Vector2(1.0, 1.0)
					cd_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
			else:
				cd_label.visible = false
				cd_label.scale = Vector2(1.0, 1.0)
		if cooldown > 0:
			# Button shows icon only; cooldown indicated by overlay + disabled state
			_skill_was_on_cooldown[skill_name] = true
		else:
			# Play skill ready sound when cooldown finishes
			if was_on_cd and AudioManager:
				AudioManager.play_sfx("bat_skill_ready", 0.5)
			_skill_was_on_cooldown[skill_name] = false


## Get max cooldown for a skill
func _get_skill_max_cooldown(skill_name: String) -> float:
	match skill_name:
		"heavy_strike":
			return 5.0
		"quick_strike":
			return 2.0
		"heal":
			return 8.0
		"defend":
			return 6.0
	return 5.0


## Handle battle started
func _on_battle_started(p_battle_info: Dictionary) -> void:
	_battle_active = true
	# Enable pause button and reset speed
	if _pause_button:
		_pause_button.disabled = false
	_current_speed = 1.0
	RTSArenaManager.set_battle_speed(1.0)
	if _speed_button:
		_speed_button.text = "⚡ 1x"
		_speed_button.disabled = false
	_add_log("Battle started!")

	# Play battle start sound and BGM
	if AudioManager:
		AudioManager.play_sfx("battle_ui_start")
		AudioManager.play_bgm("battle")

	# Start countdown (3-2-1-GO!)
	_start_battle_countdown()

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

	# GAP-001: Setup team battle visuals if team battle
	if p_battle_info.get("team_battle", false):
		_setup_team_visuals(p_battle_info)

	GameLog.info("RTSArenaController: Battle started", "Arena")


## GAP-001: Setup visual proxies and HP bars for team battle (4v4)
func _setup_team_visuals(p_battle_info: Dictionary) -> void:
	GameLog.info("RTSArenaController: Setting up team battle visuals", "Arena")

	# Clear existing team visuals
	_clear_team_visuals()

	# Create player team visuals
	var player_team = p_battle_info.get("player_team", [])
	for i in range(player_team.size()):
		var unit_info = player_team[i]
		var element = unit_info.get("element", "neutral")
		var visual = _create_unit_visual(element)
		visual.name = "PlayerTeamVisual_%d" % i
		visual.position = Vector2(200, 300 + i * 80)
		visual.z_index = 10
		add_child(visual)
		_player_visuals.append(visual)

		# Create light for each unit
		var light = PointLight2D.new()
		light.texture = _create_light_texture()
		light.energy = 1.2
		light.color = _get_element_light_color(element)
		light.position = visual.position
		add_child(light)
		_player_lights.append(light)

	# Create AI team visuals
	var ai_team = p_battle_info.get("ai_team", [])
	for i in range(ai_team.size()):
		var unit_info = ai_team[i]
		var element = unit_info.get("element", "neutral")
		var visual = _create_unit_visual(element)
		visual.name = "AITeamVisual_%d" % i
		visual.modulate = Color(1.0, 0.7, 0.7)  # Slight red tint for enemy
		visual.position = Vector2(1080, 300 + i * 80)
		visual.z_index = 10
		add_child(visual)
		_ai_visuals.append(visual)

		# Create light for each unit
		var light = PointLight2D.new()
		light.texture = _create_light_texture()
		light.energy = 1.2
		light.color = Color(1.0, 0.5, 0.5)
		light.position = visual.position
		add_child(light)
		_ai_lights.append(light)

	# Create selection indicator (gold circle under selected unit)
	_selection_indicator = _create_selection_indicator()
	add_child(_selection_indicator)
	_selection_indicator.visible = false

	# Create selected unit info panel (bottom-left, above HP bars)
	_selected_unit_panel = _create_selected_unit_panel()
	add_child(_selected_unit_panel)
	_selected_unit_panel.visible = false

	# Create team HP bars with soul names and element colors
	_create_team_hp_bars(player_team, ai_team)


## GAP-001: Create team HP bars UI with soul names and element colors
func _create_team_hp_bars(p_player_team: Array, p_ai_team: Array) -> void:
	# Element colors for HP bar fill
	var element_colors = {
		"fire": Color(1.0, 0.4, 0.2),
		"water": Color(0.2, 0.5, 1.0),
		"earth": Color(0.6, 0.5, 0.3),
		"wind": Color(0.4, 0.9, 0.7),
		"thunder": Color(0.9, 0.8, 0.2),
		"ice": Color(0.5, 0.8, 1.0),
		"dark": Color(0.6, 0.3, 0.8),
		"light": Color(1.0, 0.9, 0.5),
		"neutral": Color(0.5, 0.5, 0.5)
	}

	# Player team HP bars (top-left, vertical stack with names)
	for i in range(p_player_team.size()):
		var unit_info = p_player_team[i]
		var soul_name = unit_info.get("name", "灵魂%d" % (i + 1))
		var element = unit_info.get("element", "neutral")
		var fill_color = element_colors.get(element, Color(0.3, 0.8, 0.3))

		# Clickable container for name + HP bar (unit selection)
		var container = Button.new()
		container.name = "PlayerUnitSelect_%d" % i
		container.position = Vector2(15, 15 + i * 42)
		container.custom_minimum_size = Vector2(245, 44)
		container.flat = true
		# Normal style: transparent with element color border
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.06, 0.04, 0.12, 0.7)
		normal_style.border_color = fill_color.darkened(0.4)
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_right = 4
		normal_style.corner_radius_bottom_left = 4
		container.add_theme_stylebox_override("normal", normal_style)
		# Hover style: brighter element color border
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.1, 0.08, 0.18, 0.85)
		hover_style.border_color = fill_color.lightened(0.2)
		hover_style.border_width_left = 3
		hover_style.border_width_right = 3
		hover_style.border_width_top = 3
		hover_style.border_width_bottom = 3
		hover_style.corner_radius_top_left = 4
		hover_style.corner_radius_top_right = 4
		hover_style.corner_radius_bottom_right = 4
		hover_style.corner_radius_bottom_left = 4
		container.add_theme_stylebox_override("hover", hover_style)
		# Pressed style: element color border
		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.12, 0.1, 0.2, 0.9)
		pressed_style.border_color = fill_color
		pressed_style.border_width_left = 2
		pressed_style.border_width_right = 2
		pressed_style.border_width_top = 2
		pressed_style.border_width_bottom = 2
		pressed_style.corner_radius_top_left = 4
		pressed_style.corner_radius_top_right = 4
		pressed_style.corner_radius_bottom_right = 4
		pressed_style.corner_radius_bottom_left = 4
		container.add_theme_stylebox_override("pressed", pressed_style)
		# Focus style: gold border for selected
		var focus_style = StyleBoxFlat.new()
		focus_style.bg_color = Color(0.12, 0.08, 0.2, 0.9)
		focus_style.border_color = Color(1.0, 0.88, 0.5)
		focus_style.border_width_left = 3
		focus_style.border_width_right = 3
		focus_style.border_width_top = 3
		focus_style.border_width_bottom = 3
		focus_style.corner_radius_top_left = 4
		focus_style.corner_radius_top_right = 4
		focus_style.corner_radius_bottom_right = 4
		focus_style.corner_radius_bottom_left = 4
		container.add_theme_stylebox_override("focus", focus_style)
		add_child(container)
		_player_unit_containers.append(container)

		# Inner HBox for portrait + (name + HP bar)
		var inner_hbox = HBoxContainer.new()
		inner_hbox.name = "InnerHBox"
		inner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(inner_hbox)

		# Soul portrait (40x40 with element color border)
		var portrait_panel = Panel.new()
		portrait_panel.name = "PortraitPanel"
		portrait_panel.custom_minimum_size = Vector2(40, 40)
		var portrait_style = StyleBoxFlat.new()
		portrait_style.bg_color = Color(0.06, 0.04, 0.12, 0.9)
		portrait_style.border_color = fill_color
		portrait_style.border_width_left = 2
		portrait_style.border_width_right = 2
		portrait_style.border_width_top = 2
		portrait_style.border_width_bottom = 2
		portrait_style.corner_radius_top_left = 4
		portrait_style.corner_radius_top_right = 4
		portrait_style.corner_radius_bottom_right = 4
		portrait_style.corner_radius_bottom_left = 4
		portrait_panel.add_theme_stylebox_override("panel", portrait_style)
		inner_hbox.add_child(portrait_panel)

		var portrait_texture = TextureRect.new()
		portrait_texture.name = "PortraitTexture"
		portrait_texture.custom_minimum_size = Vector2(36, 36)
		portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Load soul portrait based on element
		var element_name = element
		if element_name == "dark":
			element_name = "shadow"
		var portrait_path = "res://assets/art/characters/character_%s_soul_portrait.png" % element_name
		if ResourceLoader.exists(portrait_path):
			portrait_texture.texture = load(portrait_path)
		portrait_panel.add_child(portrait_texture)

		# Inner VBox for name + HP bar
		var inner_box = VBoxContainer.new()
		inner_box.name = "InnerBox"
		inner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_hbox.add_child(inner_box)

		# Name label
		var name_label = Label.new()
		name_label.text = soul_name
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner_box.add_child(name_label)

		# HP bar
		var hp_bar = ProgressBar.new()
		hp_bar.name = "PlayerTeamHP_%d" % i
		hp_bar.custom_minimum_size = Vector2(195, 18)
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
		hp_bar.show_percentage = false
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# HP value label overlay
		var hp_value_label = Label.new()
		hp_value_label.name = "HPValueLabel"
		hp_value_label.text = "100/100"
		hp_value_label.anchors_preset = Control.PRESET_FULL_RECT
		hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_value_label.add_theme_font_size_override("font_size", 10)
		hp_value_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		hp_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		hp_value_label.add_theme_constant_override("outline_size", 2)
		hp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_value_label.z_index = 5
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.08, 0.12, 0.9)
		bg_style.border_color = Color(0.5, 0.4, 0.25)
		bg_style.border_width_left = 1
		bg_style.border_width_right = 1
		bg_style.border_width_top = 1
		bg_style.border_width_bottom = 1
		bg_style.corner_radius_top_left = 3
		bg_style.corner_radius_top_right = 3
		bg_style.corner_radius_bottom_right = 3
		bg_style.corner_radius_bottom_left = 3
		hp_bar.add_theme_stylebox_override("background", bg_style)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_right = 2
		fill_style.corner_radius_bottom_left = 2
		hp_bar.add_theme_stylebox_override("fill", fill_style)
		inner_box.add_child(hp_bar)
		hp_bar.add_child(hp_value_label)
		_player_team_hp_bars.append(hp_bar)

		# Connect click signal for unit selection
		var unit_idx = i
		container.pressed.connect(func(): _select_player_unit(unit_idx))

	# AI team HP bars (top-right, vertical stack with names)
	for i in range(p_ai_team.size()):
		var unit_info = p_ai_team[i]
		var soul_name = unit_info.get("name", "敌方%d" % (i + 1))
		var element = unit_info.get("element", "neutral")
		var fill_color = element_colors.get(element, Color(0.8, 0.3, 0.3))

		# Panel container with element color border
		var container = Panel.new()
		container.name = "AITeamHPContainer_%d" % i
		container.position = Vector2(1065, 15 + i * 42)
		container.custom_minimum_size = Vector2(245, 44)
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.7)
		panel_style.border_color = fill_color.darkened(0.4)
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 4
		panel_style.corner_radius_top_right = 4
		panel_style.corner_radius_bottom_right = 4
		panel_style.corner_radius_bottom_left = 4
		container.add_theme_stylebox_override("panel", panel_style)
		add_child(container)

		# Inner HBox for (name + HP bar) + portrait
		var inner_hbox = HBoxContainer.new()
		inner_hbox.name = "InnerHBox"
		inner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(inner_hbox)

		# Inner VBox for name + HP bar
		var inner_box = VBoxContainer.new()
		inner_box.name = "InnerBox"
		inner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_hbox.add_child(inner_box)

		# Name label (right-aligned)
		var name_label = Label.new()
		name_label.text = soul_name
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		inner_box.add_child(name_label)

		# Soul portrait (40x40 with element color border, on the right)
		var portrait_panel = Panel.new()
		portrait_panel.name = "PortraitPanel"
		portrait_panel.custom_minimum_size = Vector2(40, 40)
		var ai_portrait_style = StyleBoxFlat.new()
		ai_portrait_style.bg_color = Color(0.06, 0.04, 0.12, 0.9)
		ai_portrait_style.border_color = fill_color
		ai_portrait_style.border_width_left = 2
		ai_portrait_style.border_width_right = 2
		ai_portrait_style.border_width_top = 2
		ai_portrait_style.border_width_bottom = 2
		ai_portrait_style.corner_radius_top_left = 4
		ai_portrait_style.corner_radius_top_right = 4
		ai_portrait_style.corner_radius_bottom_right = 4
		ai_portrait_style.corner_radius_bottom_left = 4
		portrait_panel.add_theme_stylebox_override("panel", ai_portrait_style)
		inner_hbox.add_child(portrait_panel)

		var ai_portrait_texture = TextureRect.new()
		ai_portrait_texture.name = "PortraitTexture"
		ai_portrait_texture.custom_minimum_size = Vector2(36, 36)
		ai_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ai_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ai_portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Load soul portrait based on element
		var ai_element_name = element
		if ai_element_name == "dark":
			ai_element_name = "shadow"
		var ai_portrait_path = "res://assets/art/characters/character_%s_soul_portrait.png" % ai_element_name
		if ResourceLoader.exists(ai_portrait_path):
			ai_portrait_texture.texture = load(ai_portrait_path)
		portrait_panel.add_child(ai_portrait_texture)

		# HP bar
		var hp_bar = ProgressBar.new()
		hp_bar.name = "AITeamHP_%d" % i
		hp_bar.custom_minimum_size = Vector2(200, 18)
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
		hp_bar.show_percentage = false
		# HP value label overlay
		var ai_hp_value_label = Label.new()
		ai_hp_value_label.name = "HPValueLabel"
		ai_hp_value_label.text = "100/100"
		ai_hp_value_label.anchors_preset = Control.PRESET_FULL_RECT
		ai_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ai_hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ai_hp_value_label.add_theme_font_size_override("font_size", 10)
		ai_hp_value_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))
		ai_hp_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		ai_hp_value_label.add_theme_constant_override("outline_size", 2)
		ai_hp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ai_hp_value_label.z_index = 5
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.12, 0.08, 0.08, 0.9)
		bg_style.border_color = Color(0.5, 0.3, 0.25)
		bg_style.border_width_left = 1
		bg_style.border_width_right = 1
		bg_style.border_width_top = 1
		bg_style.border_width_bottom = 1
		bg_style.corner_radius_top_left = 3
		bg_style.corner_radius_top_right = 3
		bg_style.corner_radius_bottom_right = 3
		bg_style.corner_radius_bottom_left = 3
		hp_bar.add_theme_stylebox_override("background", bg_style)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_right = 2
		fill_style.corner_radius_bottom_left = 2
		hp_bar.add_theme_stylebox_override("fill", fill_style)
		inner_box.add_child(hp_bar)
		hp_bar.add_child(ai_hp_value_label)
		_ai_team_hp_bars.append(hp_bar)


## Select a player unit by index (clickable HP bar)
func _select_player_unit(p_index: int) -> void:
	_selected_unit_index = p_index
	GameLog.info("RTSArena: Selected player unit %d" % p_index, "Arena")
	# Immediately update selection indicator position
	if _selection_indicator and is_instance_valid(_selection_indicator):
		if p_index < _player_visuals.size():
			var sel_visual = _player_visuals[p_index]
			if sel_visual and is_instance_valid(sel_visual) and sel_visual.visible:
				_selection_indicator.visible = true
				_selection_indicator.position = sel_visual.position + Vector2(0, 35)
	# Update visual selection state
	for idx in range(_player_unit_containers.size()):
		var btn = _player_unit_containers[idx]
		if btn and is_instance_valid(btn):
			if idx == p_index:
				# Selected: gold border + brighter bg
				var selected_style = StyleBoxFlat.new()
				selected_style.bg_color = Color(0.15, 0.1, 0.25, 0.95)
				selected_style.border_color = Color(1.0, 0.88, 0.5)
				selected_style.border_width_left = 3
				selected_style.border_width_right = 3
				selected_style.border_width_top = 3
				selected_style.border_width_bottom = 3
				selected_style.corner_radius_top_left = 4
				selected_style.corner_radius_top_right = 4
				selected_style.corner_radius_bottom_right = 4
				selected_style.corner_radius_bottom_left = 4
				btn.add_theme_stylebox_override("normal", selected_style)
			else:
				# Deselected: normal style
				var normal_style = StyleBoxFlat.new()
				normal_style.bg_color = Color(0.06, 0.04, 0.12, 0.7)
				normal_style.border_color = Color(0.4, 0.35, 0.2)
				normal_style.border_width_left = 1
				normal_style.border_width_right = 1
				normal_style.border_width_top = 1
				normal_style.border_width_bottom = 1
				normal_style.corner_radius_top_left = 4
				normal_style.corner_radius_top_right = 4
				normal_style.corner_radius_bottom_right = 4
				normal_style.corner_radius_bottom_left = 4
				btn.add_theme_stylebox_override("normal", normal_style)
	# Play selection sound
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")


## GAP-001: Clear team battle visuals
func _clear_team_visuals() -> void:
	for visual in _player_visuals:
		if visual and is_instance_valid(visual):
			visual.queue_free()
	_player_visuals.clear()
	for visual in _ai_visuals:
		if visual and is_instance_valid(visual):
			visual.queue_free()
	_ai_visuals.clear()
	for light in _player_lights:
		if light and is_instance_valid(light):
			light.queue_free()
	_player_lights.clear()
	for light in _ai_lights:
		if light and is_instance_valid(light):
			light.queue_free()
	_ai_lights.clear()
	for hp_bar in _player_team_hp_bars:
		if hp_bar and is_instance_valid(hp_bar):
			# Free parent container if it exists (new layout), else free the bar itself
			var parent = hp_bar.get_parent()
			if parent and parent.name.begins_with("PlayerTeamHPContainer_"):
				parent.queue_free()
			else:
				hp_bar.queue_free()
	_player_team_hp_bars.clear()
	_player_unit_containers.clear()
	if _selection_indicator and is_instance_valid(_selection_indicator):
		_selection_indicator.queue_free()
	_selection_indicator = null
	if _selected_unit_panel and is_instance_valid(_selected_unit_panel):
		_selected_unit_panel.queue_free()
	_selected_unit_panel = null
	for hp_bar in _ai_team_hp_bars:
		if hp_bar and is_instance_valid(hp_bar):
			# Free parent container if it exists (new layout), else free the bar itself
			var parent = hp_bar.get_parent()
			if parent and parent.name.begins_with("AITeamHPContainer_"):
				parent.queue_free()
			else:
				hp_bar.queue_free()
	_ai_team_hp_bars.clear()


## Get element light color
func _get_element_light_color(p_element: String) -> Color:
	match p_element:
		"fire": return Color(1.0, 0.6, 0.2)
		"water": return Color(0.3, 0.6, 1.0)
		"earth": return Color(0.6, 0.5, 0.3)
		"wind": return Color(0.7, 1.0, 0.8)
		"thunder": return Color(1.0, 0.9, 0.3)
		"ice": return Color(0.6, 0.9, 1.0)
		"dark": return Color(0.6, 0.3, 0.8)
		"light": return Color(1.0, 0.95, 0.7)
		_: return Color(1.0, 1.0, 1.0)


## Start battle countdown (3-2-1-GO!)
## Disables skill buttons during countdown, enables after GO!
func _start_battle_countdown() -> void:
	_countdown_active = true
	_countdown_value = 3
	_countdown_timer = 0.0
	# Disable skill buttons during countdown
	for skill_name in skill_buttons.keys():
		if skill_buttons[skill_name]:
			skill_buttons[skill_name].disabled = true
	# Create countdown label
	if _countdown_label == null:
		_countdown_label = Label.new()
		_countdown_label.name = "CountdownLabel"
		_countdown_label.anchors_preset = Control.PRESET_CENTER
		_countdown_label.offset_left = -100
		_countdown_label.offset_top = -60
		_countdown_label.offset_right = 100
		_countdown_label.offset_bottom = 60
		_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_countdown_label.add_theme_font_size_override("font_size", 72)
		_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_countdown_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05))
		_countdown_label.add_theme_constant_override("outline_size", 4)
		_countdown_label.z_index = 200
		add_child(_countdown_label)
	_countdown_label.text = "3"
	_countdown_label.scale = Vector2(1.5, 1.5)
	_countdown_label.modulate.a = 1.0
	if AudioManager:
		AudioManager.play_sfx("battle_ui_start")


## Update countdown timer and display
func _update_countdown(delta: float) -> void:
	if not _countdown_active:
		return
	_countdown_timer += delta
	# Each number lasts 0.8 seconds
	var number_duration = 0.8
	if _countdown_timer >= number_duration:
		_countdown_timer = 0.0
		_countdown_value -= 1
		if _countdown_value > 0:
			_countdown_label.text = str(_countdown_value)
			_countdown_label.scale = Vector2(1.5, 1.5)
			if AudioManager:
				AudioManager.play_sfx("battle_ui_start")
		elif _countdown_value == 0:
			_countdown_label.text = "GO!"
			_countdown_label.scale = Vector2(2.0, 2.0)
			_countdown_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			if AudioManager:
				AudioManager.play_sfx("battle_critical")
		else:
			# Countdown finished
			_countdown_active = false
			_countdown_label.visible = false
			# Re-enable skill buttons
			for skill_name in skill_buttons.keys():
				if skill_buttons[skill_name]:
					skill_buttons[skill_name].disabled = false
			_add_log("Fight!")
			return
	# Scale animation (pop effect)
	var scale_progress = _countdown_timer / number_duration
	var pop_scale = 1.5 - scale_progress * 0.5 if _countdown_value > 0 else 2.0 - scale_progress * 1.0
	_countdown_label.scale = Vector2(pop_scale, pop_scale)
	# Fade out in last 30%
	if scale_progress > 0.7:
		_countdown_label.modulate.a = 1.0 - (scale_progress - 0.7) / 0.3
	else:
		_countdown_label.modulate.a = 1.0


## Handle battle finished
func _on_battle_finished(p_result: String, p_winner_id: String, p_loser_id: String) -> void:
	_battle_active = false
	# End achievement tracking
	var player_won = (p_result == "player_win")
	_end_achievement_tracking(player_won)
	# Award soul experience
	var battle_time = RTSArenaManager.battle_time if RTSArenaManager else 0.0
	_award_soul_experience(player_won, battle_time)
	# Award cognitive experience (intelligence upgrade)
	_award_cognitive_experience(player_won, battle_time)
	# Record training battle statistics (M2.11 Battle Modes)
	_record_training_battle(player_won, battle_time)
	# Trigger victory particles if player won
	if p_result == "player_win" and RTSArenaManager.player_unit:
		_spawn_victory_particles(RTSArenaManager.player_unit.position)
		# Trigger victory animation on player unit
		if RTSArenaManager.player_unit.has_method("trigger_victory_animation"):
			RTSArenaManager.player_unit.trigger_victory_animation()
	# Reset pause state
	if _is_paused:
		_is_paused = false
		_hide_pause_overlay()
	if _pause_button:
		_pause_button.text = "暂停"
		_pause_button.disabled = true
	# Disable speed button
	if _speed_button:
		_speed_button.disabled = true

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
				AudioManager.play_sfx("battle_ui_victory")
				AudioManager.play_bgm("victory_celebration")
		"defeat":
			result_text = "DEFEAT..."
			result_color = Color(0.9, 0.4, 0.4)
			if AudioManager:
				AudioManager.play_sfx("battle_ui_defeat")
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

	# Play full-screen victory/defeat effect before showing modal
	_play_battle_end_effect(p_result)

	# Show battle result modal
	var battle_stats = RTSArenaManager.last_battle_stats
	_show_result_modal(p_result, result_text, result_color, exp_gained, stats, battle_stats)

	GameLog.info("RTSArenaController: Battle finished - %s, EXP: +%d" % [p_result, exp_gained], "Arena")


## Record training battle statistics (M2.11 Battle Modes)
func _record_training_battle(p_won: bool, p_battle_time: float) -> void:
	var training_system = TrainingBattleSystem.new()
	training_system.load_stats()

	# Get difficulty from battle config (default: normal)
	var difficulty = "normal"
	if GameState and GameState.has_section("battle") and GameState.get_value("battle", "difficulty", ""):
		difficulty = GameState.get_value("battle", "difficulty", "normal")

	# Get soul info
	var player_soul = {}
	var ai_soul = {}
	if GameState and GameState.has_section("battle"):
		player_soul = GameState.get_value("battle", "player_soul", {})
		ai_soul = GameState.get_value("battle", "ai_soul", {})

	training_system.record_battle_result(p_won, difficulty, p_battle_time, player_soul, ai_soul)
	training_system.queue_free()


## Play full-screen battle end effect (victory flash / defeat darken)
func _play_battle_end_effect(p_result: String) -> void:
	# Full-screen overlay layer
	var effect_layer := CanvasLayer.new()
	effect_layer.layer = 90
	effect_layer.name = "BattleEndEffect"
	add_child(effect_layer)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_layer.add_child(overlay)

	if p_result == "victory" or p_result == "player_win":
		# Victory: golden flash + brighten
		overlay.color = Color(1.0, 0.85, 0.4, 0.0)
		var tween := create_tween()
		tween.tween_property(overlay, "color:a", 0.7, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(overlay, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
		tween.tween_callback(effect_layer.queue_free)
		# Extra screen shake for victory
		_trigger_screen_shake(4.0, 0.3)
	elif p_result == "defeat":
		# Defeat: red darken + slow fade
		overlay.color = Color(0.6, 0.1, 0.1, 0.0)
		var tween := create_tween()
		tween.tween_property(overlay, "color:a", 0.5, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(overlay, "color:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
		tween.tween_callback(effect_layer.queue_free)
		_trigger_screen_shake(3.0, 0.25)
	else:
		# Draw: neutral white flash
		overlay.color = Color(0.8, 0.8, 0.8, 0.0)
		var tween := create_tween()
		tween.tween_property(overlay, "color:a", 0.4, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(overlay, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		tween.tween_callback(effect_layer.queue_free)


## Show battle result modal dialog
func _show_result_modal(p_result: String, p_title: String, p_title_color: Color, p_exp: int, p_stats: Dictionary, p_battle_stats: Dictionary = {}) -> void:
	# Play battle end sound
	if AudioManager:
		AudioManager.play_sfx("battle_ui_end")
	if AudioManager:
		AudioManager.play_sfx("ui_panel_open")
	if AudioManager:
		AudioManager.play_sfx("ui_exp_gain")

	# Create modal background (semi-transparent dark overlay)
	var modal_bg = ColorRect.new()
	modal_bg.color = Color(0, 0, 0, 0.0)
	modal_bg.size = Vector2(1280, 720)
	modal_bg.name = "ResultModalBG"
	add_child(modal_bg)
	var bg_tween = create_tween()
	bg_tween.tween_property(modal_bg, "color:a", 0.8, 0.2)

	# Create result panel with 9-slice game over UI component
	var panel = Panel.new()
	panel.position = Vector2(340, 100)
	panel.size = Vector2(600, 520)
	panel.name = "ResultModal"
	# Panel styling: StyleBoxFlat (dynamic StyleBoxTexture broken in Godot 4.7 GDScript)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.18, 0.97)
	panel_style.border_color = Color(0.83, 0.66, 0.36, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	# Animate panel appearance
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	tween.set_parallel(false)

	# === Title with gold decoration ===
	var title = Label.new()
	title.text = p_title
	title.position = Vector2(0, 25)
	title.size = Vector2(600, 55)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = p_title_color
	panel.add_child(title)

	# Gold decorative line under title
	var title_line = ColorRect.new()
	title_line.color = Color(0.83, 0.66, 0.36, 0.8)
	title_line.position = Vector2(150, 85)
	title_line.size = Vector2(300, 2)
	panel.add_child(title_line)

	# === EXP gained card ===
	var exp_card = Panel.new()
	exp_card.position = Vector2(50, 100)
	exp_card.size = Vector2(500, 50)
	var exp_style = StyleBoxFlat.new()
	exp_style.bg_color = Color(0.15, 0.12, 0.25, 0.9)
	exp_style.border_color = Color(0.83, 0.66, 0.36, 0.6)
	exp_style.border_width_left = 2
	exp_style.border_width_right = 2
	exp_style.border_width_top = 2
	exp_style.border_width_bottom = 2
	exp_style.corner_radius_top_left = 6
	exp_style.corner_radius_top_right = 6
	exp_style.corner_radius_bottom_left = 6
	exp_style.corner_radius_bottom_right = 6
	exp_card.add_theme_stylebox_override("panel", exp_style)
	panel.add_child(exp_card)

	var exp_icon = Label.new()
	exp_icon.text = "★"
	exp_icon.position = Vector2(20, 8)
	exp_icon.size = Vector2(30, 35)
	exp_icon.add_theme_font_size_override("font_size", 24)
	exp_icon.modulate = Color(1.0, 0.85, 0.3)
	exp_card.add_child(exp_icon)

	var exp_label = Label.new()
	exp_label.text = "经验获得  +%d" % p_exp
	exp_label.position = Vector2(60, 12)
	exp_label.size = Vector2(420, 30)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 20)
	exp_label.modulate = Color(0.95, 0.88, 0.5)
	exp_card.add_child(exp_label)

	# === Battle stats section (visualized with progress bars) ===
	var section1_title = Label.new()
	section1_title.text = "◆ 本场战斗 ◆"
	section1_title.position = Vector2(0, 165)
	section1_title.size = Vector2(600, 25)
	section1_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section1_title.add_theme_font_size_override("font_size", 16)
	section1_title.modulate = Color(0.83, 0.66, 0.36)
	panel.add_child(section1_title)

	# Duration
	var duration = p_battle_stats.get("duration", 0.0)
	var minutes = int(duration) / 60
	var seconds = int(duration) % 60
	var dur_label = Label.new()
	dur_label.text = "⏱  战斗时长: %02d:%02d" % [minutes, seconds]
	dur_label.position = Vector2(70, 195)
	dur_label.size = Vector2(200, 22)
	dur_label.add_theme_font_size_override("font_size", 14)
	dur_label.modulate = Color(0.8, 0.85, 0.95)
	panel.add_child(dur_label)

	# GAP-001: Team battle stats - show team damage and alive count
	var is_team = p_battle_stats.get("is_team_battle", false)
	if is_team:
		var player_team_dmg = p_battle_stats.get("player_team_damage", 0)
		var ai_team_dmg = p_battle_stats.get("ai_team_damage", 0)
		var player_alive = p_battle_stats.get("player_alive_count", 0)
		var ai_alive = p_battle_stats.get("ai_alive_count", 0)
		var player_size = p_battle_stats.get("player_team_size", 4)
		var ai_size = p_battle_stats.get("ai_team_size", 4)
		var max_team_dmg = max(player_team_dmg, ai_team_dmg, 1)

		# Team damage dealt label
		var dmg_dealt_label = Label.new()
		dmg_dealt_label.text = "⚔ 我方总伤害: %d" % player_team_dmg
		dmg_dealt_label.position = Vector2(70, 222)
		dmg_dealt_label.size = Vector2(200, 20)
		dmg_dealt_label.add_theme_font_size_override("font_size", 13)
		dmg_dealt_label.modulate = Color(1.0, 0.7, 0.5)
		panel.add_child(dmg_dealt_label)

		var dmg_dealt_bar = ProgressBar.new()
		dmg_dealt_bar.position = Vector2(280, 224)
		dmg_dealt_bar.size = Vector2(250, 16)
		dmg_dealt_bar.max_value = 100
		dmg_dealt_bar.value = float(player_team_dmg) / float(max_team_dmg) * 100.0
		var dmg_dealt_bg = StyleBoxFlat.new()
		dmg_dealt_bg.bg_color = Color(0.15, 0.08, 0.08, 0.9)
		dmg_dealt_bg.corner_radius_top_left = 4
		dmg_dealt_bg.corner_radius_top_right = 4
		dmg_dealt_bg.corner_radius_bottom_left = 4
		dmg_dealt_bg.corner_radius_bottom_right = 4
		var dmg_dealt_fill = StyleBoxFlat.new()
		dmg_dealt_fill.bg_color = Color(0.9, 0.35, 0.25, 1.0)
		dmg_dealt_fill.corner_radius_top_left = 3
		dmg_dealt_fill.corner_radius_top_right = 3
		dmg_dealt_fill.corner_radius_bottom_left = 3
		dmg_dealt_fill.corner_radius_bottom_right = 3
		dmg_dealt_bar.add_theme_stylebox_override("background", dmg_dealt_bg)
		dmg_dealt_bar.add_theme_stylebox_override("fill", dmg_dealt_fill)
		panel.add_child(dmg_dealt_bar)

		# Team damage taken label (enemy team damage)
		var dmg_taken_label = Label.new()
		dmg_taken_label.text = "🛡 敌方总伤害: %d" % ai_team_dmg
		dmg_taken_label.position = Vector2(70, 248)
		dmg_taken_label.size = Vector2(200, 20)
		dmg_taken_label.add_theme_font_size_override("font_size", 13)
		dmg_taken_label.modulate = Color(0.5, 0.7, 1.0)
		panel.add_child(dmg_taken_label)

		var dmg_taken_bar = ProgressBar.new()
		dmg_taken_bar.position = Vector2(280, 250)
		dmg_taken_bar.size = Vector2(250, 16)
		dmg_taken_bar.max_value = 100
		dmg_taken_bar.value = float(ai_team_dmg) / float(max_team_dmg) * 100.0
		var dmg_taken_bg = StyleBoxFlat.new()
		dmg_taken_bg.bg_color = Color(0.08, 0.1, 0.18, 0.9)
		dmg_taken_bg.corner_radius_top_left = 4
		dmg_taken_bg.corner_radius_top_right = 4
		dmg_taken_bg.corner_radius_bottom_left = 4
		dmg_taken_bg.corner_radius_bottom_right = 4
		var dmg_taken_fill = StyleBoxFlat.new()
		dmg_taken_fill.bg_color = Color(0.3, 0.55, 0.9, 1.0)
		dmg_taken_fill.corner_radius_top_left = 3
		dmg_taken_fill.corner_radius_top_right = 3
		dmg_taken_fill.corner_radius_bottom_left = 3
		dmg_taken_fill.corner_radius_bottom_right = 3
		dmg_taken_bar.add_theme_stylebox_override("background", dmg_taken_bg)
		dmg_taken_bar.add_theme_stylebox_override("fill", dmg_taken_fill)
		panel.add_child(dmg_taken_bar)

		# Team alive count
		var alive_label = Label.new()
		alive_label.text = "👥 存活: 我方 %d/%d  vs  敌方 %d/%d" % [player_alive, player_size, ai_alive, ai_size]
		alive_label.position = Vector2(70, 274)
		alive_label.size = Vector2(460, 20)
		alive_label.add_theme_font_size_override("font_size", 13)
		alive_label.modulate = Color(0.85, 0.8, 0.65)
		panel.add_child(alive_label)
	else:
		# 1v1 damage stats
		var dmg_dealt = p_battle_stats.get("damage_dealt", 0)
		var dmg_taken = p_battle_stats.get("damage_taken", 0)
		var max_dmg = max(dmg_dealt, dmg_taken, 1)

		var dmg_dealt_label = Label.new()
		dmg_dealt_label.text = "⚔ 伤害输出: %d" % dmg_dealt
		dmg_dealt_label.position = Vector2(70, 222)
		dmg_dealt_label.size = Vector2(200, 20)
		dmg_dealt_label.add_theme_font_size_override("font_size", 13)
		dmg_dealt_label.modulate = Color(1.0, 0.7, 0.5)
		panel.add_child(dmg_dealt_label)

		var dmg_dealt_bar = ProgressBar.new()
		dmg_dealt_bar.position = Vector2(280, 224)
		dmg_dealt_bar.size = Vector2(250, 16)
		dmg_dealt_bar.max_value = 100
		dmg_dealt_bar.value = float(dmg_dealt) / float(max_dmg) * 100.0
		var dmg_dealt_bg = StyleBoxFlat.new()
		dmg_dealt_bg.bg_color = Color(0.15, 0.08, 0.08, 0.9)
		dmg_dealt_bg.corner_radius_top_left = 4
		dmg_dealt_bg.corner_radius_top_right = 4
		dmg_dealt_bg.corner_radius_bottom_left = 4
		dmg_dealt_bg.corner_radius_bottom_right = 4
		var dmg_dealt_fill = StyleBoxFlat.new()
		dmg_dealt_fill.bg_color = Color(0.9, 0.35, 0.25, 1.0)
		dmg_dealt_fill.corner_radius_top_left = 3
		dmg_dealt_fill.corner_radius_top_right = 3
		dmg_dealt_fill.corner_radius_bottom_left = 3
		dmg_dealt_fill.corner_radius_bottom_right = 3
		dmg_dealt_bar.add_theme_stylebox_override("background", dmg_dealt_bg)
		dmg_dealt_bar.add_theme_stylebox_override("fill", dmg_dealt_fill)
		panel.add_child(dmg_dealt_bar)

		var dmg_taken_label = Label.new()
		dmg_taken_label.text = "🛡 承受伤害: %d" % dmg_taken
		dmg_taken_label.position = Vector2(70, 248)
		dmg_taken_label.size = Vector2(200, 20)
		dmg_taken_label.add_theme_font_size_override("font_size", 13)
		dmg_taken_label.modulate = Color(0.5, 0.7, 1.0)
		panel.add_child(dmg_taken_label)

		var dmg_taken_bar = ProgressBar.new()
		dmg_taken_bar.position = Vector2(280, 250)
		dmg_taken_bar.size = Vector2(250, 16)
		dmg_taken_bar.max_value = 100
		dmg_taken_bar.value = float(dmg_taken) / float(max_dmg) * 100.0
		var dmg_taken_bg = StyleBoxFlat.new()
		dmg_taken_bg.bg_color = Color(0.08, 0.1, 0.18, 0.9)
		dmg_taken_bg.corner_radius_top_left = 4
		dmg_taken_bg.corner_radius_top_right = 4
		dmg_taken_bg.corner_radius_bottom_left = 4
		dmg_taken_bg.corner_radius_bottom_right = 4
		var dmg_taken_fill = StyleBoxFlat.new()
		dmg_taken_fill.bg_color = Color(0.3, 0.55, 0.9, 1.0)
		dmg_taken_fill.corner_radius_top_left = 3
		dmg_taken_fill.corner_radius_top_right = 3
		dmg_taken_fill.corner_radius_bottom_left = 3
		dmg_taken_fill.corner_radius_bottom_right = 3
		dmg_taken_bar.add_theme_stylebox_override("background", dmg_taken_bg)
		dmg_taken_bar.add_theme_stylebox_override("fill", dmg_taken_fill)
		panel.add_child(dmg_taken_bar)

		var player_hp = p_battle_stats.get("player_hp_remaining", 0)
		var player_max_hp = p_battle_stats.get("player_max_hp", 100)
		var hp_pct = float(player_hp) / float(player_max_hp) * 100.0 if player_max_hp > 0 else 0

		var hp_label = Label.new()
		hp_label.text = "❤ 剩余生命: %d/%d (%.0f%%)" % [player_hp, player_max_hp, hp_pct]
		hp_label.position = Vector2(70, 274)
		hp_label.size = Vector2(200, 20)
		hp_label.add_theme_font_size_override("font_size", 13)
		hp_label.modulate = Color(0.9, 0.4, 0.4)
		panel.add_child(hp_label)

		var hp_bar = ProgressBar.new()
		hp_bar.position = Vector2(280, 276)
		hp_bar.size = Vector2(250, 16)
		hp_bar.max_value = 100
		hp_bar.value = hp_pct
		var hp_bg = StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.15, 0.05, 0.05, 0.9)
		hp_bg.corner_radius_top_left = 4
		hp_bg.corner_radius_top_right = 4
		hp_bg.corner_radius_bottom_left = 4
		hp_bg.corner_radius_bottom_right = 4
		var hp_fill = StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.85, 0.25, 0.25, 1.0)
		hp_fill.corner_radius_top_left = 3
		hp_fill.corner_radius_top_right = 3
		hp_fill.corner_radius_bottom_left = 3
		hp_fill.corner_radius_bottom_right = 3
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		panel.add_child(hp_bar)

	# === Overall stats section ===
	var section2_title = Label.new()
	section2_title.text = "◆ 总体统计 ◆"
	section2_title.position = Vector2(0, 310)
	section2_title.size = Vector2(600, 25)
	section2_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section2_title.add_theme_font_size_override("font_size", 16)
	section2_title.modulate = Color(0.83, 0.66, 0.36)
	panel.add_child(section2_title)

	# Win rate card
	var win_rate = p_stats.get("win_rate", 0)
	var victories = p_stats.get("victories", 0)
	var total_battles = p_stats.get("total_battles", 0)
	var wr_card = Panel.new()
	wr_card.position = Vector2(50, 340)
	wr_card.size = Vector2(160, 60)
	var wr_style = StyleBoxFlat.new()
	wr_style.bg_color = Color(0.12, 0.15, 0.12, 0.9)
	wr_style.border_color = Color(0.4, 0.7, 0.4, 0.5)
	wr_style.border_width_left = 2
	wr_style.border_width_right = 2
	wr_style.border_width_top = 2
	wr_style.border_width_bottom = 2
	wr_style.corner_radius_top_left = 6
	wr_style.corner_radius_top_right = 6
	wr_style.corner_radius_bottom_left = 6
	wr_style.corner_radius_bottom_right = 6
	wr_card.add_theme_stylebox_override("panel", wr_style)
	panel.add_child(wr_card)

	var wr_value = Label.new()
	wr_value.text = "%.1f%%" % win_rate
	wr_value.position = Vector2(0, 8)
	wr_value.size = Vector2(160, 28)
	wr_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wr_value.add_theme_font_size_override("font_size", 22)
	wr_value.modulate = Color(0.5, 0.9, 0.5)
	wr_card.add_child(wr_value)

	var wr_desc = Label.new()
	wr_desc.text = "胜率 (%d/%d)" % [victories, total_battles]
	wr_desc.position = Vector2(0, 36)
	wr_desc.size = Vector2(160, 18)
	wr_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wr_desc.add_theme_font_size_override("font_size", 11)
	wr_desc.modulate = Color(0.7, 0.75, 0.7)
	wr_card.add_child(wr_desc)

	# Streak card
	var current_streak = p_stats.get("current_streak", 0)
	var best_streak = p_stats.get("best_streak", 0)
	var streak_card = Panel.new()
	streak_card.position = Vector2(220, 340)
	streak_card.size = Vector2(160, 60)
	var streak_style = StyleBoxFlat.new()
	streak_style.bg_color = Color(0.15, 0.12, 0.08, 0.9)
	streak_style.border_color = Color(0.83, 0.66, 0.36, 0.5)
	streak_style.border_width_left = 2
	streak_style.border_width_right = 2
	streak_style.border_width_top = 2
	streak_style.border_width_bottom = 2
	streak_style.corner_radius_top_left = 6
	streak_style.corner_radius_top_right = 6
	streak_style.corner_radius_bottom_left = 6
	streak_style.corner_radius_bottom_right = 6
	streak_card.add_theme_stylebox_override("panel", streak_style)
	panel.add_child(streak_card)

	var streak_value = Label.new()
	streak_value.text = "%d" % current_streak
	streak_value.position = Vector2(0, 8)
	streak_value.size = Vector2(160, 28)
	streak_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_value.add_theme_font_size_override("font_size", 22)
	streak_value.modulate = Color(1.0, 0.85, 0.4)
	streak_card.add_child(streak_value)

	var streak_desc = Label.new()
	streak_desc.text = "当前连胜 (最佳%d)" % best_streak
	streak_desc.position = Vector2(0, 36)
	streak_desc.size = Vector2(160, 18)
	streak_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_desc.add_theme_font_size_override("font_size", 11)
	streak_desc.modulate = Color(0.75, 0.7, 0.6)
	streak_card.add_child(streak_desc)

	# Total EXP card
	var total_exp = p_stats.get("total_experience_gained", 0)
	var exp_total_card = Panel.new()
	exp_total_card.position = Vector2(390, 340)
	exp_total_card.size = Vector2(160, 60)
	var exp_total_style = StyleBoxFlat.new()
	exp_total_style.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	exp_total_style.border_color = Color(0.4, 0.6, 0.9, 0.5)
	exp_total_style.border_width_left = 2
	exp_total_style.border_width_right = 2
	exp_total_style.border_width_top = 2
	exp_total_style.border_width_bottom = 2
	exp_total_style.corner_radius_top_left = 6
	exp_total_style.corner_radius_top_right = 6
	exp_total_style.corner_radius_bottom_left = 6
	exp_total_style.corner_radius_bottom_right = 6
	exp_total_card.add_theme_stylebox_override("panel", exp_total_style)
	panel.add_child(exp_total_card)

	var exp_total_value = Label.new()
	exp_total_value.text = "%d" % total_exp
	exp_total_value.position = Vector2(0, 8)
	exp_total_value.size = Vector2(160, 28)
	exp_total_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_total_value.add_theme_font_size_override("font_size", 22)
	exp_total_value.modulate = Color(0.5, 0.7, 1.0)
	exp_total_card.add_child(exp_total_value)

	var exp_total_desc = Label.new()
	exp_total_desc.text = "累计经验"
	exp_total_desc.position = Vector2(0, 36)
	exp_total_desc.size = Vector2(160, 18)
	exp_total_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_total_desc.add_theme_font_size_override("font_size", 11)
	exp_total_desc.modulate = Color(0.65, 0.7, 0.8)
	exp_total_card.add_child(exp_total_desc)

	# === Buttons with 9-slice UI component ===
	var btn_y = 440

	# Rematch button with 9-slice style
	var rematch_btn = Button.new()
	rematch_btn.text = "⚔ 再战一局"
	rematch_btn.position = Vector2(100, btn_y)
	rematch_btn.size = Vector2(170, 50)
	rematch_btn.add_theme_font_size_override("font_size", 18)
	rematch_btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	rematch_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	rematch_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.5))
	_apply_9slice_button_style(rematch_btn)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	_setup_button_hover(rematch_btn)
	panel.add_child(rematch_btn)

	# Back to menu button with 9-slice style
	var back_btn = Button.new()
	back_btn.text = "🏠 返回主菜单"
	back_btn.position = Vector2(330, btn_y)
	back_btn.size = Vector2(170, 50)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	back_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	back_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.5))
	_apply_9slice_button_style(back_btn)
	back_btn.pressed.connect(_on_back_to_menu_pressed)
	_setup_button_hover(back_btn)
	panel.add_child(back_btn)

	# Animate internal elements appearing sequentially
	_animate_result_elements(panel)

	GameLog.info("RTSArenaController: Result modal shown (visualized UI)", "Arena")


## Apply 9-slice button style from UI component textures
func _apply_9slice_button_style(p_button: Button) -> void:
	# Apply game-level three-state StyleBoxFlat (dynamic StyleBoxTexture broken in Godot 4.7)
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.09, 0.20, 0.95)
	normal_style.border_color = Color(0.83, 0.66, 0.36, 0.9)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	p_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.20, 0.15, 0.30, 0.98)
	hover_style.border_color = Color(1.0, 0.88, 0.5, 1.0)
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_right = 8
	hover_style.corner_radius_bottom_left = 8
	p_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.08, 0.06, 0.14, 1.0)
	pressed_style.border_color = Color(0.7, 0.55, 0.3, 1.0)
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_right = 8
	pressed_style.corner_radius_bottom_left = 8
	p_button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.08, 0.07, 0.10, 0.8)
	disabled_style.border_color = Color(0.4, 0.35, 0.25, 0.5)
	disabled_style.border_width_left = 1
	disabled_style.border_width_right = 1
	disabled_style.border_width_top = 1
	disabled_style.border_width_bottom = 1
	disabled_style.corner_radius_top_left = 8
	disabled_style.corner_radius_top_right = 8
	disabled_style.corner_radius_bottom_right = 8
	disabled_style.corner_radius_bottom_left = 8
	p_button.add_theme_stylebox_override("disabled", disabled_style)

## Animate result modal elements appearing sequentially (staggered fade in + slide up)
func _animate_result_elements(p_panel: Panel) -> void:
	var children = p_panel.get_children()
	var delay = 0.1
	for child in children:
		if child is CanvasItem:
			# Save original position and set initial state
			var orig_pos = child.position
			child.position = orig_pos + Vector2(0, 15)
			child.modulate.a = 0.0
			# Create tween for this element
			var elem_tween = create_tween()
			elem_tween.set_parallel(true)
			elem_tween.tween_interval(delay)
			elem_tween.tween_property(child, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
			elem_tween.tween_property(child, "position:y", orig_pos.y, 0.25).set_ease(Tween.EASE_OUT)
			delay += 0.06


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
		# Reset battle and start countdown
		RTSArenaManager.reset_battle()
		_battle_active = false
		# Reset pause state
		_is_paused = false
		_hide_pause_overlay()
		if _pause_button:
			_pause_button.text = "暂停"
			_pause_button.disabled = false
		# Reset speed
		_current_speed = 1.0
		RTSArenaManager.set_battle_speed(1.0)
		if _speed_button:
			_speed_button.text = "⚡ 1x"
			_speed_button.disabled = false
		_pending_battle_config = {
			"player_soul": player_soul,
			"ai_soul": ai_soul,
			"map_name": map_name
		}
		_start_countdown()
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


## Create unit visual: AnimatedSprite2D from design sheet (with chroma-key shader) or procedural sprite with bob
## Create selected unit info panel (game-level UI)
func _create_selected_unit_panel() -> Panel:
	var panel = Panel.new()
	panel.name = "SelectedUnitPanel"
	panel.position = Vector2(15, 200)
	panel.size = Vector2(220, 140)
	# Game-level panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	style.border_color = Color(1.0, 0.88, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)

	# Title
	var title = Label.new()
	title.name = "UnitName"
	title.text = "选中单位"
	title.position = Vector2(10, 8)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	panel.add_child(title)

	# Element label
	var elem_label = Label.new()
	elem_label.name = "UnitElement"
	elem_label.text = ""
	elem_label.position = Vector2(10, 30)
	elem_label.add_theme_font_size_override("font_size", 12)
	elem_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	panel.add_child(elem_label)

	# HP bar
	var hp_bar = ProgressBar.new()
	hp_bar.name = "UnitHPBar"
	hp_bar.position = Vector2(10, 52)
	hp_bar.size = Vector2(200, 16)
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	hp_bg.border_color = Color(0.5, 0.3, 0.3)
	hp_bg.border_width_left = 1
	hp_bg.border_width_right = 1
	hp_bg.border_width_top = 1
	hp_bg.border_width_bottom = 1
	hp_bg.corner_radius_top_left = 3
	hp_bg.corner_radius_top_right = 3
	hp_bg.corner_radius_bottom_right = 3
	hp_bg.corner_radius_bottom_left = 3
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.9, 0.25, 0.2)
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_right = 2
	hp_fill.corner_radius_bottom_left = 2
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	panel.add_child(hp_bar)

	# HP text
	var hp_text = Label.new()
	hp_text.name = "UnitHPText"
	hp_text.text = ""
	hp_text.position = Vector2(10, 70)
	hp_text.add_theme_font_size_override("font_size", 11)
	hp_text.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	panel.add_child(hp_text)

	# Energy bar
	var energy_bar = ProgressBar.new()
	energy_bar.name = "UnitEnergyBar"
	energy_bar.position = Vector2(10, 88)
	energy_bar.size = Vector2(200, 12)
	energy_bar.max_value = 100.0
	energy_bar.value = 100.0
	energy_bar.show_percentage = false
	var energy_bg = StyleBoxFlat.new()
	energy_bg.bg_color = Color(0.05, 0.05, 0.15, 0.9)
	energy_bg.border_color = Color(0.3, 0.3, 0.6)
	energy_bg.border_width_left = 1
	energy_bg.border_width_right = 1
	energy_bg.border_width_top = 1
	energy_bg.border_width_bottom = 1
	energy_bg.corner_radius_top_left = 3
	energy_bg.corner_radius_top_right = 3
	energy_bg.corner_radius_bottom_right = 3
	energy_bg.corner_radius_bottom_left = 3
	energy_bar.add_theme_stylebox_override("background", energy_bg)
	var energy_fill = StyleBoxFlat.new()
	energy_fill.bg_color = Color(0.3, 0.5, 1.0)
	energy_fill.corner_radius_top_left = 2
	energy_fill.corner_radius_top_right = 2
	energy_fill.corner_radius_bottom_right = 2
	energy_fill.corner_radius_bottom_left = 2
	energy_bar.add_theme_stylebox_override("fill", energy_fill)
	panel.add_child(energy_bar)

	# Energy text
	var energy_text = Label.new()
	energy_text.name = "UnitEnergyText"
	energy_text.text = ""
	energy_text.position = Vector2(10, 102)
	energy_text.add_theme_font_size_override("font_size", 11)
	energy_text.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	panel.add_child(energy_text)

	# ATK/DEF labels
	var stats_label = Label.new()
	stats_label.name = "UnitStats"
	stats_label.text = ""
	stats_label.position = Vector2(10, 118)
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	panel.add_child(stats_label)

	return panel


## Update selected unit info panel display
func _update_selected_unit_panel() -> void:
	if not _selected_unit_panel or not is_instance_valid(_selected_unit_panel):
		return
	if _selected_unit_index >= RTSArenaManager.player_units.size():
		_selected_unit_panel.visible = false
		return
	var unit = RTSArenaManager.player_units[_selected_unit_index]
	if not unit or not is_instance_valid(unit) or unit.state == SoulUnit.UnitState.DEAD:
		_selected_unit_panel.visible = false
		return
	_selected_unit_panel.visible = true
	# Update name
	var name_label = _selected_unit_panel.get_node_or_null("UnitName")
	if name_label:
		name_label.text = unit.soul_name if unit.soul_name else "灵魂%d" % (_selected_unit_index + 1)
	# Update element
	var elem_label = _selected_unit_panel.get_node_or_null("UnitElement")
	if elem_label:
		var elem_names = {"fire": "火元素", "water": "水元素", "earth": "土元素", "wind": "风元素", "thunder": "雷元素", "ice": "冰元素", "light": "光元素", "dark": "暗元素"}
		elem_label.text = elem_names.get(unit.element, unit.element)
	# Update HP bar
	var hp_bar = _selected_unit_panel.get_node_or_null("UnitHPBar")
	if hp_bar:
		hp_bar.max_value = unit.max_hp
		hp_bar.value = unit.current_hp
	# Update HP text
	var hp_text = _selected_unit_panel.get_node_or_null("UnitHPText")
	if hp_text:
		hp_text.text = "HP: %d / %d" % [int(unit.current_hp), int(unit.max_hp)]
	# Update energy bar
	var energy_bar = _selected_unit_panel.get_node_or_null("UnitEnergyBar")
	if energy_bar:
		energy_bar.max_value = unit.max_energy if unit.max_energy > 0 else 100.0
		energy_bar.value = unit.current_energy
	# Update energy text
	var energy_text = _selected_unit_panel.get_node_or_null("UnitEnergyText")
	if energy_text:
		energy_text.text = "能量: %d / %d" % [int(unit.current_energy), int(unit.max_energy if unit.max_energy > 0 else 100)]
	# Update stats
	var stats_label = _selected_unit_panel.get_node_or_null("UnitStats")
	if stats_label:
		stats_label.text = "ATK: %d  DEF: %d  SPD: %.1f" % [int(unit.attack), int(unit.defense), unit.speed]


## Create gold circle selection indicator for selected unit
func _create_selection_indicator() -> Node2D:
	var indicator = Node2D.new()
	indicator.name = "SelectionIndicator"
	indicator.z_index = 5

	# Outer glow ring
	var glow = _create_ring_texture(48, Color(1.0, 0.88, 0.5, 0.3))
	var glow_sprite = Sprite2D.new()
	glow_sprite.texture = glow
	glow_sprite.scale = Vector2(1.3, 1.3)
	indicator.add_child(glow_sprite)

	# Main gold ring
	var ring = _create_ring_texture(40, Color(1.0, 0.88, 0.5, 0.9))
	var ring_sprite = Sprite2D.new()
	ring_sprite.texture = ring
	indicator.add_child(ring_sprite)

	# Inner accent ring
	var inner = _create_ring_texture(34, Color(1.0, 0.95, 0.7, 0.5))
	var inner_sprite = Sprite2D.new()
	inner_sprite.texture = inner
	indicator.add_child(inner_sprite)

	return indicator


## Create a ring texture procedurally
func _create_ring_texture(p_radius: int, p_color: Color) -> ImageTexture:
	var size = p_radius * 2 + 4
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(size / 2, size / 2)
	for x in range(size):
		for y in range(size):
			var dist = center.distance_to(Vector2(x, y))
			if dist <= p_radius and dist >= p_radius - 3:
				var alpha = p_color.a * (1.0 - abs(dist - (p_radius - 1.5)) / 2.0)
				img.set_pixel(x, y, Color(p_color.r, p_color.g, p_color.b, alpha))
	return ImageTexture.create_from_image(img)


func _create_unit_visual(p_element: String, p_personality: Dictionary = {}) -> CanvasItem:
	# Try new element sprite sheet first (has animation frames, no alpha - use chroma-key shader)
	var sheet_path := "res://assets/art/new_soul_unit_%s_sprite_sheet.png" % p_element.to_lower()
	if ResourceLoader.exists(sheet_path):
		var sheet = load(sheet_path)
		if sheet != null and sheet is Texture2D:
			var animated = AnimatedSprite2D.new()
			var frames = SpriteFrames.new()
			frames.add_animation("idle")
			frames.set_animation_speed("idle", 4.0)
			# First 4 frames are 256x256 character animations
			for i in range(4):
				var atlas = AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(i * 256, 0, 256, 256)
				frames.add_frame("idle", atlas)
			animated.sprite_frames = frames
			animated.animation = "idle"
			animated.play()
			animated.centered = true
			animated.scale = Vector2(1.2, 1.2)
			# Chroma-key shader: discard dark purple background (no alpha in design sheets)
			var shader = Shader.new()
			shader.code = """
shader_type canvas_item;
uniform float threshold : hint_range(0.0, 1.0) = 0.22;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (lum < threshold) discard;
	COLOR = c;
}
"""
			var mat = ShaderMaterial.new()
			mat.shader = shader
			animated.material = mat
			GameLog.debug("RTSArena: Animated sprite from design sheet (element=%s)" % p_element, "Visual")
			return animated
	# Fallback: procedural pixel sprite
	var generator = PixelSpriteGenerator.new()
	var sprite_tex = generator.generate_soul_sprite(p_element, p_personality)
	var visual = Sprite2D.new()
	visual.texture = sprite_tex
	visual.centered = true
	visual.scale = Vector2(1.0, 1.0)
	GameLog.debug("RTSArena: Procedural sprite fallback (element=%s)" % p_element, "Visual")
	return visual


## Handle unit spawned
func _on_unit_spawned(p_unit: SoulUnit, p_is_player: bool) -> void:
	GameLog.info("RTSArenaController: Unit spawned - %s (player: %s)" % [p_unit.soul_name, str(p_is_player)], "Arena")

	# Create visible visual proxy - SoulUnit is child of autoload RTSArenaManager,
	# which is NOT in the visible scene tree, so its internal Sprite2D never renders.
	var personality_val: Dictionary = {}
	if "personality" in p_unit and p_unit.personality is Dictionary:
		personality_val = p_unit.personality
	var visual = _create_unit_visual(p_unit.element, personality_val)
	visual.position = p_unit.position
	visual.z_index = 10
	if p_is_player:
		_player_visual = visual
	else:
		_ai_visual = visual
	add_child(visual)

	# Create dynamic point light for unit glow
	var light = PointLight2D.new()
	light.position = p_unit.position
	light.energy = 1.2
	light.texture = _create_light_texture()
	if p_is_player:
		light.color = Color(0.3, 0.5, 1.0, 0.6)  # Blue glow for player
		light.texture_scale = 3.5
		_player_light = light
	else:
		light.color = Color(1.0, 0.3, 0.2, 0.6)  # Red glow for AI
		light.texture_scale = 3.5
		_ai_light = light
	light.z_index = 5  # Below unit visual, above background
	add_child(light)

	# Connect unit signals for particle effects
	p_unit.hp_changed.connect(_on_unit_hp_changed.bind(p_unit))
	p_unit.unit_died.connect(_on_unit_died)


## Create radial gradient texture for point light
func _create_light_texture() -> Texture2D:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(128):
		for x in range(128):
			var dx = x - 64.0
			var dy = y - 64.0
			var dist = sqrt(dx * dx + dy * dy) / 64.0
			if dist < 1.0:
				var alpha = pow(1.0 - dist, 1.5)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex = ImageTexture.create_from_image(img)
	return tex


## Handle unit HP change (trigger hit particles when damaged)
func _on_unit_hp_changed(p_current_hp: int, p_max_hp: int, p_unit: SoulUnit) -> void:
	# Only spawn hit particles if HP decreased (damage taken)
	if p_unit.last_damage_taken > 0:
		var hit_color = Color(1.0, 0.4, 0.2) if p_unit.is_player_controlled else Color(1.0, 0.6, 0.3)
		_spawn_hit_particles(p_unit.position, hit_color)


## Handle unit death (trigger death particles)
func _on_unit_died(p_unit: SoulUnit) -> void:
	var death_color = Color(1.0, 0.3, 0.2) if p_unit.is_player_controlled else Color(1.0, 0.5, 0.3)
	_spawn_death_particles(p_unit.position, death_color)
	# Auto-switch selected unit if the selected player unit died
	if p_unit.is_player_controlled:
		var is_team = GameState.get_value("battle", "is_team_battle", false)
		if is_team and _selected_unit_index >= 0:
			var dead_unit = RTSArenaManager.player_units[_selected_unit_index]
			if dead_unit == p_unit:
				# Find next alive player unit
				var next_idx = -1
				for i in range(RTSArenaManager.player_units.size()):
					var check_unit = RTSArenaManager.player_units[i]
					if check_unit and check_unit.state != SoulUnit.UnitState.DEAD:
						next_idx = i
						break
				if next_idx >= 0:
					_select_player_unit(next_idx)
				else:
					_selected_unit_index = -1
					if _selection_indicator and is_instance_valid(_selection_indicator):
						_selection_indicator.visible = false


## Spawn hit effect particles (small burst of sparks)
func _spawn_hit_particles(p_position: Vector2, p_color: Color) -> void:
	for i in range(6):
		var angle = randf() * TAU
		var particle = Sprite2D.new()
		particle.name = "HitParticle_%d" % Time.get_ticks_msec()
		particle.centered = true
		particle.position = p_position
		particle.modulate = p_color
		particle.scale = Vector2(0.2, 0.2)
		particle.z_index = 50
		# Procedural circle texture
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in range(12):
			for y in range(12):
				var dx = x - 6
				var dy = y - 6
				var dist = sqrt(dx * dx + dy * dy)
				if dist < 5:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 - dist / 5.0))
		particle.texture = ImageTexture.create_from_image(img)
		add_child(particle)
		_skill_particles.append({
			"particle": particle,
			"timer": 0.3,
			"duration": 0.3,
			"velocity": Vector2(cos(angle), sin(angle)) * randf_range(40, 100),
			"start_pos": p_position
		})


## Spawn death effect particles (large burst)
func _spawn_death_particles(p_position: Vector2, p_color: Color) -> void:
	for i in range(16):
		var angle = (TAU / 16.0) * i + randf_range(-0.2, 0.2)
		var particle = Sprite2D.new()
		particle.name = "DeathParticle_%d" % Time.get_ticks_msec()
		particle.centered = true
		particle.position = p_position
		particle.modulate = p_color
		particle.scale = Vector2(0.3, 0.3)
		particle.z_index = 50
		# Procedural circle texture
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in range(16):
			for y in range(16):
				var dx = x - 8
				var dy = y - 8
				var dist = sqrt(dx * dx + dy * dy)
				if dist < 7:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 - dist / 7.0))
		particle.texture = ImageTexture.create_from_image(img)
		add_child(particle)
		_skill_particles.append({
			"particle": particle,
			"timer": 0.8,
			"duration": 0.8,
			"velocity": Vector2(cos(angle), sin(angle)) * randf_range(60, 150),
			"start_pos": p_position
		})


## Spawn victory effect particles (golden celebration)
func _spawn_victory_particles(p_position: Vector2) -> void:
	for i in range(24):
		var angle = randf() * TAU
		var particle = Sprite2D.new()
		particle.name = "VictoryParticle_%d" % Time.get_ticks_msec()
		particle.centered = true
		particle.position = p_position
		particle.modulate = Color(1.0, 0.85, 0.3)  # Golden
		particle.scale = Vector2(0.25, 0.25)
		particle.z_index = 50
		# Procedural star texture
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in range(16):
			for y in range(16):
				var dx = x - 8
				var dy = y - 8
				var dist = sqrt(dx * dx + dy * dy)
				if dist < 6:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 - dist / 6.0))
		particle.texture = ImageTexture.create_from_image(img)
		add_child(particle)
		_skill_particles.append({
			"particle": particle,
			"timer": 1.2,
			"duration": 1.2,
			"velocity": Vector2(cos(angle), sin(angle)) * randf_range(30, 120),
			"start_pos": p_position
		})


## Spawn trap trigger effect particles
func _spawn_trap_effect(p_position: Vector2, trap_id: String) -> void:
	# Determine effect color based on trap type
	var effect_color = Color(1.0, 0.3, 0.3)  # Default red
	match trap_id:
		"fire_trap":
			effect_color = Color(1.0, 0.5, 0.1)  # Orange
		"frost_trap":
			effect_color = Color(0.3, 0.7, 1.0)  # Blue
		"thunder_trap":
			effect_color = Color(0.9, 0.9, 0.3)  # Yellow
		"poison_trap":
			effect_color = Color(0.3, 0.8, 0.3)  # Green
		"explosion_trap":
			effect_color = Color(1.0, 0.6, 0.1)  # Orange-red
		"shadow_trap":
			effect_color = Color(0.5, 0.2, 0.7)  # Purple
		"holy_trap":
			effect_color = Color(1.0, 0.95, 0.6)  # Light yellow
	# Spawn burst particles
	for i in range(16):
		var angle = randf() * TAU
		var particle = Sprite2D.new()
		particle.name = "TrapParticle_%d" % Time.get_ticks_msec()
		particle.centered = true
		particle.position = p_position
		particle.modulate = effect_color
		particle.scale = Vector2(0.2, 0.2)
		particle.z_index = 50
		# Procedural circle texture
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in range(12):
			for y in range(12):
				var dx = x - 6
				var dy = y - 6
				var dist = sqrt(dx * dx + dy * dy)
				if dist < 5:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 - dist / 5.0))
		particle.texture = ImageTexture.create_from_image(img)
		add_child(particle)
		_skill_particles.append({
			"particle": particle,
			"timer": 0.8,
			"duration": 0.8,
			"velocity": Vector2(cos(angle), sin(angle)) * randf_range(40, 100),
			"start_pos": p_position
		})


## Handle log added
func _on_log_added(p_message: String) -> void:
	_add_log(p_message)


## Add message to battle log
func _add_log(p_message: String) -> void:
	if battle_log:
		# Color-code messages based on content type
		var colored_msg = p_message
		var lower = p_message.to_lower()
		if "暴击" in p_message or "critical" in lower:
			colored_msg = "[color=#ffd700]%s[/color]" % p_message  # Gold for crits
		elif "治疗" in p_message or "heal" in lower:
			colored_msg = "[color=#4ade80]%s[/color]" % p_message  # Green for heals
		elif "闪避" in p_message or "dodge" in lower:
			colored_msg = "[color=#94a3b8]%s[/color]" % p_message  # Gray for dodges
		elif "防御" in p_message or "defend" in lower:
			colored_msg = "[color=#60a5fa]%s[/color]" % p_message  # Blue for defense
		elif "战术" in p_message or "tactic" in lower or "指令" in p_message:
			colored_msg = "[color=#c084fc]%s[/color]" % p_message  # Purple for tactics
		elif "伤害" in p_message or "damage" in lower or "攻击" in p_message:
			colored_msg = "[color=#f87171]%s[/color]" % p_message  # Red for damage
		elif "胜利" in p_message or "victory" in lower or "win" in lower:
			colored_msg = "[color=#fbbf24]%s[/color]" % p_message  # Gold for victory
		elif "失败" in p_message or "defeat" in lower or "lose" in lower:
			colored_msg = "[color=#ef4444]%s[/color]" % p_message  # Red for defeat
		elif "技能" in p_message or "skill" in lower:
			colored_msg = "[color=#38bdf8]%s[/color]" % p_message  # Cyan for skills
		elif "暂停" in p_message or "继续" in p_message:
			colored_msg = "[color=#a78bfa]%s[/color]" % p_message  # Violet for system
		else:
			colored_msg = "[color=#d4d4d8]%s[/color]" % p_message  # Light gray for normal
		battle_log.text += colored_msg + "\n"
		# Scroll to bottom (RichTextLabel uses scroll_to_line, not caret_position)
		battle_log.scroll_to_line(battle_log.get_line_count() - 1)


## Skill button handlers
func _on_heavy_strike_pressed() -> void:
	var is_team = GameState.get_value("battle", "is_team_battle", false)
	var success = false
	var skill_pos = Vector2.ZERO
	if is_team and _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
		success = RTSArenaManager.player_unit_use_skill(_selected_unit_index, "heavy_strike")
		if success and _selected_unit_index < _player_visuals.size():
			skill_pos = _player_visuals[_selected_unit_index].position
	else:
		success = RTSArenaManager.player_use_skill("heavy_strike")
		if success and RTSArenaManager.player_unit:
			skill_pos = RTSArenaManager.player_unit.position
	if success:
		_spawn_skill_particle("heavy_strike", skill_pos)
		_trigger_chromatic_aberration(12.0, 0.35)
		if AudioManager:
			AudioManager.play_sfx("skill_rock")
	else:
		_show_skill_error("重击")

func _on_quick_strike_pressed() -> void:
	var is_team = GameState.get_value("battle", "is_team_battle", false)
	var success = false
	var skill_pos = Vector2.ZERO
	if is_team and _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
		success = RTSArenaManager.player_unit_use_skill(_selected_unit_index, "quick_strike")
		if success and _selected_unit_index < _player_visuals.size():
			skill_pos = _player_visuals[_selected_unit_index].position
	else:
		success = RTSArenaManager.player_use_skill("quick_strike")
		if success and RTSArenaManager.player_unit:
			skill_pos = RTSArenaManager.player_unit.position
	if success:
		_spawn_skill_particle("quick_strike", skill_pos)
		_trigger_chromatic_aberration(8.0, 0.25)
		if AudioManager:
			AudioManager.play_sfx("skill_windblade")
	else:
		_show_skill_error("快击")

func _on_heal_pressed() -> void:
	var is_team = GameState.get_value("battle", "is_team_battle", false)
	var success = false
	var skill_pos = Vector2.ZERO
	if is_team and _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
		success = RTSArenaManager.player_unit_use_skill(_selected_unit_index, "heal")
		if success and _selected_unit_index < _player_visuals.size():
			skill_pos = _player_visuals[_selected_unit_index].position
	else:
		success = RTSArenaManager.player_use_skill("heal")
		if success and RTSArenaManager.player_unit:
			skill_pos = RTSArenaManager.player_unit.position
	if success:
		_spawn_skill_particle("heal", skill_pos)
		_trigger_chromatic_aberration(5.0, 0.2)
		if AudioManager:
			AudioManager.play_sfx("skill_heal")
	else:
		_show_skill_error("治疗")

func _on_defend_pressed() -> void:
	var is_team = GameState.get_value("battle", "is_team_battle", false)
	var success = false
	var skill_pos = Vector2.ZERO
	if is_team and _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
		success = RTSArenaManager.player_unit_use_skill(_selected_unit_index, "defend")
		if success and _selected_unit_index < _player_visuals.size():
			skill_pos = _player_visuals[_selected_unit_index].position
	else:
		success = RTSArenaManager.player_use_skill("defend")
		if success and RTSArenaManager.player_unit:
			skill_pos = RTSArenaManager.player_unit.position
	if success:
		_spawn_skill_particle("defend", skill_pos)
		_trigger_chromatic_aberration(6.0, 0.2)
		if AudioManager:
			AudioManager.play_sfx("skill_defend")
	else:
		_show_skill_error("防御")


## Show skill release error (on cooldown or not enough energy)
func _show_skill_error(skill_name: String) -> void:
	# Determine which unit to check for skill error
	var unit_for_check = RTSArenaManager.player_unit
	var is_team = GameState.get_value("battle", "is_team_battle", false)
	if is_team and _selected_unit_index >= 0 and _selected_unit_index < RTSArenaManager.player_units.size():
		unit_for_check = RTSArenaManager.player_units[_selected_unit_index]
	if unit_for_check == null:
		return
	var cooldown = unit_for_check.skill_cooldowns.get(skill_name.to_lower(), 0)
	var energy = unit_for_check.current_energy
	var reason = ""
	if cooldown > 0:
		reason = "冷却中 (%.1fs)" % cooldown
	elif energy < 10:
		reason = "能量不足"
	else:
		reason = "无法释放"
	# Show error message in battle log
	if battle_log:
		battle_log.text += "\n[技能] %s %s" % [skill_name, reason]
	# Play error sound
	if AudioManager:
		AudioManager.play_sfx("error")
	# Flash skill button red
	var skill_key = skill_name.to_lower()
	if skill_buttons.has(skill_key) and skill_buttons[skill_key]:
		var btn = skill_buttons[skill_key]
		btn.modulate = Color(1.5, 0.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(btn):
			btn.modulate = Color(1, 1, 1)


## Initialize tactical command system (GDD v2.0 Chapter 2.1.1)
func _init_tactical_command_system() -> void:
	# Create tactical command system instance
	_tactical_system = TacticalCommandSystem.new()
	_tactical_system.name = "TacticalCommandSystem"
	add_child(_tactical_system)

	# Connect command changed signal
	_tactical_system.command_changed.connect(_on_tactical_command_changed)

	# Connect tactical buttons
	for command_id in _tactical_buttons.keys():
		var button = _tactical_buttons[command_id]
		if button:
			button.pressed.connect(_on_tactical_button_pressed.bind(command_id))
			# Set tooltip
			if _tactical_system and _tactical_system.COMMANDS.has(command_id):
				var cmd_data = _tactical_system.COMMANDS[command_id]
				button.tooltip_text = cmd_data["description"]

	# Load initial command from battle config (set in battle_config scene)
	var initial_command = GameState.get_value("battle", "tactic", "free")
	if initial_command and _tactical_system.is_valid_command(initial_command):
		_tactical_system.set_command(initial_command)
	else:
		_tactical_system.set_command("free")

	GameLog.info("Tactical command system initialized", "Arena")


## Handle tactical button press
func _on_tactical_button_pressed(command_id: String) -> void:
	if _tactical_system:
		_tactical_system.set_command(command_id)
		if AudioManager:
			AudioManager.play_sfx("ui_button_click")


## Handle tactical command changed
func _on_tactical_command_changed(command_id: String, command_name: String) -> void:
	_current_tactical_command = command_id
	# Update RTSArenaManager (autoload) so AI controllers can access weights
	if _tactical_system:
		var weights = _tactical_system.get_weight_modifiers()
		RTSArenaManager.set_tactical_command(command_id, weights)
	# Update button visual states: active = gold border + bright bg
	var tactical_colors = {
		"aggressive": Color(0.9, 0.3, 0.3),
		"defensive": Color(0.3, 0.5, 0.9),
		"focus": Color(0.9, 0.5, 0.2),
		"retreat": Color(0.7, 0.7, 0.3),
		"follow": Color(0.3, 0.8, 0.5),
		"free": Color(0.6, 0.6, 0.65)
	}
	for btn_id in _tactical_buttons.keys():
		var button = _tactical_buttons[btn_id]
		if button:
			if btn_id == command_id:
				# Active: bright gold border + lighter bg + scale up
				var active_style = StyleBoxFlat.new()
				active_style.bg_color = Color(0.18, 0.14, 0.08, 0.98)
				active_style.border_color = Color(1.0, 0.88, 0.5)
				active_style.border_width_left = 3
				active_style.border_width_right = 3
				active_style.border_width_top = 3
				active_style.border_width_bottom = 3
				active_style.corner_radius_top_left = 5
				active_style.corner_radius_top_right = 5
				active_style.corner_radius_bottom_right = 5
				active_style.corner_radius_bottom_left = 5
				button.add_theme_stylebox_override("normal", active_style)
				button.modulate = Color(1.1, 1.05, 0.95)
			else:
				# Inactive: reset to colored border style
				var cmd_color = tactical_colors.get(btn_id, Color(0.6, 0.6, 0.65))
				var inactive_style = StyleBoxFlat.new()
				inactive_style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
				inactive_style.border_color = cmd_color
				inactive_style.border_width_left = 2
				inactive_style.border_width_right = 2
				inactive_style.border_width_top = 2
				inactive_style.border_width_bottom = 2
				inactive_style.corner_radius_top_left = 5
				inactive_style.corner_radius_top_right = 5
				inactive_style.corner_radius_bottom_right = 5
				inactive_style.corner_radius_bottom_left = 5
				button.add_theme_stylebox_override("normal", inactive_style)
				button.modulate = Color(1, 1, 1)
	# Show battle log message
	if battle_log:
		battle_log.text += "\n[战术] 切换为: %s" % command_name
	GameLog.info("Tactical command: %s -> %s" % [command_id, command_name], "Arena")


## Get current tactical weight modifier (for AI controllers)
func get_tactical_weight(modifier_name: String, default_value: float = 1.0) -> float:
	if _tactical_system:
		return _tactical_system.get_weight(modifier_name, default_value)
	return default_value


## Initialize talent upgrade system (GDD v2.0 Chapter 5)
func _init_talent_system() -> void:
	_talent_system = TalentSystem.new()
	_talent_system.name = "TalentSystem"
	add_child(_talent_system)
	_talent_system.talent_options_generated.connect(_on_talent_options_generated)
	_talent_system.talent_selected.connect(_on_talent_selected)
	GameLog.info("Talent system initialized", "Arena")


## Initialize battle item system (GDD v2.0 Chapter 7)
func _init_item_system() -> void:
	if _item_system != null:
		_item_system.stop_item_system()
		_item_system.queue_free()
	_item_system = ItemSystem.new()
	_item_system.name = "ItemSystem"
	add_child(_item_system)
	# Create item container for sprites
	if _item_container != null:
		_item_container.queue_free()
	_item_container = Node2D.new()
	_item_container.name = "ItemContainer"
	add_child(_item_container)
	# Set battlefield bounds
	_item_system.set_battlefield_bounds(Vector2(200, 150), Vector2(1080, 500))
	_item_system.set_spawn_interval(15.0)
	_item_system.set_item_parent(_item_container)
	_item_system.item_picked_up.connect(_on_item_picked_up)
	_item_system.item_spawned.connect(_on_item_spawned)
	_item_system.start_item_system()
	GameLog.info("Item system initialized", "Arena")


## Handle item spawned - add sprite to scene
func _on_item_spawned(item_id: String, position: Vector2) -> void:
	# Item sprite is created by ItemSystem, need to reparent to our container
	# Find the newly created item sprite and add to container
	pass  # Sprites are managed by ItemSystem internally


## Handle item picked up
func _on_item_picked_up(item_id: String, unit) -> void:
	var item = _item_system.get_item(item_id) if _item_system else {}
	var item_name = item.get("name", item_id)
	var unit_name = unit.soul_name if unit else "Unknown"
	_add_log("%s 拾取了 %s" % [unit_name, item_name])
	if AudioManager:
		AudioManager.play_sfx("ui_item_pickup")
	# Track achievement stat
	if _achievement_system:
		_achievement_system.record_item_picked()


## Initialize trap system (GDD v2.0 Chapter 7)
func _init_trap_system() -> void:
	if _trap_system != null:
		_trap_system.stop_trap_system()
		_trap_system.queue_free()
	_trap_system = TrapSystem.new()
	_trap_system.name = "TrapSystem"
	add_child(_trap_system)
	# Create trap container for sprites
	if _trap_container != null:
		_trap_container.queue_free()
	_trap_container = Node2D.new()
	_trap_container.name = "TrapContainer"
	add_child(_trap_container)
	# Set battlefield bounds
	_trap_system.set_battlefield_bounds(Vector2(250, 200), Vector2(1030, 450))
	_trap_system.set_spawn_interval(20.0)
	_trap_system.set_trap_parent(_trap_container)
	_trap_system.trap_triggered.connect(_on_trap_triggered)
	_trap_system.trap_spawned.connect(_on_trap_spawned)
	_trap_system.start_trap_system()
	GameLog.info("Trap system initialized", "Arena")


## Handle trap spawned
func _on_trap_spawned(trap_id: String, position: Vector2) -> void:
	pass  # Trap sprites are managed by TrapSystem internally


## Handle trap triggered
func _on_trap_triggered(trap_id: String, unit, damage: float) -> void:
	var trap = _trap_system.get_trap(trap_id) if _trap_system else {}
	var trap_name = trap.get("name", trap_id)
	var unit_name = unit.soul_name if unit else "Unknown"
	_add_log("⚠ %s 触发了 %s (%.0f伤害)" % [unit_name, trap_name, damage])
	if AudioManager:
		AudioManager.play_sfx("battle_trap_trigger")
	# Spawn trap effect particles
	_spawn_trap_effect(unit.global_position if unit else Vector2.ZERO, trap_id)


## Initialize soul upgrade system (GDD v2.0 Chapter 5 - Permanent)
func _init_soul_upgrade_system() -> void:
	if _soul_upgrade_system != null:
		return
	_soul_upgrade_system = SoulUpgradeSystem.new()
	_soul_upgrade_system.name = "SoulUpgradeSystem"
	add_child(_soul_upgrade_system)
	_soul_upgrade_system.upgrade_applied.connect(_on_soul_upgrade_applied)
	_soul_upgrade_system.soul_leveled_up.connect(_on_soul_leveled_up)
	GameLog.info("Soul upgrade system initialized (level %d, %d points)" % [
		_soul_upgrade_system.get_soul_level(),
		_soul_upgrade_system.get_upgrade_points()
	], "Arena")


## Apply permanent soul upgrades to player unit at battle start
func _apply_soul_upgrades_to_player() -> void:
	if _soul_upgrade_system == null:
		return
	if RTSArenaManager.player_unit:
		_soul_upgrade_system.apply_upgrades_to_unit(RTSArenaManager.player_unit)
		GameLog.info("Soul upgrades applied to player unit", "Arena")


## Award soul experience after battle
func _award_soul_experience(victory: bool, battle_duration: float) -> void:
	if _soul_upgrade_system == null:
		return
	# Base experience: 50 for win, 20 for loss
	var exp = 50 if victory else 20
	# Time bonus: faster battles give more exp
	if victory and battle_duration > 0:
		var time_bonus = int(max(0, 120 - battle_duration) * 0.5)
		exp += time_bonus
	_soul_upgrade_system.add_experience(exp)
	_add_log("灵魂经验 +%d (等级 %d)" % [exp, _soul_upgrade_system.get_soul_level()])


## Handle soul upgrade applied
func _on_soul_upgrade_applied(dimension: String, new_level: int) -> void:
	var dim = _soul_upgrade_system.get_dimension(dimension) if _soul_upgrade_system else {}
	var dim_name = dim.get("name", dimension)
	_add_log("灵魂升级: %s Lv.%d" % [dim_name, new_level])


## Handle soul level up
func _on_soul_leveled_up(new_level: int) -> void:
	_add_log("🌟 灵魂等级提升! Lv.%d (获得1升级点)" % new_level)
	if AudioManager:
		AudioManager.play_sfx("ui_level_up")


## Initialize intelligence upgrade system (GDD v2.0 Chapter 5 - Ember core)
func _init_intelligence_upgrade_system() -> void:
	if _intelligence_upgrade_system != null:
		return
	_intelligence_upgrade_system = IntelligenceUpgradeSystem.new()
	_intelligence_upgrade_system.name = "IntelligenceUpgradeSystem"
	add_child(_intelligence_upgrade_system)
	_intelligence_upgrade_system.cognitive_upgraded.connect(_on_cognitive_upgraded)
	_intelligence_upgrade_system.stage_changed.connect(_on_cognitive_stage_changed)
	_intelligence_upgrade_system.cognitive_leveled_up.connect(_on_cognitive_leveled_up)
	GameLog.info("Intelligence system initialized (stage: %s, level: %d, points: %d)" % [
		_intelligence_upgrade_system.get_cognitive_stage_name(),
		_intelligence_upgrade_system.get_cognitive_level_overall(),
		_intelligence_upgrade_system.get_intelligence_points()
	], "Arena")


## Apply cognitive upgrades to player AI controller at battle start
func _apply_cognitive_upgrades_to_ai() -> void:
	if _intelligence_upgrade_system == null:
		return
	# Apply to player unit's AI controller
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.ai_controller:
		_intelligence_upgrade_system.apply_to_ai_controller(RTSArenaManager.player_unit.ai_controller)
		GameLog.info("Cognitive upgrades applied to player AI", "Arena")


## Award cognitive experience after battle
func _award_cognitive_experience(victory: bool, battle_duration: float) -> void:
	if _intelligence_upgrade_system == null:
		return
	# Base cognitive experience: 30 for win, 15 for loss
	var exp = 30 if victory else 15
	# Performance bonus: longer battles give more cognitive experience (learning)
	if battle_duration > 0:
		var time_bonus = int(min(battle_duration, 180) * 0.1)
		exp += time_bonus
	_intelligence_upgrade_system.add_cognitive_experience(exp)
	_add_log("认知经验 +%d (阶段: %s)" % [exp, _intelligence_upgrade_system.get_cognitive_stage_name()])


## Handle cognitive dimension upgraded
func _on_cognitive_upgraded(dimension: String, new_level: int) -> void:
	var dim = _intelligence_upgrade_system.get_dimension(dimension) if _intelligence_upgrade_system else {}
	var dim_name = dim.get("name", dimension)
	_add_log("🧠 认知升级: %s Lv.%d" % [dim_name, new_level])


## Handle cognitive stage changed
func _on_cognitive_stage_changed(new_stage: int, new_stage_name: String) -> void:
	_add_log("✨ 认知阶段提升: %s!" % new_stage_name)
	if AudioManager:
		AudioManager.play_sfx("ui_evolution")


## Handle cognitive level up
func _on_cognitive_leveled_up(new_level: int) -> void:
	_add_log("🧠 认知等级提升! Lv.%d (获得1智能点)" % new_level)
	if AudioManager:
		AudioManager.play_sfx("ui_level_up")


## Initialize achievement system (GDD v2.0 Chapter 13)
func _init_achievement_system() -> void:
	if _achievement_system != null:
		return
	_achievement_system = AchievementSystem.new()
	_achievement_system.name = "AchievementSystem"
	add_child(_achievement_system)
	_achievement_system.achievement_unlocked.connect(_on_achievement_unlocked)
	GameLog.info("Achievement system initialized", "Arena")


## Handle achievement unlocked - show notification popup
func _on_achievement_unlocked(achievement_id: String, achievement_data: Dictionary) -> void:
	var ach_name = achievement_data.get("name", achievement_id)
	_add_log("🏆 成就解锁: %s" % ach_name)
	if AudioManager:
		AudioManager.play_sfx("ui_achievement")
	# Show achievement popup
	_show_achievement_popup(achievement_id, achievement_data)


## Show achievement unlock notification popup
func _show_achievement_popup(achievement_id: String, achievement_data: Dictionary) -> void:
	if _achievement_popup != null:
		_achievement_popup.queue_free()
	# Create popup panel
	var popup = Panel.new()
	popup.name = "AchievementPopup"
	popup.size = Vector2(320, 80)
	popup.position = Vector2(480, 20)
	popup.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(popup)
	_achievement_popup = popup
	# Apply dark purple + gold style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.2, 0.95)
	style.border_color = Color(0.8, 0.6, 0.2, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("panel", style)
	# Achievement icon
	var icon_rect = TextureRect.new()
	icon_rect.position = Vector2(10, 10)
	icon_rect.size = Vector2(60, 60)
	if _achievement_system:
		icon_rect.texture = _achievement_system.get_achievement_icon(achievement_id)
	popup.add_child(icon_rect)
	# Achievement title
	var title = Label.new()
	title.text = "成就解锁!"
	title.position = Vector2(80, 10)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	popup.add_child(title)
	# Achievement name
	var name_label = Label.new()
	name_label.text = achievement_data.get("name", "")
	name_label.position = Vector2(80, 30)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	popup.add_child(name_label)
	# Achievement description
	var desc = Label.new()
	desc.text = achievement_data.get("description", "")
	desc.position = Vector2(80, 50)
	desc.size = Vector2(230, 25)
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	popup.add_child(desc)
	# Animate popup in
	var tween = create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)


## Start battle achievement tracking
func _start_achievement_tracking() -> void:
	if _achievement_system:
		_achievement_system.start_battle_tracking()


## End battle achievement tracking
func _end_achievement_tracking(victory: bool) -> void:
	if _achievement_system:
		var map_name = GameState.get_value("battle", "map", "aether_temple")
		var battle_time = RTSArenaManager.battle_time if RTSArenaManager else 0.0
		_achievement_system.end_battle_tracking(victory, map_name, battle_time)


## Track damage dealt for achievements
func _track_damage_dealt(amount: float) -> void:
	if _achievement_system:
		_achievement_system.record_damage_dealt(amount)


## Track damage taken for achievements
func _track_damage_taken(amount: float) -> void:
	if _achievement_system:
		_achievement_system.record_damage_taken(amount)


## Track skill used for achievements
func _track_skill_used() -> void:
	if _achievement_system:
		_achievement_system.record_skill_used()


## Track crit dealt for achievements
func _track_crit_dealt() -> void:
	if _achievement_system:
		_achievement_system.record_crit_dealt()


## Track talent selected for achievements
func _track_talent_selected() -> void:
	if _achievement_system:
		_achievement_system.record_talent_selected()


## Create talent selection panel UI
func _create_talent_panel() -> void:
	if _talent_panel:
		return
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.name = "TalentOverlay"
	overlay.color = Color(0.05, 0.03, 0.1, 0.85)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_talent_panel = overlay

	# Main panel
	var panel = Panel.new()
	panel.name = "TalentPanel"
	panel.size = Vector2(700, 300)
	panel.position = Vector2(290, 190)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.name = "TalentTitle"
	title.text = "灵魂升级 - 选择天赋"
	title.position = Vector2(0, 15)
	title.size = Vector2(700, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	panel.add_child(title)

	# Talent cards container
	var cards = HBoxContainer.new()
	cards.name = "TalentCards"
	cards.position = Vector2(25, 60)
	cards.size = Vector2(650, 200)
	cards.add_theme_constant_override("separation", 20)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(cards)

	# Create 3 talent card buttons
	_talent_buttons.clear()
	for i in range(3):
		var card = Button.new()
		card.name = "TalentCard%d" % i
		card.custom_minimum_size = Vector2(200, 180)
		card.add_theme_stylebox_override("normal", _create_card_style())
		card.add_theme_stylebox_override("hover", _create_card_hover_style())
		card.add_theme_stylebox_override("pressed", _create_card_pressed_style())
		card.pressed.connect(_on_talent_card_pressed.bind(i))
		cards.add_child(card)
		_talent_buttons.append(card)

		# Card content (VBox)
		var content = VBoxContainer.new()
		content.name = "CardContent"
		content.size = Vector2(180, 160)
		content.position = Vector2(10, 10)
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)

		# Icon (TextureRect using talent icon sheet)
		var icon = TextureRect.new()
		icon.name = "TalentIcon"
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		content.add_child(icon)

		# Talent name
		var name_label = Label.new()
		name_label.name = "TalentName"
		name_label.text = ""
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		content.add_child(name_label)

		# Talent description
		var desc_label = Label.new()
		desc_label.name = "TalentDesc"
		desc_label.text = ""
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc_label)

	_talent_panel.visible = false


## Create panel style (deep purple with gold border)
func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.2, 0.95)
	style.border_color = Color(0.8, 0.65, 0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


## Create talent card style
func _create_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.25, 0.9)
	style.border_color = Color(0.5, 0.4, 0.25)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _create_card_hover_style() -> StyleBoxFlat:
	var style = _create_card_style()
	style.bg_color = Color(0.2, 0.15, 0.3, 0.95)
	style.border_color = Color(0.9, 0.75, 0.4)
	return style


func _create_card_pressed_style() -> StyleBoxFlat:
	var style = _create_card_style()
	style.bg_color = Color(0.25, 0.2, 0.35, 1.0)
	style.border_color = Color(1.0, 0.85, 0.5)
	return style


## Handle talent options generated
func _on_talent_options_generated(options: Array) -> void:
	if not _talent_panel:
		_create_talent_panel()
	_talent_panel.visible = true
	_talent_active = true
	# Pause battle while selecting
	get_tree().paused = true
	# Load talent icon sheet (4 rows x 5 cols, 1024x1024)
	var sheet_path := "res://assets/art/talent_icon_sheet_v1.png"
	var sheet = null
	if ResourceLoader.exists(sheet_path):
		sheet = load(sheet_path)
	# Update card content
	for i in range(min(options.size(), _talent_buttons.size())):
		var talent_id = options[i]
		var talent = _talent_system.get_talent(talent_id)
		var card = _talent_buttons[i]
		var icon_rect = card.get_node("CardContent/TalentIcon")
		var name_label = card.get_node("CardContent/TalentName")
		var desc_label = card.get_node("CardContent/TalentDesc")
		# Set talent icon from sheet
		if icon_rect and sheet:
			var icon_idx = talent.get("icon_index", 0)
			var row: int = icon_idx / 5
			var col: int = icon_idx % 5
			var cell_w: int = 204  # 1024 / 5
			var cell_h: int = 256  # 1024 / 4
			var atlas = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
			icon_rect.texture = atlas
		elif icon_rect:
			icon_rect.texture = null
		if name_label:
			name_label.text = talent.get("name", talent_id)
		if desc_label:
			desc_label.text = talent.get("description", "")
	GameLog.info("Talent options shown: %s" % str(options), "Arena")


## Handle talent card pressed
func _on_talent_card_pressed(index: int) -> void:
	if not _talent_system or not _talent_system.is_selection_pending():
		return
	var options = _talent_system.get_pending_options()
	if index >= options.size():
		return
	var talent_id = options[index]
	_talent_system.select_player_talent(talent_id)


## Handle talent selected
func _on_talent_selected(talent_id: String, talent_name: String) -> void:
	_talent_active = false
	if _talent_panel:
		_talent_panel.visible = false
	# Resume battle
	get_tree().paused = false
	# Apply talent effects to player unit
	_apply_talent_effects(talent_id)
	# Show battle log
	if battle_log:
		battle_log.text += "\n[天赋] 获得: %s" % talent_name
	if AudioManager:
		AudioManager.play_sfx("ui_confirm")
	GameLog.info("Talent selected: %s (%s)" % [talent_id, talent_name], "Arena")
	# Track achievement stat
	_track_talent_selected()


## Apply talent effects to player unit
func _apply_talent_effects(talent_id: String) -> void:
	if not RTSArenaManager.player_unit:
		return
	var talent = _talent_system.get_talent(talent_id)
	var effect = talent.get("effect", {})
	var unit = RTSArenaManager.player_unit
	# Apply multiplier effects
	if effect.has("attack_damage_mult"):
		unit.attack_damage = int(unit.attack_damage * effect["attack_damage_mult"])
	if effect.has("max_hp_mult"):
		var old_max = unit.max_hp
		unit.max_hp = int(unit.max_hp * effect["max_hp_mult"])
		unit.current_hp += (unit.max_hp - old_max)
	if effect.has("move_speed_mult"):
		unit.move_speed = int(unit.move_speed * effect["move_speed_mult"])
	if effect.has("attack_speed_mult"):
		unit.attack_speed *= effect["attack_speed_mult"]
	if effect.has("attack_range_mult"):
		unit.attack_range = int(unit.attack_range * effect["attack_range_mult"])
	if effect.has("crit_rate_add"):
		unit.crit_rate += effect["crit_rate_add"]
	# Store flag effects in unit for damage calculation
	if not unit.has_meta("talent_effects"):
		unit.set_meta("talent_effects", {})
	var existing = unit.get_meta("talent_effects")
	for key in effect.keys():
		existing[key] = effect[key]
	unit.set_meta("talent_effects", existing)


## Check for talent upgrade timing (called from _process)
func _update_talent_check(delta: float) -> void:
	if not _talent_system or not RTSArenaManager:
		return
	if RTSArenaManager.battle_state != RTSArenaManager.BattleState.ACTIVE:
		return
	if _talent_active:
		return
	var battle_time = RTSArenaManager.battle_time
	# Player upgrade
	if _talent_system.check_player_upgrade(battle_time):
		_talent_system.generate_player_options()
	# AI upgrade (auto)
	if _talent_system.check_ai_upgrade(battle_time):
		_talent_system.generate_ai_options()
		# Apply AI talent effects
		var ai_talents = _talent_system._ai_talents
		if ai_talents.size() > 0 and RTSArenaManager.ai_unit:
			var last_talent = ai_talents[ai_talents.size() - 1]
			_apply_ai_talent_effects(last_talent)


## Apply AI talent effects
func _apply_ai_talent_effects(talent_id: String) -> void:
	if not RTSArenaManager.ai_unit:
		return
	var talent = _talent_system.get_talent(talent_id)
	var effect = talent.get("effect", {})
	var unit = RTSArenaManager.ai_unit
	if effect.has("attack_damage_mult"):
		unit.attack_damage = int(unit.attack_damage * effect["attack_damage_mult"])
	if effect.has("max_hp_mult"):
		var old_max = unit.max_hp
		unit.max_hp = int(unit.max_hp * effect["max_hp_mult"])
		unit.current_hp += (unit.max_hp - old_max)
	if effect.has("move_speed_mult"):
		unit.move_speed = int(unit.move_speed * effect["move_speed_mult"])


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
