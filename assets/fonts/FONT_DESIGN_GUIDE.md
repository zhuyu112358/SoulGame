# 战策 Battleplan 像素字体设计规范

## 概述

战策Battleplan使用复古8-bit像素字体，配合深紫(#1a1428)+金色(#cc9933)主色调，营造怀旧像素游戏氛围。

## 当前字体资源

| 文件 | 类型 | 大小 | 授权 | 说明 |
|------|------|------|------|------|
| PressStart2P-Regular.ttf | TrueType字体 | 115KB | SIL OFL 1.1 | 开源像素字体，Google Fonts发布，可免费商用 |
| pixel_font_reference.png | 风格参考图 | 256KB | — | AI生成的像素字体风格参考，金色字符深紫背景 |

## Press Start 2P 字体说明

- **来源**: Google Fonts (https://fonts.google.com/specimen/Press+Start+2P)
- **作者**: CodeMan38
- **授权**: SIL Open Font License 1.1 (可免费商用、修改、再分发)
- **风格**: 8-bit复古像素字体，灵感来自Namco街机游戏
- **字符集**: 覆盖ASCII基本字符集（大写、小写、数字、常用符号）
- **字重**: 仅Regular
- **适用**: 标题、菜单、按钮、HUD、游戏内文字

## 字体设计规范

### 视觉风格
- **像素尺寸**: 每个字符基于5x7像素网格
- **字重**: 中等粗细，像素边缘锐利
- **色调**: 游戏中使用金色(#cc9933)或白色(#ffffff)，深色背景
- **抗锯齿**: 关闭抗锯齿，保持像素锐利感
- **等宽**: 所有字符等宽，适合像素游戏

### 字号规范
| 用途 | 字号 | 颜色 | 说明 |
|------|------|------|------|
| 游戏标题 | 32-48px | 金色#cc9933 | 主菜单大标题 |
| 菜单选项 | 16-20px | 白色/金色 | 按钮、菜单文字 |
| HUD信息 | 12-14px | 白色/金色 | 血量、能量、战斗日志 |
| 对话文字 | 14-16px | 白色 | 剧情对话、提示 |
| 小字说明 | 10-12px | 浅灰#aaa | 辅助说明、版权信息 |

### 在Godot中使用

1. 将PressStart2P-Regular.ttf放入ssets/fonts/目录
2. 在Godot编辑器中导入字体文件（自动生成.import）
3. 创建Theme资源，设置默认字体为PressStart2P
4. 或在Control节点的theme_override_fonts中单独设置

`gdscript
# 代码中加载字体
var font = load("res://assets/fonts/PressStart2P-Regular.ttf")
label.add_theme_font_override("font", font)
label.add_theme_font_size_override("font_size", 16)
label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))  # 金色
`

### 字体效果
- **描边**: 可添加1-2px深色描边，增强可读性
- **阴影**: 可添加2px偏移的深色阴影
- **发光**: 标题文字可添加金色发光效果
- **像素完美**: 确保字号为整数倍，避免像素模糊

## 未来自定义字体计划

### 目标
创建战策专属像素字体，包含完整字符集和特殊符号。

### 字符集规划
- **基本ASCII**: 95个可打印字符（已覆盖）
- **中文支持**: 常用汉字3500个（M3+，需大量工作量）
- **游戏符号**: 元素图标、技能图标、UI符号（M2+）
- **特殊字符**: 箭头、星星、心形等装饰符号

### 创建工具
- **FontForge**: 开源字体编辑器，可手动绘制像素字形
- **fontTools (Python)**: 程序化创建字体（需安装fontTools库）
- **Bitmap Font Generator**: 位图字体生成工具
- **在线工具**: Pixellari、BitFontMaker2等

### 自定义字体设计规范
- **em大小**: 1000 units (标准)
- **字符宽度**: 600 units (等宽)
- **上升**: 800 units
- **下降**: -200 units
- **行高**: 1000 units
- **像素网格**: 基于8x8或16x16像素

## 授权与合规

### Press Start 2P 授权 (SIL OFL 1.1)
- ✅ 可免费商用
- ✅ 可修改字体
- ✅ 可再分发
- ✅ 可嵌入游戏/软件
- ❌ 不可单独售卖字体文件
- ❌ 修改后不可使用原字体名称（需改名）

### 游戏中使用
- 字体文件随游戏分发，符合SIL OFL授权
- 在游戏 credits/致谢中注明字体来源和作者
- 建议在Steam商店页"法律声明"中包含字体授权信息

## 相关资源

- **Google Fonts Press Start 2P**: https://fonts.google.com/specimen/Press+Start+2P
- **SIL OFL 1.1 全文**: https://openfontlicense.org/
- **FontForge**: https://fontforge.org/
- **Godot字体文档**: https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html

---
*文档版本: v1.0*
*创建日期: 2026-09-10*
*设计任务: 第165轮*
