# 🚨 紧急BUG - 用户试玩反馈（2026-09-08）

## 优先级：P0 - 阻塞可玩原型验证

### 问题1：RTS竞技场单位不创建 / 卡着不动
- **现象**：进入RTS竞技场后，战斗开始（Tick跑了141），但调试面板显示 **Souls: 0**，地图上只有几个彩色方块卡着不动
- **截图**：用户试玩截图，rts_arena场景，Battle started，Tick: 141，Souls: 0
- **可能原因**：
  1. 用户未经过灵魂选择场景直接进入竞技场，GameState中无player_soul
  2. RTSArenaManager.start_battle()中SoulUnit.new()或init_from_soul()失败
  3. 单位创建了但调试面板Souls计数逻辑有bug
  4. 最近的commit（战斗反馈系统/设置保存加载）可能引入了回归
- **排查方向**：
  1. 检查RTSArenaManager.start_battle()执行流程，确认player_unit和ai_unit是否成功add_child
  2. 检查SoulUnit.gd的init_from_soul()和_ready()是否有报错
  3. 检查调试面板Souls计数的数据源
  4. 检查从主菜单直接进入竞技场的路径是否有默认灵魂创建逻辑
  5. 用Godot headless运行测试，确认RTS竞技场相关测试是否通过
- **验收标准**：进入竞技场后，Souls计数 > 0，单位能正常移动和战斗

### 问题2：音频wav加载失败
- **现象**：大量"Failed to load res://assets/audio/..."警告，包括ui_battle_start.wav、bgm_battle.wav、ui_game_start.wav等
- **根因**：wav文件未被Godot导入（缺少.import文件）。Godot headless --import处理大量wav时会崩溃（exit code -1073741819）
- **已知情况**：图片资源全部导入成功（118个.import文件），音频只有约20/351导入成功
- **排查方向**：
  1. 检查assets/audio/目录下.import文件数量
  2. 尝试分批导入音频（每次导入一个子目录）
  3. 检查AudioManager的音频注册列表，确认引用的文件名是否与实际文件一致
  4. 考虑在AudioManager中添加容错：加载失败时静默跳过而不是刷屏警告
- **验收标准**：运行游戏时无音频加载失败警告，关键音效（按钮点击、战斗开始、BGM）能正常播放

## 处理要求
- 战策任务自触发每轮优先处理此BUG
- 每轮DEVLOG必须记录排查进展
- 修复后必须运行Godot测试确认无回归
- 修复完成后删除此文件
