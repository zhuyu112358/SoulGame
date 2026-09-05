class_name PhysicsUtils
extends RefCounted
## PhysicsUtils - Common physics and collision utility functions
##
## Static utility class for 2D physics calculations. No game logic,
## only generic math and physics helpers.
##
## Usage:
##   var hit = PhysicsUtils.ray_cast(origin, direction, 100)
##   var collision = PhysicsUtils.check_circle_collision(a, b, radius)

## MathUtils preload (class_name may not be registered in all contexts)
const MathUtils = preload("res://scripts/core/MathUtils.gd")
##   var velocity = PhysicsUtils.apply_friction(velocity, 0.9, delta)

## Ray cast in 2D space
## space_state: DirectSpaceState2D from get_world_2d().direct_space_state
## Returns dictionary with {collision, position, normal, collider} or empty if no hit
static func ray_cast(space_state: PhysicsDirectSpaceState2D, from: Vector2, direction: Vector2, distance: float, collision_mask: int = 0x7FFFFFFF, exclude: Array = []) -> Dictionary:
	if space_state == null:
		return {}

	var query = PhysicsRayQueryParameters2D.create(from, from + direction.normalized() * distance, collision_mask)
	query.exclude = exclude
	var result = space_state.intersect_ray(query)
	return result


## Circle overlap check
static func check_circle_collision(center_a: Vector2, radius_a: float, center_b: Vector2, radius_b: float) -> bool:
	return center_a.distance_to(center_b) < radius_a + radius_b


## Rectangle overlap check (AABB)
static func check_rect_collision(rect_a: Rect2, rect_b: Rect2) -> bool:
	return rect_a.intersects(rect_b)


## Point in circle check
static func point_in_circle(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_to(center) <= radius


## Point in rectangle check
static func point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)


## Distance from point to line segment
## Returns closest point on segment and distance
static func distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Dictionary:
	var ap = point - segment_start
	var ab = segment_end - segment_start
	var ab2 = ab.dot(ab)

	if ab2 == 0.0:
		var dist: float = point.distance_to(segment_start)
		return {"closest_point": segment_start, "distance": dist}

	var t: float = clamp(ap.dot(ab) / ab2, 0.0, 1.0)
	var closest: Vector2 = segment_start + ab * t
	var dist: float = point.distance_to(closest)
	return {"closest_point": closest, "distance": dist, "t": t}


## Apply friction/drag to velocity
static func apply_friction(velocity: Vector2, friction: float, delta: float) -> Vector2:
	var decay = pow(friction, delta)
	return velocity * decay


## Apply gravity to velocity
static func apply_gravity(velocity: Vector2, gravity: float, delta: float, direction: Vector2 = Vector2.DOWN) -> Vector2:
	return velocity + direction * gravity * delta


## Clamp velocity to max speed
static func clamp_velocity(velocity: Vector2, max_speed: float) -> Vector2:
	if velocity.length() > max_speed:
		return velocity.normalized() * max_speed
	return velocity


## Calculate bounce velocity off a normal
static func bounce(velocity: Vector2, normal: Vector2, bounciness: float = 1.0) -> Vector2:
	return velocity - (1.0 + bounciness) * velocity.dot(normal) * normal


## Calculate steering force (for AI movement)
static func seek(current_pos: Vector2, target_pos: Vector2, current_velocity: Vector2, max_speed: float, max_force: float) -> Vector2:
	var desired = (target_pos - current_pos).normalized() * max_speed
	var steering = desired - current_velocity
	return clamp_velocity(steering, max_force)


## Calculate arrival steering (slows down near target)
static func arrive(current_pos: Vector2, target_pos: Vector2, current_velocity: Vector2, max_speed: float, max_force: float, slowing_radius: float = 50.0) -> Vector2:
	var to_target = target_pos - current_pos
	var distance = to_target.length()

	var desired = to_target.normalized() * max_speed
	if distance < slowing_radius:
		desired *= distance / slowing_radius

	var steering = desired - current_velocity
	return clamp_velocity(steering, max_force)


## Calculate separation force (avoid crowding)
static func separation(current_pos: Vector2, neighbors: Array, desired_separation: float) -> Vector2:
	var steer = Vector2.ZERO
	var count = 0

	for neighbor in neighbors:
		var d = current_pos.distance_to(neighbor)
		if d > 0 and d < desired_separation:
			var diff: Vector2 = (current_pos - neighbor).normalized() / d
			steer += diff
			count += 1

	if count > 0:
		steer /= count
	return steer


## Line-line intersection
## Returns intersection point or null if parallel
static func line_intersection(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Vector2:
	var denom = (a1.x - a2.x) * (b1.y - b2.y) - (a1.y - a2.y) * (b1.x - b2.x)
	if abs(denom) < 0.0001:
		return Vector2.ZERO

	var t = ((a1.x - b1.x) * (b1.y - b2.y) - (a1.y - b1.y) * (b1.x - b2.x)) / denom
	return a1 + (a2 - a1) * t


## Check if lines intersect (within segments)
static func segments_intersect(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var d1 = _cross(b2 - b1, a1 - b1)
	var d2 = _cross(b2 - b1, a2 - b1)
	var d3 = _cross(a2 - a1, b1 - a1)
	var d4 = _cross(a2 - a1, b2 - a1)

	if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
		return true
	return false


## Convert screen position to world position (for camera)
static func screen_to_world(screen_pos: Vector2, camera: Camera2D, viewport_size: Vector2) -> Vector2:
	return camera.get_global_transform().affine_inverse() * (screen_pos - viewport_size / 2.0)


## Kinematic body move and slide (simplified)
## space_state: DirectSpaceState2D from get_world_2d().direct_space_state
## Returns final position after collision
static func move_and_slide(space_state: PhysicsDirectSpaceState2D, position: Vector2, velocity: Vector2, delta: float, collision_layer: int = 0x7FFFFFFF) -> Dictionary:
	if space_state == null:
		return {"position": position + velocity * delta, "velocity": velocity, "collision": false}

	var motion = velocity * delta
	var result = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(position, position + motion, collision_layer))

	if not result.is_empty():
		var hit_pos: Vector2 = result["position"]
		var normal: Vector2 = result["normal"]
		# Slide along surface
		var remaining = (position + motion) - hit_pos
		var slide = remaining - normal * remaining.dot(normal)
		return {
			"position": hit_pos + slide * 0.99,
			"velocity": velocity.slide(normal),
			"collision": true,
			"normal": normal,
			"collider": result.get("collider", null)
		}

	return {"position": position + motion, "velocity": velocity, "collision": false}


## Calculate angular velocity to face target
static func look_at_rotation(current_rotation: float, target_angle: float, rotation_speed: float, delta: float) -> float:
	var diff: float = MathUtils.normalize_angle(target_angle - current_rotation)
	var max_rotation = rotation_speed * delta
	if abs(diff) <= max_rotation:
		return target_angle
	return current_rotation + sign(diff) * max_rotation


## Projectile trajectory calculation
## Returns position at time t given initial velocity and gravity
static func projectile_position(start: Vector2, velocity: Vector2, gravity: float, t: float) -> Vector2:
	return start + velocity * t + Vector2.DOWN * gravity * t * t * 0.5


## Projectile velocity needed to hit target (angle-based)
static func projectile_velocity(start: Vector2, target: Vector2, angle: float, gravity: float) -> Vector2:
	var dx = target.x - start.x
	var dy = target.y - start.y
	var cos_a = cos(angle)
	var sin_a = sin(angle)

	if cos_a == 0:
		return Vector2.ZERO

	var v2 = gravity * dx * dx / (2.0 * cos_a * cos_a * (dx * tan(angle) - dy))
	if v2 <= 0:
		return Vector2.ZERO

	var v = sqrt(v2)
	return Vector2(v * cos_a, v * sin_a)


## Spring physics (damped harmonic oscillator)
static func spring_damper(current: float, target: float, velocity: float, stiffness: float, damping: float, delta: float) -> Dictionary:
	var force = -stiffness * (current - target) - damping * velocity
	var new_velocity = velocity + force * delta
	var new_position = current + new_velocity * delta
	return {"position": new_position, "velocity": new_velocity}


## 2D spring damper
static func spring_damper_2d(current: Vector2, target: Vector2, velocity: Vector2, stiffness: float, damping: float, delta: float) -> Dictionary:
	var force = -stiffness * (current - target) - damping * velocity
	var new_velocity = velocity + force * delta
	var new_position = current + new_velocity * delta
	return {"position": new_position, "velocity": new_velocity}


## --- Internal ---

static func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x
