# Changelog

All notable changes to SoulGame will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **M2: RTS Real-Time Battle Arena System**
  - **SoulUnit** (`scripts/game/SoulUnit.gd`) - Real-time combat unit
    - Movement, attack, skills, cooldowns, status effects
    - Element-based damage calculation (fire/water/earth/wind/light/dark)
    - Level-scaled stats (HP, attack, defense, energy)
    - 4 skills: basic_attack, heavy_strike, quick_strike, heal, defend
    - Obstacle collision detection with sliding
    - Terrain speed modifiers (grass 0.85x, water 0.6x, sand 0.75x)
  - **RTSArenaManager** (`scripts/game/RTSArenaManager.gd`, autoload) - Real-time battle manager
    - Battle state machine (IDLE/ACTIVE/FINISHED)
    - Player vs AI combat with real-time updates
    - AI decision system (move/attack/skill/heal)
    - Battle time limit and forfeit
    - Player commands: move, attack, skill
  - **RTSArenaController** (`scripts/game/RTSArenaController.gd`) - Arena scene controller
    - Real-time HP/energy bar updates
    - Skill buttons with cooldown display
    - Battle log with color-coded events
    - Unit visual representation
    - Battle result display (victory/defeat, XP, stats)
    - Minimap integration
  - **rts_arena.tscn** (`scenes/rts_arena.tscn`) - RTS arena scene (1280x720)
    - Top bar: player/AI panels, HP/energy bars, timer
    - Arena area: combat space with map rendering
    - Bottom bar: skill buttons, back button
    - Battle log panel
    - Minimap (top-right)
  - **ArenaMap** (`scripts/game/ArenaMap.gd`, autoload) - Arena map system
    - 3 map layouts: default_arena, forest_arena, crystal_arena
    - 6 terrain types: NORMAL, GRASS, STONE, WATER, LAVA, SAND
    - 5 obstacle types: ROCK, TREE, WALL, CRYSTAL, PILLAR
    - Destructible obstacles with HP and buff effects
    - Terrain speed modifiers and lava damage
    - Collision detection with obstacle sliding
    - Per-map spawn points
    - Visual rendering of terrain and obstacles
  - **BattleResultManager** (`scripts/game/BattleResultManager.gd`, autoload) - Battle results and growth
    - Experience calculation (victory/defeat/draw, level difference)
    - Soul growth feedback (cognitive/emotional/skill XP)
    - Battle history recording
    - Win/loss statistics and win rate
    - Streak tracking (win/loss streaks)
    - Per-soul battle records
    - Persistence via SaveSystem
  - **Minimap** (`scripts/ui/Minimap.gd`) - RTS arena minimap
    - Top-down arena overview (150x150)
    - Player/AI unit positions (blue/red dots)
    - Obstacle and terrain display
    - Real-time updates
    - Click-to-move camera hook (reserved)
  - **Complete Battle Flow** - Soul selection to arena entry
    - CLI command: `rts_arena [soul_id] [opponent|map] [map]`
    - GameState-based battle configuration passing
    - Auto-start battle on scene load
    - 3 selectable maps
    - Random AI opponent generation
- **M2: Server-Authority Architecture** (`scripts/network/ServerAuthority.gd`)
  - 3 authority modes: LOCAL_SIMULATION (M2), CLIENT_PREDICT, SERVER_ONLY
  - Input command submission with sequence numbers and timestamps
  - Pending command queue for server validation
  - State snapshot history for anti-cheat verification
  - State verification with critical field comparison
  - Signature fields reserved for cryptographic signing
  - Rollback hooks for client prediction correction
- **M2: Monetization System Stubs** (`scripts/monetization/`)
  - **IItem** - Base item interface (cosmetic-only invariant)
  - **ISkin** - Soul skin interface (visual resources by ID, no stats)
  - **MonetizationManager** (autoload) - Payment and cosmetic manager
    - is_subscriber() / has_skin() (M2 mock)
    - Purchase flow with soft currency (M2 mock)
    - Equipment system with slot management
    - 3 currency types: soft/hard/premium
    - Season pass data structure reserved
    - All items cosmetic-only (no pay-to-win)
- **M2: Integration Tests** (`tests/M2IntegrationTest.gd`)
  - 81 tests covering all M2 features
  - BattleResultManager: 7 tests
  - ArenaMap: 10 tests
  - SoulUnit: 10 tests
  - RTSArenaManager: 11 tests
  - m2_test_runner.gd + m2_test.tscn (SceneTree wrapper)
- **THIRD_PARTY_LICENSES.md** - Third-party license compliance document
  - Godot Engine (MIT)
  - SDK dependencies (internal)
  - Font/audio/visual asset policy
  - Compliance checklist
  - Update process
- **CLIManager** (`scripts/ui/CLIManager.gd`) - Text-based command line interface for M1
  - 18 commands: help, status, create_soul, list_souls, select_soul, soul_home, train, deploy, create_world, list_worlds, start_world, stop_world, save, load, clear, quit
  - Soul management: create, list, select, train, deploy
  - World management: create, list, start, stop simulation
  - Command history and output buffer (100 lines)
- **CLI scene** (`scenes/cli.tscn`) - Terminal-style UI with scrollable output and input line
- **SDK Connectivity Verification** (`docs/SDK_CONNECTIVITY_VERIFICATION.md`)
  - All 7 SoulArena API endpoints verified: souls list, soul detail, enter-world, world-state, perceive, action-result, exit-world
  - Confirmed plural `/api/souls/` path for all endpoints
  - Documented correct request body formats
  - SoulArenaClient implementation matches actual API specification
- **Soul Home Scene Enhancement** (`scenes/soul_home.tscn`, `scripts/game/SoulHomeController.gd`)
  - Complete UI layout: status panel, growth panel, interaction buttons, chat panel
  - 5 interaction buttons: Chat, Pet, Feed, Play, Train
  - Chat system with message history and color-coded senders
  - Real-time status display: level, XP, cognitive/emotional/skills levels, energy, mood, milestones
  - Growth progress display: perception, memory, reasoning, decision, empathy, expression, attachment
  - Event log for interaction feedback
  - Back to CLI navigation
  - Fixed enter_world() API call parameter (world_id string, not body dict)
  - Fixed exit_world() API call parameter (reason string, not dict)
  - Added get_mood() method to SoulGrowthData
- **Growth Visualizer** (`scripts/ui/GrowthVisualizer.gd`, `scenes/growth_visualizer.tscn`)
  - Radar chart for 8 soul attributes (perception, memory, reasoning, decision, empathy, expression, attachment, creativity)
  - Progress bars for XP, energy, cognitive, emotional, skills
  - Level and milestone display
  - Auto-loads active soul data from SoulManager
  - CLI command 'growth' to open visualizer
  - Custom _draw() radar chart with grid, data polygon, and labels
- **Pixel Art Soul Sprite** (`scripts/ui/SoulSprite.gd`)
  - Procedurally generated 128x128 pixel-art soul (16x16 grid at 8x scale)
  - Element-based coloring: fire, water, earth, wind, light, dark
  - Mood-based expressions: happy, neutral, sad, angry, sleepy
  - Pulsing aura effect based on soul level
  - Animated with _process() for continuous aura pulse
  - Integrated into soul_home.tscn replacing placeholder ColorRect
- **SoulGrowthData**: Added 'element' property with serialization

### Fixed
- **Godot 4.7.2 Compatibility** (BUG-010 through BUG-015) - Project now fully loads with 0 script errors
  - Renamed `Logger` autoload to `GameLog` (conflict with internal symbol)
  - Renamed built-in method conflicts: `get/set/connect/disconnect/load/preload` 闂?prefixed versions
  - Renamed `create_tween()` 闂?`create_anim_tween()`, `tr()` 闂?`translate()`
  - Fixed Performance API: `get_monitor(index)` with numeric indices for removed RENDER_* enums
  - Fixed HTTPRequest API: 4-parameter `request()` (removed ssl_verify_domain)
  - Fixed AudioServer: `is_bus_mute()` (not `is_bus_muted()`)
  - Fixed ConfigFile: string values must be quoted
  - Fixed encoding corruption: replaced all damaged Chinese strings with English
  - Fixed `trait` parameter name conflict (Godot 4.7.2 reserved word) 闂?`trait_name`
  - Fixed lambda function parsing issues 闂?named functions
  - Fixed for-loop iteration over Dictionary/Array 闂?index-based iteration
  - Fixed class_name global registration issue 闂?preload constants
  - Fixed SaveSystem API: `get_value/set_value` 闂?`get_setting/set_setting`
  - Fixed stats dictionary missing keys (sfx_playing, critical_count, pending_count)
  - All 20 autoloads initialize successfully
- **M1 Test Infrastructure** (BUG-016, BUG-017, BUG-018) - All 184 tests passing
  - BUG-016: M1IntegrationTest compilation failure - Created `tests/m1_test_runner.gd` (extends SceneTree) to load full project with autoloads, 73 M1 integration tests passing
  - BUG-017: TestRunner compilation failure - Fixed nested functions, deprecated API calls (Logger->GameLog, get/set->get_value/set_value), string multiplication, type inference warnings, 111 unit tests passing
  - BUG-018: LocalizationManager `tr()` method conflict with Godot native `Object.tr()` - Removed custom `tr()` alias, all call sites use `translate()`, 0 script errors
  - Fixed Logger warning count bug: `_level_to_string` returns "WARN" but `_counts` key was "warning", added key mapping
  - Fixed zh translations: replaced English placeholders with proper Chinese text
  - Final: 184 tests passing (111 unit + 73 integration), 0 script errors

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
