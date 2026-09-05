# SoulGame - GDScript Style Guide

## Naming Conventions

- **Files**: PascalCase (`EventBus.gd`, `SoulArenaClient.gd`)
- **Classes**: PascalCase, matching filename
- **Functions**: snake_case (`_on_event`, `get_state`)
- **Variables**: snake_case (`current_scene`, `max_retries`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_RETRIES`, `DEFAULT_TIMEOUT`)
- **Signals**: past tense or descriptive (`game_saved`, `scene_changed`)
- **Private members**: prefix with underscore (`_subscribers`, `_initialize()`)

## File Structure

```gdscript
extends Node
## Brief description of class
##
## More detailed description, usage examples.

## Public variable description
var public_var: int = 0

## Private variable description
var _private_var: String = ""

func _ready() -> void:
	pass

func public_method() -> void:
	pass

func _private_method() -> void:
	pass
```

## Comments

- All comments in **English**
- Use `##` for docstrings (before classes and functions)
- Use `#` for inline comments
- Comment *why*, not *what*

## Type Hints

- Always use type hints for function parameters and return values
- Use `-> void` for functions that don't return
- Use `Variant` only when truly necessary

```gdscript
# Good
func get_value(key: String, default_value = null) -> Variant:
	pass

# Avoid
func get_value(key, default_value):
	pass
```

## Error Handling

- Use `Logger.error/warning` instead of `print` for errors
- Return error codes or booleans for failure states
- Never silently swallow errors

## Architecture Rules

1. **No game logic in infrastructure** - This repo is infrastructure-only until design freeze
2. **Autoload singletons** - Global systems use autoload, accessed via `ClassName.method()`
3. **Event-driven** - Decouple systems using EventBus, avoid direct references
4. **SDK through clients** - All external API calls go through SoulArenaClient/SeedClient
5. **Config through ConfigManager** - No hardcoded URLs, keys, or magic numbers
6. **State through GameState** - Global state managed centrally, not scattered

## Directory Structure

```
scripts/
├── autoload/    # Global singletons (EventBus, Logger, etc.)
├── core/        # Core systems (Network, Debug, Bootstrap)
├── sdk/         # SDK client wrappers
└── ui/          # UI scripts (post-design-freeze)
scenes/          # Godot scene files
config/          # Configuration files
tests/           # Unit tests
assets/          # Art, audio, fonts
```

## Git Commit Messages

Format: `<type>: <description>`

Types:
- `feat`: New infrastructure feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Build/config changes

Examples:
```
feat: add WebSocket support to NetworkClient
fix: handle null response in SoulArenaClient
docs: update architecture diagram in README
```
