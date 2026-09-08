@tool
extends EditorPlugin
# Ember Soul Engine - Godot Editor Plugin
# Provides a Soul Inspector dock for debugging NPC cognition during playtesting.

var _dock: Control = null
var _dock_script: Script = null

const CLASSES_CORE = ["SoulData", "Personality", "EmotionState", "CognitiveEngine", "MemorySystem", "Soul"]
const CLASSES_SYSTEMS = ["PerceptionSystem", "DecisionSystem", "ActionSystem", "GrowthSystem", "SoulPool"]
const CLASSES_ADVANCED = ["RelationshipSystem", "SocialSystem", "LearningSystem", "ConsciousnessSystem", "DreamSystem"]
const CLASSES_AI = ["GoalPlanner", "BayesianNetwork"]


func _enter_tree() -> void:
	print("[Ember] Soul Engine v1.1.0 loaded")
	print("[Ember] 18 cognitive classes available:")
	print("[Ember]   Core: %s" % ", ".join(CLASSES_CORE))
	print("[Ember]   Systems: %s" % ", ".join(CLASSES_SYSTEMS))
	print("[Ember]   Advanced: %s" % ", ".join(CLASSES_ADVANCED))
	print("[Ember]   AI: %s" % ", ".join(CLASSES_AI))

	# Create and add the Soul Inspector dock
	_dock_script = load("res://addons/ember/editor/soul_inspector_dock.gd")
	if _dock_script:
		_dock = Control.new()
		_dock.set_script(_dock_script)
		_dock.name = "EmberSoulInspector"
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
		print("[Ember] Soul Inspector dock added")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	print("[Ember] Soul Engine unloaded")


func _has_main_screen() -> bool:
	return false


func _apply_changes() -> void:
	pass
