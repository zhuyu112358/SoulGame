extends RefCounted
class_name SDKPathfinder
## Arboreus SDK Pathfinder adapter.
## Replaces the temporary AStarPathfinder + NavigationGrid implementation.
## Provides compatible interface for SoulUnit and RTSArenaManager.

var _grid_factory: Object = null
var _grid: Object = null
var _pathfinder: Object = null

var cell_size: float = 32.0
var width: int = 40
var height: int = 19
var origin_x: float = 0.0
var origin_y: float = 0.0
var allow_diagonal: bool = true


func _init(p_cell_size: float = 32.0, p_width: int = 40, p_height: int = 19, p_origin_x: float = 0.0, p_origin_y: float = 0.0, p_allow_diagonal: bool = true) -> void:
	cell_size = p_cell_size
	width = p_width
	height = p_height
	origin_x = p_origin_x
	origin_y = p_origin_y
	allow_diagonal = p_allow_diagonal

	# Create Arboreus GridMap factory and grid
	if ClassDB.class_exists("ArboreusGridMap"):
		_grid_factory = ClassDB.instantiate("ArboreusGridMap")
		_grid = _grid_factory.create(width, height, cell_size)
	else:
		push_error("SDKPathfinder: ArboreusGridMap class not found!")

	# Create Arboreus Pathfinder
	if ClassDB.class_exists("ArboreusPathfinder"):
		_pathfinder = ClassDB.instantiate("ArboreusPathfinder")
		if _grid:
			_pathfinder.set_grid(_grid)
		_pathfinder.set_allow_diagonal(allow_diagonal)
	else:
		push_error("SDKPathfinder: ArboreusPathfinder class not found!")

	GameLog.info("SDKPathfinder: Initialized Arboreus GridMap(%dx%d, cell=%.0f) + Pathfinder" % [width, height, cell_size], "Arena")


## Find path from start world position to goal world position.
## Returns array of Vector2 waypoints in world space, or empty array if unreachable.
func find_path(p_start_x: float, p_start_y: float, p_goal_x: float, p_goal_y: float) -> Array:
	if _pathfinder == null or _grid == null:
		return []

	# Convert world to grid coordinates
	var start_grid: Vector2i = _world_to_grid(p_start_x, p_start_y)
	var goal_grid: Vector2i = _world_to_grid(p_goal_x, p_goal_y)

	# Clamp to grid bounds
	start_grid.x = clamp(start_grid.x, 0, width - 1)
	start_grid.y = clamp(start_grid.y, 0, height - 1)
	goal_grid.x = clamp(goal_grid.x, 0, width - 1)
	goal_grid.y = clamp(goal_grid.y, 0, height - 1)

	# If goal is blocked, find nearest walkable
	if not _grid.is_walkable(goal_grid.x, goal_grid.y):
		var nearest = _find_nearest_walkable(goal_grid.x, goal_grid.y, 10)
		if nearest.x < 0:
			return []
		goal_grid = nearest

	# If start is blocked, find nearest walkable
	if not _grid.is_walkable(start_grid.x, start_grid.y):
		var nearest = _find_nearest_walkable(start_grid.x, start_grid.y, 10)
		if nearest.x < 0:
			return []
		start_grid = nearest

	GameLog.debug("SDKPathfinder: start_grid=%s goal_grid=%s" % [start_grid, goal_grid], "Arena")

	# Find path using Arboreus Pathfinder (requires Vector2, not Vector2i)
	var grid_path: Array = _pathfinder.find_path(Vector2(start_grid.x, start_grid.y), Vector2(goal_grid.x, goal_grid.y))

	if grid_path.is_empty():
		GameLog.debug("SDKPathfinder: No path found", "Arena")
		return []

	# Convert grid path to world waypoints
	# Arboreus returns world coordinates already (cell centers), but verify
	var waypoints: Array = []
	for i in range(grid_path.size()):
		var p = grid_path[i]
		# Check if returned values are already world coords (floats > cell count)
		var wx: float
		var wy: float
		if p.x > width or p.y > height:
			# Already world coordinates
			wx = p.x
			wy = p.y
		else:
			# Grid coordinates, convert to world
			wx = origin_x + (p.x + 0.5) * cell_size
			wy = origin_y + (p.y + 0.5) * cell_size
		waypoints.append(Vector2(wx, wy))

	GameLog.debug("SDKPathfinder: Path found, %d waypoints, first=%s" % [waypoints.size(), waypoints[0] if waypoints.size() > 0 else "none"], "Arena")
	return waypoints


## Mark a world-space AABB region as blocked.
func block_region(p_min_x: float, p_min_y: float, p_max_x: float, p_max_y: float) -> void:
	if _grid == null:
		return

	var min_cx: int = _world_to_grid_x(p_min_x)
	var min_cy: int = _world_to_grid_y(p_min_y)
	var max_cx: int = _world_to_grid_x(p_max_x)
	var max_cy: int = _world_to_grid_y(p_max_y)

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			if cx >= 0 and cx < width and cy >= 0 and cy < height:
				_grid.set_walkable(cx, cy, false)


## Clear all blocked cells.
func clear() -> void:
	if _grid == null:
		return
	for cx in range(width):
		for cy in range(height):
			_grid.set_walkable(cx, cy, true)


## Count blocked cells.
func get_blocked_count() -> int:
	if _grid == null:
		return 0
	var count: int = 0
	for cx in range(width):
		for cy in range(height):
			if not _grid.is_walkable(cx, cy):
				count += 1
	return count


## Check if world position is walkable.
func is_walkable(p_world_x: float, p_world_y: float) -> bool:
	if _grid == null:
		return true
	var cx: int = _world_to_grid_x(p_world_x)
	var cy: int = _world_to_grid_y(p_world_y)
	if cx < 0 or cx >= width or cy < 0 or cy >= height:
		return false
	return _grid.is_walkable(cx, cy)


## Compatibility: return self as grid_map for SoulUnit.set_pathfinding.
func get_grid_map() -> RefCounted:
	return self


## Compatibility: return self as pathfinder for SoulUnit.set_pathfinding.
func get_pathfinder() -> RefCounted:
	return self


# --- Internal helpers ---

func _world_to_grid_x(p_world_x: float) -> int:
	return int(floor((p_world_x - origin_x) / cell_size))


func _world_to_grid_y(p_world_y: float) -> int:
	return int(floor((p_world_y - origin_y) / cell_size))


func _world_to_grid(p_world_x: float, p_world_y: float) -> Vector2i:
	return Vector2i(_world_to_grid_x(p_world_x), _world_to_grid_y(p_world_y))


func _find_nearest_walkable(p_cx: int, p_cy: int, p_max_radius: int) -> Vector2i:
	if _grid == null:
		return Vector2i(-1, -1)
	for r in range(1, p_max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var nx: int = p_cx + dx
				var ny: int = p_cy + dy
				if nx >= 0 and nx < width and ny >= 0 and ny < height and _grid.is_walkable(nx, ny):
					return Vector2i(nx, ny)
	return Vector2i(-1, -1)
