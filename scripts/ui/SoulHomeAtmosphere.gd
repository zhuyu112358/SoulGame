extends Node2D
## SoulHomeAtmosphere - Atmospheric effects for the Soul Home scene
##
## Provides ambient particle effects, dynamic lighting, and subtle animations
## to create a cozy, living atmosphere in the soul home.
##
## Features:
## - Floating light particles (dust motes / spirit particles)
## - Dynamic ambient light pulsing
## - Subtle background color shifts
## - All procedurally generated, no external assets needed

## Particle count
const PARTICLE_COUNT: int = 30

## Particle data
var _particles: Array = []

## Ambient light intensity
var _ambient_intensity: float = 0.5

## Animation time
var _time: float = 0.0

## Particle color (based on soul element)
var particle_color: Color = Color(1.0, 0.9, 0.5, 0.6)

## Background base color
var bg_color: Color = Color(0.1, 0.08, 0.15, 1.0)

## Scene dimensions
var scene_width: float = 1280.0
var scene_height: float = 720.0


func _ready() -> void:
	GameLog.info("SoulHomeAtmosphere: Initializing atmosphere effects", "SoulHome")
	_init_particles()
	set_process(true)


## Initialize particles with random positions and velocities
func _init_particles() -> void:
	_particles.clear()
	for i in range(PARTICLE_COUNT):
		var particle = {
			"position": Vector2(
				randf() * scene_width,
				randf() * scene_height
			),
			"velocity": Vector2(
				randf_range(-10, 10),
				randf_range(-20, -5)
			),
			"size": randf_range(2, 6),
			"phase": randf() * TAU,
			"speed": randf_range(0.5, 2.0),
			"alpha": randf_range(0.3, 0.8)
		}
		_particles.append(particle)


func _process(delta: float) -> void:
	_time += delta

	# Update particles
	for i in range(_particles.size()):
		var p = _particles[i]

		# Floating motion with sine wave drift
		p["position"].x += p["velocity"].x * delta + sin(_time * p["speed"] + p["phase"]) * 5 * delta
		p["position"].y += p["velocity"].y * delta

		# Wrap around screen
		if p["position"].y < -10:
			p["position"].y = scene_height + 10
			p["position"].x = randf() * scene_width
		if p["position"].x < -10:
			p["position"].x = scene_width + 10
		if p["position"].x > scene_width + 10:
			p["position"].x = -10

		_particles[i] = p

	# Pulse ambient light
	_ambient_intensity = 0.4 + 0.1 * sin(_time * 0.5)

	queue_redraw()


func _draw() -> void:
	# Draw background gradient
	var bg_rect = Rect2(0, 0, scene_width, scene_height)
	draw_rect(bg_rect, bg_color)

	# Draw subtle radial glow in center
	var center = Vector2(scene_width / 2, scene_height / 2)
	var glow_color = Color(particle_color.r, particle_color.g, particle_color.b, 0.05 * _ambient_intensity)
	for radius in range(100, 400, 50):
		draw_circle(center, float(radius), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * (1.0 - float(radius) / 400.0)))

	# Draw particles
	for p in _particles:
		var pos = p["position"]
		var size = p["size"]
		var alpha = p["alpha"] * (0.7 + 0.3 * sin(_time * p["speed"] + p["phase"]))

		# Particle glow
		var glow = Color(particle_color.r, particle_color.g, particle_color.b, alpha * 0.3)
		draw_circle(pos, size * 2, glow)

		# Particle core
		var core = Color(particle_color.r, particle_color.g, particle_color.b, alpha)
		draw_circle(pos, size, core)

		# Bright center
		var bright = Color(1, 1, 1, alpha * 0.8)
		draw_circle(pos, size * 0.4, bright)


## Set the soul element to adjust atmosphere colors
func set_element(p_element: String) -> void:
	match p_element:
		"fire":
			particle_color = Color(1.0, 0.5, 0.2, 0.6)
			bg_color = Color(0.15, 0.05, 0.05, 1.0)
		"water":
			particle_color = Color(0.3, 0.6, 1.0, 0.6)
			bg_color = Color(0.05, 0.08, 0.15, 1.0)
		"earth":
			particle_color = Color(0.4, 0.9, 0.4, 0.6)
			bg_color = Color(0.05, 0.12, 0.05, 1.0)
		"wind":
			particle_color = Color(0.3, 0.9, 0.9, 0.6)
			bg_color = Color(0.05, 0.12, 0.12, 1.0)
		"light":
			particle_color = Color(1.0, 0.95, 0.4, 0.6)
			bg_color = Color(0.12, 0.1, 0.05, 1.0)
		"dark":
			particle_color = Color(0.7, 0.4, 1.0, 0.6)
			bg_color = Color(0.08, 0.05, 0.12, 1.0)
		_:
			particle_color = Color(0.8, 0.8, 1.0, 0.6)
			bg_color = Color(0.1, 0.08, 0.15, 1.0)

	queue_redraw()


## Set scene dimensions
func set_dimensions(p_width: float, p_height: float) -> void:
	scene_width = p_width
	scene_height = p_height
