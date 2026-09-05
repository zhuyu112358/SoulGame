# Changelog

All notable changes to SoulGame will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Planned
- M1 Soul Home full interaction system
- M1 Soul growth visualization (radar charts, progress bars)
- M1 CLI-based player interface
- Game-specific SoulBridgeAdapter implementation

## [0.3.0] - 2026-09-06 - M1 Foundation: Soul Home + Growth System

### Added
- **SoulGrowthData** (`scripts/game/SoulGrowthData.gd`) - Complete soul growth data model
  - 5 growth dimensions: cognitive (8 sub-dims), emotional (6 sub-dims), skills, personality (8 traits), memory
  - Experience and level system with scaling thresholds
  - Milestone system (Lv.5/10/20/30/50/100)
  - Diminishing returns for long sessions (30min threshold)
  - Growth history tracking and memory system
  - Serialization (to_dict/from_dict) for persistence
- **SoulHomeController** (`scripts/game/SoulHomeController.gd`) - Soul Home scene controller
  - Room management (main room M1, training/study/garden M2)
  - Soul display placeholder (to be replaced with pixel art)
  - Basic interactions: chat, pet, feed, play
  - SoulArena API integration (enter/exit world, perceive)
  - Soul growth data auto-load/save
- **SoulManager** (`scripts/game/SoulManager.gd`) - Soul lifecycle management
  - Soul creation from description (keyword-based personality generation)
  - Soul list management (create/view/delete)
  - Training system (5 training tasks with timers)
  - Soul deployment to worlds via SoulArena API
- **WorldManager** (`scripts/game/WorldManager.gd`) - World management
  - 4 world templates (training arena, exploration forest, social plaza, challenge maze)
  - World creation from templates with customization
  - World simulation control (start/stop, tick system)
  - Soul deployment to worlds
- **Soul Home scene** (`scenes/soul_home.tscn`) - M1 scene foundation
- Registered SoulManager and WorldManager as autoloads (20 total)

### Changed
- Updated project.godot with 2 new autoloads

## [0.2.0] - 2026-09-05

### Added
- `.gitattributes` for line ending normalization
- `CONTRIBUTING.md` with development workflow and code standards
- Enhanced `game.cfg` with network, localization, performance, and input configs
- Enhanced `world.cfg` with day/night cycle, entities, communication, and sync configs

### Changed
- Updated README with complete architecture overview and quick start guide

## [0.1.6] - 2026-09-05

### Added
- `docs/ROADMAP.md` - project phases and milestone tracking
- `setup_dev.bat` - development environment setup script
- Comprehensive README rewrite with full component list

## [0.1.5] - 2026-09-05

### Added
- `docs/PERFORMANCE_BASELINE.md` - API latency and rendering performance baselines
- Dual-service connectivity verification (SoulArena + Seed simultaneously)
- WebSocket endpoint verification (ws://localhost:3001/ws)

### Verified
- Seed `/api/souls` successfully proxies 24 souls from SoulArena
- WebSocket hello + ack message exchange

## [0.1.4] - 2026-09-05

### Added
- Enhanced CI/CD pipeline with 7 new quality gates
- `docs/SDK_INTEGRATION.md` - complete SDK integration guide
- Seed service startup verification (world/status, entities, souls APIs)

### CI/CD Enhancements
- Autoload consistency check
- SDK version lock verification
- Test coverage check
- Large file detection
- Game logic pattern scan
- Comment density check
- Documentation verification

## [0.1.3] - 2026-09-05

### Added
- `PhysicsUtils` - 25+ static physics utilities (collision, friction, gravity, steering, bounce, projectile, spring damper)
- `translations/ui_strings.csv` - 80+ UI strings in en/zh/ja
- PhysicsUtils test suite (20 tests)
- LocalizationManager test suite (12 tests)
- Enhanced DebugOverlay with System panel (audio, locale, errors, memory, draw calls)

### Changed
- TestRunner now has 13 test suites with 110+ assertions

## [0.1.2] - 2026-09-05

### Added
- `LocalizationManager` - multi-language support (en/zh/ja), CSV translation loading, missing key tracking
- `AnimationManager` - tween management, fade/pop/slide/shake/pulse animations, animation player registry, sequence runner

### Changed
- Registered 2 new autoloads (total: 18 singletons)
- Built-in infrastructure translations for UI strings

## [0.1.1] - 2026-09-05

### Added
- `MathUtils` - 40+ static math utilities (lerp, easing, angle, vector, random, interpolation)
- `AudioManager` - audio bus management, SFX pool (16 players), music playback, volume control
- Expanded test coverage with TimeManager (10 tests), ErrorHandler (8 tests), MathUtils (15 tests)

### Changed
- Registered AudioManager autoload (total: 16 singletons)

## [0.1.0] - 2026-09-05

### Added
- `ErrorHandler` - global error tracking, crash dumps, 4 severity levels
- `TimeManager` - time scale, fixed tick (20Hz), scheduled callbacks, day/night cycle
- `docs/ARCHITECTURE.md` - complete architecture documentation with data flow diagrams and API contracts

## [0.0.9] - 2026-09-05

### Added
- `ObjectPool` - generic object pooling with preloading and hit rate statistics
- `ResourceManager` - async loading with reference counting and batch load groups
- `InputManager` - action bindings, input context stack, key rebinding
- 3 new test suites (ObjectPool, InputManager, PerformanceMonitor)

## [0.0.8] - 2026-09-05

### Added
- `PerformanceMonitor` - FPS/memory/draw calls monitoring and baseline testing
- `StateSyncClient` - WebSocket state synchronization with auto-reconnect and ping/pong
- `LatencyProfiler` - HTTP/WS latency measurement (p50/p95/p99)
- `scenes/performance_test.tscn` - performance baseline test scene (sprites, particles, lights, combined stress)

### Changed
- Enhanced DebugOverlay with performance data integration

## [0.0.7] - 2026-09-05

### Added
- SoulArena API connectivity verification (all endpoints 200)
- API path correction: uses plural `/api/souls/:id/` (not singular)
- perceive latency baseline: 25-58ms

### Fixed
- SoulArenaClient API paths aligned with actual implementation

## [0.0.6] - 2026-09-05

### Added
- `NetworkClient` - HTTP/WebSocket client with retry and timeout
- `SoulArenaClient` - SoulArena API wrapper
- `SeedClient` - Seed API wrapper
- `DebugOverlay` - in-game debug panel (` key toggle)
- `Bootstrap` - initialization entry point

## [0.0.5] - 2026-09-05

### Added
- `TestRunner` - lightweight unit test framework
- `.github/workflows/ci.yml` - CI/CD pipeline (structure validation, code style)
- `docs/CODING_STANDARDS.md` - GDScript style guide

## [0.0.4] - 2026-09-05

### Added
- `SceneManager` - scene switching with fade transitions and caching
- `SaveSystem` - multi-slot save and settings persistence

## [0.0.3] - 2026-09-05

### Added
- `GameState` - global/soul/world state management with namespaces

## [0.0.2] - 2026-09-05

### Added
- `ConfigManager` - configuration loading with defaults and hot reload
- Configuration files: game.cfg, soul.cfg, world.cfg, sdk_versions.cfg

## [0.0.1] - 2026-09-05

### Added
- Initial project structure (scenes/scripts/assets/ui/tests/config/.github)
- `project.godot` with autoload registration, input mapping, render settings
- `.gitignore` with Godot-specific patterns
- `EventBus` - global event publish/subscribe system
- `Logger` - leveled logging (debug/info/warn/error) with file output
- GitHub repository creation (zhuyu112358/SoulGame)
- First commit pushed to remote

## [0.0.0] - 2026-09-05

### Added
- Project initialization
- Git repository creation at D:\SoulGame
