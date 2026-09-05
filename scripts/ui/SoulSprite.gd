extends Node2D
## SoulSprite - Procedurally generated pixel-art soul sprite (128x128)
##
## Generates a pixel-art style soul character using _draw().
## The soul's appearance changes based on its element, mood, and level.
##
## Pixel art style: 16x16 logical pixels scaled to 128x128 (8x scale)
## - Body: glowing orb with eyes
## - Color: based on element (fire=red, water=blue, earth=green, wind=teal, light=gold, dark=purple)
## - Expression: based on mood (happy, neutral, sad, angry, sleepy)
## - Aura: pulsing glow based on level

## Logical pixel size (16x16 grid)
const PIXEL_GRID: int = 16

## Scale factor (128/16 = 8)
const PIXEL_SCALE: int = 8

## Soul element (affects color)
var element: String = "light"

## Soul mood (affects expression)
var mood: String = "neutral"

## Soul level (affects aura intensity)
var soul_level: int = 1

## Animation time for pulsing aura
var _anim_time: float = 0.0

## Element color mapping
var element_colors: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2, 1.0),
	"water": Color(0.2, 0.5, 1.0, 1.0),
	"earth": Color(0.3, 0.8, 0.3, 1.0),
	"wind": Color(0.2, 0.8, 0.8, 1.0),
	"light": Color(1.0, 0.9, 0.3, 1.0),
	"dark": Color(0.6, 0.3, 0.8, 1.0),
	"neutral": Color(0.7, 0.7, 0.9, 1.0)
}

## Pixel data for soul body (16x16, 0=transparent, 1=body, 2=eye, 3=highlight)
var body_pixels: Array = [
	[0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
	[0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
	[0,0,1,1,1,3,3,1,1,3,3,1,1,1,0,0],
	[0,1,1,3,3,1,1,1,1,1,1,3,3,1,1,0],
	[0,1,1,3,1,1,1,1,1,1,1,1,3,1,1,0],
	[1,1,1,1,1,2,2,1,1,2,2,1,1,1,1,1],
	[1,1,1,1,2,2,2,1,1,2,2,2,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
	[0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
	[0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
	[0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
	[0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
]

## Happy mouth pixels
var happy_mouth: Array = [
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0],
	[0,0,0,0,1,0,0,1,1,0,0,1,0,0,0,0],
	[0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
]

## Neutral mouth pixels
var neutral_mouth: Array = [
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
]

## Sad mouth pixels
var sad_mouth: Array = [
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0],
	[0,0,0,0,1,0,0,1,1,0,0,1,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
]


func _ready() -> void:
	GameLog.info("SoulSprite: Initialized (element=%s, mood=%s, level=%d)" % [element, mood, soul_level], "UI")


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()


## Set soul properties and redraw
func set_soul_properties(p_element: String, p_mood: String, p_level: int) -> void:
	element = p_element
	mood = p_mood
	soul_level = p_level
	queue_redraw()


func _draw() -> void:
	var base_color = element_colors.get(element, element_colors["neutral"])
	var aura_intensity = 0.3 + float(soul_level) / 100.0
	var pulse = 0.8 + 0.2 * sin(_anim_time * 3.0)

	# Draw aura (glowing circle behind body)
	var aura_radius = float(PIXEL_GRID * PIXEL_SCALE) / 2.0 + 10.0 * pulse
	var aura_color = Color(base_color.r, base_color.g, base_color.b, aura_intensity * 0.4 * pulse)
	draw_circle(Vector2(64, 64), aura_radius, aura_color)
	draw_circle(Vector2(64, 64), aura_radius * 0.8, Color(base_color.r, base_color.g, base_color.b, aura_intensity * 0.3 * pulse))

	# Draw body pixels
	for y in range(PIXEL_GRID):
		for x in range(PIXEL_GRID):
			var pixel_value = body_pixels[y][x]
			if pixel_value == 0:
				continue

			var pixel_color = base_color
			if pixel_value == 2:
				# Eyes - white with black pupil
				pixel_color = Color(1, 1, 1, 1)
			elif pixel_value == 3:
				# Highlight - lighter shade
				pixel_color = Color(base_color.r + 0.2, base_color.g + 0.2, base_color.b + 0.2, 1)

			var rect = Rect2(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE)
			draw_rect(rect, pixel_color)

	# Draw mouth based on mood
	var mouth_pixels = neutral_mouth
	match mood:
		"happy", "excited", "joyful":
			mouth_pixels = happy_mouth
		"sad", "depressed":
			mouth_pixels = sad_mouth
		"sleepy":
			mouth_pixels = neutral_mouth
		"angry":
			mouth_pixels = neutral_mouth

	var mouth_color = Color(0.1, 0.05, 0.1, 1)
	for y in range(PIXEL_GRID):
		for x in range(PIXEL_GRID):
			if mouth_pixels[y][x] == 1:
				var rect = Rect2(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE)
				draw_rect(rect, mouth_color)

	# Draw sleepy eyes if sleepy
	if mood == "sleepy":
		# Cover top half of eyes
		for y in range(5, 7):
			for x in range(5, 7):
				var rect = Rect2(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE)
				draw_rect(rect, base_color)
			for x in range(9, 11):
				var rect = Rect2(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE)
				draw_rect(rect, base_color)

	# Draw angry eyebrows if angry
	if mood == "angry":
		var brow_color = Color(0.3, 0.0, 0.0, 1)
		# Left eyebrow (diagonal)
		for i in range(3):
			var rect = Rect2((4 + i) * PIXEL_SCALE, (4 - i + 1) * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE)
			draw_rect(rect, brow_color)
		# Right eyebrow (diagonal)
		for i in range(3):
			var rect = Rect2((11 - i) * PIXEL_SCALE, (4 - i + 1) * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE)
			draw_rect(rect, brow_color)
