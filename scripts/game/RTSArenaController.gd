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

## Visual unit nodes
var _player_light = null
var _ai_light = null

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

## Status effect display
var _player_status_label = null
var _ai_status_label = null

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


func _ready() -> void:
	_dlog("[DEBUG-READY] _ready() start")
	GameLog.info("RTSArenaController: RTS Arena scene ready", "Arena")
	_base_position = position
	_dlog("[DEBUG-READY] before _setup_ui_refs")
	_setup_ui_refs()
	_dlog("[DEBUG-READY] after _setup_ui_refs, before _apply_ui_theme")
	_apply_ui_theme()
	_dlog("[DEBUG-READY] after _apply_ui_theme, before _apply_hp_energy_styles")
	_apply_hp_energy_styles()
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
	_pause_button.modulate = Color(0.9, 0.9, 0.7)
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
	resume_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
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
	quit_btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.7))
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


## Handle keyboard input (ESC/Space to pause/resume)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			if _battle_active:
				if _is_paused:
					_resume_battle()
				else:
					_pause_battle()
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
	# Player status label (next to player panel)
	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.text = ""
	_player_status_label.position = Vector2(10, 55)
	_player_status_label.add_theme_font_size_override("font_size", 11)
	_player_status_label.modulate = Color(0.4, 0.9, 0.6)
	add_child(_player_status_label)

	# AI status label (next to AI panel)
	_ai_status_label = Label.new()
	_ai_status_label.name = "AIStatusLabel"
	_ai_status_label.text = ""
	_ai_status_label.position = Vector2(1050, 55)
	_ai_status_label.add_theme_font_size_override("font_size", 11)
	_ai_status_label.modulate = Color(0.9, 0.4, 0.4)
	add_child(_ai_status_label)


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
	GameLog.debug("RTSArena: Damage floating text system initialized", "UI")


## Update all damage floating text displays
func _update_damage_display(delta: float) -> void:
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
	label.modulate = p_color
	label.z_index = 100
	add_child(label)
	_damage_labels.append({
		"label": label,
		"timer": 1.0,
		"duration": 1.0,
		"start_y": p_position.y - 60
	})


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
	_vignette_sprite.modulate = Color(1, 1, 1, 0.35)
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

	if player_soul != null and ai_soul != null:
		GameLog.info("RTSArenaController: Starting battle countdown with config from GameState", "Arena")
		# Save config for rematch and pending start
		_battle_config["player_soul"] = player_soul
		_battle_config["ai_soul"] = ai_soul
		_battle_config["map_name"] = map_name
		_pending_battle_config = {
			"player_soul": player_soul,
			"ai_soul": ai_soul,
			"map_name": map_name
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
	var player_soul = _pending_battle_config["player_soul"]
	var ai_soul = _pending_battle_config["ai_soul"]
	var map_name = _pending_battle_config["map_name"]
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

	var ai_panel = get_node_or_null("TopBar/AIPanel")
	if ai_panel and (ai_panel is Panel or ai_panel is PanelContainer):
		ai_panel.add_theme_stylebox_override("panel", ai_card_style)

	# Skill button style: square with gold border (matching ui_hud_skin design)
	var skill_btn_normal = StyleBoxFlat.new()
	skill_btn_normal.bg_color = Color(0.15, 0.10, 0.25, 0.95)
	skill_btn_normal.border_color = Color(0.83, 0.66, 0.36, 0.9)
	skill_btn_normal.border_width_left = 2
	skill_btn_normal.border_width_right = 2
	skill_btn_normal.border_width_top = 2
	skill_btn_normal.border_width_bottom = 2
	skill_btn_normal.corner_radius_top_left = 4
	skill_btn_normal.corner_radius_top_right = 4
	skill_btn_normal.corner_radius_bottom_left = 4
	skill_btn_normal.corner_radius_bottom_right = 4

	var skill_btn_hover = StyleBoxFlat.new()
	skill_btn_hover.bg_color = Color(0.25, 0.18, 0.35, 0.98)
	skill_btn_hover.border_color = Color(1.0, 0.85, 0.4, 1.0)
	skill_btn_hover.border_width_left = 3
	skill_btn_hover.border_width_right = 3
	skill_btn_hover.border_width_top = 3
	skill_btn_hover.border_width_bottom = 3
	skill_btn_hover.corner_radius_top_left = 4
	skill_btn_hover.corner_radius_top_right = 4
	skill_btn_hover.corner_radius_bottom_left = 4
	skill_btn_hover.corner_radius_bottom_right = 4

	var skill_btn_pressed = StyleBoxFlat.new()
	skill_btn_pressed.bg_color = Color(0.35, 0.25, 0.15, 1.0)
	skill_btn_pressed.border_color = Color(1.0, 0.9, 0.5, 1.0)
	skill_btn_pressed.border_width_left = 2
	skill_btn_pressed.border_width_right = 2
	skill_btn_pressed.border_width_top = 2
	skill_btn_pressed.border_width_bottom = 2
	skill_btn_pressed.corner_radius_top_left = 4
	skill_btn_pressed.corner_radius_top_right = 4
	skill_btn_pressed.corner_radius_bottom_left = 4
	skill_btn_pressed.corner_radius_bottom_right = 4

	for skill_name in skill_buttons.keys():
		var btn = skill_buttons[skill_name]
		if btn and btn is Button:
			btn.add_theme_stylebox_override("normal", skill_btn_normal)
			btn.add_theme_stylebox_override("hover", skill_btn_hover)
			btn.add_theme_stylebox_override("pressed", skill_btn_pressed)

	# Battle log text color adjustment
	if battle_log:
		battle_log.modulate = Color(0.9, 0.85, 0.75)

	GameLog.info("RTSArenaController: Applied HUD skin (dark purple + gold)", "UI")


## Apply custom styles to HP and energy bars (orb-like with gold border)
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
		GameLog.debug("RTSArena: Applied icon for %s (idx=%d)" % [skill_name, idx], "UI")


## Setup macro command UI (design doc: coach-style RTS)
## Player can issue one macro command per 30 seconds
## Commands: gather, retreat, attack, defend
func _setup_macro_commands() -> void:
	# Create command panel at bottom center
	_command_panel = Panel.new()
	_command_panel.position = Vector2(380, 490)
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
	# Sync dynamic lights to unit positions with subtle pulse
	if _player_light and is_instance_valid(RTSArenaManager.player_unit):
		_player_light.position = RTSArenaManager.player_unit.position
		var pulse = 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.15
		_player_light.energy = 1.2 * pulse
	if _ai_light and is_instance_valid(RTSArenaManager.ai_unit):
		_ai_light.position = RTSArenaManager.ai_unit.position
		var ai_pulse = 1.0 + sin(Time.get_ticks_msec() / 350.0 + 1.0) * 0.15
		_ai_light.energy = 1.2 * ai_pulse
	_update_skill_cooldowns()
	_update_command_cooldown(delta)
	_update_weather_display()
	_update_status_display()
	_update_crit_display(delta)
	_update_dodge_display(delta)
	_update_heal_display(delta)
	_update_defend_display(delta)
	_update_skill_display(delta)
	_update_damage_display(delta)
	_update_skill_particles(delta)
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
		if player_energy_bar:
			_target_player_energy = float(p.get("energy", 0)) / float(p.get("max_energy", 50)) * 100.0

	if info.has("ai") and ai_hp_bar:
		var a = info["ai"]
		ai_hp_bar.value = float(a.get("hp", 0)) / float(a.get("max_hp", 100)) * 100.0
		if ai_energy_bar:
			_target_ai_energy = float(a.get("energy", 0)) / float(a.get("max_energy", 50)) * 100.0


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
	if RTSArenaManager.player_unit == null:
		return

	for skill_name in skill_buttons.keys():
		var button = skill_buttons[skill_name]
		if button == null:
			continue
		var cooldown = RTSArenaManager.player_unit.skill_cooldowns.get(skill_name, 0)
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

	GameLog.info("RTSArenaController: Battle started", "Arena")


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

	# Create result panel with gold border style
	var panel = Panel.new()
	panel.position = Vector2(340, 100)
	panel.size = Vector2(600, 520)
	panel.name = "ResultModal"
	# Apply custom style: dark purple bg + gold border
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

	# Damage dealt with bar
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

	# Damage taken with bar
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

	# HP remaining with bar
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

	# === Buttons ===
	var btn_y = 440

	# Rematch button
	var rematch_btn = Button.new()
	rematch_btn.text = "⚔ 再战一局"
	rematch_btn.position = Vector2(100, btn_y)
	rematch_btn.size = Vector2(170, 50)
	rematch_btn.add_theme_font_size_override("font_size", 18)
	var rematch_normal = StyleBoxFlat.new()
	rematch_normal.bg_color = Color(0.15, 0.2, 0.35, 0.95)
	rematch_normal.border_color = Color(0.4, 0.6, 0.9, 0.8)
	rematch_normal.border_width_left = 2
	rematch_normal.border_width_right = 2
	rematch_normal.border_width_top = 2
	rematch_normal.border_width_bottom = 2
	rematch_normal.corner_radius_top_left = 8
	rematch_normal.corner_radius_top_right = 8
	rematch_normal.corner_radius_bottom_left = 8
	rematch_normal.corner_radius_bottom_right = 8
	rematch_btn.add_theme_stylebox_override("normal", rematch_normal)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	_setup_button_hover(rematch_btn)
	panel.add_child(rematch_btn)

	# Back to menu button
	var back_btn = Button.new()
	back_btn.text = "🏠 返回主菜单"
	back_btn.position = Vector2(330, btn_y)
	back_btn.size = Vector2(170, 50)
	back_btn.add_theme_font_size_override("font_size", 18)
	var back_normal = StyleBoxFlat.new()
	back_normal.bg_color = Color(0.2, 0.18, 0.15, 0.95)
	back_normal.border_color = Color(0.7, 0.6, 0.4, 0.8)
	back_normal.border_width_left = 2
	back_normal.border_width_right = 2
	back_normal.border_width_top = 2
	back_normal.border_width_bottom = 2
	back_normal.corner_radius_top_left = 8
	back_normal.corner_radius_top_right = 8
	back_normal.corner_radius_bottom_left = 8
	back_normal.corner_radius_bottom_right = 8
	back_btn.add_theme_stylebox_override("normal", back_normal)
	back_btn.pressed.connect(_on_back_to_menu_pressed)
	_setup_button_hover(back_btn)
	panel.add_child(back_btn)

	# Animate internal elements appearing sequentially
	_animate_result_elements(panel)

	GameLog.info("RTSArenaController: Result modal shown (visualized UI)", "Arena")


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


## Handle unit spawned
func _on_unit_spawned(p_unit: SoulUnit, p_is_player: bool) -> void:
	GameLog.info("RTSArenaController: Unit spawned - %s (player: %s)" % [p_unit.soul_name, str(p_is_player)], "Arena")

	# SoulUnit creates its own sprite visual in init_from_soul() / _create_visual()
	# No separate ColorRect placeholder needed - it was covering the design sprite

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
	p_unit.unit_died.connect(_on_unit_died.bind(p_unit))


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


## Handle log added
func _on_log_added(p_message: String) -> void:
	_add_log(p_message)


## Add message to battle log
func _add_log(p_message: String) -> void:
	if battle_log:
		battle_log.text += p_message + "\n"
		# Scroll to bottom (RichTextLabel uses scroll_to_line, not caret_position)
		battle_log.scroll_to_line(battle_log.get_line_count() - 1)


## Skill button handlers
func _on_heavy_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("heavy_strike")
	if RTSArenaManager.player_unit:
		_spawn_skill_particle("heavy_strike", RTSArenaManager.player_unit.position)
	_trigger_chromatic_aberration(12.0, 0.35)
	if AudioManager:
		AudioManager.play_sfx("skill_rock")

func _on_quick_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("quick_strike")
	if RTSArenaManager.player_unit:
		_spawn_skill_particle("quick_strike", RTSArenaManager.player_unit.position)
	_trigger_chromatic_aberration(8.0, 0.25)
	if AudioManager:
		AudioManager.play_sfx("skill_windblade")

func _on_heal_pressed() -> void:
	RTSArenaManager.player_use_skill("heal")
	if RTSArenaManager.player_unit:
		_spawn_skill_particle("heal", RTSArenaManager.player_unit.position)
	_trigger_chromatic_aberration(5.0, 0.2)
	if AudioManager:
		AudioManager.play_sfx("skill_heal")

func _on_defend_pressed() -> void:
	RTSArenaManager.player_use_skill("defend")
	if RTSArenaManager.player_unit:
		_spawn_skill_particle("defend", RTSArenaManager.player_unit.position)
	_trigger_chromatic_aberration(6.0, 0.2)
	if AudioManager:
		AudioManager.play_sfx("skill_defend")


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
