extends RefCounted
## PixelSpriteGenerator - Procedural pixel art generator for soul characters
##
## Generates 64x64 pixel sprites for soul characters based on element type
## and personality traits. Follows the art spec from 08_美术与技术选型.md:
## - 64x64 pixels per character
## - 32-color limit per character
## - Personality-based color schemes (brave=red/orange, cautious=blue/green,
##   curious=purple/yellow, friendly=pink/cyan)
## - Warm, fantasy, slightly mysterious atmosphere
##
## This is game-specific procedural art generation, not SDK kernel code.

## Sprite size (art spec: 64x64)
const SPRITE_SIZE: int = 64

## Element color palettes (32 colors each, art spec compliance)
const ELEMENT_PALETTES: Dictionary = {
	"fire": {
		"primary": Color(0.9, 0.3, 0.1),    # Bright orange-red
		"secondary": Color(1.0, 0.6, 0.2),   # Warm orange
		"accent": Color(1.0, 0.9, 0.4),      # Light yellow
		"dark": Color(0.5, 0.1, 0.05),       # Dark red
		"glow": Color(1.0, 0.5, 0.2),        # Fire glow
		"eye": Color(1.0, 1.0, 0.8)          # Bright eyes
	},
	"water": {
		"primary": Color(0.2, 0.5, 0.9),     # Bright blue
		"secondary": Color(0.4, 0.8, 1.0),   # Light blue
		"accent": Color(0.7, 0.95, 1.0),     # Pale cyan
		"dark": Color(0.05, 0.2, 0.5),       # Dark blue
		"glow": Color(0.3, 0.7, 1.0),        # Water glow
		"eye": Color(0.9, 1.0, 1.0)          # Bright eyes
	},
	"earth": {
		"primary": Color(0.5, 0.35, 0.2),    # Brown
		"secondary": Color(0.7, 0.55, 0.35), # Light brown
		"accent": Color(0.4, 0.7, 0.3),      # Green
		"dark": Color(0.3, 0.2, 0.1),        # Dark brown
		"glow": Color(0.6, 0.5, 0.3),        # Earth glow
		"eye": Color(1.0, 0.95, 0.8)         # Warm eyes
	},
	"wind": {
		"primary": Color(0.7, 0.9, 0.95),    # Pale cyan
		"secondary": Color(0.9, 0.95, 1.0),  # Near white
		"accent": Color(0.5, 0.7, 0.8),      # Muted blue
		"dark": Color(0.3, 0.45, 0.55),      # Dark slate
		"glow": Color(0.8, 0.95, 1.0),       # Wind glow
		"eye": Color(1.0, 1.0, 1.0)          # White eyes
	},
	"light": {
		"primary": Color(1.0, 0.95, 0.7),    # Golden
		"secondary": Color(1.0, 1.0, 0.9),   # Near white
		"accent": Color(1.0, 0.85, 0.4),     # Gold
		"dark": Color(0.6, 0.5, 0.2),        # Dark gold
		"glow": Color(1.0, 0.95, 0.6),       # Light glow
		"eye": Color(1.0, 1.0, 1.0)          # White eyes
	},
	"dark": {
		"primary": Color(0.4, 0.2, 0.6),     # Purple
		"secondary": Color(0.6, 0.4, 0.8),   # Light purple
		"accent": Color(0.3, 0.1, 0.4),      # Dark purple
		"dark": Color(0.15, 0.05, 0.25),     # Very dark purple
		"glow": Color(0.5, 0.3, 0.7),        # Dark glow
		"eye": Color(0.9, 0.7, 1.0)          # Glowing eyes
	},
	"neutral": {
		"primary": Color(0.6, 0.6, 0.65),    # Gray
		"secondary": Color(0.8, 0.8, 0.85),  # Light gray
		"accent": Color(0.5, 0.5, 0.55),     # Muted gray
		"dark": Color(0.3, 0.3, 0.35),       # Dark gray
		"glow": Color(0.7, 0.7, 0.75),       # Neutral glow
		"eye": Color(1.0, 1.0, 1.0)          # White eyes
	}
}

## Personality color modifiers
const PERSONALITY_MODIFIERS: Dictionary = {
	"brave": {"hue_shift": 0.05, "saturation_boost": 0.15, "value_boost": 0.1},
	"cautious": {"hue_shift": -0.05, "saturation_boost": -0.1, "value_boost": -0.05},
	"curious": {"hue_shift": 0.1, "saturation_boost": 0.1, "value_boost": 0.05},
	"friendly": {"hue_shift": -0.1, "saturation_boost": 0.05, "value_boost": 0.1},
	"neutral": {"hue_shift": 0.0, "saturation_boost": 0.0, "value_boost": 0.0}
}


## Generate a soul sprite based on element and personality
## Returns an ImageTexture for use in Sprite2D
func generate_soul_sprite(p_element: String = "neutral", p_personality: Dictionary = {}) -> ImageTexture:
	var image = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	var palette = _get_palette(p_element, p_personality)
	var seed = _hash_string(p_element + str(p_personality))
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Draw soul body (ethereal orb shape)
	_draw_soul_body(image, palette, rng)

	# Draw eyes
	_draw_eyes(image, palette, rng)

	# Draw aura/glow
	_draw_aura(image, palette, rng)

	# Draw personality-specific features
	_draw_personality_features(image, palette, p_personality, rng)

	var texture = ImageTexture.create_from_image(image)
	return texture


## Get color palette with personality modifiers
func _get_palette(p_element: String, p_personality: Dictionary) -> Dictionary:
	var base_palette = ELEMENT_PALETTES.get(p_element, ELEMENT_PALETTES["neutral"])
	var result = {}

	# Determine dominant personality trait
	var dominant = "neutral"
	var max_val = 0
	var trait_keys: Array = p_personality.keys()
	var ti: int = 0
	while ti < trait_keys.size():
		var trait_name = trait_keys[ti]
		if p_personality[trait_name] > max_val:
			max_val = p_personality[trait_name]
			if trait_name == "aggression" and max_val > 60:
				dominant = "brave"
			elif trait_name == "patience" and max_val > 60:
				dominant = "cautious"
			elif trait_name == "curiosity" and max_val > 60:
				dominant = "curious"
			elif trait_name == "loyalty" and max_val > 70:
				dominant = "friendly"
		ti += 1

	var modifier = PERSONALITY_MODIFIERS.get(dominant, PERSONALITY_MODIFIERS["neutral"])

	var color_keys: Array = base_palette.keys()
	var ci: int = 0
	while ci < color_keys.size():
		var color_name = color_keys[ci]
		var col = base_palette[color_name]
		var hue = col.h
		var sat = col.s
		var val = col.v
		hue = wrapf(hue + modifier["hue_shift"], 0.0, 1.0)
		sat = clamp(sat + modifier["saturation_boost"], 0.0, 1.0)
		val = clamp(val + modifier["value_boost"], 0.0, 1.0)
		result[color_name] = Color.from_hsv(hue, sat, val)
		ci += 1

	return result


## Draw the main soul body (ethereal orb)
func _draw_soul_body(image: Image, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var center = Vector2(SPRITE_SIZE / 2, SPRITE_SIZE / 2)
	var body_radius = 20.0

	for y in range(SPRITE_SIZE):
		for x in range(SPRITE_SIZE):
			var dist = Vector2(x, y).distance_to(center)
			if dist < body_radius:
				# Gradient from center to edge
				var t = dist / body_radius
				var col = palette["primary"].lerp(palette["dark"], t * 0.7)
				# Add some noise for texture
				var noise = rng.randf_range(-0.05, 0.05)
				col = Color(
					clamp(col.r + noise, 0, 1),
					clamp(col.g + noise, 0, 1),
					clamp(col.b + noise, 0, 1),
					1.0 - t * 0.3  # Slightly transparent at edges
				)
				image.set_pixel(x, y, col)
			elif dist < body_radius + 3:
				# Soft edge
				var t = (dist - body_radius) / 3.0
				image.set_pixel(x, y, Color(palette["primary"], 1.0 - t))


## Draw eyes
func _draw_eyes(image: Image, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var center = Vector2(SPRITE_SIZE / 2, SPRITE_SIZE / 2)
	var eye_y = center.y - 3
	var eye_spacing = 7

	for side in [-1, 1]:
		var eye_x = center.x + side * eye_spacing
		# Eye white
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if abs(dx) + abs(dy) <= 3:
					image.set_pixel(eye_x + dx, eye_y + dy, palette["eye"])
		# Pupil
		image.set_pixel(eye_x, eye_y, Color(0.1, 0.1, 0.15))
		image.set_pixel(eye_x + side, eye_y, Color(0.1, 0.1, 0.15))


## Draw aura/glow around soul
func _draw_aura(image: Image, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var center = Vector2(SPRITE_SIZE / 2, SPRITE_SIZE / 2)
	var aura_radius = 28.0

	for y in range(SPRITE_SIZE):
		for x in range(SPRITE_SIZE):
			var dist = Vector2(x, y).distance_to(center)
			if dist > 20 and dist < aura_radius:
				var t = (dist - 20) / (aura_radius - 20)
				var alpha = (1.0 - t) * 0.3
				var existing = image.get_pixel(x, y)
				if existing.a < alpha:
					image.set_pixel(x, y, Color(palette["glow"], alpha))


## Draw personality-specific features
func _draw_personality_features(image: Image, palette: Dictionary, p_personality: Dictionary, rng: RandomNumberGenerator) -> void:
	var center = Vector2(SPRITE_SIZE / 2, SPRITE_SIZE / 2)

	# High aggression: flame-like top
	if p_personality.get("aggression", 50) > 70:
		for i in range(3):
			var flame_x = center.x + rng.randf_range(-8, 8)
			var flame_height = rng.randf_range(4, 10)
			for y in range(int(center.y - 20 - flame_height), int(center.y - 20)):
				var width = int((1.0 - float(y - (center.y - 20 - flame_height)) / flame_height) * 3)
				for x in range(int(flame_x - width), int(flame_x + width)):
					if x >= 0 and x < SPRITE_SIZE and y >= 0 and y < SPRITE_SIZE:
						image.set_pixel(x, y, palette["accent"])

	# High curiosity: sparkles around
	if p_personality.get("curiosity", 50) > 70:
		for i in range(5):
			var angle = rng.randf() * TAU
			var dist = rng.randf_range(22, 28)
			var sx = int(center.x + cos(angle) * dist)
			var sy = int(center.y + sin(angle) * dist)
			if sx >= 0 and sx < SPRITE_SIZE and sy >= 0 and sy < SPRITE_SIZE:
				image.set_pixel(sx, sy, palette["accent"])
				image.set_pixel(sx + 1, sy, palette["accent"])

	# High loyalty: heart shape
	if p_personality.get("loyalty", 50) > 80:
		var heart_x = center.x
		var heart_y = center.y + 12
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				if abs(dx) + abs(dy) <= 3 and not (abs(dx) == 3 and abs(dy) == 2):
					var hx = heart_x + dx
					var hy = heart_y + dy
					if hx >= 0 and hx < SPRITE_SIZE and hy >= 0 and hy < SPRITE_SIZE:
						image.set_pixel(hx, hy, Color(1.0, 0.4, 0.6, 0.8))


## Generate a simple color swatch for UI display
func generate_color_swatch(p_element: String = "neutral", p_size: int = 32) -> ImageTexture:
	var image = Image.create(p_size, p_size, false, Image.FORMAT_RGBA8)
	var palette = ELEMENT_PALETTES.get(p_element, ELEMENT_PALETTES["neutral"])

	for y in range(p_size):
		for x in range(p_size):
			var t = float(x + y) / (p_size * 2)
			var col = palette["primary"].lerp(palette["secondary"], t)
			image.set_pixel(x, y, col)

	return ImageTexture.create_from_image(image)


## Hash string to seed for deterministic generation
func _hash_string(s: String) -> int:
	var h_val = 0
	var si: int = 0
	while si < s.length():
		h_val = (h_val * 31 + s.unicode_at(si)) & 0x7FFFFFFF
		si += 1
	return h_val


## Get list of supported elements
func get_supported_elements() -> Array:
	return ELEMENT_PALETTES.keys()
