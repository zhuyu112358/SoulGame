# SoulGame - AI Soul Game Application

[![CI](https://github.com/zhuyu112358/SoulGame/actions/workflows/ci.yml/badge.svg)](https://github.com/zhuyu112358/SoulGame/actions)

AI灵魂游戏应用 — 基于Godot 4的游戏客户端，连接SoulArena灵魂认知引擎和Seed世界引擎。

## 当前阶段

**全功能开发期 M1** — 游戏设计v1.1已冻结，双SDK v1.1.0已发布。
正在开发灵魂之家场景和灵魂成长系统基础。

- M1目标：灵魂之家 + 灵魂成长基础
- 灵魂之家：主房间场景，基础交互（对话/抚摸/喂食/玩耍）
- 灵魂成长：5大维度（认知/情感/技能/个性/记忆），经验/等级/里程碑
- 灵魂管理：创建/查看/训练/部署灵魂
- 世界管理：创建/配置/运行世界
- 详见 [docs/ROADMAP.md](docs/ROADMAP.md)

## 技术架构

```
┌─────────────────────────────────────────┐
│              SoulGame (Godot 4)          │
│  ┌─────────┐ ┌─────────┐ ┌──────────┐  │
│  │ 游戏层   │ │ 适配层   │ │ 基础架构  │  │
│  │灵魂之家  │ │SoulBridge│ │20个autoload│ │
│  │成长系统  │ │ Adapter  │ │2个工具类  │  │
│  │灵魂管理  │ │         │ │          │  │
│  │世界管理  │ │         │ │          │  │
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

## 快速开始

### 环境要求

- Godot 4.2+
- Git
- Node.js (用于运行后端服务)

### 安装

```bash
# 克隆仓库
git clone https://github.com/zhuyu112358/SoulGame.git
cd SoulGame

# 运行环境检查
setup_dev.bat

# 用Godot打开项目
godot --editor
```

### 运行测试

```bash
# 单元测试
godot --headless -s res://tests/TestRunner.gd
```

### 后端服务

```bash
# SoulArena (localhost:3000)
cd D:\SoulArena
npm start

# Seed (localhost:3001)
cd D:\Seed
# 需要启动入口脚本，详见 docs/SDK_INTEGRATION.md
```

## 项目结构

```
SoulGame/
├── scenes/                    # Godot场景文件
│   ├── main.tscn              # 主场景（Bootstrap入口）
│   ├── bootstrap.tscn         # 启动场景
│   ├── loading.tscn           # 加载场景
│   └── performance_test.tscn  # 性能基线测试场景
├── scripts/
│   ├── autoload/              # 自动加载单例（6个）
│   │   ├── EventBus.gd        # 全局事件总线
│   │   ├── Logger.gd          # 分级日志系统
│   │   ├── ConfigManager.gd   # 配置管理
│   │   ├── GameState.gd       # 全局状态管理
│   │   ├── SceneManager.gd    # 场景管理
│   │   └── SaveSystem.gd      # 存档系统
│   ├── core/                  # 核心系统（14个）
│   │   ├── NetworkClient.gd   # HTTP/WS网络客户端
│   │   ├── DebugOverlay.gd    # 调试面板（`键切换）
│   │   ├── Bootstrap.gd       # 初始化入口
│   │   ├── PerformanceMonitor.gd  # 性能监控
│   │   ├── StateSyncClient.gd # WebSocket状态同步
│   │   ├── LatencyProfiler.gd # 延迟测量
│   │   ├── ObjectPool.gd      # 对象池
│   │   ├── ResourceManager.gd # 资源管理
│   │   ├── InputManager.gd    # 输入管理
│   │   ├── ErrorHandler.gd    # 错误处理
│   │   ├── TimeManager.gd     # 时间管理
│   │   ├── AudioManager.gd    # 音频管理
│   │   ├── LocalizationManager.gd  # 本地化
│   │   └── AnimationManager.gd    # 动画管理
│   ├── sdk/                   # SDK封装层
│   │   ├── SoulArenaClient.gd # SoulArena API客户端
│   │   └── SeedClient.gd      # Seed API客户端
│   └── utils/                 # 静态工具类
│       ├── MathUtils.gd       # 数学工具（40+函数）
│       └── PhysicsUtils.gd    # 物理工具（25+函数）
├── assets/                    # 资源文件
├── ui/                        # UI场景（设计冻结后开发）
├── translations/              # 翻译文件
│   └── ui_strings.csv         # UI字符串（en/zh/ja）
├── tests/                     # 单元测试
│   └── TestRunner.gd          # 测试框架（13套件）
├── config/                    # 配置文件
│   ├── game.cfg               # 游戏配置
│   ├── soul.cfg               # 灵魂配置
│   ├── world.cfg              # 世界配置
│   └── sdk_versions.cfg       # SDK版本锁定
├── .github/workflows/         # CI/CD
└── docs/                      # 文档
    ├── ARCHITECTURE.md        # 架构文档
    ├── SDK_INTEGRATION.md     # SDK集成指南
    ├── PERFORMANCE_BASELINE.md # 性能基线
    ├── CODING_STANDARDS.md    # 代码规范
    └── ROADMAP.md             # 项目路线图
```

## 基础架构组件

### Autoload Singletons (18)

| 类别 | 组件 | 职责 |
|------|------|------|
| 核心 | EventBus | 全局发布/订阅事件系统 |
| 核心 | Logger | 分级日志（debug/info/warn/error）+ 文件输出 |
| 核心 | ConfigManager | 配置文件加载 + 默认值 |
| 核心 | GameState | 全局/灵魂/世界状态管理 |
| 核心 | TimeManager | 时间缩放、固定tick、调度、昼夜 |
| 核心 | ErrorHandler | 全局错误追踪、崩溃转储、4级严重度 |
| 场景/存档 | SceneManager | 场景切换、淡入淡出、缓存 |
| 场景/存档 | SaveSystem | 多槽位存档、设置持久化 |
| 网络/SDK | NetworkClient | HTTP/WS统一封装、重试、超时 |
| 网络/SDK | SoulArenaClient | SoulArena API封装 |
| 网络/SDK | SeedClient | Seed API封装 |
| 网络/SDK | StateSyncClient | WebSocket状态同步、自动重连 |
| 网络/SDK | LatencyProfiler | HTTP/WS延迟p50/p95/p99 |
| 性能/资源 | PerformanceMonitor | FPS/内存/draw calls/基线测试 |
| 性能/资源 | ObjectPool | 通用对象池、预加载、统计 |
| 性能/资源 | ResourceManager | 异步加载、引用计数、批量加载 |
| 输入/音频/本地化 | InputManager | 动作绑定、输入上下文栈、按键重绑定 |
| 输入/音频/本地化 | AudioManager | 音频总线、SFX池、音乐播放 |
| 输入/音频/本地化 | LocalizationManager | 多语言、CSV翻译、缺失键追踪 |
| 动画/调试 | AnimationManager | Tween管理、UI动画、序列运行器 |
| 动画/调试 | DebugOverlay | FPS/状态/网络/系统/日志调试面板 |
| 动画/调试 | Bootstrap | 初始化入口 |

### Static Utility Classes (2)

| 组件 | 职责 |
|------|------|
| MathUtils | 40+ 静态数学函数（插值/缓动/几何/随机） |
| PhysicsUtils | 25+ 静态物理函数（碰撞/摩擦/转向/弹道/弹簧） |

## SDK版本锁定

- **SoulArena**: v4.2.0 (通过HTTP API调用，不跟踪开发分支)
- **Seed**: dist/src 打包版本 (含SoulBridgeAdapter)

SDK版本配置在 `config/sdk_versions.cfg`，详见 [docs/SDK_INTEGRATION.md](docs/SDK_INTEGRATION.md)。

## API连通性

### SoulArena (localhost:3000)

| 端点 | 方法 | 状态 | 基线延迟 |
|------|------|------|----------|
| /api/souls | GET | ✅ | 5ms |
| /api/souls/:id/enter-world | POST | ✅ | 10ms |
| /api/souls/:id/perceive | POST | ✅ | 25ms |
| /api/souls/:id/action-result | POST | ✅ | 8ms |
| /api/souls/:id/exit-world | POST | ✅ | 8ms |

### Seed (localhost:3001)

| 端点 | 方法 | 状态 |
|------|------|------|
| /api/world/status | GET | ✅ |
| /api/entities | GET | ✅ |
| /api/souls | GET | ✅ (代理SoulArena) |
| /ws | WebSocket | ✅ |

## 测试

13个测试套件，110+断言：

- EventBus, GameState, ConfigManager, Logger, SaveSystem
- ObjectPool, InputManager, PerformanceMonitor
- TimeManager, ErrorHandler, MathUtils
- PhysicsUtils, LocalizationManager

```bash
godot --headless -s res://tests/TestRunner.gd
```

## 文档

| 文档 | 说明 |
|------|------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 完整架构文档、数据流图、API契约 |
| [docs/SDK_INTEGRATION.md](docs/SDK_INTEGRATION.md) | SDK集成指南、版本锁定、API参考 |
| [docs/PERFORMANCE_BASELINE.md](docs/PERFORMANCE_BASELINE.md) | 性能基线、回归检测 |
| [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | GDScript代码规范 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 项目路线图、里程碑 |

## 约束

- 不得修改SoulArena/Seed的内核代码（通过SDK/API使用）
- 游戏-specific逻辑只在SoulGame仓库中
- 依赖固定SDK版本，不跟踪开发分支
- 接口对齐 `D:\ai-soul-project-mgmt\docs\interface_spec.md`
- 设计冻结前，只做基础架构，不做游戏逻辑
- 代码注释使用英语

## License

MIT
