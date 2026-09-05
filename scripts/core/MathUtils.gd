class_name MathUtils
extends RefCounted
## MathUtils - Common math utility functions
##
## Static utility class for game math. No game logic, only generic math.
##
## Usage:
##   var dist = MathUtils.distance(a, b)
##   var clamped = MathUtils.clamp(value, 0, 100)
##   var lerped = MathUtils.lerp(a, b, t)
##   var angle = MathUtils.angle_between(a, b)

## Clamp a value between min and max
static func clamp(value: float, min_value: float, max_value: float) -> float:
	return clampf(value, min_value, max_value)


## Linear interpolation between a and b by t (0-1)
static func lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * clamp(t, 0.0, 1.0)


## Frame-rate independent damping (smooth follow)
static func damp(current: float, target: float, smoothing: float, delta: float) -> float:
	return lerp(current, target, 1.0 - exp(-smoothing * delta))


## Map a value from one range to another
static func map_range(value: float, in_min: float, in_max: float, out_min: float, out_max: float) -> float:
	if in_max == in_min:
		return out_min
	return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)


## Distance between two 2D points
static func distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)


## Distance between two 3D points
static func distance_3d(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b)


## Squared distance (faster, for comparisons)
static func distance_squared(a: Vector2, b: Vector2) -> float:
	return a.distance_squared_to(b)


## Angle between two vectors in radians
static func angle_between(a: Vector2, b: Vector2) -> float:
	return a.angle_to(b)


## Angle from one point to another in radians
static func angle_to(from: Vector2, to: Vector2) -> float:
	return (to - from).angle()


## Direction vector from angle (radians)
static func direction_from_angle(angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle))


## Normalize angle to [-PI, PI]
static func normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


## Shortest angular difference (signed, radians)
static func angle_difference(from: float, to: float) -> float:
	return normalize_angle(to - from)


## Rotate a vector by angle (radians)
static func rotate_vector(v: Vector2, angle: float) -> Vector2:
	return v.rotated(angle)


## Move a point towards target by max distance
static func move_toward(current: Vector2, target: Vector2, max_distance: float) -> Vector2:
	var diff := target - current
	var dist := diff.length()
	if dist <= max_distance or dist == 0.0:
		return target
	return current + diff / dist * max_distance


## Move a float towards target by max delta
static func move_toward_float(current: float, target: float, max_delta: float) -> float:
	if abs(target - current) <= max_delta:
		return target
	return current + sign(target - current) * max_delta


## Check if a value is approximately equal (within epsilon)
static func approx(a: float, b: float, epsilon: float = 0.001) -> bool:
	return abs(a - b) < epsilon


## Check if two vectors are approximately equal
static func approx_vector(a: Vector2, b: Vector2, epsilon: float = 0.001) -> bool:
	return approx(a.x, b.x, epsilon) and approx(a.y, b.y, epsilon)


## Wrap a value within [min, max)
static func wrap(value: float, min_value: float, max_value: float) -> float:
	var range := max_value - min_value
	if range == 0:
		return min_value
	return value - range * floor((value - min_value) / range)


## Random float in range [min, max]
static func random_range(min_value: float, max_value: float) -> float:
	return randf_range(min_value, max_value)


## Random integer in range [min, max] inclusive
static func random_int(min_value: int, max_value: int) -> int:
	return randi_range(min_value, max_value)


## Random point in circle
static func random_in_circle(radius: float = 1.0) -> Vector2:
	var angle := randf() * TAU
	var r := sqrt(randf()) * radius
	return Vector2(cos(angle), sin(angle)) * r


## Random point on circle edge
static func random_on_circle(radius: float = 1.0) -> Vector2:
	var angle := randf() * TAU
	return Vector2(cos(angle), sin(angle)) * radius


## Smoothstep interpolation
static func smoothstep(from: float, to: float, t: float) -> float:
	var x := clamp((t - from) / (to - from), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Smootherstep (Ken Perlin's improved)
static func smootherstep(from: float, to: float, t: float) -> float:
	var x := clamp((t - from) / (to - from), 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


## Dot product of two Vector2
static func dot(a: Vector2, b: Vector2) -> float:
	return a.dot(b)


## Cross product of two Vector2 (returns scalar)
static func cross(a: Vector2, b: Vector2) -> float:
	return a.cross(b)


## Perpendicular vector (rotated 90 degrees CCW)
static func perpendicular(v: Vector2) -> Vector2:
	return Vector2(-v.y, v.x)


## Reflect a vector off a normal
static func reflect(v: Vector2, normal: Vector2) -> Vector2:
	return v - 2.0 * v.dot(normal) * normal


## Convert degrees to radians
static func deg_to_rad(degrees: float) -> float:
	return degrees * PI / 180.0


## Convert radians to degrees
static func rad_to_deg(radians: float) -> float:
	return radians * 180.0 / PI


## Inverse lerp: find t from value between a and b
static func inverse_lerp(a: float, b: float, value: float) -> float:
	if b == a:
		return 0.0
	return clamp((value - a) / (b - a), 0.0, 1.0)


## Remap with clamping
static func remap_clamped(value: float, in_min: float, in_max: float, out_min: float, out_max: float) -> float:
	var t := inverse_lerp(in_min, in_max, value)
	return lerp(out_min, out_max, t)


## Ease-in (quadratic)
static func ease_in(t: float) -> float:
	return t * t


## Ease-out (quadratic)
static func ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


## Ease-in-out (quadratic)
static func ease_in_out(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0


## Elastic ease-out
static func elastic_out(t: float) -> float:
	var c4 := (2.0 * PI) / 3.0
	if t == 0.0 or t == 1.0:
		return t
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0


## Bounce ease-out
static func bounce_out(t: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375
