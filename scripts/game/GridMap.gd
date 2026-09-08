extends RefCounted
class_name NavigationGrid
## Grid-based navigation map for A* pathfinding.
## Ported from Arboreus SDK pathfinding system.
## Supports obstacle marking, 8-directional movement, and world/cell coordinate conversion.

var cell_size: float = 32.0
var width: int = 40  # 1280 / 32
var height: int = 19  # 600 / 32 (approx)
var origin_x: float = 0.0
var origin_y: float = 0.0
var allow_diagonal: bool = true

var _blocked: Array = []  # Flat array: _blocked[height * x + y] = true means blocked

func _init(p_cell_size: float = 32.0, p_width: int = 40, p_height: int = 19, p_origin_x: float = 0.0, p_origin_y: float = 0.0, p_allow_diagonal: bool = true) -> void:
	cell_size = p_cell_size
	width = p_width
	height = p_height
	origin_x = p_origin_x
	origin_y = p_origin_y
	allow_diagonal = p_allow_diagonal
	_blocked.resize(width * height)
	for i in range(width * height):
		_blocked[i] = false


## Convert world x to cell x coordinate.
func world_to_cell_x(p_world_x: float) -> int:
	return int(floor((p_world_x - origin_x) / cell_size))


## Convert world y to cell y coordinate.
func world_to_cell_y(p_world_y: float) -> int:
	return int(floor((p_world_y - origin_y) / cell_size))


## Convert cell x to world x (center of cell).
func cell_to_world_x(p_cell_x: int) -> float:
	return origin_x + (p_cell_x + 0.5) * cell_size


## Convert cell y to world y (center of cell).
func cell_to_world_y(p_cell_y: int) -> float:
	return origin_y + (p_cell_y + 0.5) * cell_size


## Check if a cell coordinate is within grid bounds.
func in_bounds(p_cell_x: int, p_cell_y: int) -> bool:
	return p_cell_x >= 0 and p_cell_x < width and p_cell_y >= 0 and p_cell_y < height


## Check if a world position is walkable.
func is_walkable(p_world_x: float, p_world_y: float) -> bool:
	var cx: int = world_to_cell_x(p_world_x)
	var cy: int = world_to_cell_y(p_world_y)
	if not in_bounds(cx, cy):
		return false
	return not _blocked[cy * width + cx]


## Mark a cell as blocked (true) or walkable (false).
func set_cell(p_cell_x: int, p_cell_y: int, p_blocked: bool) -> void:
	if in_bounds(p_cell_x, p_cell_y):
		_blocked[p_cell_y * width + p_cell_x] = p_blocked


## Mark a world-space AABB region as blocked.
func block_region(p_min_x: float, p_min_y: float, p_max_x: float, p_max_y: float) -> void:
	var min_cx: int = world_to_cell_x(p_min_x)
	var min_cy: int = world_to_cell_y(p_min_y)
	var max_cx: int = world_to_cell_x(p_max_x)
	var max_cy: int = world_to_cell_y(p_max_y)
	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			set_cell(cx, cy, true)


## Clear all blocked cells.
func clear() -> void:
	for i in range(width * height):
		_blocked[i] = false


## Get walkable neighbors of a cell (for A*).
## Returns array of {x, y, cost}.
func get_neighbors(p_cell_x: int, p_cell_y: int) -> Array:
	var neighbors: Array = []
	var directions: Array = [
		{"x": 0, "y": -1, "cost": 1.0},  # Up
		{"x": 0, "y": 1, "cost": 1.0},   # Down
		{"x": -1, "y": 0, "cost": 1.0},  # Left
		{"x": 1, "y": 0, "cost": 1.0},   # Right
	]
	if allow_diagonal:
		directions.append({"x": -1, "y": -1, "cost": 1.414})  # Up-Left
		directions.append({"x": 1, "y": -1, "cost": 1.414})   # Up-Right
		directions.append({"x": -1, "y": 1, "cost": 1.414})   # Down-Left
		directions.append({"x": 1, "y": 1, "cost": 1.414})    # Down-Right
	
	for d in directions:
		var nx: int = p_cell_x + d["x"]
		var ny: int = p_cell_y + d["y"]
		if in_bounds(nx, ny) and not _blocked[ny * width + nx]:
			# For diagonal movement, ensure both adjacent cells are walkable (no corner cutting)
			if d["cost"] > 1.0:
				var adj1_walkable: bool = in_bounds(p_cell_x + d["x"], p_cell_y) and not _blocked[p_cell_y * width + (p_cell_x + d["x"])]
				var adj2_walkable: bool = in_bounds(p_cell_x, p_cell_y + d["y"]) and not _blocked[(p_cell_y + d["y"]) * width + p_cell_x]
				if not adj1_walkable or not adj2_walkable:
					continue
			neighbors.append({"x": nx, "y": ny, "cost": d["cost"]})
	
	return neighbors


## Count blocked cells (for debugging/metrics).
func get_blocked_count() -> int:
	var count: int = 0
	for i in range(width * height):
		if _blocked[i]:
			count += 1
	return count
