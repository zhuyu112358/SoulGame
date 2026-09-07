# 战策美术资源清单

> 战策/Battleplan 游戏美术资源，全部AI生成，无第三方版权问题。
> 设计资源由设计任务产出，应用开发任务集成使用。

## 资源清单

| 文件名 | 分辨率 | 描述 | 生成方式 | 版权状态 | 日期 |
|--------|--------|------|----------|----------|------|
| concept_ui_soul_home.png | 1920×1080 | 灵魂之家界面背景图（温暖灵魂之家内部+柔和灯光木质家具+多个不同颜色灵魂光球+左侧灵魂列表留白+右侧灵魂详情留白+下方确认按钮留白，精致像素风，P1设计需求正式资源，替换占位资源concept_home_mainroom.png） | AI生成（image_gen） | 自行生成，无第三方版权 | 2026-09-08 |
| concept_steam_header.png | 1920×1080 | Steam商店页头图概念图（战策RTS游戏Steam商店页头图+中央显示游戏标题"战策 Battleplan"+背景广阔RTS战场远景+城堡山脉战云阳光像素军队旗帜+中央发光灵魂光球橙红色光芒+下方"灵魂对战竞技场"副标题，精致像素风，Steam EA上架P1素材） | AI生成（image_gen） | 自行生成，无第三方版权 | 2026-09-08 |
| concept_steam_screenshot_battle.png | 1920×1080 | Steam商店页截图概念图（RTS对战界面，左侧玩家灵魂单位+右侧AI灵魂单位+中间战场+底部4个技能按钮+顶部单位血条和战斗计时器+屏幕中央战斗反馈文字+左上角小地图，精致像素风，Steam EA上架P1素材） | AI生成（image_gen） | 自行生成，无第三方版权 | 2026-09-08 |

## 导入注意事项

1. 新复制的.png文件缺少.import文件，需要在Godot编辑器中打开项目自动导入
2. headless模式load()新资源会失败，但FileAccess.file_exists()检查正常
3. 编译时会显示资源导入警告，但不是代码错误
4. 导出PNG使用Nearest过滤，保持像素风清晰

## 资源来源

- 设计资源总库：`D:\Sojourn\management\docs\game-design\assets\art\`（100张概念图）
- 设计文档：`D:\Sojourn\management\docs\game-design\`
- 设计DEVLOG：`D:\Sojourn\battleplan\docs\DESIGN_DEVLOG.md`
- 设计验收标准：`D:\Sojourn\battleplan\docs\design_acceptance.md`
