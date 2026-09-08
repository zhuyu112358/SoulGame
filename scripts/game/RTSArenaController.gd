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
var _skill_was_on_cooldown = {}

## Screen shake effect (combat feedback)
var _screen_shake_timer = 0.0
var _screen_shake_intensity = 0.0
var _base_position = Vector2.ZERO

## Hit flash effect (combat feedback)
var _hit_flash = null
var _hit_flash_timer = 0.0
var _hit_flash_duration = 0.0

## Skill particle effect (combat feedback)
var _skill_particles = []
var _skill_particle_timer = 0.0

## Skill cooldown overlays (visual cooldown indicator)
var _skill_cooldown_overlays = {}

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

## Damage floating text display
var _damage_label = null
var _damage_timer = 0.0
var _damage_active = false


func _ready() -> void:
	GameLog.info("RTSArenaController: RTS Arena scene ready", "Arena")
	_base_position = position
	_setup_ui_refs()
	_apply_ui_theme()
	_setup_arena_background()
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


## Play hover sound and visual feedback
func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	p_button.modulate = Color(1.2, 1.2, 1.0)


## Reset button visual on mouse exit
func _on_button_exit(p_button: Button) -> void:
	p_button.modulate = Color(1.0, 1.0, 1.0)


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


## Show pause overlay
func _show_pause_overlay() -> void:
	if _pause_overlay != null:
		return
	# Create semi-transparent overlay
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0, 0, 0, 0.6)
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_overlay)
	# Create pause label
	_pause_label = Label.new()
	_pause_label.name = "PauseLabel"
	_pause_label.text = "战斗暂停"
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.set_grow_horizontal(Control.GROW_DIRECTION_BOTH)
	_pause_label.set_grow_vertical(Control.GROW_DIRECTION_BOTH)
	_pause_label.position = Vector2(-150, -50)
	_pause_label.size = Vector2(300, 100)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 48)
	_pause_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_pause_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_pause_label.add_theme_constant_override("outline_size", 4)
	_pause_overlay.add_child(_pause_label)


## Hide pause overlay
func _hide_pause_overlay() -> void:
	if _pause_overlay != null:
		_pause_overlay.queue_free()
		_pause_overlay = null
		_pause_label = null


## Setup battle speed button UI
func _setup_speed_button() -> void:
	# Create speed button next to pause button
	_speed_button = Button.new()
	_speed_button.name = "SpeedButton"
	_speed_button.text = "1x"
	_speed_button.position = Vector2(690, 10)
	_speed_button.size = Vector2(60, 35)
	_speed_button.add_theme_font_size_override("font_size", 14)
	_speed_button.modulate = Color(0.7, 0.9, 0.7)
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
	# Update button text
	if _speed_button:
		_speed_button.text = "%.1fx" % _current_speed
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


## Setup damage floating text label
func _setup_damage_label() -> void:
	_damage_label = Label.new()
	_damage_label.name = "DamageLabel"
	_damage_label.text = ""
	_damage_label.position = Vector2(540, 600)
	_damage_label.size = Vector2(200, 50)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_label.add_theme_font_size_override("font_size", 32)
	_damage_label.modulate = Color(1.0, 0.3, 0.3)
	_damage_label.visible = false
	add_child(_damage_label)


## Update damage floating text display
func _update_damage_display(delta: float) -> void:
	if _damage_active:
		_damage_timer -= delta
		if _damage_timer <= 0:
			_damage_active = false
			if _damage_label:
				_damage_label.visible = false
		else:
			# Animate: float upward and fade out
			if _damage_label:
				var progress = 1.0 - (_damage_timer / 1.0)
				_damage_label.position.y = 600 - progress * 40
				_damage_label.modulate.a = 1.0 - progress
		return

	# Check if player unit just took damage
	if RTSArenaManager.player_unit and RTSArenaManager.player_unit.last_damage_taken > 0:
		_show_damage(RTSArenaManager.player_unit.last_damage_taken)
		# Reset the flag to avoid repeated display
		RTSArenaManager.player_unit.last_damage_taken = 0


## Show damage floating text
func _show_damage(damage_amount: int) -> void:
	if _damage_label == null:
		return
	_damage_label.text = "-%d" % damage_amount
	_damage_label.visible = true
	_damage_label.position = Vector2(540, 600)
	_damage_label.modulate.a = 1.0
	_damage_active = true
	_damage_timer = 1.0
	# Trigger hit flash on damage taken
	_trigger_hit_flash(Color(1.0, 0.2, 0.2, 0.25), 0.15)


## Trigger screen shake effect
func _trigger_screen_shake(p_intensity: float = 3.0, p_duration: float = 0.2) -> void:
	_screen_shake_intensity = p_intensity
	_screen_shake_timer = p_duration


## Update screen shake effect
func _update_screen_shake(delta: float) -> void:
	if _screen_shake_timer > 0:
		_screen_shake_timer -= delta
		if _screen_shake_timer > 0:
			# Random offset within intensity range
			var shake_x = randf_range(-_screen_shake_intensity, _screen_shake_intensity)
			var shake_y = randf_range(-_screen_shake_intensity, _screen_shake_intensity)
			position = _base_position + Vector2(shake_x, shake_y)
		else:
			# Reset to base position when shake ends
			position = _base_position
			_screen_shake_timer = 0.0


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
		_skill_particles.append({"node": particle, "velocity": velocity, "life": 0.5, "max_life": 0.5})
	_skill_particle_timer = 0.5


## Update skill particle effect
func _update_skill_particles(delta: float) -> void:
	if _skill_particles.is_empty():
		return
	var to_remove = []
	for particle_data in _skill_particles:
		particle_data["life"] -= delta
		if particle_data["life"] <= 0:
			particle_data["node"].queue_free()
			to_remove.append(particle_data)
		else:
			var progress = 1.0 - (particle_data["life"] / particle_data["max_life"])
			particle_data["node"].position += particle_data["velocity"] * delta
			var current_color = particle_data["node"].color
			current_color.a = 1.0 - progress
			particle_data["node"].color = current_color
			# Shrink particle
			var scale_factor = 1.0 - progress * 0.5
			particle_data["node"].scale = Vector2(scale_factor, scale_factor)
	for particle_data in to_remove:
		_skill_particles.erase(particle_data)


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
	# Create cooldown overlays for each skill button
	for skill_name in skill_buttons.keys():
		var button = skill_buttons[skill_name]
		if button:
			var overlay = ColorRect.new()
			overlay.name = "CooldownOverlay"
			overlay.color = Color(0.0, 0.0, 0.0, 0.6)
			overlay.size = button.size
			overlay.position = Vector2(0, 0)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.visible = false
			button.add_child(overlay)
			_skill_cooldown_overlays[skill_name] = overlay


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
	# Skip battle logic updates when paused (UI still renders)
	if _is_paused:
		_update_unit_display()
		return
	_update_unit_display()
	# Sync unit visuals to logical positions (replaces unreliable position_changed signal)
	if _player_visual and is_instance_valid(RTSArenaManager.player_unit):
		_player_visual.position = RTSArenaManager.player_unit.position - Vector2(32, 32)
	if _ai_visual and is_instance_valid(RTSArenaManager.ai_unit):
		_ai_visual.position = RTSArenaManager.ai_unit.position - Vector2(32, 32)
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
		if cooldown > 0:
			button.text = "%s (%.1f)" % [skill_name.capitalize(), cooldown]
			_skill_was_on_cooldown[skill_name] = true
		else:
			button.text = skill_name.capitalize()
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
		_speed_button.text = "1x"
		_speed_button.disabled = false
	_add_log("Battle started!")

	# Play battle start sound and BGM
	if AudioManager:
		AudioManager.play_sfx("battle_ui_start")
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

	# Show battle result modal
	var battle_stats = RTSArenaManager.last_battle_stats
	_show_result_modal(p_result, result_text, result_color, exp_gained, stats, battle_stats)

	GameLog.info("RTSArenaController: Battle finished - %s, EXP: +%d" % [p_result, exp_gained], "Arena")


## Show battle result modal dialog
func _show_result_modal(p_result: String, p_title: String, p_title_color: Color, p_exp: int, p_stats: Dictionary, p_battle_stats: Dictionary = {}) -> void:
	# Play battle end sound
	if AudioManager:
		AudioManager.play_sfx("battle_ui_end")
	# Play panel open sound
	if AudioManager:
		AudioManager.play_sfx("ui_panel_open")
	# Play EXP gain sound
	if AudioManager:
		AudioManager.play_sfx("ui_exp_gain")

	# Create modal background (semi-transparent dark overlay)
	var modal_bg = ColorRect.new()
	modal_bg.color = Color(0, 0, 0, 0.0)
	modal_bg.size = Vector2(1280, 720)
	modal_bg.name = "ResultModalBG"
	add_child(modal_bg)
	# Fade in modal background
	var bg_tween = create_tween()
	bg_tween.tween_property(modal_bg, "color:a", 0.75, 0.2)

	# Create result panel (taller to fit more stats)
	var panel = Panel.new()
	panel.position = Vector2(390, 140)
	panel.size = Vector2(500, 440)
	panel.name = "ResultModal"
	add_child(panel)
	# Animate panel appearance (scale up + fade in)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.set_parallel(false)

	# Title
	var title = Label.new()
	title.text = p_title
	title.position = Vector2(0, 20)
	title.size = Vector2(500, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = p_title_color
	panel.add_child(title)

	# EXP gained
	var exp_label = Label.new()
	exp_label.text = "Experience Gained: +%d" % p_exp
	exp_label.position = Vector2(0, 75)
	exp_label.size = Vector2(500, 30)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 18)
	exp_label.modulate = Color(0.9, 0.8, 0.4)
	panel.add_child(exp_label)

	# Separator 1
	var sep1 = HSeparator.new()
	sep1.position = Vector2(50, 115)
	sep1.size = Vector2(400, 10)
	panel.add_child(sep1)

	# Battle stats (this battle)
	var battle_stats_text = "--- 本场战斗 ---\n"
	var duration = p_battle_stats.get("duration", 0.0)
	var minutes = int(duration) / 60
	var seconds = int(duration) % 60
	battle_stats_text += "战斗时长: %02d:%02d\n" % [minutes, seconds]
	battle_stats_text += "伤害输出: %d\n" % p_battle_stats.get("damage_dealt", 0)
	battle_stats_text += "承受伤害: %d\n" % p_battle_stats.get("damage_taken", 0)
	var player_hp = p_battle_stats.get("player_hp_remaining", 0)
	var player_max_hp = p_battle_stats.get("player_max_hp", 100)
	battle_stats_text += "剩余HP: %d/%d (%.0f%%)" % [player_hp, player_max_hp, float(player_hp) / float(player_max_hp) * 100.0]

	var battle_stats_label = Label.new()
	battle_stats_label.text = battle_stats_text
	battle_stats_label.position = Vector2(50, 130)
	battle_stats_label.size = Vector2(400, 100)
	battle_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_stats_label.add_theme_font_size_override("font_size", 14)
	battle_stats_label.modulate = Color(0.7, 0.9, 1.0)
	panel.add_child(battle_stats_label)

	# Separator 2
	var sep2 = HSeparator.new()
	sep2.position = Vector2(50, 240)
	sep2.size = Vector2(400, 10)
	panel.add_child(sep2)

	# Overall stats
	var stats_text = "--- 总体统计 ---\n"
	stats_text += "胜率: %.1f%%  (%d/%d)\n" % [
		p_stats.get("win_rate", 0),
		p_stats.get("victories", 0),
		p_stats.get("total_battles", 0)
	]
	stats_text += "当前连胜: %d  (最佳: %d)\n" % [
		p_stats.get("current_streak", 0),
		p_stats.get("best_streak", 0)
	]
	stats_text += "总经验: %d" % p_stats.get("total_experience_gained", 0)

	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(50, 255)
	stats_label.size = Vector2(400, 90)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.modulate = Color(0.85, 0.85, 0.9)
	panel.add_child(stats_label)

	# Buttons
	var btn_y = 360

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
			_speed_button.text = "1x"
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

	# Create visual representation
	var visual = ColorRect.new()
	visual.size = Vector2(64, 64)
	visual.position = p_unit.position - Vector2(32, 32)
	visual.z_index = 10  # Render above arena obstacles
	if p_is_player:
		visual.color = Color(0.2, 0.6, 1.0)  # Blue for player
		_player_visual = visual
	else:
		visual.color = Color(1.0, 0.3, 0.3)  # Red for AI
		_ai_visual = visual
	# Visual position synced in _process (position_changed signal unreliable in Godot 4.7)
	add_child(visual)


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
	if AudioManager:
		AudioManager.play_sfx("skill_rock")

func _on_quick_strike_pressed() -> void:
	RTSArenaManager.player_use_skill("quick_strike")
	if AudioManager:
		AudioManager.play_sfx("skill_windblade")

func _on_heal_pressed() -> void:
	RTSArenaManager.player_use_skill("heal")
	if AudioManager:
		AudioManager.play_sfx("skill_heal")

func _on_defend_pressed() -> void:
	RTSArenaManager.player_use_skill("defend")
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
