# 自定义像素字体目录

## 说明
本目录用于存放战策Battleplan的自定义像素字体文件。

## 设计需求 [设计需求]
当前只有像素字体参考图（assets/art/pixel_font_reference.png），
需要设计产出实际可用的字体文件：

### 优先需求
- **pixel_font.ttf** 或 **pixel_font.otf**：完整像素字体（英文+数字+常用中文）
- 风格：金色像素风，奇幻魔法主题
- 参考：assets/art/pixel_font_reference.png

### 可选需求
- **battleplan_pixel.fnt** + 对应PNG图集：BitmapFont格式
- 字重：Regular / Bold

## 字体加载机制
FontLoader.gd会自动按以下顺序尝试加载：
1. res://assets/fonts/pixel_font.ttf
2. res://assets/fonts/pixel_font.otf
3. res://assets/fonts/battleplan_font.ttf
4. res://assets/fonts/battleplan_pixel.ttf

加载失败时自动fallback到Godot默认字体，不影响游戏运行。

## 字体应用范围
- MainMenu（主菜单）
- SoulSelect（灵魂选择）
- SettingsMenu（设置）
- RTSArenaController（RTS竞技场）

## 注意
- 新字体文件放入本目录后，需用Godot编辑器打开项目自动导入
- headless模式下新资源可能无法加载，FontLoader有fallback处理
