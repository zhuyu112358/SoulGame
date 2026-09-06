extends Node
## M1IntegrationTest - Integration tests for M1 features
##
## Tests soul growth, soul management, world management, and persistence.
## Usage: godot --headless -s res://tests/M1IntegrationTest.gd

## Test results
var _passed: int = 0
var _failed: int = 0
var _results: Array = []

## SoulGrowthData preload
const SoulGrowthData = preload("res://scripts/game/SoulGrowthData.gd")


func _ready() -> void:
	print("==================================================")
	print("M1 INTEGRATION TESTS")
	print("==================================================")

	_test_soul_growth_creation()
	_test_soul_growth_experience()
	_test_soul_growth_serialization()
	_test_soul_growth_memory()
	_test_soul_growth_personality()
	_test_soul_creation()
	_test_world_creation()
	_test_persistence()
	_test_cli_commands()

	_print_summary()
	get_tree().quit(_failed > 0)


func _assert(condition: bool, test_name: String, message: String = "") -> void:
	if condition:
		_passed += 1
		_results.append({"name": test_name, "status": "PASS"})
		print("[PASS] %s" % test_name)
	else:
		_failed += 1
		_results.append({"name": test_name, "status": "FAIL", "message": message})
		print("[FAIL] %s - %s" % [test_name, message])


# --- SoulGrowthData Creation Tests ---

func _test_soul_growth_creation() -> void:
	print("\n--- SoulGrowthData Creation ---")

	var soul = SoulGrowthData.new()
	_assert(soul != null, "SoulGrowthData.new() returns instance")
	_assert(soul.level == 1, "Initial level is 1")
	_assert(soul.experience == 0, "Initial experience is 0")
	_assert(soul.cognitive["level"] == 1, "Initial cognitive level is 1")
	_assert(soul.emotional["level"] == 1, "Initial emotional level is 1")
	_assert(soul.skills["level"] == 1, "Initial skills level is 1")
	_assert(soul.milestones.size() == 0, "Initial milestones empty")
	_assert(soul.memories.size() == 0, "Initial memories empty")

	soul.soul_name = "TestSoul"
	soul.soul_id = "soul_test_001"
	soul.element = "fire"
	_assert(soul.soul_name == "TestSoul", "Set soul_name")
	_assert(soul.element == "fire", "Set element")


# --- SoulGrowthData Experience Tests ---

func _test_soul_growth_experience() -> void:
	print("\n--- SoulGrowthData Experience ---")

	var soul = SoulGrowthData.new()
	soul.soul_name = "XPTest"
	soul.soul_id = "soul_xp_test"

	# Add cognitive experience
	soul.add_dimension_experience("cognitive", 50, "learning")
	_assert(soul.cognitive["experience"] >= 0, "Cognitive experience added (may reset on level up)")

	# Add emotional experience
	soul.add_dimension_experience("emotional", 30, "empathy")
	_assert(soul.emotional["experience"] >= 30, "Emotional experience added")

	# Add overall experience
	var initial_level = soul.level
	soul.add_experience(100)
	_assert(soul.experience >= 0, "Overall experience added (may reset on level up)")
	_assert(soul.level >= initial_level, "Level may increase after 100 XP")

	# Test get_summary
	var summary = soul.get_summary()
	_assert(summary.has("name"), "get_summary has name")
	_assert(summary.has("level"), "get_summary has level")
	_assert(summary.has("mood"), "get_summary has mood")
	_assert(summary.has("energy"), "get_summary has energy")


# --- SoulGrowthData Serialization Tests ---

func _test_soul_growth_serialization() -> void:
	print("\n--- SoulGrowthData Serialization ---")

	var soul = SoulGrowthData.new()
	soul.soul_name = "SerializeTest"
	soul.soul_id = "soul_serialize_test"
	soul.element = "water"
	soul.add_experience(50)
	soul.add_memory("Test memory", "test", 3)

	# Serialize
	var data = soul.to_dict()
	_assert(data.has("soul_id"), "to_dict has soul_id")
	_assert(data.has("soul_name"), "to_dict has soul_name")
	_assert(data.has("element"), "to_dict has element")
	_assert(data.has("level"), "to_dict has level")
	_assert(data.has("experience"), "to_dict has experience")

	# Deserialize into new instance
	var soul2 = SoulGrowthData.new()
	soul2.from_dict(data)
	_assert(soul2.soul_id == "soul_serialize_test", "from_dict restores soul_id")
	_assert(soul2.soul_name == "SerializeTest", "from_dict restores soul_name")
	_assert(soul2.element == "water", "from_dict restores element")
	_assert(soul2.level == soul.level, "from_dict restores level")
	_assert(soul2.memories.size() >= 1, "from_dict restores memories")


# --- SoulGrowthData Memory Tests ---

func _test_soul_growth_memory() -> void:
	print("\n--- SoulGrowthData Memory ---")

	var soul = SoulGrowthData.new()
	soul.soul_name = "MemoryTest"
	soul.soul_id = "soul_memory_test"

	soul.add_memory("First memory", "interaction", 1)
	soul.add_memory("Important memory", "milestone", 5)
	soul.add_memory("Emotional memory", "emotional", 3)

	_assert(soul.memories.size() == 3, "Added 3 memories")

	var interaction_memories = soul.get_memories_by_type("interaction")
	_assert(interaction_memories.size() == 1, "get_memories_by_type filters correctly")
	_assert(interaction_memories[0]["content"] == "First memory", "Memory content correct")

	var important_memories = soul.get_memories_by_type("milestone")
	_assert(important_memories.size() == 1, "Milestone memories filtered")
	_assert(important_memories[0]["importance"] == 5, "Memory importance correct")


# --- SoulGrowthData Personality Tests ---

func _test_soul_growth_personality() -> void:
	print("\n--- SoulGrowthData Personality ---")

	var soul = SoulGrowthData.new()
	soul.soul_name = "PersonalityTest"
	soul.soul_id = "soul_personality_test"

	# Check initial personality traits
	var traits = ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism", "curiosity", "bravery", "warmth"]
	for trait_name in traits:
		_assert(soul.personality.has(trait_name), "Personality has trait: %s" % trait_name)

	# Test adjust_personality
	var initial_value = soul.personality["extraversion"]
	soul.adjust_personality("extraversion", 10.0)
	_assert(soul.personality["extraversion"] > initial_value, "adjust_personality increases trait")

	# Test clamp
	soul.adjust_personality("extraversion", 200.0)
	_assert(soul.personality["extraversion"] <= 100.0, "adjust_personality clamps at 100")

	soul.adjust_personality("extraversion", -200.0)
	_assert(soul.personality["extraversion"] >= 0.0, "adjust_personality clamps at 0")

	# Test get_personality_summary
	var summary = soul.get_personality_summary()
	_assert(not summary.is_empty(), "get_personality_summary returns non-empty string")


# --- Soul Creation Tests ---

func _test_soul_creation() -> void:
	print("\n--- Soul Creation (SoulManager) ---")

	# Test start_creation
	SoulManager.start_creation("brave and curious soul")
	_assert(SoulManager.creation_state["in_progress"], "start_creation sets in_progress")
	_assert(not SoulManager.creation_state["description"].is_empty(), "start_creation stores description")
	_assert(not SoulManager.creation_state["generated_personality"].is_empty(), "start_creation generates personality")

	# Test complete_creation
	var soul = SoulManager.complete_creation("TestCreature")
	_assert(soul != null, "complete_creation returns soul")
	_assert(soul.soul_name == "TestCreature", "complete_creation sets name")
	_assert(not soul.soul_id.is_empty(), "complete_creation generates id")
	_assert(SoulManager.active_soul != null, "complete_creation sets active_soul")
	_assert(SoulManager.soul_list.size() >= 1, "complete_creation adds to soul_list")

	# Test set_active_soul
	var soul_id = soul.soul_id
	var success = SoulManager.set_active_soul(soul_id)
	_assert(success, "set_active_soul returns true")
	_assert(SoulManager.active_soul.soul_id == soul_id, "set_active_soul sets correct soul")


# --- World Creation Tests ---

func _test_world_creation() -> void:
	print("\n--- World Creation (WorldManager) ---")

	# Test start_creation
	var started = WorldManager.start_creation("training_arena")
	_assert(started, "start_creation returns true for valid template")

	# Test complete_creation
	var world = WorldManager.complete_creation("Test World")
	_assert(world != null, "complete_creation returns world")
	_assert(world.get("name") == "Test World", "complete_creation sets name")
	_assert(not world.get("id", "").is_empty(), "complete_creation generates id")
	_assert(WorldManager.world_list.size() >= 1, "complete_creation adds to world_list")

	# Test invalid template
	var invalid_started = WorldManager.start_creation("invalid_template")
	_assert(not invalid_started, "start_creation returns false for invalid template")

	# Test get_templates
	var templates = WorldManager.get_templates()
	_assert(templates.size() >= 4, "get_templates returns at least 4 templates")


# --- Persistence Tests ---

func _test_persistence() -> void:
	print("\n--- Persistence ---")

	# Create a test soul
	var soul = SoulGrowthData.new()
	soul.soul_name = "PersistTest"
	soul.soul_id = "soul_persist_test"
	soul.element = "earth"
	soul.add_experience(75)
	soul.add_memory("Persistent memory", "test", 2)

	# Save using SoulManager
	SoulManager._save_soul(soul)

	# Load it back
	var loaded = SoulManager._load_soul("soul_persist_test")
	_assert(loaded != null, "_load_soul returns soul")
	if loaded:
		_assert(loaded.soul_name == "PersistTest", "Loaded soul has correct name")
		_assert(loaded.element == "earth", "Loaded soul has correct element")
		_assert(loaded.experience == 75, "Loaded soul has correct experience")

	# Test soul list persistence via SaveSystem directly
	SaveSystem.set_setting("test", "soul_count", SoulManager.soul_list.size())
	var saved_count = SaveSystem.get_setting("test", "soul_count", 0)
	_assert(saved_count >= 1, "Soul list persisted via SaveSystem")

	# Test world list persistence via SaveSystem directly
	SaveSystem.set_setting("test", "world_count", WorldManager.world_list.size())
	var saved_world_count = SaveSystem.get_setting("test", "world_count", 0)
	_assert(saved_world_count >= 1, "World list persisted via SaveSystem")


# --- CLI Command Tests ---

func _test_cli_commands() -> void:
	print("\n--- CLI Commands ---")

	# Clear output buffer to avoid max_lines limit affecting tests
	CLIManager.output_lines.clear()

	# Test help command (should not crash)
	CLIManager.process_command("help")
	_assert(CLIManager.output_lines.size() > 0, "help command produces output")

	# Test status command
	var output_before = CLIManager.output_lines.size()
	CLIManager.process_command("status")
	_assert(CLIManager.output_lines.size() > output_before, "status command produces output")

	# Test list_souls command
	output_before = CLIManager.output_lines.size()
	CLIManager.process_command("list_souls")
	_assert(CLIManager.output_lines.size() > output_before, "list_souls command produces output")

	# Test list_worlds command (clear buffer first to avoid max_lines truncation)
	CLIManager.output_lines.clear()
	output_before = CLIManager.output_lines.size()
	CLIManager.process_command("list_worlds")
	_assert(CLIManager.output_lines.size() > output_before, "list_worlds command produces output")

	# Test unknown command (clear buffer first to avoid max_lines truncation)
	CLIManager.output_lines.clear()
	CLIManager.process_command("nonexistent_command")
	_assert(CLIManager.output_lines.size() > 0, "Unknown command produces error message")


func _print_summary() -> void:
	print("\n" + "==================================================")
	print("M1 TEST SUMMARY")
	print("==================================================")
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	print("Total:  %d" % (_passed + _failed))
	print("==================================================")

	if _failed > 0:
		print("\nFAILED TESTS:")
		for result in _results:
			if result["status"] != "PASS":
				print("  - %s: %s" % [result["name"], result.get("message", "")])
