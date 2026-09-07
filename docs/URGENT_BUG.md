# 🚨 紧急BUG - 用户试玩反馈（2026-09-08，第三次更新）

## 优先级：P0 - 阻塞可玩原型验证

### 问题1：RTS竞技场AI单位移动一下就停住（最新问题，需战策排查）

**当前状态（监控已修复前两层根因）：**
- ✅ position_changed信号问题已修复（改用_process每帧视觉同步，commit 6daad3c）
- ✅ z-index遮挡问题已修复（单位视觉z_index=10，渲染在ArenaMap障碍物之上，commit 6948fe8）
- ✅ 用户现在能看到红色（AI）和蓝色（玩家）单位了
- ❌ **新问题：红色方块（AI）动了一下然后不动了**，蓝色方块（玩家）似乎也没动

**用户最新截图（2026-09-08 06:54）：**
- Tick: 331，战斗在运行
- 红色AI单位在上方（约x=540, y=200）
- 蓝色玩家单位在下方（约x=540, y=400）
- 两者距离约200像素（大于attack_range=102），AI应该继续向玩家移动
- 中间有障碍物：柱子(640,150)、水晶(640,300)、柱子(640,450)
- AI单位停在障碍物左侧，没有继续移动或绕开

**需排查的方向（按优先级）：**
1. **障碍物碰撞检测是否导致单位被卡住**：
   - SoulUnit._is_position_valid()调用ArenaMap.is_position_valid()
   - 检查障碍物碰撞盒是否过大，单位是否被障碍物"粘住"
   - 检查滑动逻辑（slide_x/slide_y）是否正常工作
   - 单位出生点(200,300)和(1080,300)，中间有障碍物，直线路径会被挡住
2. **AI决策是否变成了IDLE**：
   - SoulAIController.make_decision()的分数计算是否有问题
   - ATTACK分数应该是40（aggression=50, courage=50），IDLE是10
   - 但如果personality字典为空或值为0，ATTACK分数可能为0，导致选IDLE
   - 检查_apply_soul_personality是否正确设置了personality值
3. **移动逻辑本身是否有bug**：
   - SoulUnit._update_movement()中distance < 5.0就设置state=IDLE
   - 检查target_position是否被正确设置
   - 检查move_speed是否为0或异常值
   - 检查_update_attack()中distance > attack_range时是否正确调用了_update_movement()
4. **玩家单位是否在移动**：
   - auto模式下_player_ai_controller是否正常工作
   - _update_player_ai()是否被调用
   - 玩家单位的state是否为MOVING或ATTACKING
5. **RTSArenaManager._process是否在运行**：
   - battle_state是否为ACTIVE
   - _ai_decision_timer是否在累积
   - _update_ai()是否被调用

**建议的排查方法：**
1. 在SoulUnit._process中加调试打印：state、position、target_position、attack_target
2. 在SoulAIController.make_decision中加调试打印：各决策分数、最终选择
3. 在SoulUnit._update_movement中加调试打印：distance、move_amount、新位置
4. 在RTSArenaManager._update_ai中加调试打印：是否被调用、决策结果
5. 用Godot编辑器运行游戏，在远程调试中查看单位的实时状态

**验收标准：**
- 进入竞技场后，AI单位和玩家单位都能持续移动
- 单位能绕开障碍物或与障碍物交互
- 单位进入攻击范围后能正常攻击
- 战斗能正常结束（一方HP归零或超时）

---

### 问题2：音频wav加载失败（P1，持续存在）

- **现象**：大量"Failed to load res://assets/audio/..."警告
- **根因**：wav文件未被Godot导入（缺少.import文件），仅约20/452导入成功
- **已知限制**：Godot headless --import处理大量wav时会崩溃
- **临时缓解**：AudioManager已加_failed_streams失败缓存，避免重复刷屏警告
- **根本解决**：需要用户用Godot编辑器打开项目等待自动导入，或分批导入
- **验收标准**：运行游戏时无音频加载失败警告，关键音效能正常播放

---

## 处理要求
- 战策任务自触发每轮**最优先**处理问题1（AI单位移动卡住）
- 每轮DEVLOG必须记录排查进展和调试输出
- 修复后必须运行Godot测试确认无回归
- **重要：必须加入运行时冒烟测试**（见下方测试改进要求）
- 修复完成后删除此文件

---

## 测试改进要求（用户反馈：现有测试完全测不出真实运行问题）

**用户反馈核心问题**：2901个测试全通过，但实际运行时单位不移动、视觉被挡住、音频加载失败——这些问题测试完全没测出来。

**必须新增的测试类型：**

1. **运行时冒烟测试（Smoke Test）**：
   - 实际实例化RTSArenaController场景，运行_process 60帧
   - 检查是否有SCRIPT ERROR
   - 检查单位是否被创建（player_unit和ai_unit不为null）
   - 检查单位视觉是否被创建（_player_visual和_ai_visual不为null）
   - 检查单位视觉的z_index是否大于障碍物层
   - 检查60帧后单位position是否发生了变化（移动了）

2. **端到端流程测试（E2E Test）**：
   - 模拟主菜单→灵魂选择→开始战斗→战斗结束的完整流程
   - 检查每个场景切换是否有报错
   - 检查战斗是否能正常结束（一方HP归零或超时）

3. **资源完整性检查（Resource Integrity Test）**：
   - 扫描所有场景文件和脚本中引用的资源路径
   - 检查每个引用的资源文件是否实际存在
   - 检查音频文件是否有对应的.import文件
   - 列出所有缺失的资源

4. **视觉渲染测试（Visual Render Test）**：
   - 检查单位视觉是否可见（不在障碍物层之下）
   - 检查UI元素是否在屏幕范围内
   - 检查调试面板是否遮挡游戏区域

5. **障碍物碰撞测试（Obstacle Collision Test）**：
   - 单位从出生点向对方移动，检查是否能到达
   - 单位碰到障碍物时检查滑动逻辑是否正常
   - 检查单位是否会被障碍物永久卡住

**这些测试必须在战策任务的每轮测试中运行，不能只跑单元测试。**
