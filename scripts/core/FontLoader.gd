extends RefCounted
## FontLoader - Utility for loading and applying custom pixel fonts
##
## Attempts to load custom pixel font from assets/fonts/. Falls back to
## Godot default font if custom font not available.
##
## Usage:
##   const FontLoader = preload("res://scripts/core/FontLoader.gd")
##   FontLoader.apply_font_to_control(control)
##   var font = FontLoader.get_custom_font()

## Cached custom font (null if not available)
static var _cached_font: Font = null
static var _checked: bool = false

## Paths to try for custom pixel font
const FONT_PATHS := [
	"res://assets/fonts/pixel_font.ttf",
	"res://assets/fonts/pixel_font.otf",
	"res://assets/fonts/battleplan_font.ttf",
	"res://assets/fonts/battleplan_pixel.ttf",
]


## Get custom pixel font, or null if not available
static func get_custom_font() -> Font:
	if _checked:
		return _cached_font
	_checked = true
	for path in FONT_PATHS:
		if ResourceLoader.exists(path):
			var font = load(path)
			if font and font is Font:
				_cached_font = font
				GameLog.info("FontLoader: Loaded custom font from %s" % path, "UI")
				return _cached_font
	GameLog.warning("FontLoader: No custom pixel font found, using default", "UI")
	return null


## Apply custom font to a Control and all its children
static func apply_font_to_control(p_control: Control) -> void:
	var font = get_custom_font()
	if not font:
		return  # Use default font
	_apply_font_recursive(p_control, font)


## Recursively apply font to control tree
static func _apply_font_recursive(p_node: Node, p_font: Font) -> void:
	if p_node is Control:
		var ctrl = p_node as Control
		# Apply font override
		ctrl.add_theme_font_override("font", p_font)
		# Also apply to common font sizes
		ctrl.add_theme_font_size_override("font_size", 16)
	# Recurse to children
	for child in p_node.get_children():
		_apply_font_recursive(child, p_font)


## Check if custom font is available
static func has_custom_font() -> bool:
	return get_custom_font() != null


## Reset cache (for testing or font hot-reload)
static func reset_cache() -> void:
	_cached_font = null
	_checked = false
