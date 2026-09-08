extends Node2D
## ArenaMap - Manages arena terrain, obstacles, and spawn points
##
## Handles the RTS arena layout: terrain types, obstacle placement,
## collision detection, pathfinding helpers, and spawn positions.
##
## This is game-specific logic for M2 RTS arena, not SDK kernel code.

## Terrain type constants
enum TerrainType {
	NORMAL,      # Normal movement speed
	GRASS,       # Slightly slower movement
	STONE,       # Normal movement, harder texture
	WATER,       # Slower movement, no obstacles
	LAVA,        # Damage over time
	SAND         # Slower movement
}

## Obstacle type constants
enum ObstacleType {
	ROCK,        # Blocks movement, destructible
	TREE,        # Blocks movement, destructible
	WALL,        # Blocks movement, indestructible
	CRYSTAL,     # Blocks movement, gives buff when destroyed
	PILLAR       # Blocks movement, indestructible
}

## Arena dimensions
var arena_width: int = 1280
var arena_height: int = 600
var grid_size: int = 40  # Grid cell size for pathfinding

## Terrain grid (2D array of TerrainType)
var terrain_grid: Array = []

## Obstacles: Array of Dictionaries
## {id, type, position, size, hp, max_hp, destructible, buff_effect}
var obstacles: Array = []

## Spawn points
var player_spawn: Vector2 = Vector2(200, 300)
var ai_spawn: Vector2 = Vector2(1080, 300)

## Map name
var map_name: String = "default_arena"

## Visual nodes
var _terrain_layer: Node2D = null
var _obstacle_layer: Node2D = null
var _grid_layer: Node2D = null

## Signals
signal obstacle_destroyed(obstacle_data)
signal terrain_changed(cell_x, cell_y, new_type)
signal map_loaded(map_name)


func _ready() -> void:
	GameLog.info("ArenaMap: Initialized", "Arena")
	_setup_layers()


## Setup visual layers
func _setup_layers() -> void:
	_terrain_layer = Node2D.new()
	_terrain_layer.name = "TerrainLayer"
	add_child(_terrain_layer)

	_obstacle_layer = Node2D.new()
	_obstacle_layer.name = "ObstacleLayer"
	add_child(_obstacle_layer)

	_grid_layer = Node2D.new()
	_grid_layer.name = "GridLayer"
	add_child(_grid_layer)


## Load a map by name
func load_map(p_map_name: String = "default_arena") -> void:
	map_name = p_map_name
	obstacles.clear()
	terrain_grid.clear()

	match p_map_name:
		"default_arena":
			_load_default_arena()
		"forest_arena":
			_load_forest_arena()
		"crystal_arena":
			_load_crystal_arena()
		_:
			_load_default_arena()

	_generate_terrain_grid()
	_render_terrain()
	_render_obstacles()

	emit_signal("map_loaded", map_name)
	GameLog.info("ArenaMap: Loaded map '%s' with %d obstacles" % [map_name, obstacles.size()], "Arena")


## Load default arena layout
func _load_default_arena() -> void:
	player_spawn = Vector2(200, 300)
	ai_spawn = Vector2(1080, 300)

	# Center pillars
	_add_obstacle(ObstacleType.PILLAR, Vector2(640, 150), Vector2(40, 40), false)
	_add_obstacle(ObstacleType.PILLAR, Vector2(640, 450), Vector2(40, 40), false)

	# Side rocks
	_add_obstacle(ObstacleType.ROCK, Vector2(400, 200), Vector2(50, 50), true, 50)
	_add_obstacle(ObstacleType.ROCK, Vector2(400, 400), Vector2(50, 50), true, 50)
	_add_obstacle(ObstacleType.ROCK, Vector2(880, 200), Vector2(50, 50), true, 50)
	_add_obstacle(ObstacleType.ROCK, Vector2(880, 400), Vector2(50, 50), true, 50)

	# Center crystal
	_add_obstacle(ObstacleType.CRYSTAL, Vector2(640, 300), Vector2(45, 45), true, 80, "attack_buff")


## Load forest arena layout
func _load_forest_arena() -> void:
	player_spawn = Vector2(150, 300)
	ai_spawn = Vector2(1130, 300)

	# Tree clusters
	for i in range(5):
		_add_obstacle(ObstacleType.TREE, Vector2(350 + i * 30, 100 + i * 20), Vector2(35, 35), true, 30)
		_add_obstacle(ObstacleType.TREE, Vector2(900 - i * 30, 500 - i * 20), Vector2(35, 35), true, 30)

	# Center wall
	_add_obstacle(ObstacleType.WALL, Vector2(640, 200), Vector2(20, 100), false)
	_add_obstacle(ObstacleType.WALL, Vector2(640, 400), Vector2(20, 100), false)


## Load crystal arena layout
func _load_crystal_arena() -> void:
	player_spawn = Vector2(200, 300)
	ai_spawn = Vector2(1080, 300)

	# Crystal formations
	var crystal_positions = [
		Vector2(500, 150), Vector2(780, 150),
		Vector2(500, 450), Vector2(780, 450),
		Vector2(640, 220), Vector2(640, 380)
	]
	for pos in crystal_positions:
		_add_obstacle(ObstacleType.CRYSTAL, pos, Vector2(40, 40), true, 60, "energy_regen")

	# Corner pillars
	_add_obstacle(ObstacleType.PILLAR, Vector2(100, 100), Vector2(35, 35), false)
	_add_obstacle(ObstacleType.PILLAR, Vector2(1180, 100), Vector2(35, 35), false)
	_add_obstacle(ObstacleType.PILLAR, Vector2(100, 500), Vector2(35, 35), false)
	_add_obstacle(ObstacleType.PILLAR, Vector2(1180, 500), Vector2(35, 35), false)


## Add an obstacle to the map
func _add_obstacle(p_type: int, p_position: Vector2, p_size: Vector2, p_destructible: bool = true, p_hp: int = 50, p_buff_effect: String = "") -> void:
	var obstacle: Dictionary = {
		"id": "obstacle_%d" % obstacles.size(),
		"type": p_type,
		"position": p_position,
		"size": p_size,
		"hp": p_hp,
		"max_hp": p_hp,
		"destructible": p_destructible,
		"buff_effect": p_buff_effect,
		"destroyed": false
	}
	obstacles.append(obstacle)


## Generate terrain grid
func _generate_terrain_grid() -> void:
	var cols = arena_width / grid_size
	var rows = arena_height / grid_size

	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			# Default terrain based on position
			var terrain = TerrainType.NORMAL
			# Border areas are stone
			if x == 0 or x == cols - 1 or y == 0 or y == rows - 1:
				terrain = TerrainType.STONE
			row.append(terrain)
		terrain_grid.append(row)


## Render terrain visually
func _render_terrain() -> void:
	if _terrain_layer == null:
		return

	# Clear existing
	for child in _terrain_layer.get_children():
		child.queue_free()

	var cols = arena_width / grid_size
	var rows = arena_height / grid_size

	for y in range(rows):
		for x in range(cols):
			var cell = ColorRect.new()
			cell.position = Vector2(x * grid_size, y * grid_size)
			cell.size = Vector2(grid_size, grid_size)

			match terrain_grid[y][x]:
				TerrainType.NORMAL:
					cell.color = Color(0.15, 0.2, 0.15)
				TerrainType.GRASS:
					cell.color = Color(0.1, 0.25, 0.1)
				TerrainType.STONE:
					cell.color = Color(0.25, 0.25, 0.28)
				TerrainType.WATER:
					cell.color = Color(0.1, 0.15, 0.35)
				TerrainType.LAVA:
					cell.color = Color(0.4, 0.15, 0.05)
				TerrainType.SAND:
					cell.color = Color(0.35, 0.3, 0.15)

			_terrain_layer.add_child(cell)


## Render obstacles visually
func _render_obstacles() -> void:
	if _obstacle_layer == null:
		return

	# Clear existing
	for child in _obstacle_layer.get_children():
		child.queue_free()

	for obstacle in obstacles:
		if obstacle["destroyed"]:
			continue

		var rect = ColorRect.new()
		rect.position = obstacle["position"] - obstacle["size"] / 2
		rect.size = obstacle["size"]
		rect.name = obstacle["id"]

		match obstacle["type"]:
			ObstacleType.ROCK:
				rect.color = Color(0.4, 0.35, 0.3)
			ObstacleType.TREE:
				rect.color = Color(0.15, 0.35, 0.15)
			ObstacleType.WALL:
				rect.color = Color(0.5, 0.5, 0.55)
			ObstacleType.CRYSTAL:
				rect.color = Color(0.3, 0.6, 0.9)
			ObstacleType.PILLAR:
				rect.color = Color(0.45, 0.4, 0.5)

		_obstacle_layer.add_child(rect)


## Get all obstacles
func get_obstacles() -> Array:
	return obstacles


## Check if a position is valid (not colliding with obstacles)
func is_position_valid(p_position: Vector2, p_unit_size: float = 32.0) -> bool:
	# Check arena bounds
	if p_position.x < p_unit_size / 2 or p_position.x > arena_width - p_unit_size / 2:
		return false
	if p_position.y < p_unit_size / 2 or p_position.y > arena_height - p_unit_size / 2:
		return false

	# Check obstacle collision
	for obstacle in obstacles:
		if obstacle["destroyed"]:
			continue
		var half_size = obstacle["size"] / 2
		var obstacle_pos = obstacle["position"]
		if (abs(p_position.x - obstacle_pos.x) < half_size.x + p_unit_size / 2 and
				abs(p_position.y - obstacle_pos.y) < half_size.y + p_unit_size / 2):
			return false

	return true


## Get terrain type at position
func get_terrain_type(p_position: Vector2) -> int:
	var cell_x = int(p_position.x / grid_size)
	var cell_y = int(p_position.y / grid_size)

	if cell_y < 0 or cell_y >= terrain_grid.size():
		return TerrainType.NORMAL
	if cell_x < 0 or cell_x >= terrain_grid[cell_y].size():
		return TerrainType.NORMAL

	return terrain_grid[cell_y][cell_x]


## Get movement speed modifier for terrain at position
func get_terrain_speed_modifier(p_position: Vector2) -> float:
	var cell_x = int(p_position.x / grid_size)
	var cell_y = int(p_position.y / grid_size)

	if cell_y < 0 or cell_y >= terrain_grid.size():
		return 1.0
	if cell_x < 0 or cell_x >= terrain_grid[cell_y].size():
		return 1.0

	match terrain_grid[cell_y][cell_x]:
		TerrainType.GRASS:
			return 0.85
		TerrainType.WATER:
			return 0.6
		TerrainType.SAND:
			return 0.75
		TerrainType.LAVA:
			return 0.9
		_:
			return 1.0


## Check if position is on damaging terrain (lava)
func is_damaging_terrain(p_position: Vector2) -> bool:
	var cell_x = int(p_position.x / grid_size)
	var cell_y = int(p_position.y / grid_size)

	if cell_y < 0 or cell_y >= terrain_grid.size():
		return false
	if cell_x < 0 or cell_x >= terrain_grid[cell_y].size():
		return false

	return terrain_grid[cell_y][cell_x] == TerrainType.LAVA


## Damage an obstacle
func damage_obstacle(p_obstacle_id: String, p_damage: int) -> Dictionary:
	for obstacle in obstacles:
		if obstacle["id"] == p_obstacle_id and not obstacle["destroyed"]:
			if not obstacle["destructible"]:
				return {"success": false, "message": "Obstacle is indestructible"}

			obstacle["hp"] -= p_damage
			if obstacle["hp"] <= 0:
				obstacle["destroyed"] = true
				obstacle["hp"] = 0
				_render_obstacles()
				emit_signal("obstacle_destroyed", obstacle)
				return {
					"success": true,
					"destroyed": true,
					"buff_effect": obstacle["buff_effect"],
					"message": "Obstacle destroyed!"
				}
			return {"success": true, "destroyed": false, "hp": obstacle["hp"]}

	return {"success": false, "message": "Obstacle not found"}


## Get obstacle at position
func get_obstacle_at(p_position: Vector2) -> Dictionary:
	for obstacle in obstacles:
		if obstacle["destroyed"]:
			continue
		var half_size = obstacle["size"] / 2
		var obstacle_pos = obstacle["position"]
		if (abs(p_position.x - obstacle_pos.x) < half_size.x and
				abs(p_position.y - obstacle_pos.y) < half_size.y):
			return obstacle
	return {}


## Get available maps list
func get_available_maps() -> Array:
	return ["default_arena", "forest_arena", "crystal_arena"]


## Get map info
func get_map_info() -> Dictionary:
	return {
		"name": map_name,
		"width": arena_width,
		"height": arena_height,
		"grid_size": grid_size,
		"obstacle_count": obstacles.size(),
		"player_spawn": player_spawn,
		"ai_spawn": ai_spawn
	}


## Reset map
func reset_map() -> void:
	for obstacle in obstacles:
		obstacle["destroyed"] = false
		obstacle["hp"] = obstacle["max_hp"]
	_render_obstacles()
	GameLog.info("ArenaMap: Map reset", "Arena")
