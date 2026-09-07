# 战策 Battleplan 开发日志

## 2026-09-07 - M2可玩原型冲刺第一轮

### 完成功能

#### 1. 主菜单场景 (P0)
- **文件**: `scripts/ui/MainMenu.gd`, `scenes/main_menu.tscn`
- **功能**: 游戏标题「战策 Battleplan」、开始游戏、灵魂之家、设置、退出按钮
- **UI**: 浮空岛概念图背景 + 半透明遮罩 + 像素风按钮样式
- **音效**: 按钮点击使用ui_button_click_01，背景音乐使用bgm_menu_01
- **流程**: 开始游戏→灵魂选择，灵魂之家→灵魂之家场景

#### 2. 灵魂选择场景 (P0)
- **文件**: `scripts/ui/SoulSelect.gd`, `scenes/soul_select.tscn`
- **功能**: 显示可选灵魂列表（名称、元素、等级、HP/攻击/防御预览）
- **UI**: 灵魂卡片（元素颜色指示条 + 名称等级 + 属性预览），滚动列表
- **默认灵魂**: 炎灵(fire)、水灵(water)、岩灵(earth)、风灵(wind)
- **流程**: 选择灵魂→进入RTS对战，返回→主菜单

#### 3. 游戏流程串联 (P0)
- **Bootstrap.gd**: 初始化完成后自动切换到主菜单
- **RTSArenaController.gd**: 返回按钮回到main_menu.tscn（原main.tscn）
- **SceneManager.gd**: 注册场景别名 main_menu, soul_select, rts_arena, soul_home

#### 4. 设计资源集成
- 复制 `concept_world_floating_island.png` 为 `assets/art/background/main_menu_bg.png`
- 背景图尺寸: 1920x1080，952KB

### 测试
- MainMenu测试: 10个（脚本存在、场景存在、实例化、属性检查）
- SoulSelect测试: 15个（脚本存在、场景存在、实例化、元素颜色方法）
- M2测试: 1390 → 1415
- 总计测试: 1574 → 1599

### 已知问题
- 背景图main_menu_bg.png缺少.import文件，需要在Godot编辑器中打开项目自动导入
- 场景加载时有资源警告，但不影响功能

### [设计需求]
- 需要: 概念图 - 灵魂选择场景背景（像素风，灵魂主题）- P1
- 需要: 音效 - 主菜单背景音乐（空灵、神秘风格）- P1
- 需要: 概念图 - 设置界面背景 - P2

### 下一步
- 可玩原型端到端验证（实际运行游戏，从头玩到尾）
- RTSArenaController接收选中的灵魂数据

## 2026-09-07 - M2可玩原型冲刺第二轮

### 完成功能

#### 灵魂之家集成 (P1)
- **文件**: `scripts/game/SoulHomeController.gd`, `scenes/soul_home.tscn`
- **新增UI方法**:
  - `_on_back_button()`: 返回主菜单（原"Back to CLI"）
  - `_on_battle_button()`: 进入对战（跳转到灵魂选择）
  - `_on_chat_button()`: 切换聊天面板显示
  - `_on_pet_button()`: 抚摸灵魂，增加情感经验
  - `_on_feed_button()`: 喂食灵魂，恢复能量
  - `_on_play_button()`: 和灵魂玩耍，增加技能经验
  - `_on_train_button()`: 训练灵魂，增加技能经验
  - `_on_chat_send()`: 发送消息给灵魂
  - `_on_chat_close()`: 关闭聊天面板
- **辅助方法**: `_update_event_log()`, `_update_chat_history()`
- **场景修改**:
  - BackButton文字改为"返回主菜单"，位置调整
  - 新增BattleButton"进入对战"，连接到_on_battle_button
- **流程**: 主菜单→灵魂之家→查看灵魂/互动→进入对战→灵魂选择→RTS对战

### 测试
- SoulHomeController测试: 25个（脚本存在、场景存在、实例化、属性、方法检查）
- M2测试: 1415 → 1442
- 总计测试: 1599 → 1626

### 已知问题
- 背景图main_menu_bg.png缺少.import文件，需要在Godot编辑器中打开项目自动导入
- 场景加载时有资源警告，但不影响功能

### [设计需求]
- 需要: 概念图 - 灵魂之家背景（温馨、像素风）- P1
- 需要: 音效 - 灵魂之家环境音（温暖、空灵）- P1

### 下一步
- 可玩原型端到端验证（实际运行游戏，从头玩到尾）
- RTSArenaController接收选中的灵魂数据
- 修复端到端验证中发现的bug
