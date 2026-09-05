# SDK Integration Guide

## Overview

SoulGame integrates with two backend SDKs through HTTP/WebSocket APIs:

- **SoulArena** (localhost:3000) - Cognitive soul system (perception, decision, action)
- **Seed** (localhost:3001) - Virtual world engine (physics, entities, communication)

This document describes the integration strategy, version locking, and update procedures.

## Version Locking Policy

### Why Lock Versions?

1. **Stability**: Game development depends on stable API contracts
2. **Reproducibility**: Every build uses known-good SDK versions
3. **Isolation**: SDK development can continue independently without breaking the game
4. **Rollback**: Easy to revert if a new version introduces issues

### Current Locked Versions

| SDK | Version | Base URL | API Prefix | Timeout | Retries |
|-----|---------|----------|------------|---------|---------|
| SoulArena | 4.2.0 | http://localhost:3000 | /api | 5000ms | 3 |
| Seed | dist (latest build) | http://localhost:3001 | /api | 5000ms | 3 |

Configuration file: `config/sdk_versions.cfg`

### Version Format

- **SoulArena**: Semantic version (e.g., `4.2.0`) matching the backend release
- **Seed**: `dist` indicates using the compiled `dist/` directory from the Seed repository

## API Endpoints

### SoulArena API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/souls` | GET | List all souls |
| `/api/souls/:id/enter-world` | POST | Enter a soul into a world |
| `/api/souls/:id/perceive` | POST | Send perception data, receive decision |
| `/api/souls/:id/action-result` | POST | Report action execution result |
| `/api/souls/:id/exit-world` | POST | Remove soul from world |
| `/api/souls/:id/world-state` | GET | Get current world state for soul |

**Important**: API path uses plural `souls` (not singular `soul`).

### Seed API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/world/status` | GET | Get world engine status |
| `/api/entities` | GET | List all entities |
| `/api/entities/:id` | GET | Get entity details |
| `/api/souls/:id/action` | POST | Execute soul action in world |
| `/api/souls` | GET | List souls (proxied from SoulArena) |
| `/ws` | WebSocket | Real-time state sync |

## Client Architecture

### SoulArenaClient (`scripts/sdk/SoulArenaClient.gd`)

- Wraps all SoulArena API calls
- Unified error handling with retry logic
- Statistics tracking (total calls, successes, failures)
- Timeout configuration per request

### SeedClient (`scripts/sdk/SeedClient.gd`)

- Wraps all Seed API calls
- WebSocket connection management
- SoulBridgeAdapter integration pattern
- Statistics tracking

### NetworkClient (`scripts/core/NetworkClient.gd`)

- Low-level HTTP/WebSocket client
- Connection pooling
- Retry with exponential backoff
- Request/response statistics

## Update Procedure

### When to Update

1. SDK team announces a new stable release
2. Current version has a critical bug fix
3. New API features are required for game development

### How to Update

1. **Read the changelog** for breaking changes
2. **Update `config/sdk_versions.cfg`** with the new version
3. **Run API connectivity tests** to verify all endpoints work
4. **Run integration tests** to verify game behavior
5. **Update client code** if API signatures changed
6. **Commit with version bump** in commit message

### Rollback

If a new version causes issues:
1. Revert `config/sdk_versions.cfg` to previous version
2. Revert any client code changes
3. The previous SDK version should still be available

## Bridge Adapter Pattern

The `SoulBridgeAdapter` (from Seed SDK) provides a pattern for adapting SDK APIs to game-specific needs:

- **SDK layer**: Raw API calls (SoulArenaClient, SeedClient)
- **Bridge layer**: Translation between SDK data formats and game data formats
- **Game layer**: Game-specific logic using adapted data

During the base architecture phase, the bridge layer is minimal. Full game-specific adapters will be implemented after design freeze.

## Connectivity Verification

Run the following checks periodically:

```bash
# SoulArena
curl http://localhost:3000/api/souls
curl -X POST http://localhost:3000/api/souls/<id>/enter-world -d '{"worldId":"test"}'
curl -X POST http://localhost:3000/api/souls/<id>/perceive -d '{"tick":1,"situation":"test"}'
curl -X POST http://localhost:3000/api/souls/<id>/exit-world -d '{"reason":"done"}'

# Seed
curl http://localhost:3001/api/world/status
curl http://localhost:3001/api/entities
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| 404 on `/api/soul/:id/` | Wrong path (singular) | Use `/api/souls/:id/` (plural) |
| 400 on perceive | Soul not in world | Call enter-world first |
| 429 rate limited | Too many concurrent calls | Reduce call frequency or increase limits |
| Connection refused | Backend not running | Start SoulArena/Seed servers |
| Timeout | Backend overloaded | Check backend load, increase timeout |

## References

- Interface spec: `D:\ai-soul-project-mgmt\docs\interface_spec.md`
- Architecture constraints: `D:\ai-soul-project-mgmt\docs\ARCHITECTURE_CONSTRAINTS_*.md`
- SoulArena source: `D:\SoulArena`
- Seed source: `D:\Seed`
