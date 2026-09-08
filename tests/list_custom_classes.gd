extends SceneTree

# List all non-builtin classes to find Arboreus class names

func _initialize():
	print("=== ALL CUSTOM CLASSES ===")

	for i in range(60):
		await process_frame

	var all_classes = ClassDB.get_class_list()
	var builtin_prefixes = ["VisualShader", "Animation", "Audio", "BaseButton", "BoxShape",
		"Camera", "Canvas", "Collision", "Control", "CPUParticles", "DirectionalLight",
		"Environment", "Font", "GPUParticles", "HBox", "HScroll", "HSlider", "HSplit",
		"Image", "Input", "ItemList", "Label", "Light", "Line2D", "LineEdit", "LinkButton",
		"List", "Mesh", "MultiMesh", "Node", "Node2D", "Node3D", "Object", "Occluder",
		"OmniLight", "Option", "Packed", "Panel", "Particle", "Path", "Physical", "Physics",
		"Popup", "Progress", "Projection", "QuadMesh", "Range", "RayCast", "Rectangle",
		"Reference", "Reflection", "Resource", "RichText", "Scene", "Script", "Scroll",
		"Shape", "Skeleton", "Skin", "Slider", "SpinBox", "Split", "Sprite", "SpotLight",
		"Static", "Style", "Surface", "Tab", "Text", "Texture", "Theme", "Tile", "Timer",
		"ToolButton", "Tree", "Tween", "VBox", "Vehicle", "Video", "Viewport", "VScroll",
		"VSlider", "VSplit", "Window", "World", "World2D", "WorldBoundary", "XR",
		"AStar", "AStar2D", "AStarGrid2D", "BackBuffer", "BitMap", "Bone", "Bones",
		"Callback", "Capsule", "Center", "Char", "Circle", "Class", "Codec", "Color",
		"Concave", "Config", "Cone", "Cube", "Curve", "Cylinder", "Damped", "Decal",
		"Dictionary", "Digi", "Display", "Dummy", "Dynamic", "Encoded", "Engine",
		"Expression", "File", "FileAccess", "Float", "Func", "Geometry", "Gradient",
		"Graph", "Groove", "Hashing", "HeightMap", "HMAC", "HashingContext", "ImageTexture",
		"Immediate", "Instance", "Integer", "IP", "JSON", "JSONParse", "Kinematic",
		"Large", "Lightmap", "LightmapGI", "Lottie", "MainLoop", "Marshalls", "Material",
		"Matrix", "Menu", "Mutex", "Navigation", "Network", "Nil", "NinePatch", "Noise",
		"Object", "OS", "Packet", "PacketPeer", "Painter", "Palette", "Panorama",
		"Parallel", "PCK", "Performance", "Permutation", "PhysicsBody", "PhysicsDirect",
		"PhysicsMaterial", "PhysicsServer", "PinJoint", "Plane", "PlaneMesh", "Point",
		"Polygon", "PolyPath", "Position", "Primitive", "Prism", "Project", "ProjectSettings",
		"Proxy", "Quad", "Quaternion", "Random", "Ray", "Rect2", "Rect2i", "RectangleShape",
		"RefCounted", "RegEx", "RegExMatch", "Remote", "Rendering", "RenderingDevice",
		"RenderingServer", "ResourceFormat", "ResourceImporter", "ResourceLoader",
		"ResourceSaver", "Ribbon", "RID", "Rigid", "Root", "Rotation", "Sample",
		"SceneState", "SceneTree", "SceneTreeTimer", "ScriptCreate", "ScriptEditor",
		"ScriptExtension", "ScriptLanguage", "ScriptServer", "ScrollBar", "Segment",
		"Semaphore", "Separator", "Shader", "Shortcut", "Signal", "Skeleton2D",
		"SkeletonModification", "SkeletonProfile", "SkinReference", "Sky", "SliderJoint",
		"SoftBody", "Sphere", "SpinBox", "Spline", "SpotLight3D", "Spring", "Sprite2D",
		"Sprite3D", "SpriteFrames", "Standard", "Star", "StaticBody", "Stream", "StreamPeer",
		"StreamTexture", "String", "StringName", "Struct", "StyleBox", "SubViewport",
		"Surface", "Syntax", "System", "TabContainer", "TabBar", "TextEdit", "TextLine",
		"TextMesh", "TextParagraph", "TextServer", "Texture2D", "Texture3D", "TextureArray",
		"TextureLayered", "Theme", "Thread", "TileMap", "TileSet", "Time", "Timer", "Torus",
		"Touch", "Transform", "Translation", "Triangle", "Tube", "Tween", "UDPServer",
		"Undo", "Uniform", "Unique", "Unit", "Vector", "VehicleBody", "VideoStream",
		"VideoStreamPlayer", "Viewport", "ViewportContainer", "ViewportTexture", "Visible",
		"Visual", "VisualInstance", "VisualShader", "Voxel", "WebRTC", "WebSocket",
		"WebXR", "Wheel", "Window", "World", "World2D", "World3D", "WorldBoundary",
		"X509", "XML", "XR"]

	var custom_classes = []
	for cls in all_classes:
		var is_builtin = false
		for prefix in builtin_prefixes:
			if cls.begins_with(prefix):
				is_builtin = true
				break
		if not is_builtin and cls != "Object" and cls != "RefCounted" and cls != "Node" and cls != "Node2D" and cls != "Node3D" and cls != "Resource" and cls != "MainLoop" and cls != "SceneTree":
			custom_classes.append(cls)

	custom_classes.sort()
	for cls in custom_classes:
		print("  %s" % cls)

	print("\nTotal custom classes: %d" % custom_classes.size())

	# Specifically check for Arboreus-prefixed classes
	print("\n=== ARBOREUS-PREFIXED CLASSES ===")
	for cls in all_classes:
		if cls.to_lower().begins_with("arboreus") or cls.to_lower().begins_with("arbo"):
			print("  %s" % cls)

	# Check for Ember-prefixed classes
	print("\n=== EMBER-PREFIXED CLASSES ===")
	for cls in all_classes:
		if cls.to_lower().begins_with("ember"):
			print("  %s" % cls)

	quit(0)
