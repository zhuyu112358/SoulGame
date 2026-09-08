@tool
extends EditorPlugin
# Ember Soul Engine - Godot Editor Plugin
# Auto-detects and enables the Ember GDExtension.

func _enter_tree() -> void:
	print("[Ember] Soul Engine v1.0.0 loaded")
	print("[Ember] 15 cognitive classes available:")
	print("[Ember]   Core: SoulData, Personality, EmotionState, CognitiveEngine, MemorySystem, Soul")
	print("[Ember]   Systems: PerceptionSystem, DecisionSystem, ActionSystem, GrowthSystem")
	print("[Ember]   Advanced: RelationshipSystem, SocialSystem, LearningSystem, ConsciousnessSystem, DreamSystem")

func _exit_tree() -> void:
	print("[Ember] Soul Engine unloaded")
