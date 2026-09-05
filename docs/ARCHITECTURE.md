# SoulGame Architecture

## Overview

SoulGame is a Godot 4 game client that connects to two backend engines:
- **SoulArena** (localhost:3000) — AI soul cognition engine (perception, decision, action)
- **Seed** (localhost:3001) — World simulation engine (entities, physics, events)

The game layer is purely a client: it renders state, sends perceptions, receives actions, and provides user interaction. All cognition and world simulation happens in the backend engines.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     SoulGame (Godot 4)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Game Layer  │  │  Adaptation  │  │   Infrastructure  │  │
│  │ (design      │  │    Layer     │  │      Layer        │  │
│  │  freeze后)   │  │ (design      │  │  (current phase)  │  │
│  │              │  │  freeze后)   │  │                   │  │
│  │ - Scenes     │  │ - SoulBridge │  │ - Core Systems    │  │
│  │ - Game UI    │  │   Adapter    │  │ - Network/SDK     │  │
│  │ - Game logic │  │ - Game-      │  │ - State Mgmt      │  │
│  │              │  │   specific   │  │ - Resource Mgmt   │  │
│  │              │  │   mapping    │  │ - Debug/Tools     │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│                          │                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │ HTTP / WebSocket
          ┌────────────────┴────────────────┐
          ▼                                 ▼
┌───────────────────┐           ┌───────────────────┐
│    SoulArena      │           │      Seed         │
│  Cognition Engine │           │  World Engine     │
│  localhost:3000   │           │  localhost:3001   │
│                   │           │                   │
│ - Perception API  │           │ - World API       │
│ - Decision Engine │           │ - Entity System   │
│ - Action Output   │           │ - Physics         │
│ - Memory System   │           │ - Events          │
│ - 90+ subsystems  │           │ - SoulBridge      │
└───────────────────┘           └───────────────────┘
```

## Infrastructure Layer (Current Phase)

### Autoload Singletons (15 total)

| Singleton | Category | Responsibility |
|-----------|----------|----------------|
| `EventBus` | Core | Global pub/sub event system |
| `Logger` | Core | Leveled logging (debug/info/warn/error) |
| `ConfigManager` | Core | Config file loading, defaults, hot-reload |
| `GameState` | State | Global/soul/world/session state management |
| `SceneManager` | Scene | Scene switching, transitions, stack, cache |
| `SaveSystem` | Persistence | Save slots, settings, auto-save, import/export |
| `NetworkClient` | Network | HTTP/WebSocket client with retry and timeout |
| `SoulArenaClient` | SDK | SoulArena API wrapper (perceive/action/enter-world) |
| `SeedClient` | SDK | Seed world engine API wrapper |
| `DebugOverlay` | Debug | FPS/state/network/log real-time panel |
| `PerformanceMonitor` | Debug | FPS/memory/draw calls, baseline testing |
| `StateSyncClient` | Network | WebSocket state sync with auto-reconnect |
| `LatencyProfiler` | Network | HTTP/WS/sync latency measurement (p50/p95/p99) |
| `ObjectPool` | Performance | Generic object pooling for Node reuse |
| `ResourceManager` | Resource | Async loading, ref counting, cache, group loads |
| `InputManager` | Input | Action binding, contexts, key rebinding |
| `ErrorHandler` | Reliability | Error tracking, crash dumps, recovery |
| `TimeManager` | Core | Game time, fixed ticks, scheduled callbacks |

### Core Systems Detail

#### EventBus
- Publish/subscribe with automatic invalid subscriber cleanup
- Statistics tracking (emitted, delivered, active events)
- `unsubscribe_all(target)` for safe cleanup on node free

#### GameState
- Namespaced state: `game`, `soul`, `world`, `ui`, `session`
- Per-soul state tracking (`set_soul_state`/`get_soul_state`)
- State change subscriptions with old/new value
- State history for debugging (100 entries)

#### NetworkClient
- HTTP: GET/POST/PUT/DELETE with JSON
- Exponential backoff retry (3 attempts, 500ms base)
- WebSocket: connect, send, poll, auto-reconnect
- Response time averaging and statistics

#### SoulArenaClient
- Aligned with actual API: `/api/souls/:id/` (plural, not singular)
- Full lifecycle: enter-world → perceive → action-result → exit-world
- Simplified perception mode via `situation` field
- Connection checking and statistics

### Data Flow

```
User Input → InputManager → EventBus → Game Logic (post-freeze)
                                          ↓
                          ResourceManager → SceneManager → Rendering
                                          ↓
                          GameState ← StateSyncClient ← WebSocket
                                          ↓
                          SoulArenaClient → HTTP → SoulArena (perceive)
                                          ↓
                          SoulArenaClient ← HTTP ← SoulArena (actions)
                                          ↓
                          SeedClient → HTTP → Seed (world state)
```

### Configuration Files

| File | Purpose |
|------|---------|
| `config/game.cfg` | Display, audio, debug settings |
| `config/soul.cfg` | Soul default parameters (perception, training, rendering) |
| `config/world.cfg` | World engine defaults (physics, environment) |
| `config/sdk_versions.cfg` | SDK version locking and API endpoints |

### Performance Testing

`PerformanceTest` scene provides technical validation:
- Multi-sprite render test (up to 500 objects)
- Particle system test (up to 20 emitters × 100 particles)
- 2D lighting test (up to 20 dynamic lights)
- Combined stress test
- Baseline metrics: avg FPS, 1% low FPS, peak frame time, draw calls

## Design Constraints

### Current Phase (Pre-Design-Freeze)
- **Only infrastructure** — no game logic, scenes, UI, or art
- All code must be design-agnostic
- SDK versions are locked (no tracking development branches)
- No modification to SoulArena/Seed kernel code

### Post-Design-Freeze
- Game layer implements specific scenes and UI
- Adaptation layer creates game-specific SoulBridgeAdapter
- Soul game abilities acquired through training (not hardcoded)
- Knowledge injection via config/documents, not code

## API Contract

SoulArena API (verified working):
- `GET /api/souls` — list all souls
- `GET /api/souls/:id` — soul details
- `POST /api/souls/:id/enter-world` — enter soul into world
- `POST /api/souls/:id/perceive` — send perception, receive cognitive result
- `POST /api/souls/:id/action-result` — report action execution result
- `GET /api/souls/:id/world-state` — query connection state
- `POST /api/souls/:id/exit-world` — remove soul from world

**Note:** Interface spec v1.0 documents `/api/soul/:id/` (singular), but actual implementation uses `/api/souls/:id/` (plural). Client is aligned with actual implementation.

## Build & Test

```bash
# Run unit tests (headless)
godot --headless -s res://tests/TestRunner.gd

# Run performance test scene
godot res://scenes/performance_test.tscn
```

## CI/CD

GitHub Actions (`ci.yml`):
- Project structure validation
- GDScript syntax checking
- Autoload reference verification
- Code style checks (English comments, naming conventions)
