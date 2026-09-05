# Project Roadmap

## Current Phase: M1 Full Feature Development (In Progress)

Game design v1.1 has been frozen. Dual SDK v1.1.0 released.
Now developing actual game features: Soul Home + Soul Growth foundation.

### Phase 1: Base Architecture (Completed)

**Goal**: Build a solid foundation that can support any game design.

#### Completed

- [x] Godot 4 project initialization (git, directory structure, project.godot)
- [x] GitHub repository (zhuyu112358/SoulGame)
- [x] Core systems (20 autoload singletons):
  - [x] EventBus - global event publish/subscribe (enhanced: history, filtering, stats)
  - [x] Logger - leveled logging with file output (enhanced: rotation, category levels)
  - [x] ConfigManager - configuration loading with defaults
  - [x] GameState - global/soul/world state management
  - [x] SceneManager - scene switching with fade transitions
  - [x] SaveSystem - multi-slot save and settings persistence
  - [x] TimeManager - time scale, fixed tick, scheduling, day/night (enhanced: named timers, tick scheduling, FPS stats)
  - [x] ErrorHandler - global error tracking, crash dumps, severity levels (enhanced: recovery strategies, rate monitoring, storm suppression)
  - [x] AudioManager - audio bus management, SFX pool, music playback (enhanced: cross-fade, SFX priority, audio groups)
  - [x] LocalizationManager - multi-language support, CSV translations
  - [x] AnimationManager - tween management, UI animations (fixed: recursion bug, enhanced: queue, node state)
  - [x] InputManager - action bindings, input context stack, key rebinding
  - [x] SoulManager - soul lifecycle: create, view, train, deploy (NEW M1)
  - [x] WorldManager - world management: create, configure, simulate (NEW M1)
- [x] Network layer:
  - [x] NetworkClient - HTTP/WebSocket with retry and timeout (enhanced: priority queue, circuit breaker)
  - [x] StateSyncClient - WebSocket state sync with auto-reconnect
  - [x] LatencyProfiler - HTTP/WS latency p50/p95/p99
- [x] SDK integration:
  - [x] SoulArenaClient - SoulArena API wrapper (API paths corrected to plural /souls/)
  - [x] SeedClient - Seed API wrapper
  - [x] SDK version locking (config/sdk_versions.cfg)
- [x] Performance & resources:
  - [x] PerformanceMonitor - FPS/memory/draw calls/baseline tests
  - [x] ObjectPool - generic object pooling with stats
  - [x] ResourceManager - async loading with reference counting
  - [x] MathUtils - 40+ static math utilities
  - [x] PhysicsUtils - 25+ static physics utilities
- [x] Debug tools:
  - [x] DebugOverlay - in-game debug panel (` key toggle)
  - [x] Bootstrap - initialization entry point
- [x] Toolchain:
  - [x] TestRunner - 13 test suites, 110+ assertions
  - [x] CI/CD (GitHub Actions: structure validation, code style, quality gates)
  - [x] Coding standards (GDScript style guide)
  - [x] Architecture documentation

### Phase 2: M1 - Soul Home + Soul Growth (Current)

**Goal**: Build the soul home scene and soul growth system foundation.

#### In Progress

- [x] **Godot 4.7.2 Compatibility** - Project fully loads with 0 script errors (BUG-010 through BUG-015)
  - [x] All 20 autoloads initialize successfully
  - [x] All M1 game scripts compile (SoulGrowthData, SoulManager, WorldManager, SoulHomeController)
  - [x] Key compatibility issues resolved: Logger鈫扜ameLog, trait parameter name, built-in method conflicts, Performance API, encoding corruption
- [x] SoulGrowthData - 5-dimension growth data model (cognitive/emotional/skills/personality/memory)
- [x] SoulHomeController - soul home scene controller with basic interactions
- [x] SoulManager - soul creation, training, deployment
- [x] WorldManager - world creation, simulation, soul deployment
- [x] soul_home.tscn - M1 scene foundation
- [x] CLI-based player interface (main menu, soul home UI, soul management)
- [x] SDK connectivity verification (all 7 SoulArena API endpoints)
- [x] Soul home interaction system (dialogue, pet, feed, play with soul reactions)
- [x] Soul growth visualization (radar charts, progress bars, level up animations)
- [x] Soul home pixel art (128x128 soul sprite, room backgrounds)
- [x] Soul growth persistence integration
- [x] M1 integration tests (73 tests, 0 failures)

#### Next (M2)

- [ ] Training room, study room, garden rooms
- [ ] Soul home customization
- [ ] Mini-games in soul home
- [ ] Battle arena mode
- [ ] Economy system
  - [x] SDK integration guide
  - [x] Performance baseline documentation
- [x] Technical verification:
  - [x] SoulArena API connectivity (all endpoints 200, perceive ~30ms)
  - [x] Seed API connectivity (world/status, entities, souls proxied)
  - [x] WebSocket connectivity (hello + ack verified)
  - [x] Cross-service integration (Seed proxies SoulArena souls)
  - [x] Performance test scene (sprites, particles, lights, combined stress)

#### Remaining (Optional)

- [x] Godot editor actual runtime verification (Godot 4.7.2 installed, project loads with 0 errors)
- [ ] Seed service startup entry file (Seed project issue, not SoulGame)
- [ ] More integration test coverage
- [ ] Performance baseline actual measurements (needs Godot runtime)

### Phase 2: Full Feature Development (After Design Freeze)

**Trigger**: Monitoring task notifies that game design v1.1 is frozen.

#### Planned Work

- [ ] Game-specific SoulBridgeAdapter implementation
- [ ] Game scenes (arena, soul home, etc.)
- [ ] Game UI (main menu, battle interface, soul home)
- [ ] Game logic (combat rules, growth system, economy)
- [ ] Game art assets integration
- [ ] Soul-to-game state mapping
- [ ] Action execution system
- [ ] Perception data pipeline
- [ ] Multi-soul rendering optimization
- [ ] Save/load game state
- [ ] Settings menu integration

### Phase 3: Polish & Release

- [ ] Performance optimization pass
- [ ] Bug fixing
- [ ] Balance tuning
- [ ] Localization completion
- [ ] Audio polish
- [ ] Release build

## Architecture Summary

### Autoload Singletons (18)

| Category | Singletons |
|----------|------------|
| Core | EventBus, Logger, ConfigManager, GameState, TimeManager, ErrorHandler |
| Scene/Archive | SceneManager, SaveSystem |
| Network/SDK | NetworkClient, SoulArenaClient, SeedClient, StateSyncClient, LatencyProfiler |
| Performance/Resource | PerformanceMonitor, ObjectPool, ResourceManager |
| Input/Audio/Locale | InputManager, AudioManager, LocalizationManager |
| Animation/Debug | AnimationManager, DebugOverlay, Bootstrap |

### Static Utility Classes (2)

- MathUtils (class_name)
- PhysicsUtils (class_name)

### Project Statistics

- 10 git commits
- 26 GDScript files
- 5 documentation files
- 4 configuration files
- 3 test scenes
- 13 test suites (110+ assertions)

## Constraints (Base Architecture Phase)

- No game logic (combat, growth, economy)
- No game scenes (arena, soul home)
- No game UI (menus, battle interface)
- No game art assets
- No features depending on design document specifics
- English comments only in code
- SDK versions locked, no development branch tracking
- Do not modify SoulArena/Seed kernel code

## Coordination

- **Game design task**: Working on v1.1 detailed design. When frozen, this task switches to full development.
- **Integration test task**: Tests this task's base architecture output.
- **SoulArena/Seed tasks**: Responsible for SDK releases. This task depends on fixed SDK versions.
- **Monitoring task**: Watches for design freeze notification and triggers phase switch.

## References

- Management strategy: `D:\ai-soul-project-mgmt\MANAGEMENT_STRATEGY.md`
- Task management: `D:\ai-soul-project-mgmt\TASK_MANAGEMENT.md`
- Project status: `D:\ai-soul-project-mgmt\PROJECT_STATUS.md`
- Interface spec: `D:\ai-soul-project-mgmt\docs\interface_spec.md`
- Architecture: `docs/ARCHITECTURE.md`
- SDK integration: `docs/SDK_INTEGRATION.md`
- Performance baseline: `docs/PERFORMANCE_BASELINE.md`
- Coding standards: `docs/CODING_STANDARDS.md`
