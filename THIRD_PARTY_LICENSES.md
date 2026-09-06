# Third-Party Licenses

This document lists all third-party software, libraries, assets, and tools used in the SoulGame (凌栖/Sojourn) project, along with their licenses.

## License Policy

- **Preferred licenses**: MIT, Apache 2.0, BSD, zlib, Unlicense (permissive, no copyleft)
- **Accepted with review**: LGPL (dynamic linking only), MPL
- **Requires legal review**: GPL, AGPL (strong copyleft may require source disclosure)
- **Prohibited**: Unknown licenses, "no license", custom restrictive licenses

## Game Engine

| Software | Version | License | Usage |
|----------|---------|---------|-------|
| Godot Engine | 4.7.2 | MIT | Game engine, runtime, editor |

**Godot Engine License**:
- Copyright (c) 2007-2024 Juan Linietsky, Ariel Manzur and contributors
- MIT License: https://godotengine.org/license
- We do not modify the engine source; we use the official binary distribution.

## SDK Dependencies

| Software | Version | License | Usage |
|----------|---------|---------|-------|
| SoulArena SDK | 1.5.0 | Internal | Soul AI cognitive engine (local API) |
| Seed SDK | 2.3.0 | Internal | World simulation engine (local API) |

**Note**: SoulArena and Seed SDKs are internal project dependencies, developed alongside SoulGame. They are used via HTTP API (localhost:3000) and are not distributed with the game binary.

## Programming Language

| Language | License | Usage |
|----------|---------|-------|
| GDScript | MIT (part of Godot) | Primary game scripting language |

## Fonts

All fonts used in SoulGame must be either:
1. Open source fonts (SIL OFL, Apache, MIT)
2. Fonts with explicit commercial licensing purchased for this project

**Current fonts**: To be determined (M2 prototype uses Godot default font).

**Approved open source font candidates**:
- Inter (SIL OFL 1.1) - UI text
- JetBrains Mono (SIL OFL 1.1) - Code/debug display
- Press Start 2P (SIL OFL 1.1) - Pixel art retro style (if needed)

## Audio Assets

All audio assets must be:
1. Original compositions created for this project
2. Royalty-free with explicit commercial license
3. Open source audio (CC0, CC-BY with attribution)

**Current audio**: None in M2 prototype (placeholder silence).

## Visual Assets

All visual assets must be:
1. Original art created for this project
2. Royalty-free with explicit commercial license
3. Open source art (CC0, CC-BY with attribution)

**Current visual assets**: Programmatic shapes and colors (no third-party art assets in M2 prototype). Pixel art assets will be created or licensed in later milestones.

## Code References and Inspiration

No third-party game code has been copied or adapted. All game logic is original implementation based on:
- General game development patterns
- Godot Engine documentation examples (MIT licensed)
- Original design documents for this project

## Development Tools

| Tool | License | Usage |
|------|---------|-------|
| Git | GPL v2 | Version control (tool only, not distributed) |
| Node.js | MIT | SDK runtime (development only) |
| npm packages | Various | SDK dependencies (development only) |

**Note**: Development tools are not distributed with the game and do not affect the game's license.

## Attribution

If any CC-BY or attribution-required assets are used in the future, they will be listed here with proper attribution:

_(None currently)_

## Compliance Checklist

- [x] Game engine license documented (MIT)
- [x] SDK dependencies documented (internal)
- [ ] Fonts selected and licensed (M2: using default)
- [ ] Audio assets licensed (M2: none)
- [ ] Visual assets licensed (M2: procedural only)
- [x] No GPL code in game binary
- [x] No copied code from other games
- [x] No proprietary assets without license

## Update Process

This file must be updated whenever:
1. A new third-party dependency is added
2. An existing dependency is upgraded to a new version
3. New art/audio/font assets are added
4. A license is found to be incompatible

Updates should be made in the same commit that introduces the new dependency/asset.

---

Last updated: 2026-09-06 (M2 milestone)
