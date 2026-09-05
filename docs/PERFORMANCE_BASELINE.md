# Performance Baseline

## Overview

This document records performance baselines for the SoulGame infrastructure.
Baselines are measured during the base architecture phase and used to detect
regressions during full feature development.

## API Latency Baselines

### SoulArena (localhost:3000)

Measured with direct HTTP calls from the same machine.

| Endpoint | Method | p50 | p95 | p99 | Notes |
|----------|--------|-----|-----|-----|-------|
| /api/souls | GET | 5ms | 15ms | 30ms | List 24 souls |
| /api/souls/:id/enter-world | POST | 10ms | 25ms | 50ms | |
| /api/souls/:id/perceive | POST | 25ms | 60ms | 200ms | Cognitive processing |
| /api/souls/:id/action-result | POST | 8ms | 20ms | 40ms | |
| /api/souls/:id/exit-world | POST | 8ms | 15ms | 30ms | |

**Perceive latency notes**:
- Normal load: 23-35ms
- High concurrency (multiple tasks): 1000-9000ms
- Perceive is the most expensive call (cognitive processing)

### Seed (localhost:3001)

| Endpoint | Method | p50 | p95 | Notes |
|----------|--------|-----|-----|-------|
| /api/world/status | GET | 3ms | 8ms | |
| /api/entities | GET | 4ms | 10ms | Empty world |
| /api/souls | GET | 15ms | 30ms | Proxies SoulArena |

### WebSocket State Sync

| Metric | Baseline | Target |
|--------|----------|--------|
| Connection setup | 50ms | <100ms |
| Ping/pong round-trip | 10ms | <50ms |
| State sync latency | 20ms | <100ms |
| Reconnect time | 200ms | <1000ms |

## Rendering Performance Baselines

### Test Scenes

Performance test scene: `scenes/performance_test.tscn`

| Test | Configuration | Expected FPS | Target |
|------|---------------|--------------|--------|
| Empty scene | Baseline | 60 | 60 |
| 100 sprites | Static | 60 | 60 |
| 500 sprites | Static | 55-60 | >=50 |
| 1000 sprites | Static | 45-55 | >=30 |
| 20 particle systems | 100 particles each | 55-60 | >=50 |
| 20 point lights | 2D | 50-60 | >=45 |
| Combined stress | 500 sprites + 20 particles + 20 lights | 30-45 | >=30 |

### Multi-Soul Rendering

| Souls Rendered | Expected FPS | Target |
|----------------|--------------|--------|
| 1 | 60 | 60 |
| 5 | 60 | 60 |
| 10 | 55-60 | >=50 |
| 24 (max) | 45-55 | >=40 |

## Memory Baselines

| Metric | Baseline | Target |
|--------|----------|--------|
| Empty scene | ~50MB | <100MB |
| With all autoloads | ~60MB | <150MB |
| Performance test (500 sprites) | ~80MB | <200MB |
| Full game (estimated) | ~150MB | <500MB |

## Performance Monitoring

### PerformanceMonitor Autoload

Tracks in real-time:
- FPS (current, average, min/max)
- Frame time (ms)
- Memory usage (static, dynamic, orphan nodes)
- Draw calls
- Object count
- Custom metrics (via `record_metric()`)
- Baseline tests (via `start_baseline()` / `end_baseline()`)

### DebugOverlay

Press `` ` `` (backtick) to toggle. Shows:
- FPS with color coding (green >=55, yellow >=30, red <30)
- Game state summary
- Network stats (HTTP requests, WS latency, retries)
- System stats (audio, locale, errors, memory, draw calls)
- Recent logs (15 entries, color-coded by level)

## Performance Test How-To

1. Open Godot editor
2. Load `scenes/performance_test.tscn`
3. Run the scene (F5)
4. Use on-screen controls to switch test modes
5. View results in DebugOverlay (press `` ` ``)
6. Record results in this document

### Test Modes

- **sprites_100**: 100 static sprites
- **sprites_500**: 500 static sprites
- **sprites_1000**: 1000 static sprites
- **particles_20**: 20 particle systems (100 particles each)
- **lights_20**: 20 point lights
- **combined**: Combined stress test

## Regression Detection

When adding new features:
1. Run performance test scene
2. Compare FPS against baselines above
3. If FPS drops >10% from baseline, investigate
4. Record new baseline if change is intentional

## Network Performance

### LatencyProfiler

Measures:
- HTTP request latency (p50, p95, p99)
- WebSocket ping/pong latency
- Per-endpoint statistics

### StateSyncClient

- Automatic reconnection with exponential backoff
- Ping/pong heartbeat (configurable interval)
- Connection state tracking (disconnected -> connecting -> connected)
- Latency measurement

## References

- PerformanceMonitor: `scripts/core/PerformanceMonitor.gd`
- LatencyProfiler: `scripts/core/LatencyProfiler.gd`
- StateSyncClient: `scripts/core/StateSyncClient.gd`
- DebugOverlay: `scripts/core/DebugOverlay.gd`
- Performance test scene: `scenes/performance_test.tscn`
