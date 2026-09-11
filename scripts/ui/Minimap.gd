extends Control
## Minimap - RTS arena minimap display
##
## Shows a top-down overview of the arena with:
## - Player unit position (blue dot)
## - AI unit position (red dot)
## - Obstacles (gray blocks)
## - Terrain colors
## - Arena boundaries
##
## The minimap is a scaled representation of the arena map.
## Clicking on the minimap can move the camera (future feature).

## Minimap size (square)
var minimap_size: Vector2 = Vector2(150, 150)

## Arena map size (source coordinates)
var arena_size: Vector2 = Vector2(1280, 600)

## Scale factor from arena to minimap
var _scale: Vector2 = Vector2.ZERO

## Player unit reference
var _player_unit = null

## AI unit reference
var _ai_unit = null

## ArenaMap reference
var _arena_map = null

## Background color (game-level: dark purple)
var background_color: Color = Color(0.06, 0.04, 0.12, 0.92)

## Border color (game-level: gold)
var border_color: Color = Color(0.8, 0.6, 0.2, 1.0)

## Player dot color (brighter blue)
var player_color: Color = Color(0.3, 0.7, 1.0, 1.0)

## AI dot color (brighter red)
var ai_color: Color = Color(1.0, 0.4, 0.4, 1.0)

## Obstacle color
var obstacle_color: Color = Color(0.5, 0.5, 0.5, 0.8)

## Dot radius
var dot_radius: float = 4.0

## Whether to show terrain colors
var show_terrain: bool = true


func _ready() -> void:
	_calculate_scale()
	set_custom_minimum_size(minimap_size)


## Calculate scale from arena to minimap
func _calculate_scale() -> void:
	if arena_size.x > 0 and arena_size.y > 0:
		_scale = Vector2(
			minimap_size.x / arena_size.x,
			minimap_size.y / arena_size.y
		)


## Set arena size
func set_arena_size(p_size: Vector2) -> void:
	arena_size = p_size
	_calculate_scale()
	queue_redraw()


## Set player unit reference
func set_player_unit(p_unit) -> void:
	_player_unit = p_unit


## Set AI unit reference
func set_ai_unit(p_unit) -> void:
	_ai_unit = p_unit


## Set arena map reference
func set_arena_map(p_map) -> void:
	_arena_map = p_map


## Convert arena position to minimap position
func _arena_to_minimap(p_pos: Vector2) -> Vector2:
	return Vector2(
		p_pos.x * _scale.x,
		p_pos.y * _scale.y
	)


## Draw minimap
func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, minimap_size), background_color, true)

	# Border (gold, 3px for game-level look)
	draw_rect(Rect2(Vector2.ZERO, minimap_size), border_color, false, 3.0)
	# Inner accent border (subtle gold glow)
	draw_rect(Rect2(Vector2(2, 2), minimap_size - Vector2(4, 4)), Color(0.6, 0.45, 0.15, 0.5), false, 1.0)

	# Draw terrain (if available)
	if show_terrain and _arena_map != null and _arena_map.has_method("terrain_grid"):
		_draw_terrain()

	# Draw obstacles
	if _arena_map != null and _arena_map.has_method("obstacles"):
		_draw_obstacles()

	# Draw AI unit
	if _ai_unit != null and is_instance_valid(_ai_unit):
		var ai_pos = _arena_to_minimap(_ai_unit.position)
		_draw_unit_dot(ai_pos, ai_color, "AI")

	# Draw player unit (on top)
	if _player_unit != null and is_instance_valid(_player_unit):
		var player_pos = _arena_to_minimap(_player_unit.position)
		_draw_unit_dot(player_pos, player_color, "P")


## Draw terrain grid
func _draw_terrain() -> void:
	var grid = _arena_map.terrain_grid
	if grid == null or grid.is_empty():
		return

	var cell_size = _arena_map.terrain_cell_size
	if cell_size <= 0:
		return

	for x in range(grid.size()):
		for y in range(grid[x].size()):
			var terrain_type = grid[x][y]
			var color = _terrain_to_color(terrain_type)
			if color.a > 0:
				var arena_pos = Vector2(x * cell_size, y * cell_size)
				var mini_pos = _arena_to_minimap(arena_pos)
				var mini_size = Vector2(cell_size * _scale.x, cell_size * _scale.y)
				draw_rect(Rect2(mini_pos, mini_size), color, true)


## Draw obstacles
func _draw_obstacles() -> void:
	var obstacles = _arena_map.obstacles
	if obstacles == null or obstacles.is_empty():
		return

	for obstacle in obstacles:
		if obstacle.get("destroyed", false):
			continue
		var pos = obstacle.get("position", Vector2.ZERO)
		var size = obstacle.get("size", Vector2(32, 32))
		var mini_pos = _arena_to_minimap(pos - size / 2)
		var mini_size = Vector2(size.x * _scale.x, size.y * _scale.y)
		# Clamp to minimap bounds
		mini_pos = mini_pos.clamp(Vector2.ZERO, minimap_size - mini_size)
		draw_rect(Rect2(mini_pos, mini_size), obstacle_color, true)


## Draw unit dot with label
func _draw_unit_dot(p_pos: Vector2, p_color: Color, p_label: String) -> void:
	# Clamp to minimap bounds
	var clamped_pos = p_pos.clamp(
		Vector2(dot_radius, dot_radius),
		minimap_size - Vector2(dot_radius, dot_radius)
	)

	# Outer glow
	draw_circle(clamped_pos, dot_radius + 2, Color(p_color.r, p_color.g, p_color.b, 0.3))
	# Main dot
	draw_circle(clamped_pos, dot_radius, p_color)
	# Gold border (game-level)
	draw_arc(clamped_pos, dot_radius, 0, TAU, 16, Color(1.0, 0.88, 0.5, 0.9), 1.5)


## Convert terrain type to color
func _terrain_to_color(p_terrain: int) -> Color:
	match p_terrain:
		0:  # NORMAL
			return Color(0.15, 0.15, 0.18, 0.5)
		1:  # GRASS
			return Color(0.15, 0.3, 0.15, 0.6)
		2:  # STONE
			return Color(0.3, 0.3, 0.32, 0.6)
		3:  # WATER
			return Color(0.1, 0.2, 0.4, 0.7)
		4:  # LAVA
			return Color(0.5, 0.2, 0.05, 0.7)
		5:  # SAND
			return Color(0.4, 0.35, 0.15, 0.5)
		_:
			return Color(0, 0, 0, 0)


## Update minimap (call every frame)
func update_minimap() -> void:
	queue_redraw()


## Handle click on minimap (future: camera movement)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var click_pos = event.position
		# Convert minimap click to arena position
		var arena_pos = Vector2(
			click_pos.x / _scale.x,
			click_pos.y / _scale.y
		)
		# Emit signal for camera movement (future)
		emit_signal("minimap_clicked", arena_pos)


signal minimap_clicked(arena_position)
