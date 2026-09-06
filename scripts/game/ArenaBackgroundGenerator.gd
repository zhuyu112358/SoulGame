extends RefCounted
## ArenaBackgroundGenerator - Procedural pixel art background for RTS arena
##
## Generates pixel-style arena backgrounds following 08_美术与技术选型.md:
## - 32x32 pixel tiles (art spec base resolution)
## - 64-color limit per scene
## - Medium saturation for backgrounds (avoid conflicting with characters)
## - Warm, fantasy atmosphere
##
## Arena types: grass, stone, sand, crystal, lava
## Each type has distinct color palettes and decorative elements.

## Tile size (art spec: 32x32 base resolution)
const TILE_SIZE: int = 32

## Arena dimensions in pixels
const ARENA_WIDTH: int = 1280
const ARENA_HEIGHT: int = 640  # 720 - 80 (top bar)

## Arena type palettes (background colors, medium saturation per art spec)
const ARENA_PALETTES: Dictionary = {
	"grass": {
		"base": Color(0.25, 0.45, 0.2),       # Dark green
		"alt": Color(0.3, 0.5, 0.25),         # Medium green
		"accent": Color(0.35, 0.55, 0.3),     # Light green
		"border": Color(0.15, 0.3, 0.15),     # Dark border
		"decoration": Color(0.4, 0.6, 0.35)   # Grass tufts
	},
	"stone": {
		"base": Color(0.4, 0.4, 0.45),        # Gray stone
		"alt": Color(0.45, 0.45, 0.5),        # Light gray
		"accent": Color(0.35, 0.35, 0.4),     # Dark gray
		"border": Color(0.25, 0.25, 0.3),     # Dark border
		"decoration": Color(0.5, 0.5, 0.55)   # Stone highlights
	},
	"sand": {
		"base": Color(0.75, 0.65, 0.4),       # Sand
		"alt": Color(0.8, 0.7, 0.45),         # Light sand
		"accent": Color(0.7, 0.6, 0.35),      # Dark sand
		"border": Color(0.6, 0.5, 0.3),       # Dark border
		"decoration": Color(0.85, 0.75, 0.5)  # Sand ripples
	},
	"crystal": {
		"base": Color(0.2, 0.25, 0.4),        # Dark blue-purple
		"alt": Color(0.25, 0.3, 0.5),         # Medium blue-purple
		"accent": Color(0.3, 0.4, 0.6),       # Light blue
		"border": Color(0.15, 0.2, 0.35),     # Dark border
		"decoration": Color(0.5, 0.6, 0.8)    # Crystal glow
	},
	"lava": {
		"base": Color(0.3, 0.15, 0.1),        # Dark red
		"alt": Color(0.4, 0.2, 0.15),         # Medium red
		"accent": Color(0.5, 0.25, 0.2),      # Light red
		"border": Color(0.2, 0.1, 0.05),      # Dark border
		"decoration": Color(0.9, 0.4, 0.1)    # Lava glow
	}
}


## Generate arena background texture
## Returns ImageTexture for use as background
func generate_background(p_arena_type: String = "grass", p_seed: int = 0) -> ImageTexture:
	var image = Image.create(ARENA_WIDTH, ARENA_HEIGHT, false, Image.FORMAT_RGBA8)
	var palette = ARENA_PALETTES.get(p_arena_type, ARENA_PALETTES["grass"])
	var rng = RandomNumberGenerator.new()
	rng.seed = p_seed if p_seed > 0 else randi()

	# Draw base terrain with tile pattern
	_draw_terrain(image, palette, rng)

	# Draw grid lines (subtle)
	_draw_grid(image, palette)

	# Draw border
	_draw_border(image, palette)

	# Draw spawn point markers
	_draw_spawn_points(image, palette)

	# Draw decorations
	_draw_decorations(image, palette, rng, p_arena_type)

	return ImageTexture.create_from_image(image)


## Draw base terrain with checkerboard tile pattern
func _draw_terrain(image: Image, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var tiles_x = ARENA_WIDTH / TILE_SIZE
	var tiles_y = ARENA_HEIGHT / TILE_SIZE

	var ty: int = 0
	while ty < tiles_y:
		var tx: int = 0
		while tx < tiles_x:
			# Alternate base/alt for subtle checkerboard
			var use_alt = (tx + ty) % 2 == 0
			var base_color = palette["alt"] if use_alt else palette["base"]

			# Add per-tile noise variation
			var noise = rng.randf_range(-0.03, 0.03)
			var tile_color = Color(
				clamp(base_color.r + noise, 0, 1),
				clamp(base_color.g + noise, 0, 1),
				clamp(base_color.b + noise, 0, 1),
				1.0
			)

			# Fill tile
			var py: int = 0
			while py < TILE_SIZE:
				var px: int = 0
				while px < TILE_SIZE:
					var x = tx * TILE_SIZE + px
					var y = ty * TILE_SIZE + py
					if x < ARENA_WIDTH and y < ARENA_HEIGHT:
						# Add pixel-level noise
						var pnoise = rng.randf_range(-0.02, 0.02)
						image.set_pixel(x, y, Color(
							clamp(tile_color.r + pnoise, 0, 1),
							clamp(tile_color.g + pnoise, 0, 1),
							clamp(tile_color.b + pnoise, 0, 1),
							1.0
						))
					px += 1
				py += 1
			tx += 1
		ty += 1


## Draw subtle grid lines
func _draw_grid(image: Image, palette: Dictionary) -> void:
	var grid_color = Color(palette["accent"].r, palette["accent"].g, palette["accent"].b, 0.15)

	# Vertical lines
	var x: int = 0
	while x < ARENA_WIDTH:
		var y: int = 0
		while y < ARENA_HEIGHT:
			image.set_pixel(x, y, grid_color)
			y += 1
		x += TILE_SIZE

	# Horizontal lines
	var y2: int = 0
	while y2 < ARENA_HEIGHT:
		var x2: int = 0
		while x2 < ARENA_WIDTH:
			image.set_pixel(x2, y2, grid_color)
			x2 += 1
		y2 += TILE_SIZE


## Draw arena border
func _draw_border(image: Image, palette: Dictionary) -> void:
	var border_color = palette["border"]
	var border_width = 4

	# Top and bottom
	var bx: int = 0
	while bx < ARENA_WIDTH:
		var by: int = 0
		while by < border_width:
			image.set_pixel(bx, by, border_color)
			image.set_pixel(bx, ARENA_HEIGHT - 1 - by, border_color)
			by += 1
		bx += 1

	# Left and right
	var by2: int = 0
	while by2 < ARENA_HEIGHT:
		var bx2: int = 0
		while bx2 < border_width:
			image.set_pixel(bx2, by2, border_color)
			image.set_pixel(ARENA_WIDTH - 1 - bx2, by2, border_color)
			bx2 += 1
		by2 += 1


## Draw spawn point markers (player left, AI right)
func _draw_spawn_points(image: Image, palette: Dictionary) -> void:
	var player_spawn = Vector2(150, ARENA_HEIGHT / 2)
	var ai_spawn = Vector2(ARENA_WIDTH - 150, ARENA_HEIGHT / 2)

	# Player spawn (blue tint)
	_draw_spawn_marker(image, player_spawn, Color(0.3, 0.5, 0.9, 0.4))
	# AI spawn (red tint)
	_draw_spawn_marker(image, ai_spawn, Color(0.9, 0.3, 0.3, 0.4))


## Draw a single spawn marker (circle)
func _draw_spawn_marker(image: Image, center: Vector2, color: Color) -> void:
	var radius = 40
	var dy: int = -radius
	while dy <= radius:
		var dx: int = -radius
		while dx <= radius:
			var dist = sqrt(float(dx * dx + dy * dy))
			if dist <= radius:
				var x = int(center.x + dx)
				var y = int(center.y + dy)
				if x >= 0 and x < ARENA_WIDTH and y >= 0 and y < ARENA_HEIGHT:
					if dist > radius - 3:
						# Ring
						image.set_pixel(x, y, color)
					elif dist < 5:
						# Center dot
						image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.6))
			dx += 1
		dy += 1


## Draw decorative elements based on arena type
func _draw_decorations(image: Image, palette: Dictionary, rng: RandomNumberGenerator, p_arena_type: String) -> void:
	match p_arena_type:
		"grass":
			_draw_grass_tufts(image, palette, rng, 30)
		"stone":
			_draw_stone_cracks(image, palette, rng, 15)
		"sand":
			_draw_sand_ripples(image, palette, rng, 20)
		"crystal":
			_draw_crystals(image, palette, rng, 8)
		"lava":
			_draw_lava_pockets(image, palette, rng, 6)


## Draw grass tufts
func _draw_grass_tufts(image: Image, palette: Dictionary, rng: RandomNumberGenerator, p_count: int) -> void:
	var i: int = 0
	while i < p_count:
		var x = rng.randi_range(20, ARENA_WIDTH - 20)
		var y = rng.randi_range(20, ARENA_HEIGHT - 20)
		var color = palette["decoration"]

		# Small grass tuft (3-5 pixels)
		var h = rng.randi_range(3, 6)
		var j: int = 0
		while j < h:
			var gx = x + rng.randi_range(-2, 2)
			var gy = y - j
			if gx >= 0 and gx < ARENA_WIDTH and gy >= 0 and gy < ARENA_HEIGHT:
				image.set_pixel(gx, gy, color)
			j += 1
		i += 1


## Draw stone cracks
func _draw_stone_cracks(image: Image, palette: Dictionary, rng: RandomNumberGenerator, p_count: int) -> void:
	var i: int = 0
	while i < p_count:
		var x = rng.randi_range(20, ARENA_WIDTH - 20)
		var y = rng.randi_range(20, ARENA_HEIGHT - 20)
		var color = palette["accent"]

		# Short crack line
		var length = rng.randi_range(5, 15)
		var angle = rng.randf() * TAU
		var j: int = 0
		while j < length:
			var cx = int(x + cos(angle) * j)
			var cy = int(y + sin(angle) * j)
			if cx >= 0 and cx < ARENA_WIDTH and cy >= 0 and cy < ARENA_HEIGHT:
				image.set_pixel(cx, cy, color)
			j += 1
		i += 1


## Draw sand ripples
func _draw_sand_ripples(image: Image, palette: Dictionary, rng: RandomNumberGenerator, p_count: int) -> void:
	var i: int = 0
	while i < p_count:
		var x = rng.randi_range(20, ARENA_WIDTH - 20)
		var y = rng.randi_range(20, ARENA_HEIGHT - 20)
		var color = palette["decoration"]

		# Curved ripple
		var j: int = -5
		while j <= 5:
			var cx = x + j * 2
			var cy = y + int(sin(float(j) * 0.5) * 2)
			if cx >= 0 and cx < ARENA_WIDTH and cy >= 0 and cy < ARENA_HEIGHT:
				image.set_pixel(cx, cy, color)
			j += 1
		i += 1


## Draw crystal formations
func _draw_crystals(image: Image, palette: Dictionary, rng: RandomNumberGenerator, p_count: int) -> void:
	var i: int = 0
	while i < p_count:
		var x = rng.randi_range(40, ARENA_WIDTH - 40)
		var y = rng.randi_range(40, ARENA_HEIGHT - 40)
		var color = palette["decoration"]
		var height = rng.randi_range(8, 20)

		# Diamond-shaped crystal
		var j: int = 0
		while j < height:
			var width = int(sin(float(j) / height * PI) * 6)
			var k: int = -width
			while k <= width:
				var cx = x + k
				var cy = y - j
				if cx >= 0 and cx < ARENA_WIDTH and cy >= 0 and cy < ARENA_HEIGHT:
					image.set_pixel(cx, cy, color)
				k += 1
			j += 1
		i += 1


## Draw lava pockets
func _draw_lava_pockets(image: Image, palette: Dictionary, rng: RandomNumberGenerator, p_count: int) -> void:
	var i: int = 0
	while i < p_count:
		var x = rng.randi_range(40, ARENA_WIDTH - 40)
		var y = rng.randi_range(40, ARENA_HEIGHT - 40)
		var color = palette["decoration"]
		var radius = rng.randi_range(5, 12)

		var dy: int = -radius
		while dy <= radius:
			var dx: int = -radius
			while dx <= radius:
				var dist = sqrt(float(dx * dx + dy * dy))
				if dist <= radius:
					var cx = x + dx
					var cy = y + dy
					if cx >= 0 and cx < ARENA_WIDTH and cy >= 0 and cy < ARENA_HEIGHT:
						var alpha = 1.0 - dist / radius
						image.set_pixel(cx, cy, Color(color.r, color.g, color.b, alpha * 0.7))
				dx += 1
			dy += 1
		i += 1


## Get list of supported arena types
func get_arena_types() -> Array:
	return ARENA_PALETTES.keys()
