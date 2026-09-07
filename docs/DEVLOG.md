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
- 灵魂之家集成（从主菜单进入，查看灵魂、成长）
- 可玩原型端到端验证（实际运行游戏，从头玩到尾）
- RTSArenaController接收选中的灵魂数据
