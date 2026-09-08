extends Node2D
## SoulUnit - RTS battle unit representing a soul in the arena
##
## Handles real-time movement, attack, skills, and status effects.
## This is game-specific logic for RTS combat, not SDK kernel code.
##
## Properties:
##   - Position: Vector2 in arena coordinates
##   - Movement: speed, target position, pathfinding
##   - Combat: attack range, attack speed, damage, cooldowns
##   - Status: HP, energy, buffs/debuffs
##   - Visual: procedurally generated pixel sprite (64x64, art spec compliant)

## Pixel sprite generator (procedural 64x64 pixel art)
const PixelSpriteGenerator = preload("res://scripts/game/PixelSpriteGenerator.gd")

## Unit state constants
enum UnitState {
	IDLE,
	MOVING,
	ATTACKING,
	CASTING,
	DEAD
}

## Soul data reference
var soul_id: String = ""
var soul_name: String = ""
var element: String = "neutral"
var level: int = 1

## Personality traits (0-100 scale, influence AI decision-making)
## Design doc: "个性即战术" - personality directly affects battle behavior
var personality: Dictionary = {
	"aggression": 50,      # 激进 vs 谨慎 - higher = more likely to attack
	"courage": 50,         # 勇敢 vs 怯懦 - higher = more likely to engage
	"curiosity": 50,       # 好奇 vs 保守 - higher = more exploration
	"patience": 50,        # 耐心 vs 急躁 - higher = waits for better opportunities
	"loyalty": 50,         # 忠诚 vs 独立 - higher = more likely to follow player commands
	"intelligence": 50     # 智力 - higher = better tactical decisions
}

## Emotional state (influences decision-making and skill effectiveness)
## Design doc: emotion affects skill effects (anger: +20% attack, fear: +20% defense)
var emotion: Dictionary = {
	"mood": "calm",        # calm/excited/fear/anger/sad/happy
	"intensity": 0.0,      # 0-1, how strong the current emotion is
	"anger": 0.0,          # 0-1
	"fear": 0.0,           # 0-1
	"excitement": 0.0,     # 0-1
	"calmness": 1.0        # 0-1
}

## Combat stats
var max_hp: int = 100
var current_hp: int = 100
var max_energy: int = 50
var current_energy: int = 50
var attack_damage: int = 10
var attack_range: float = 100.0
var attack_speed: float = 1.0  # attacks per second
var move_speed: float = 150.0  # pixels per second

## Real-time state
var state: int = UnitState.IDLE
var target_position: Vector2 = Vector2.ZERO
var attack_target: Node2D = null
var attack_cooldown: float = 0.0
var is_player_controlled: bool = false

## Skill cooldowns (skill_name -> remaining seconds)
var skill_cooldowns: Dictionary = {}

## Status effects (effect_name -> remaining seconds)
var status_effects: Dictionary = {}

## Critical hit system
var crit_rate: float = 0.1  # 10% base critical hit chance
var crit_multiplier: float = 1.5  # 150% damage on critical hit
var last_attack_critical: bool = false  # whether the last attack was a critical hit

## Dodge system
var dodge_rate: float = 0.05  # 5% base dodge chance
var last_damage_dodged: bool = false  # whether the last incoming damage was dodged

## Heal tracking
var last_heal_amount: int = 0  # amount of last heal performed

## Defend tracking
var last_defend_used: bool = false  # whether defend skill was just used

## Skill usage tracking
var last_skill_used: String = ""  # name of last skill used

## Damage tracking
var last_damage_taken: int = 0  # amount of last damage taken

## Visual sprite
var _sprite: Node2D = null

## Hit flash effect (white flash when damaged)
var _hit_flash_timer: float = 0.0
var _hit_flash_duration: float = 0.15

## HP bar smooth transition
var _target_hp_ratio: float = 1.0
var _current_hp_ratio: float = 1.0
var _hp_bar_smooth_speed: float = 5.0

## Signal for state changes
signal hp_changed(current_hp, max_hp)
signal energy_changed(current_energy, max_energy)
signal state_changed(new_state)
signal unit_died(unit)
signal attack_performed(target, damage)
signal skill_used(skill_name, target)


func _ready() -> void:
	GameLog.info("SoulUnit: %s initialized (HP:%d, ATK:%d)" % [soul_name, max_hp, attack_damage], "Arena")
	_setup_skill_cooldowns()
	_create_visual()


## Create visual representation (pixel sprite + name label + HP bar)
func _create_visual() -> void:
	# Create pixel sprite using procedural generator
	var generator = PixelSpriteGenerator.new()
	var texture = generator.generate_soul_sprite(element, personality)

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.scale = Vector2(1.5, 1.5)  # Scale up for visibility (64x64 -> 96x96)
	_sprite.centered = true
	add_child(_sprite)

	# Create name label
	var name_label = Label.new()
	name_label.text = soul_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-40, -55)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.modulate = Color(1, 1, 1, 0.9)
	add_child(name_label)

	# Create HP bar background
	var hp_bg = ColorRect.new()
	hp_bg.size = Vector2(50, 5)
	hp_bg.position = Vector2(-25, -48)
	hp_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	add_child(hp_bg)

	# Create HP bar fill
	var hp_fill = ColorRect.new()
	hp_fill.size = Vector2(50, 5)
	hp_fill.position = Vector2(-25, -48)
	hp_fill.color = Color(0.2, 0.8, 0.3, 1.0)
	hp_fill.name = "HPBar"
	add_child(hp_fill)

	# Player indicator
	if is_player_controlled:
		var indicator = Label.new()
		indicator.text = "▼"
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.position = Vector2(-8, -68)
		indicator.add_theme_font_size_override("font_size", 10)
		indicator.modulate = Color(0.4, 0.8, 1.0)
		add_child(indicator)


## Initialize unit from soul data
func init_from_soul(p_soul_id: String, p_soul_name: String, p_element: String, p_level: int, p_is_player: bool = false) -> void:
	soul_id = p_soul_id
	soul_name = p_soul_name
	element = p_element
	level = p_level
	is_player_controlled = p_is_player

	# Scale stats by level
	max_hp = 100 + level * 20
	current_hp = max_hp
	max_energy = 50 + level * 5
	current_energy = max_energy
	attack_damage = 10 + level * 3
	attack_range = 100.0 + level * 2
	move_speed = 150.0 + level * 5

	_setup_skill_cooldowns()
	GameLog.info("SoulUnit: %s initialized from soul data (Lvl %d, HP:%d)" % [soul_name, level, max_hp], "Arena")


## Update HP bar visual
func _update_hp_bar() -> void:
	var hp_bar = get_node_or_null("HPBar")
	if hp_bar:
		var ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		_target_hp_ratio = ratio
		# Color changes based on HP ratio
		if ratio > 0.5:
			hp_bar.color = Color(0.2, 0.8, 0.3, 1.0)
		elif ratio > 0.25:
			hp_bar.color = Color(0.9, 0.7, 0.2, 1.0)
		else:
			hp_bar.color = Color(0.9, 0.3, 0.2, 1.0)


## Smoothly update HP bar width towards target
func _update_hp_bar_smooth(delta: float) -> void:
	var hp_bar = get_node_or_null("HPBar")
	if hp_bar == null:
		return
	# Smoothly interpolate current ratio towards target
	_current_hp_ratio = lerp(_current_hp_ratio, _target_hp_ratio, delta * _hp_bar_smooth_speed)
	hp_bar.size.x = 50.0 * _current_hp_ratio


## Setup initial skill cooldowns
func _setup_skill_cooldowns() -> void:
	skill_cooldowns = {
		"basic_attack": 0.0,
		"heavy_strike": 0.0,
		"quick_strike": 0.0,
		"heal": 0.0,
		"defend": 0.0
	}


## Process real-time updates
func _process(delta: float) -> void:
	if state == UnitState.DEAD:
		return

	_update_cooldowns(delta)
	_update_status_effects(delta)
	_update_energy_regen(delta)
	_update_hit_flash(delta)
	_update_hp_bar_smooth(delta)

	match state:
		UnitState.MOVING:
			_update_movement(delta)
		UnitState.ATTACKING:
			_update_attack(delta)


## Update skill cooldowns
func _update_cooldowns(delta: float) -> void:
	for skill_name in skill_cooldowns.keys():
		if skill_cooldowns[skill_name] > 0:
			skill_cooldowns[skill_name] = max(0.0, skill_cooldowns[skill_name] - delta)


## Update status effects
func _update_status_effects(delta: float) -> void:
	var effects_to_remove: Array = []
	for effect_name in status_effects.keys():
		status_effects[effect_name] -= delta
		if status_effects[effect_name] <= 0:
			effects_to_remove.append(effect_name)
	for effect_name in effects_to_remove:
		status_effects.erase(effect_name)


## Update energy regeneration
func _update_energy_regen(delta: float) -> void:
	if current_energy < max_energy:
		current_energy = min(max_energy, current_energy + delta * 2.0)
		emit_signal("energy_changed", current_energy, max_energy)


## Update hit flash effect (white flash when damaged)
func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer > 0 and _sprite != null:
		_hit_flash_timer -= delta
		if _hit_flash_timer > 0:
			# Fade from overexposed white back to normal
			var progress = 1.0 - (_hit_flash_timer / _hit_flash_duration)
			var white_amount = 1.0 - progress
			# Overexpose to simulate white flash (values > 1.0 brighten)
			_sprite.modulate = Color(1.0 + white_amount * 0.8, 1.0 + white_amount * 0.8, 1.0 + white_amount * 0.8)
		else:
			_sprite.modulate = Color(1.0, 1.0, 1.0)
			_hit_flash_timer = 0.0


## Update movement toward target position
func _update_movement(delta: float) -> void:
	var direction: Vector2 = target_position - position
	var distance: float = direction.length()

	if distance < 5.0:
		state = UnitState.IDLE
		emit_signal("state_changed", state)
		return

	# Apply terrain speed modifier
	var speed_modifier: float = 1.0
	if ArenaMap and ArenaMap.has_method("get_terrain_speed_modifier"):
		speed_modifier = ArenaMap.get_terrain_speed_modifier(position)

	var actual_speed: float = move_speed * speed_modifier
	var move_amount: float = actual_speed * delta

	if move_amount >= distance:
		# Check if target position is valid
		if _is_position_valid(target_position):
			position = target_position
		state = UnitState.IDLE
		emit_signal("state_changed", state)
	else:
		var new_position: Vector2 = position + direction.normalized() * move_amount
		# Check obstacle collision, slide along obstacle if blocked
		if _is_position_valid(new_position):
			position = new_position
		else:
			# Try sliding along X or Y axis
			var slide_x: Vector2 = Vector2(new_position.x, position.y)
			var slide_y: Vector2 = Vector2(position.x, new_position.y)
			if _is_position_valid(slide_x):
				position = slide_x
			elif _is_position_valid(slide_y):
				position = slide_y
			else:
				# Blocked completely, try to navigate around obstacle
				# Try moving perpendicular to target direction (up or down)
				var perp_up: Vector2 = position + Vector2(0, -move_amount)
				var perp_down: Vector2 = position + Vector2(0, move_amount)
				var perp_left: Vector2 = position + Vector2(-move_amount, 0)
				var perp_right: Vector2 = position + Vector2(move_amount, 0)
				
				# Prefer direction that moves closer to target while avoiding obstacle
				var best_pos: Vector2 = position
				var best_dist: float = distance
				
				for test_pos in [perp_up, perp_down, perp_left, perp_right]:
					if _is_position_valid(test_pos):
						var test_dist: float = test_pos.distance_to(target_position)
						if test_dist < best_dist:
							best_dist = test_dist
							best_pos = test_pos
				
				if best_pos != position:
					position = best_pos
				else:
					# Truly stuck, stop moving
					state = UnitState.IDLE
					emit_signal("state_changed", state)


## Check if position is valid (not colliding with obstacles or out of bounds)
func _is_position_valid(p_position: Vector2) -> bool:
	if ArenaMap and ArenaMap.has_method("is_position_valid"):
		return ArenaMap.is_position_valid(p_position, 32.0)
	return true


## Update attack behavior
func _update_attack(delta: float) -> void:
	if attack_target == null or not is_instance_valid(attack_target):
		state = UnitState.IDLE
		emit_signal("state_changed", state)
		return

	var distance: float = position.distance_to(attack_target.position)

	# Move into range if too far
	if distance > attack_range:
		target_position = attack_target.position
		_update_movement(delta)
		return

	# Attack if cooldown ready
	if attack_cooldown <= 0:
		_perform_basic_attack()


## Move to a position
func move_to(p_position: Vector2) -> void:
	if state == UnitState.DEAD:
		return
	target_position = p_position
	state = UnitState.MOVING
	attack_target = null
	emit_signal("state_changed", state)


## Set attack target
func set_attack_target(p_target: Node2D) -> void:
	if state == UnitState.DEAD:
		return
	attack_target = p_target
	state = UnitState.ATTACKING
	emit_signal("state_changed", state)


## Perform basic attack
func _perform_basic_attack() -> void:
	if attack_target == null or not is_instance_valid(attack_target):
		return

	var damage: int = _calculate_damage(attack_damage, 1.0)
	attack_target.take_damage(damage, self)
	attack_cooldown = 1.0 / attack_speed
	emit_signal("attack_performed", attack_target, damage)
	# Play attack sound
	if AudioManager:
		AudioManager.play_sfx("soul_unit_attack", 0.6)

	GameLog.debug("SoulUnit: %s attacks %s for %d damage" % [soul_name, attack_target.soul_name, damage], "Arena")


## Calculate damage with element advantage and critical hit
func _calculate_damage(p_base_damage: int, p_multiplier: float) -> int:
	var element_mult: float = 1.0
	if attack_target != null and attack_target.has_method("get_element"):
		element_mult = _get_element_multiplier(element, attack_target.get_element())

	# Critical hit calculation
	last_attack_critical = randf() < crit_rate
	var crit_mult: float = 1.0
	if last_attack_critical:
		crit_mult = crit_multiplier

	var final_damage: int = int(p_base_damage * p_multiplier * element_mult * crit_mult)
	return max(1, final_damage)


## Get element advantage multiplier
func _get_element_multiplier(p_attacker_element: String, p_defender_element: String) -> float:
	var advantages: Dictionary = {
		"fire": {"wood": 1.5, "ice": 1.5, "wind": 0.75},
		"water": {"fire": 1.5, "earth": 0.75, "electric": 1.5},
		"earth": {"water": 1.5, "electric": 0.75, "fire": 0.75},
		"wind": {"earth": 1.5, "fire": 1.5, "water": 0.75},
		"light": {"dark": 1.5, "water": 0.75},
		"dark": {"light": 0.75, "earth": 1.5},
		"neutral": {}
	}
	if advantages.has(p_attacker_element) and advantages[p_attacker_element].has(p_defender_element):
		return advantages[p_attacker_element][p_defender_element]
	return 1.0


## Use a skill
func use_skill(p_skill_name: String, p_target: Node2D = null) -> bool:
	if state == UnitState.DEAD:
		return false

	if not skill_cooldowns.has(p_skill_name):
		return false

	if skill_cooldowns[p_skill_name] > 0:
		GameLog.debug("SoulUnit: %s skill %s on cooldown (%.1fs)" % [soul_name, p_skill_name, skill_cooldowns[p_skill_name]], "Arena")
		return false

	var energy_cost: int = _get_skill_energy_cost(p_skill_name)
	if current_energy < energy_cost:
		GameLog.debug("SoulUnit: %s not enough energy for %s" % [soul_name, p_skill_name], "Arena")
		return false

	current_energy -= energy_cost
	emit_signal("energy_changed", current_energy, max_energy)
	# Play skill cast sound
	if AudioManager:
		AudioManager.play_sfx("soul_unit_skill", 0.7)

	match p_skill_name:
		"heavy_strike":
			if p_target != null:
				var damage: int = _calculate_damage(attack_damage, 1.5)
				p_target.take_damage(damage, self)
				last_skill_used = "heavy_strike"
				skill_cooldowns[p_skill_name] = 5.0
				emit_signal("skill_used", p_skill_name, p_target)
				return true
		"quick_strike":
			if p_target != null:
				var damage: int = _calculate_damage(attack_damage, 0.7)
				p_target.take_damage(damage, self)
				last_skill_used = "quick_strike"
				skill_cooldowns[p_skill_name] = 2.0
				emit_signal("skill_used", p_skill_name, p_target)
				return true
		"heal":
			var heal_amount: int = 15 + level * 2
			last_heal_amount = heal_amount
			current_hp = min(max_hp, current_hp + heal_amount)
			emit_signal("hp_changed", current_hp, max_hp)
			last_skill_used = "heal"
			skill_cooldowns[p_skill_name] = 8.0
			emit_signal("skill_used", p_skill_name, self)
			return true
		"defend":
			status_effects["defense_up"] = 3.0
			last_defend_used = true
			last_skill_used = "defend"
			skill_cooldowns[p_skill_name] = 6.0
			emit_signal("skill_used", p_skill_name, self)
			return true

	return false


## Get skill energy cost
func _get_skill_energy_cost(p_skill_name: String) -> int:
	match p_skill_name:
		"basic_attack": return 0
		"heavy_strike": return 15
		"quick_strike": return 3
		"heal": return 10
		"defend": return 2
	return 5


## Take damage
func take_damage(p_damage: int, p_attacker: Node2D = null) -> void:
	if state == UnitState.DEAD:
		return

	# Dodge check
	last_damage_dodged = randf() < dodge_rate
	if last_damage_dodged:
		GameLog.debug("SoulUnit: %s dodged the attack!" % soul_name, "Arena")
		return

	# Apply defense buff
	var actual_damage: int = p_damage
	if status_effects.has("defense_up"):
		actual_damage = int(p_damage * 0.5)

	last_damage_taken = actual_damage
	current_hp -= actual_damage
	emit_signal("hp_changed", current_hp, max_hp)
	_update_hp_bar()
	# Trigger hit flash effect
	_hit_flash_timer = _hit_flash_duration

	# Play hit sound effect
	if AudioManager:
		AudioManager.play_sfx("soul_unit_hurt", 0.8)

	GameLog.debug("SoulUnit: %s takes %d damage (HP: %d/%d)" % [soul_name, actual_damage, current_hp, max_hp], "Arena")

	if current_hp <= 0:
		current_hp = 0
		state = UnitState.DEAD
		emit_signal("state_changed", state)
		emit_signal("unit_died", self)
		# Play death sound effect
		if AudioManager:
			AudioManager.play_sfx("soul_unit_death", 1.0)
		GameLog.info("SoulUnit: %s has been defeated!" % soul_name, "Arena")


## Get element (for damage calculation)
func get_element() -> String:
	return element


## Stop all actions
func stop() -> void:
	state = UnitState.IDLE
	attack_target = null
	emit_signal("state_changed", state)


## Get unit info as dictionary
func get_info() -> Dictionary:
	return {
		"id": soul_id,
		"name": soul_name,
		"element": element,
		"level": level,
		"hp": current_hp,
		"max_hp": max_hp,
		"energy": current_energy,
		"max_energy": max_energy,
		"state": state,
		"position": position,
		"attack_range": attack_range,
		"is_alive": state != UnitState.DEAD
	}
