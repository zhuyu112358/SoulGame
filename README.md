# SoulGame - AI Soul Game Application

[![CI](https://github.com/zhuyu112358/SoulGame/actions/workflows/ci.yml/badge.svg)](https://github.com/zhuyu112358/SoulGame/actions)

AI灵魂游戏应用 — 基于Godot 4的游戏客户端，连接SoulArena灵魂认知引擎和Seed世界引擎。

## 当前阶段

**基础架构期** — 游戏设计v1.1详细设计进行中，本阶段只做不依赖游戏设计的基础架构工作。

- 禁止开发任何游戏逻辑/游戏场景/游戏UI
- 设计冻结后切换到全功能开发

## 技术架构

```
┌─────────────────────────────────────────┐
│              SoulGame (Godot 4)          │
│  ┌─────────┐ ┌─────────┐ ┌──────────┐  │
│  │ 游戏层   │ │ 适配层   │ │ 基础架构  │  │
│  │(设计冻结 │ │SoulBridge│ │事件/状态/ │  │
│  │ 后开发)  │ │ Adapter  │ │网络/存档 │  │
│  └─────────┘ └────┬────┘ └──────────┘  │
└───────────────────┼─────────────────────┘
                    │ HTTP/WebSocket
        ┌───────────┴───────────┐
        ▼                       ▼
┌───────────────┐      ┌───────────────┐
│  SoulArena    │      │     Seed      │
│ 灵魂认知引擎   │      │  世界引擎      │
│ (localhost:3000)│    │ (localhost:3001)│
└───────────────┘      └───────────────┘
```

## 项目结构

```
SoulGame/
├── scenes/              # Godot场景文件
│   └── main.tscn        # 主场景（占位，设计冻结后替换）
├── scripts/
│   ├── autoload/        # 自动加载单例
│   │   ├── EventBus.gd       # 全局事件总线
│   │   ├── Logger.gd         # 日志系统
│   │   ├── ConfigManager.gd  # 配置管理
│   │   ├── GameState.gd      # 全局状态管理
│   │   ├── SceneManager.gd   # 场景管理
│   │   └── SaveSystem.gd     # 存档系统
│   ├── core/            # 核心系统
│   │   ├── NetworkClient.gd  # 网络客户端（HTTP/WS）
│   │   └── DebugOverlay.gd   # 调试覆盖层
│   ├── sdk/             # SDK封装层
│   │   ├── SoulArenaClient.gd # SoulArena API客户端
│   │   └── SeedClient.gd      # Seed API客户端
│   └── ui/              # UI脚本（设计冻结后开发）
├── assets/              # 资源文件
│   ├── textures/
│   ├── audio/
│   └── fonts/
├── ui/                  # UI场景（设计冻结后开发）
├── tests/               # 单元测试
├── config/              # 配置文件
│   ├── game.cfg         # 游戏配置
│   ├── soul.cfg         # 灵魂配置
│   └── world.cfg        # 世界配置
├── .github/workflows/   # CI/CD
└── docs/                # 文档
```

## 基础架构组件

| 组件 | 职责 | 状态 |
|------|------|------|
| EventBus | 全局发布/订阅事件系统 | ✅ |
| Logger | 分级日志（debug/info/warn/error） | ✅ |
| ConfigManager | 配置文件加载/热重载 | ✅ |
| GameState | 全局状态/灵魂状态/世界状态 | ✅ |
| SceneManager | 场景切换/加载/过渡 | ✅ |
| SaveSystem | 本地存档/配置持久化 | ✅ |
| NetworkClient | HTTP/WebSocket统一封装 | ✅ |
| SoulArenaClient | SoulArena API封装（perceive/action） | ✅ |
| SeedClient | Seed世界引擎API封装 | ✅ |
| DebugOverlay | FPS/状态/网络调试面板 | ✅ |

## SDK版本锁定

- SoulArena: v4.2.0 (通过HTTP API调用，不跟踪开发分支)
- Seed: dist/src 打包版本 (含SoulBridgeAdapter)

SDK版本配置在 `config/sdk_versions.cfg`。

## 开发环境

- Godot 4.2+
- SoulArena服务运行在 localhost:3000
- Seed服务运行在 localhost:3001

## 运行测试

```bash
# 单元测试（GUT框架）
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## 约束

- 不得修改SoulArena/Seed的内核代码（通过SDK/API使用）
- 游戏-specific逻辑只在SoulGame仓库中
- 依赖固定SDK版本，不跟踪开发分支
- 接口对齐 `D:\ai-soul-project-mgmt\docs\interface_spec.md`
- 设计冻结前，只做基础架构，不做游戏逻辑

## License

MIT
