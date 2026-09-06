extends RefCounted
## ArenaEnvironment - Weather and terrain effect system for RTS battles
##
## Implements environmental effects that influence combat:
## - Weather types affect movement speed, attack accuracy, and visibility
## - Terrain effects (lava damage, water slowdown) apply per-position
## - Each map has a default weather, can be overridden for variety
##
## Design reference: M2 RTS arena environmental integration
## This is game-specific logic, not SDK kernel code.

## Weather type enum
enum WeatherType {
	CLEAR,   # No modifiers
	RAIN,    # -10% movement, -5% attack accuracy
	FOG,     # -30% visibility, -10% attack accuracy
	SNOW,    # -15% movement, +10% defense (cold resistance)
	STORM    # -20% movement, -15% accuracy, random lightning damage
}

## Current weather
var current_weather: int = WeatherType.CLEAR

## Weather duration timer (seconds)
var weather_timer: float = 0.0
var weather_duration: float = 60.0  # Weather changes every 60 seconds

## Storm lightning timer
var _lightning_timer: float = 0.0
const LIGHTNING_INTERVAL: float = 8.0  # Lightning every 8s in storm

## Map default weather mapping
var _map_default_weather: Dictionary = {
	"default_arena": WeatherType.CLEAR,
	"forest_arena": WeatherType.RAIN,
	"crystal_arena": WeatherType.SNOW
}

## Weather name mapping
var _weather_names: Dictionary = {
	WeatherType.CLEAR: "Clear",
	WeatherType.RAIN: "Rain",
	WeatherType.FOG: "Fog",
	WeatherType.SNOW: "Snow",
	WeatherType.STORM: "Storm"
}


## Initialize environment for a map
func setup_for_map(p_map_name: String) -> void:
	current_weather = _map_default_weather.get(p_map_name, WeatherType.CLEAR)
	weather_timer = 0.0
	_lightning_timer = 0.0
	GameLog.info("ArenaEnvironment: Setup for map %s, weather=%s" % [p_map_name, _weather_names[current_weather]], "Arena")


## Update environment timers (call every frame)
func update(delta: float) -> Dictionary:
	var events: Dictionary = {"weather_changed": false, "lightning": false, "lightning_position": Vector2.ZERO}

	weather_timer += delta
	if weather_timer >= weather_duration:
		weather_timer = 0.0
		_randomize_weather()
		events["weather_changed"] = true

	# Storm lightning
	if current_weather == WeatherType.STORM:
		_lightning_timer += delta
		if _lightning_timer >= LIGHTNING_INTERVAL:
			_lightning_timer = 0.0
			events["lightning"] = true
			events["lightning_position"] = Vector2(
				randi() % 1280,
				randi() % 600
			)

	return events


## Randomize weather (weighted towards current map's default)
func _randomize_weather() -> void:
	var roll = randf()
	if roll < 0.5:
		# 50% chance stay same
		pass
	elif roll < 0.7:
		current_weather = WeatherType.CLEAR
	elif roll < 0.85:
		current_weather = WeatherType.RAIN
	elif roll < 0.95:
		current_weather = WeatherType.FOG
	else:
		current_weather = WeatherType.STORM
	GameLog.info("ArenaEnvironment: Weather changed to %s" % _weather_names[current_weather], "Arena")


## Get movement speed modifier from current weather
func get_weather_movement_modifier() -> float:
	match current_weather:
		WeatherType.CLEAR:
			return 1.0
		WeatherType.RAIN:
			return 0.9
		WeatherType.FOG:
			return 1.0  # Fog doesn't slow movement
		WeatherType.SNOW:
			return 0.85
		WeatherType.STORM:
			return 0.8
	return 1.0


## Get attack accuracy modifier from current weather (0.0-1.0, lower = less accurate)
func get_weather_accuracy_modifier() -> float:
	match current_weather:
		WeatherType.CLEAR:
			return 1.0
		WeatherType.RAIN:
			return 0.95
		WeatherType.FOG:
			return 0.9
		WeatherType.SNOW:
			return 0.95
		WeatherType.STORM:
			return 0.85
	return 1.0


## Get visibility modifier from current weather (for minimap/range)
func get_visibility_modifier() -> float:
	match current_weather:
		WeatherType.CLEAR:
			return 1.0
		WeatherType.RAIN:
			return 0.85
		WeatherType.FOG:
			return 0.7
		WeatherType.SNOW:
			return 0.8
		WeatherType.STORM:
			return 0.6
	return 1.0


## Get defense modifier from current weather
func get_weather_defense_modifier() -> float:
	match current_weather:
		WeatherType.SNOW:
			return 1.1  # Cold resistance bonus
		WeatherType.STORM:
			return 0.95  # Storm makes defense harder
		_:
			return 1.0
	return 1.0


## Get terrain damage at a position (e.g., lava)
## Returns damage per second
func get_terrain_damage(p_position: Vector2) -> float:
	var terrain = ArenaMap.get_terrain_type(p_position)
	match terrain:
		ArenaMap.TerrainType.LAVA:
			return 5.0  # 5 damage per second in lava
		_:
			return 0.0
	return 0.0


## Get terrain movement modifier at a position
func get_terrain_movement_modifier(p_position: Vector2) -> float:
	return ArenaMap.get_terrain_speed_modifier(p_position)


## Get combined movement modifier (weather + terrain)
func get_total_movement_modifier(p_position: Vector2) -> float:
	var weather_mod = get_weather_movement_modifier()
	var terrain_mod = get_terrain_movement_modifier(p_position)
	return weather_mod * terrain_mod


## Get current weather name
func get_weather_name() -> String:
	return _weather_names.get(current_weather, "Unknown")


## Get environment info for UI display
func get_environment_info() -> Dictionary:
	return {
		"weather": get_weather_name(),
		"weather_type": current_weather,
		"movement_mod": get_weather_movement_modifier(),
		"accuracy_mod": get_weather_accuracy_modifier(),
		"visibility_mod": get_visibility_modifier(),
		"defense_mod": get_weather_defense_modifier(),
		"weather_timer": weather_timer,
		"weather_duration": weather_duration
	}


## Force set weather (for testing or special events)
func set_weather(p_weather: int) -> void:
	if p_weather >= 0 and p_weather <= WeatherType.STORM:
		current_weather = p_weather
		weather_timer = 0.0
		GameLog.info("ArenaEnvironment: Weather forced to %s" % _weather_names[current_weather], "Arena")
