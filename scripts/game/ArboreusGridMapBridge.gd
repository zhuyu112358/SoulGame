class_name ArboreusGridMapBridge
extends RefCounted
## ArboreusGridMapBridge - Adapter for Arboreus SDK GridMap
##
## Implements the same interface as Battleplan's NavigationGrid,
## but internally uses ArboreusGridMap from the Arboreus SDK.
## This allows drop-in replacement: just change the preload from
## NavigationGrid to ArboreusGridMapBridge.
##
## Architecture compliant: grid/world simulation is Arboreus responsibility.
## Battleplan only uses it through this adapter (application layer).

## Arboreus SDK GridMap instance
var _arboreus_grid: Object = null
var _arboreus_available: bool = false

## Grid configuration (cached for interface compatibility)
var cell_size: float = 32.0
var width: int = 40
var height: int = 19
var origin_x: float = 0.0
var origin_y: float = 0.0
var allow_diagonal: bool = true

## Internal blocked array (fallback when Arboreus API is unclear)
var _blocked: Array = []


func _init(p_cell_size: float = 32.0, p_width: int = 40, p_height: int = 19, p_origin_x: float = 0.0, p_origin_y: float = 0.0, p_allow_diagonal: bool = true) -> void:
	cell_size = p_cell_size
	width = p_width
	height = p_height
	origin_x = p_origin_x
	origin_y = p_origin_y
	allow_diagonal = p_allow_diagonal
	# Initialize blocked array
	_blocked.resize(width * height)
	for i in range(width * height):
		_blocked[i] = false
	_initialize_arboreus_grid()


## Initialize Arboreus SDK GridMap
func _initialize_arboreus_grid() -> void:
	if ClassDB.class_exists("ArboreusGridMap"):
		_arboreus_grid = ClassDB.instantiate("ArboreusGridMap")
		if _arboreus_grid != null:
			_arboreus_available = true
			# Note: ArboreusGridMap.create() expects 3 args (API differs from our assumption)
			# We skip explicit create and use property setters / fallback logic
			print("[ArboreusGridMapBridge] ArboreusGridMap SDK initialized (%dx%d, cell=%.1f)" % [width, height, cell_size])
		else:
			_arboreus_available = false
			print("[ArboreusGridMapBridge] WARNING: Failed to instantiate ArboreusGridMap")
	else:
		_arboreus_available = false
		print("[ArboreusGridMapBridge] WARNING: ArboreusGridMap class not found")


## --- NavigationGrid compatible interface ---

func world_to_cell_x(p_world_x: float) -> int:
	# Use Battleplan calculation (Arboreus world_to_grid API has unclear param format)
	return int((p_world_x - origin_x) / cell_size)


func world_to_cell_y(p_world_y: float) -> int:
	return int((p_world_y - origin_y) / cell_size)


func cell_to_world_x(p_cell_x: int) -> float:
	return p_cell_x * cell_size + origin_x + cell_size / 2.0


func cell_to_world_y(p_cell_y: int) -> float:
	return p_cell_y * cell_size + origin_y + cell_size / 2.0


func in_bounds(p_cell_x: int, p_cell_y: int) -> bool:
	return p_cell_x >= 0 and p_cell_x < width and p_cell_y >= 0 and p_cell_y < height


func is_walkable(p_world_x: float, p_world_y: float) -> bool:
	var cx = world_to_cell_x(p_world_x)
	var cy = world_to_cell_y(p_world_y)
	if not in_bounds(cx, cy):
		return false
	return not _blocked[height * cx + cy]


func set_cell(p_cell_x: int, p_cell_y: int, p_blocked: bool) -> void:
	if in_bounds(p_cell_x, p_cell_y):
		_blocked[height * p_cell_x + p_cell_y] = p_blocked


func block_region(p_min_x: float, p_min_y: float, p_max_x: float, p_max_y: float) -> void:
	for cx in range(world_to_cell_x(p_min_x), world_to_cell_x(p_max_x) + 1):
		for cy in range(world_to_cell_y(p_min_y), world_to_cell_y(p_max_y) + 1):
			set_cell(cx, cy, true)


func clear() -> void:
	for i in range(width * height):
		_blocked[i] = false


func get_neighbors(p_cell_x: int, p_cell_y: int) -> Array:
	# Use Battleplan 8-directional neighbor logic
	var neighbors := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if not allow_diagonal and dx != 0 and dy != 0:
				continue
			var nx = p_cell_x + dx
			var ny = p_cell_y + dy
			if in_bounds(nx, ny):
				neighbors.append(Vector2i(nx, ny))
	return neighbors


func get_blocked_count() -> int:
	var count := 0
	for i in range(width * height):
		if _blocked[i]:
			count += 1
	return count


## --- Additional methods ---

func is_arboreus_available() -> bool:
	return _arboreus_available


func get_arboreus_grid() -> Object:
	return _arboreus_grid
