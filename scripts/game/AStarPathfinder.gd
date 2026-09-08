extends RefCounted
class_name AStarPathfinder
## TODO: 临时实现，待Arboreus SDK提供GDScript版本PathfinderSystem后替换
## A* pathfinding algorithm over a GridMap.
## Ported from Arboreus SDK pathfinding system.
## Uses binary heap for open set, octile distance heuristic.
## Returns array of world-space waypoints from start to goal, or empty array if no path.

var max_iterations: int = 100000

# Internal node structure: {x, y, g, f, parent}
var _open: Array = []  # Binary min-heap
var _g_score: Dictionary = {}  # key = y * width + x
var _closed: Dictionary = {}

func _init(p_max_iterations: int = 100000) -> void:
	max_iterations = p_max_iterations


## Find a path from start to goal on the given grid.
## Returns array of Vector2 waypoints in world space, or empty array if unreachable.
func find_path(p_start_x: float, p_start_y: float, p_goal_x: float, p_goal_y: float, p_grid: RefCounted) -> Array:
	var start_cx: int = p_grid.world_to_cell_x(p_start_x)
	var start_cy: int = p_grid.world_to_cell_y(p_start_y)
	var goal_cx: int = p_grid.world_to_cell_x(p_goal_x)
	var goal_cy: int = p_grid.world_to_cell_y(p_goal_y)
	
	# Bounds check
	if not p_grid.in_bounds(start_cx, start_cy) or not p_grid.in_bounds(goal_cx, goal_cy):
		return []
	
	# If goal is blocked, try to find nearest walkable cell
	var actual_goal_x: int = goal_cx
	var actual_goal_y: int = goal_cy
	if not p_grid.is_walkable(p_goal_x, p_goal_y):
		var nearest = _find_nearest_walkable(goal_cx, goal_cy, p_grid, 10)
		if nearest.is_empty():
			return []
		actual_goal_x = nearest["x"]
		actual_goal_y = nearest["y"]
	
	# If start is blocked, try nearest walkable
	var actual_start_x: int = start_cx
	var actual_start_y: int = start_cy
	if not p_grid.is_walkable(p_start_x, p_start_y):
		var nearest = _find_nearest_walkable(start_cx, start_cy, p_grid, 10)
		if nearest.is_empty():
			return []
		actual_start_x = nearest["x"]
		actual_start_y = nearest["y"]
	
	# Initialize
	_open.clear()
	_g_score.clear()
	_closed.clear()
	
	var start_node: Dictionary = {
		"x": actual_start_x,
		"y": actual_start_y,
		"g": 0.0,
		"f": _heuristic(actual_start_x, actual_start_y, actual_goal_x, actual_goal_y, p_grid),
		"parent": null
	}
	_heap_push(start_node)
	_g_score[actual_start_y * p_grid.get("width") + actual_start_x] = 0.0
	
	var cells_explored: int = 0
	GameLog.debug("AStar: start=(%d,%d) goal=(%d,%d) start_walkable=%s goal_walkable=%s" % [
		actual_start_x, actual_start_y, actual_goal_x, actual_goal_y,
		str(p_grid.is_walkable(p_start_x, p_start_y)), str(p_grid.is_walkable(p_goal_x, p_goal_y))
	], "Arena")
	
	while _open.size() > 0 and cells_explored < max_iterations:
		var current = _heap_pop()
		cells_explored += 1
		var current_key: int = current["y"] * p_grid.get("width") + current["x"]
		
		if current["x"] == actual_goal_x and current["y"] == actual_goal_y:
			return _reconstruct_path(current, p_grid)
		
		if _closed.has(current_key):
			continue
		_closed[current_key] = true
		
		for neighbor in p_grid.get_neighbors(current["x"], current["y"]):
			var neighbor_key: int = neighbor["y"] * p_grid.get("width") + neighbor["x"]
			if _closed.has(neighbor_key):
				continue
			
			var tentative_g: float = current["g"] + neighbor["cost"] * p_grid.get("cell_size")
			var existing_g = _g_score.get(neighbor_key, null)
			if existing_g != null and tentative_g >= existing_g:
				continue
			
			_g_score[neighbor_key] = tentative_g
			var neighbor_node: Dictionary = {
				"x": neighbor["x"],
				"y": neighbor["y"],
				"g": tentative_g,
				"f": tentative_g + _heuristic(neighbor["x"], neighbor["y"], actual_goal_x, actual_goal_y, p_grid),
				"parent": current
			}
			_heap_push(neighbor_node)
	
	return []  # No path found or max iterations reached


## Octile distance heuristic (optimal for 8-directional grid).
func _heuristic(p_x1: int, p_y1: int, p_x2: int, p_y2: int, p_grid: RefCounted) -> float:
	var dx: int = abs(p_x1 - p_x2)
	var dy: int = abs(p_y1 - p_y2)
	if p_grid.get("allow_diagonal"):
		return (dx + dy + (1.414 - 2.0) * min(dx, dy)) * p_grid.get("cell_size")
	return (dx + dy) * p_grid.get("cell_size")


## Reconstruct world-space waypoints from the goal node back to start.
func _reconstruct_path(p_goal: Dictionary, p_grid: RefCounted) -> Array:
	var cells: Array = []
	var current = p_goal
	while current != null:
		cells.append({"x": current["x"], "y": current["y"]})
		current = current["parent"]
	cells.reverse()
	
	# Convert to world space, skip the start cell (caller already there)
	var waypoints: Array = []
	for i in range(1, cells.size()):
		var wx: float = p_grid.cell_to_world_x(cells[i]["x"])
		var wy: float = p_grid.cell_to_world_y(cells[i]["y"])
		waypoints.append(Vector2(wx, wy))
	
	return waypoints


## BFS search for nearest walkable cell within max_radius.
func _find_nearest_walkable(p_cx: int, p_cy: int, p_grid: RefCounted, p_max_radius: int) -> Dictionary:
	for r in range(1, p_max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue  # only perimeter
				var nx: int = p_cx + dx
				var ny: int = p_cy + dy
				if p_grid.in_bounds(nx, ny) and p_grid.is_walkable(p_grid.cell_to_world_x(nx), p_grid.cell_to_world_y(ny)):
					return {"x": nx, "y": ny}
	return {}


## Binary min-heap: push node.
func _heap_push(p_node: Dictionary) -> void:
	_open.append(p_node)
	_heap_bubble_up(_open.size() - 1)


## Binary min-heap: pop node with lowest f.
func _heap_pop() -> Dictionary:
	if _open.size() == 0:
		return {}
	var top = _open[0]
	var last = _open.pop_back()
	if _open.size() > 0:
		_open[0] = last
		_heap_bubble_down(0)
	return top


## Binary min-heap: bubble up.
func _heap_bubble_up(p_index: int) -> void:
	var i: int = p_index
	while i > 0:
		var parent: int = (i - 1) / 2
		if _open[parent]["f"] <= _open[i]["f"]:
			break
		var temp = _open[parent]
		_open[parent] = _open[i]
		_open[i] = temp
		i = parent


## Binary min-heap: bubble down.
func _heap_bubble_down(p_index: int) -> void:
	var i: int = p_index
	var n: int = _open.size()
	while true:
		var smallest: int = i
		var left: int = 2 * i + 1
		var right: int = 2 * i + 2
		if left < n and _open[left]["f"] < _open[smallest]["f"]:
			smallest = left
		if right < n and _open[right]["f"] < _open[smallest]["f"]:
			smallest = right
		if smallest == i:
			break
		var temp = _open[smallest]
		_open[smallest] = _open[i]
		_open[i] = temp
		i = smallest
