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

## Write debug log to file (user://debug_unit.log)
static func _dlog(msg: String) -> void:
	var f = FileAccess.open("user://debug_unit.log", FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(Time.get_datetime_string_from_system() + " " + msg)
		f.close()

## Pixel sprite generator (procedural 64x64 pixel art)
const PixelSpriteGenerator = preload("res://scripts/game/PixelSpriteGenerator.gd")

## Ember soul data bridge (SDK integration - architecture compliant)
const EmberSoulDataBridge = preload("res://scripts/game/EmberSoulDataBridge.gd")

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

## Ember SDK soul data bridge (manages personality/emotion via Ember SDK)
var _ember_bridge: EmberSoulDataBridge = null

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

## A* pathfinding
var _path: Array = []  # Array of Vector2 waypoints
var _path_index: int = 0
var _pathfinder: RefCounted = null
var _grid_map: RefCounted = null
var _use_pathfinding: bool = true

## Hit flash effect (white flash when damaged)
var _hit_flash_timer: float = 0.0
var _hit_flash_duration: float = 0.2
var _hit_flash_sprite = null  # White flash overlay sprite
var _selection_ring_sprite = null  # Gold selection ring for player unit
var _selection_pulse_time: float = 0.0

## Animation system
var _anim_time: float = 0.0  # Animation time accumulator
var _base_scale: Vector2 = Vector2(0.4, 0.4)  # Base sprite scale
var _attack_pulse_timer: float = 0.0  # Attack pulse effect timer
var _attack_pulse_duration: float = 0.15  # Attack pulse duration
var _hit_shake_timer: float = 0.0  # Hit shake timer
var _hit_shake_duration: float = 0.15  # Hit shake duration
var _sprite_base_position: Vector2 = Vector2.ZERO  # Base sprite position (for shake offset)

# Death animation (using extended sprite sheet)
var _death_anim_active: bool = false
var _death_anim_timer: float = 0.0
var _death_anim_duration: float = 1.2
var _death_explosion_sprite: Sprite2D = null
var _death_soul_sprite: Sprite2D = null
var _extended_sheet_loaded: bool = false
var _extended_sheet: Texture2D = null

# Victory animation (using extended sprite sheet row 1)
var _victory_anim_active: bool = false
var _victory_anim_timer: float = 0.0
var _victory_anim_duration: float = 2.0
var _victory_sprite: Sprite2D = null
var _victory_ring_sprite: Sprite2D = null

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
	# Visual creation moved to init_from_soul() to ensure element/is_player are set first
	# If visual not yet created (e.g. unit added without init_from_soul), create now
	if _sprite == null:
		GameLog.warning("SoulUnit: _ready() creating visual without init_from_soul (element=%s, player=%s)" % [element, is_player_controlled], "Unit")
		_create_visual()


## Create visual representation (pixel sprite + name label + HP bar)
## Load soul unit sprite from design asset sheet
## Prefers element-specific sprite sheet (player or AI variant), falls back to 2-row sheet
## Player sheet: 3 rows x 4 cols, cell 480x270 (fire/water/earth+wind)
## AI sheet: 4 rows x 6 cols, cell 320x270 (fire/water/earth/wind, col 0-2 idle frames)
## New element sheets: new_soul_unit_{element}_sprite_sheet.png (8 frames: idle4+move2+attack1+hit1)
## Returns AtlasTexture for idle frame, or null if load fails
func _load_design_sprite() -> Texture2D:
	# Normalize element name (handle Chinese -> English mapping)
	var normalized_element := element.to_lower()
	_dlog("[DEBUG-SPRITE] element='" + element + "' normalized='" + normalized_element + "' player=" + str(is_player_controlled))
	var element_map := {
		"火": "fire", "水": "water", "土": "earth", "风": "wind",
		"雷": "thunder", "光": "light", "暗": "dark", "冰": "ice",
		"neutral": "water",  # Default player element
	}
	if element_map.has(normalized_element):
		normalized_element = element_map[normalized_element]
	_dlog("[DEBUG-SPRITE] after map normalized='" + normalized_element + "'")

	# Try new element-specific sprite sheet first (8-frame animation sheets)
	var new_sheet_path := "res://assets/art/new_soul_unit_%s_sprite_sheet.png" % normalized_element
	_dlog("[DEBUG-SPRITE] new_sheet_path=" + new_sheet_path + " exists=" + str(ResourceLoader.exists(new_sheet_path)))
	if ResourceLoader.exists(new_sheet_path):
		var new_sheet = load(new_sheet_path)
		if new_sheet != null and new_sheet is Texture2D:
			# New sheets: 2048x256, 8 frames x 256x256, first frame is idle
			var atlas = AtlasTexture.new()
			atlas.atlas = new_sheet
			atlas.region = Rect2(0, 0, 256, 256)
			_dlog("[DEBUG-SPRITE] SUCCESS: new element sprite")
			GameLog.debug("SoulUnit: Loaded new element sprite (element=%s)" % normalized_element, "Unit")
			return atlas

	# AI units: try AI-specific element sprite sheet first (darker/redder style)
	if not is_player_controlled:
		var ai_sheet_path := "res://assets/art/ai_soul_unit_element_sprite_sheet.png"
		_dlog("[DEBUG-SPRITE] ai_sheet_path=" + ai_sheet_path + " exists=" + str(ResourceLoader.exists(ai_sheet_path)))
		if ResourceLoader.exists(ai_sheet_path):
			var ai_sheet = load(ai_sheet_path)
			if ai_sheet != null and ai_sheet is Texture2D:
				# AI sheet: 1920x1080, 4 rows x 6 cols, each cell 320x270
				var cell_w: int = 320
				var cell_h: int = 270
				var row: int = 0
				match normalized_element:
					"fire":
						row = 0
					"water":
						row = 1
					"earth":
						row = 2
					"wind":
						row = 3
					_:
						row = 0  # Default AI: fire (red)
				var atlas = AtlasTexture.new()
				atlas.atlas = ai_sheet
				atlas.region = Rect2(0, row * cell_h, cell_w, cell_h)
				_dlog("[DEBUG-SPRITE] SUCCESS: AI element sprite row=" + str(row))
				GameLog.debug("SoulUnit: Loaded AI element sprite (element=%s, row=%d)" % [normalized_element, row], "Unit")
				return atlas
	# Player units (or AI fallback): try 4-element sprite sheet
	var element_sheet_path := "res://assets/art/soul_unit_element_sprite_sheet.png"
	_dlog("[DEBUG-SPRITE] element_sheet_path=" + element_sheet_path + " exists=" + str(ResourceLoader.exists(element_sheet_path)))
	if ResourceLoader.exists(element_sheet_path):
		var sheet = load(element_sheet_path)
		if sheet != null and sheet is Texture2D:
			# Element sheet: 1920x1080, 3 rows x 4 cols, each cell 480x270
			var cell_w: int = 480
			var cell_h: int = 270
			var row: int = 0
			var col: int = 0
			match normalized_element:
				"fire":
					row = 0
					col = 0
				"water":
					row = 1
					col = 0
				"earth":
					row = 2
					col = 0
				"wind":
					row = 2
					col = 1
				_:
					# Default: player=water(blue), AI=fire(red)
					row = 1 if is_player_controlled else 0
					col = 0
			var atlas = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
			_dlog("[DEBUG-SPRITE] SUCCESS: element sprite row=" + str(row) + " col=" + str(col))
			GameLog.debug("SoulUnit: Loaded element sprite (element=%s, row=%d, col=%d)" % [normalized_element, row, col], "Unit")
			return atlas
	# Fallback to original 2-row sprite sheet
	var sheet_path := "res://assets/art/soul_unit_sprite_sheet.png"
	_dlog("[DEBUG-SPRITE] fallback sheet_path=" + sheet_path + " exists=" + str(ResourceLoader.exists(sheet_path)))
	if not ResourceLoader.exists(sheet_path):
		_dlog("[DEBUG-SPRITE] FAILED: all sheets not found, returning null")
		GameLog.warning("SoulUnit: All design sprite sheets not found, using procedural (element=%s)" % element, "Unit")
		return null
	var sheet = load(sheet_path)
	if sheet == null or not (sheet is Texture2D):
		_dlog("[DEBUG-SPRITE] FAILED: failed to load sheet, returning null")
		GameLog.warning("SoulUnit: Failed to load design sprite sheet", "Unit")
		return null
	# Sprite sheet: 1920x1080, 2 rows x 4 cols, each cell ~480x270
	var cell_w: int = 480
	var cell_h: int = 270
	var row: int = 0 if is_player_controlled else 1
	var atlas = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, row * cell_h, cell_w, cell_h)
	GameLog.debug("SoulUnit: Loaded design sprite (row=%d, %dx%d)" % [row, cell_w, cell_h], "Unit")
	return atlas


func _create_visual() -> void:
	# Prevent duplicate visual creation
	if _sprite != null:
		GameLog.debug("SoulUnit: Visual already exists, skipping", "Unit")
		return

	# Try to use design asset sprite sheet first, fallback to procedural generator
	var sprite_texture = _load_design_sprite()
	var used_procedural := false
	if sprite_texture == null:
		var generator = PixelSpriteGenerator.new()
		sprite_texture = generator.generate_soul_sprite(element, personality)
		used_procedural = true
		GameLog.warning("SoulUnit: %s using PROCEDURAL sprite (element=%s, player=%s) - design sprite load failed" % [soul_name, element, is_player_controlled], "Unit")
	else:
		GameLog.info("SoulUnit: %s using DESIGN sprite (element=%s, player=%s)" % [soul_name, element, is_player_controlled], "Unit")

	_sprite = Sprite2D.new()
	_sprite.texture = sprite_texture
	_sprite.scale = Vector2(0.6, 0.6)  # Larger scale for better visibility
	_sprite.centered = true
	add_child(_sprite)
	_sprite_base_position = _sprite.position
	var tex_size = sprite_texture.get_size() if sprite_texture else Vector2.ZERO
	_dlog("[DEBUG-SPRITE] Sprite created! used_procedural=" + str(used_procedural) + " texture=" + str(sprite_texture) + " size=" + str(tex_size) + " scale=" + str(_sprite.scale) + " global_pos=" + str(_sprite.global_position))

	# Create hit flash overlay (white circle that expands and fades on damage)
	_hit_flash_sprite = Sprite2D.new()
	_hit_flash_sprite.name = "HitFlash"
	_hit_flash_sprite.centered = true
	_hit_flash_sprite.scale = Vector2(0.5, 0.5)
	_hit_flash_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hit_flash_sprite.z_index = 10
	# Create a simple white circle texture for flash
	var flash_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	flash_image.fill(Color(0, 0, 0, 0))
	for x in range(64):
		for y in range(64):
			var dx = x - 32
			var dy = y - 32
			var dist = sqrt(dx * dx + dy * dy)
			if dist < 28:
				var alpha = 1.0 - (dist / 28.0)
				flash_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var flash_texture = ImageTexture.create_from_image(flash_image)
	_hit_flash_sprite.texture = flash_texture
	add_child(_hit_flash_sprite)

	# Create selection ring for player unit (gold breathing pulse)
	if is_player_controlled:
		_selection_ring_sprite = Sprite2D.new()
		_selection_ring_sprite.name = "SelectionRing"
		_selection_ring_sprite.centered = true
		_selection_ring_sprite.scale = Vector2(1.2, 1.2)
		_selection_ring_sprite.modulate = Color(1.0, 0.85, 0.3, 0.7)
		_selection_ring_sprite.z_index = -1
		# Create gold ring texture (128x128, thick ring with gradient)
		var ring_image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		ring_image.fill(Color(0, 0, 0, 0))
		for x in range(128):
			for y in range(128):
				var dx = x - 64
				var dy = y - 64
				var dist = sqrt(dx * dx + dy * dy)
				# Ring: outer radius 58, inner radius 48, gradient edge
				if dist < 58 and dist > 48:
					var edge_dist = min(dist - 48, 58 - dist)
					var alpha = clamp(edge_dist / 5.0, 0.0, 1.0)
					ring_image.set_pixel(x, y, Color(1.0, 0.85, 0.3, alpha * 0.8))
				elif dist <= 48 and dist > 46:
					# Inner glow
					var alpha = (48 - dist) / 2.0
					ring_image.set_pixel(x, y, Color(1.0, 0.9, 0.5, alpha * 0.3))
		var ring_texture = ImageTexture.create_from_image(ring_image)
		_selection_ring_sprite.texture = ring_texture
		add_child(_selection_ring_sprite)

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

	# Initialize Ember SDK soul data bridge (architecture compliant)
	_ember_bridge = EmberSoulDataBridge.new()
	_ember_bridge.init_from_soul_data(p_soul_id, p_soul_name, p_level, p_element, personality)
	# Sync personality/emotion dictionaries to bridge (so existing code works unchanged)
	personality = _ember_bridge.personality
	emotion = _ember_bridge.emotion

	_setup_skill_cooldowns()
	GameLog.info("SoulUnit: %s initialized from soul data (Lvl %d, HP:%d, Ember:%s)" % [
		soul_name, level, max_hp, _ember_bridge.is_ember_available()
	], "Arena")
	# Create visual AFTER element/is_player are set
	_create_visual()


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
	_update_animation(delta)
	_update_selection_ring(delta)

	match state:
		UnitState.IDLE:
			# If has attack target, resume attacking
			if attack_target != null and is_instance_valid(attack_target):
				state = UnitState.ATTACKING
		UnitState.MOVING:
			_update_movement(delta)
		UnitState.ATTACKING:
			_update_attack(delta)


## Update skill cooldowns
func _update_cooldowns(delta: float) -> void:
	# Decrement basic attack cooldown
	if attack_cooldown > 0:
		attack_cooldown = max(0.0, attack_cooldown - delta)
	# Decrement skill cooldowns
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


## Update hit flash effect (white expanding flash when damaged)
func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer > 0 and _hit_flash_sprite != null:
		_hit_flash_timer -= delta
		if _hit_flash_timer > 0:
			# Animate: expand from 0.5x to 1.5x, fade from opaque to transparent
			var progress = 1.0 - (_hit_flash_timer / _hit_flash_duration)
			var scale_amount = 0.5 + progress * 1.2
			_hit_flash_sprite.scale = Vector2(scale_amount, scale_amount)
			_hit_flash_sprite.modulate.a = 1.0 - progress
		else:
			_hit_flash_sprite.modulate.a = 0.0
			_hit_flash_sprite.scale = Vector2(0.5, 0.5)
			_hit_flash_timer = 0.0


## Update sprite animation: idle breathing, movement bob, attack pulse, hit shake
func _update_animation(delta: float) -> void:
	if _sprite == null:
		return
	_anim_time += delta

	# Idle breathing animation: subtle scale pulse (±5%)
	var breath_scale: float = 1.0 + sin(_anim_time * 2.5) * 0.05
	var current_scale: Vector2 = _base_scale * breath_scale

	# Movement bob: vertical position offset when moving
	var bob_offset: float = 0.0
	if state == UnitState.MOVING:
		bob_offset = sin(_anim_time * 8.0) * 3.0

	# Attack pulse: scale up briefly when attacking
	if _attack_pulse_timer > 0:
		_attack_pulse_timer -= delta
		var pulse_progress: float = 1.0 - (_attack_pulse_timer / _attack_pulse_duration)
		var pulse_amount: float = sin(pulse_progress * PI) * 0.15
		current_scale *= (1.0 + pulse_amount)

	# Hit shake: random position offset when hit
	var shake_offset: Vector2 = Vector2.ZERO
	if _hit_shake_timer > 0:
		_hit_shake_timer -= delta
		var shake_intensity: float = (_hit_shake_timer / _hit_shake_duration) * 4.0
		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

	# Apply transforms
	_sprite.scale = current_scale
	_sprite.position = _sprite_base_position + Vector2(0, bob_offset) + shake_offset
	# Update death animation (runs even when main sprite hidden)
	_update_death_animation(delta)
	# Update victory animation
	_update_victory_animation(delta)


## Update selection ring breathing pulse animation (player unit only)
func _update_selection_ring(delta: float) -> void:
	if _selection_ring_sprite == null:
		return
	_selection_pulse_time += delta
	# Breathing pulse: scale 1.0-1.3, 2Hz sine wave
	var pulse = sin(_selection_pulse_time * 2.0 * PI) * 0.15 + 1.15
	_selection_ring_sprite.scale = Vector2(pulse, pulse)
	# Subtle opacity variation
	var alpha = 0.5 + sin(_selection_pulse_time * 2.0 * PI + 0.5) * 0.2
	_selection_ring_sprite.modulate.a = alpha
	# Hide ring when dead
	if state == UnitState.DEAD:
		_selection_ring_sprite.visible = false


## Trigger attack pulse animation
func trigger_attack_pulse() -> void:
	_attack_pulse_timer = _attack_pulse_duration


## Trigger hit shake animation
func trigger_hit_shake() -> void:
	_hit_shake_timer = _hit_shake_duration


## Load extended sprite sheet and crop a frame (3 rows x 4 cols, cell 480x270)
func _get_extended_frame(p_col: int, p_row: int) -> Texture2D:
	if not _extended_sheet_loaded:
		var sheet_path := "res://assets/art/soul_unit_extended_sprite_sheet.png"
		if ResourceLoader.exists(sheet_path):
			_extended_sheet = load(sheet_path)
			_extended_sheet_loaded = true
		else:
			return null
	if _extended_sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = _extended_sheet
	atlas.region = Rect2(p_col * 480, p_row * 270, 480, 270)
	return atlas


## Trigger death animation (explosion + soul rising)
func trigger_death_animation() -> void:
	if _death_anim_active:
		return
	_death_anim_active = true
	_death_anim_timer = _death_anim_duration
	# Hide main sprite
	if _sprite:
		_sprite.visible = false
	# Create explosion sprite (row 0, col 2 - explosion frame)
	var explosion_tex = _get_extended_frame(2, 0)
	if explosion_tex:
		_death_explosion_sprite = Sprite2D.new()
		_death_explosion_sprite.name = "DeathExplosion"
		_death_explosion_sprite.centered = true
		_death_explosion_sprite.position = _sprite_base_position
		_death_explosion_sprite.texture = explosion_tex
		_death_explosion_sprite.scale = Vector2(0.3, 0.3)
		_death_explosion_sprite.z_index = 20
		# Tint by element
		var tint = Color(1, 1, 1, 1)
		match element:
			"fire": tint = Color(1.2, 0.7, 0.5, 1)
			"water": tint = Color(0.5, 0.8, 1.2, 1)
			"earth": tint = Color(0.9, 0.7, 0.5, 1)
			"wind": tint = Color(0.7, 1.0, 0.8, 1)
		_death_explosion_sprite.modulate = tint
		add_child(_death_explosion_sprite)
	# Create soul rising sprite (row 0, col 3 - soul dissipate frame)
	var soul_tex = _get_extended_frame(3, 0)
	if soul_tex:
		_death_soul_sprite = Sprite2D.new()
		_death_soul_sprite.name = "DeathSoul"
		_death_soul_sprite.centered = true
		_death_soul_sprite.position = _sprite_base_position
		_death_soul_sprite.texture = soul_tex
		_death_soul_sprite.scale = Vector2(0.25, 0.25)
		_death_soul_sprite.z_index = 21
		_death_soul_sprite.modulate = Color(1.0, 0.9, 0.6, 0.9)
		add_child(_death_soul_sprite)


## Update death animation
func _update_death_animation(delta: float) -> void:
	if not _death_anim_active:
		return
	_death_anim_timer -= delta
	var progress = 1.0 - (_death_anim_timer / _death_anim_duration)
	# Explosion: scale up and fade out (first 0.5s)
	if _death_explosion_sprite and is_instance_valid(_death_explosion_sprite):
		if progress < 0.5:
			var exp_progress = progress / 0.5
			_death_explosion_sprite.scale = Vector2(0.3 + exp_progress * 0.8, 0.3 + exp_progress * 0.8)
			_death_explosion_sprite.modulate.a = 1.0 - exp_progress * 0.8
		else:
			_death_explosion_sprite.modulate.a = 0.0
	# Soul: rise up and fade out (0.3s to 1.2s)
	if _death_soul_sprite and is_instance_valid(_death_soul_sprite):
		if progress > 0.2:
			var soul_progress = (progress - 0.2) / 0.8
			_death_soul_sprite.position.y = _sprite_base_position.y - soul_progress * 80.0
			_death_soul_sprite.modulate.a = 0.9 * (1.0 - soul_progress)
			_death_soul_sprite.scale = Vector2(0.25 + soul_progress * 0.15, 0.25 + soul_progress * 0.15)
	# Cleanup when done
	if _death_anim_timer <= 0:
		if _death_explosion_sprite and is_instance_valid(_death_explosion_sprite):
			_death_explosion_sprite.queue_free()
			_death_explosion_sprite = null
		if _death_soul_sprite and is_instance_valid(_death_soul_sprite):
			_death_soul_sprite.queue_free()
			_death_soul_sprite = null
		_death_anim_active = false


## Trigger victory animation (celebration with golden glow)
func trigger_victory_animation() -> void:
	if _victory_anim_active or _death_anim_active:
		return
	_victory_anim_active = true
	_victory_anim_timer = _victory_anim_duration
	# Create victory celebration sprite (row 1, col 1 - golden celebration)
	var victory_tex = _get_extended_frame(1, 1)
	if victory_tex:
		_victory_sprite = Sprite2D.new()
		_victory_sprite.name = "VictoryCelebration"
		_victory_sprite.centered = true
		_victory_sprite.position = _sprite_base_position
		_victory_sprite.texture = victory_tex
		_victory_sprite.scale = Vector2(0.35, 0.35)
		_victory_sprite.z_index = 25
		_victory_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(_victory_sprite)
	# Create golden ring effect (row 1, col 2 - colorful spiral, tinted gold)
	var ring_tex = _get_extended_frame(2, 1)
	if ring_tex:
		_victory_ring_sprite = Sprite2D.new()
		_victory_ring_sprite.name = "VictoryRing"
		_victory_ring_sprite.centered = true
		_victory_ring_sprite.position = _sprite_base_position
		_victory_ring_sprite.texture = ring_tex
		_victory_ring_sprite.scale = Vector2(0.3, 0.3)
		_victory_ring_sprite.z_index = 24
		_victory_ring_sprite.modulate = Color(1.0, 0.9, 0.5, 0.0)
		add_child(_victory_ring_sprite)


## Update victory animation
func _update_victory_animation(delta: float) -> void:
	if not _victory_anim_active:
		return
	_victory_anim_timer -= delta
	var progress = 1.0 - (_victory_anim_timer / _victory_anim_duration)
	# Victory celebration sprite: fade in, bounce scale, fade out
	if _victory_sprite and is_instance_valid(_victory_sprite):
		if progress < 0.2:
			# Fade in
			_victory_sprite.modulate.a = progress / 0.2
			_victory_sprite.scale = Vector2(0.35, 0.35) * (0.5 + progress / 0.2 * 0.5)
		elif progress < 0.8:
			# Bounce celebration
			_victory_sprite.modulate.a = 1.0
			var bounce = 1.0 + sin(progress * 15.0) * 0.1
			_victory_sprite.scale = Vector2(0.35, 0.35) * bounce
			_victory_sprite.position.y = _sprite_base_position.y - abs(sin(progress * 10.0)) * 15.0
		else:
			# Fade out
			var fade = 1.0 - (progress - 0.8) / 0.2
			_victory_sprite.modulate.a = fade
	# Golden ring: expand and rotate, fade in/out
	if _victory_ring_sprite and is_instance_valid(_victory_ring_sprite):
		if progress < 0.3:
			_victory_ring_sprite.modulate.a = progress / 0.3
		else:
			_victory_ring_sprite.modulate.a = max(0.0, 1.0 - (progress - 0.3) / 0.7)
		_victory_ring_sprite.scale = Vector2(0.3 + progress * 0.6, 0.3 + progress * 0.6)
		_victory_ring_sprite.rotation = progress * TAU * 2.0
	# Cleanup when done
	if _victory_anim_timer <= 0:
		if _victory_sprite and is_instance_valid(_victory_sprite):
			_victory_sprite.queue_free()
			_victory_sprite = null
		if _victory_ring_sprite and is_instance_valid(_victory_ring_sprite):
			_victory_ring_sprite.queue_free()
			_victory_ring_sprite = null
		_victory_anim_active = false


## Update movement toward target position
func _update_movement(delta: float) -> void:
	var direction: Vector2 = target_position - position
	var distance: float = direction.length()

	if distance < 5.0:
		# If following a path, move to next waypoint
		if _path.size() > 0 and _path_index < _path.size() - 1:
			_path_index += 1
			target_position = _path[_path_index]
			GameLog.debug("Unit: %s path waypoint %d/%d, target=(%.0f,%.0f)" % [
				soul_name, _path_index + 1, _path.size(), target_position.x, target_position.y
			], "Arena")
			return
		# Reached final target
		_path.clear()
		_path_index = 0
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
				# Blocked completely, navigate around obstacle with larger steps
				GameLog.debug("Unit: %s BLOCKED at (%.0f,%.0f) target=(%.0f,%.0f) dist=%.1f, navigating around" % [
					soul_name, position.x, position.y, target_position.x, target_position.y, distance
				], "Arena")
				# Use larger navigation step (20x normal) to quickly get around obstacle
				var nav_step: float = move_amount * 20.0
				var perp_up: Vector2 = position + Vector2(0, -nav_step)
				var perp_down: Vector2 = position + Vector2(0, nav_step)
				var perp_left: Vector2 = position + Vector2(-nav_step, 0)
				var perp_right: Vector2 = position + Vector2(nav_step, 0)
				
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
					# Set temporary navigation target to keep moving around obstacle
					GameLog.debug("Unit: %s NAVIGATE to (%.0f,%.0f) (was at %.0f,%.0f)" % [
						soul_name, best_pos.x, best_pos.y, position.x, position.y
					], "Arena")
					target_position = best_pos
					position = best_pos
				else:
					# Truly stuck, stop moving
					GameLog.warning("Unit: %s STUCK at (%.0f,%.0f) target=(%.0f,%.0f), all directions blocked" % [
						soul_name, position.x, position.y, target_position.x, target_position.y
					], "Arena")
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

	# Move into range if too far (use pathfinding to avoid obstacles)
	if distance > attack_range:
		# Only recalculate path if not already moving along one
		if _path.is_empty() or _path_index >= _path.size() - 1:
			move_to(attack_target.position, false)  # Keep attack_target while moving
		elif state == UnitState.ATTACKING:
			state = UnitState.MOVING  # Let MOVING state handle path following
		return

	# Attack if cooldown ready
	if attack_cooldown <= 0:
		_perform_basic_attack()


## Move to a position
## p_clear_attack_target: if true, clears attack_target when moving (default)
## Set to false when moving to attack target so auto-attack resumes after reaching range
func move_to(p_position: Vector2, p_clear_attack_target: bool = true) -> void:
	if state == UnitState.DEAD:
		return
	GameLog.debug("Unit: %s move_to target=(%.0f,%.0f) from=(%.0f,%.0f) dist=%.1f" % [
		soul_name, p_position.x, p_position.y, position.x, position.y, position.distance_to(p_position)
	], "Arena")

	# Use pathfinding if available
	if _use_pathfinding and _pathfinder != null:
		# SDKPathfinder: find_path(start_x, start_y, goal_x, goal_y) - no grid param
		if _pathfinder.has_method("find_path") and _pathfinder.get_method_argument_count("find_path") == 4:
			_path = _pathfinder.find_path(position.x, position.y, p_position.x, p_position.y)
		# Legacy AStarPathfinder: find_path(start_x, start_y, goal_x, goal_y, grid)
		elif _grid_map != null:
			_path = _pathfinder.find_path(position.x, position.y, p_position.x, p_position.y, _grid_map)
		else:
			_path = []

		_path_index = 0
		if _path.size() > 0:
			GameLog.debug("Unit: %s path found: %d waypoints, first=(%.0f,%.0f)" % [
				soul_name, _path.size(), _path[0].x, _path[0].y
			], "Arena")
			target_position = _path[0]
		else:
			GameLog.warning("Unit: %s path not found, using direct movement" % soul_name, "Arena")
			target_position = p_position
	else:
		target_position = p_position

	state = UnitState.MOVING
	if p_clear_attack_target:
		attack_target = null
	emit_signal("state_changed", state)


## Set pathfinding references (supports both SDKPathfinder and legacy pathfinder+grid)
func set_pathfinding(p_pathfinder: RefCounted, p_grid_map: RefCounted = null) -> void:
	_pathfinder = p_pathfinder
	_grid_map = p_grid_map


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
	trigger_attack_pulse()
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
	# Trigger hit shake animation
	trigger_hit_shake()

	# Play hit sound effect
	if AudioManager:
		AudioManager.play_sfx("soul_unit_hurt", 0.8)

	GameLog.debug("SoulUnit: %s takes %d damage (HP: %d/%d)" % [soul_name, actual_damage, current_hp, max_hp], "Arena")

	if current_hp <= 0:
		current_hp = 0
		state = UnitState.DEAD
		emit_signal("state_changed", state)
		emit_signal("unit_died", self)
		# Trigger death animation
		trigger_death_animation()
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
