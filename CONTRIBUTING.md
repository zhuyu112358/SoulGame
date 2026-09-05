# Contributing to SoulGame

## Development Workflow

### Branch Strategy

- `main` - Stable, production-ready code
- Feature branches - `feature/description` for new features
- Bugfix branches - `fix/description` for bug fixes

### Commit Messages

Use conventional commits format:

```
type: short description

- Detailed change 1
- Detailed change 2

API connectivity: (if applicable)
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Build process, tools, dependencies
- `perf` - Performance improvement

**Examples:**
```
feat: add AudioManager with bus and playback management

- 5 audio buses (Master/SFX/Music/UI/Ambient)
- SFX object pool with 16 players
- Music playback with volume control

API connectivity: SoulArena perceive 200 (30ms)
```

## Code Standards

### GDScript Style

- File names: PascalCase (e.g., `EventBus.gd`)
- Class names: PascalCase
- Variables/functions: snake_case
- Constants: UPPER_SNAKE_CASE
- Signals: past tense (e.g., `language_changed`)
- Comments: English only
- Indentation: Tabs (Godot default)
- Line length: < 120 characters

### File Header

Every GDScript file should start with:

```gdscript
extends Node  # or appropriate base class
## Brief description of the class
##
## Detailed description, usage examples.
##
## Usage:
##   Example.code_here()
```

### Autoload Singletons

- Must extend `Node`
- Register in `project.godot` under `[autoload]`
- Use PascalCase for autoload names
- Provide `get_stats()` method for debugging
- Emit events via EventBus for cross-system communication

### Static Utility Classes

- Use `class_name` + `extends RefCounted`
- No autoload registration needed
- All methods must be `static`
- No state (pure functions only)

## Architecture Rules

### Phase Constraints

**Base Architecture Phase (current):**
- No game logic (combat, growth, economy)
- No game scenes (arena, soul home)
- No game UI (menus, battle interface)
- No game art assets
- No features depending on design document specifics

**Full Feature Phase (after design freeze):**
- Game-specific logic allowed
- Must use existing infrastructure systems
- Bridge layer via SoulBridgeAdapter pattern

### Layer Separation

```
Game Layer (game-specific, design freeze后)
    ↓
Bridge Layer (SoulBridgeAdapter, game-specific)
    ↓
SDK Layer (SoulArenaClient, SeedClient)
    ↓
Network Layer (NetworkClient, HTTP/WebSocket)
    ↓
Backend (SoulArena :3000, Seed :3001)
```

- Game layer must not directly call NetworkClient
- SDK layer must not contain game logic
- Network layer must be generic (no game-specific code)

### SDK Integration

- Use fixed SDK versions (see `config/sdk_versions.cfg`)
- Do not track development branches
- Do not modify SoulArena/Seed kernel code
- All SDK access through client wrappers
- API paths: use plural `/api/souls/:id/` (not singular)

## Testing

### Test Framework

Custom lightweight test runner: `tests/TestRunner.gd`

### Running Tests

```bash
godot --headless -s res://tests/TestRunner.gd
```

### Writing Tests

1. Add test function: `func _test_component_name() -> void:`
2. Register in `_run_all_tests()`
3. Use `_assert(condition, "test name", "optional message")`
4. Tests must be deterministic (no randomness)
5. Tests must clean up after themselves

### Test Coverage Requirements

- New core systems must have test suite
- Bug fixes must include regression test
- Target: 13+ test suites, 100+ assertions

## Documentation

### Required Docs

- `README.md` - Project overview
- `docs/ARCHITECTURE.md` - Architecture details
- `docs/SDK_INTEGRATION.md` - SDK integration guide
- `docs/PERFORMANCE_BASELINE.md` - Performance baselines
- `docs/CODING_STANDARDS.md` - Code style guide
- `docs/ROADMAP.md` - Project roadmap

### Updating Docs

- Update relevant docs when adding features
- API changes must be documented
- Performance changes must update baselines

## Pull Request Process

1. Create feature branch from `main`
2. Implement changes with tests
3. Run tests locally
4. Update documentation
5. Commit with conventional format
6. Push and create pull request
7. CI must pass
8. Review and merge

## CI/CD Checks

GitHub Actions runs on every push/PR:

1. **Project structure validation** - Required files/directories exist
2. **GDScript syntax check** - File headers, naming
3. **Autoload reference check** - All registered scripts exist
4. **SDK version lock check** - config file present
5. **Test coverage check** - Minimum test suites
6. **Code style check** - TODO/FIXME, English comments, PascalCase
7. **Game logic scan** - No game logic in infrastructure
8. **Comment density check** - Core scripts have adequate comments
9. **Documentation check** - Class-level docs present

## Troubleshooting

### Git Line Endings

If you see CRLF/LF warnings:
```bash
git add --renormalize .
git commit -m "chore: normalize line endings"
```

### Godot Not Found

Add Godot to PATH or use full path:
```bash
"C:\Program Files\Godot\Godot.exe" --editor
```

### Backend Connection Refused

Start backend services:
```bash
# SoulArena
cd D:\SoulArena && npm start

# Seed (requires startup entry)
cd D:\Seed && node <startup-script>.mjs
```

### API 400 Errors

- Check soul is in world (call enter-world first)
- Verify request body format
- Check API path uses plural `souls`

## Getting Help

- Check `docs/` directory
- Review existing code patterns
- Look at test examples in `tests/TestRunner.gd`
- Check API connectivity with `setup_dev.bat`
