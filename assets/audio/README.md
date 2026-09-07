# 战策音效资源清单

> 战策/Battleplan 游戏音效资源，全部AI生成，无第三方版权问题。
> 设计资源由设计任务产出，应用开发任务集成使用。

## 资源清单

| 文件名 | 时长 | 格式 | 描述 | 生成方式 | 版权状态 | 日期 |
|--------|------|------|------|----------|----------|------|
| env_soul_home.wav | ~15秒 | 44100Hz/16bit/WAV | 灵魂之家环境音（温暖空灵风格+灵魂之家环境音+柔和室内环境音+远处鸟鸣声+轻微风声+灵魂光点声+温暖光点声，可循环，P1设计需求正式资源，替换占位资源env_home_indoor.wav） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |
| bgm_steam_trailer.wav | ~30秒 | 44100Hz/16bit/WAV | Steam商店页宣传视频BGM（史诗感+像素风风格+宣传视频背景音乐+史诗管弦乐+像素合成器+战斗节奏+灵魂主题旋律+渐进式高潮，Steam EA上架P1素材） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |
| ui_store_page_open.wav | ~5秒 | 44100Hz/16bit/WAV | 商店页打开音效（UI交互风格+商店页打开音效+柔和上升音+闪光+页面打开声+像素光点声，Steam EA上架P1素材） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |
| battle_heroic_victory.wav | ~5秒 | 44100Hz/16bit/WAV | 史诗胜利音效（战斗特效风格+史诗胜利音效+清脆上升音+回响+胜利号角声+史诗光点声+像素光点声，Steam EA上架P1素材） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |
| soul_epic_summon.wav | ~5秒 | 44100Hz/16bit/WAV | 史诗灵魂召唤音效（灵魂相关风格+史诗灵魂召唤音效+柔和上升音+闪光+灵魂召唤声+灵魂光点声+史诗光点声，Steam EA上架P1素材） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |
| ui_capsule_hover.wav | ~5秒 | 44100Hz/16bit/WAV | 胶囊图悬停音效（UI交互风格+胶囊图悬停音效+柔和上升音+闪光+图标悬停声+像素光点声，Steam EA上架P1素材） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |
| ui_trailer_play.wav | ~5秒 | 44100Hz/16bit/WAV | 宣传视频播放音效（UI交互风格+宣传视频播放音效+清脆短促音+回响+视频播放声+像素光点声，Steam EA上架P1素材） | AI生成（text_to_audio） | 自行生成，无第三方版权 | 2026-09-08 |

## 音频规格

- 采样率：44100Hz
- 位深：16bit
- 格式：WAV（源文件）+ OGG（游戏内）
- UI/动作音效：≤0.5秒
- 灵魂音效：≤2秒
- 环境音：15-30秒可循环
- BGM：2-4分钟可循环
- 响度：BGM -16 LUFS / 音效 -20 LUFS
- 峰值：≤-1 dBTP
- Godot 5条音频总线：Master/BGM/SFX/Voice/Ambient

## 导入注意事项

1. 新复制的.wav文件缺少.import文件，需要在Godot编辑器中打开项目自动导入
2. headless模式load()新资源会失败，但FileAccess.file_exists()检查正常
3. 编译时会显示资源导入警告，但不是代码错误

## 资源来源

- 设计资源总库：`D:\Sojourn\management\docs\game-design\assets\audio\`（360个音效）
- 设计文档：`D:\Sojourn\management\docs\game-design\`
- 设计DEVLOG：`D:\Sojourn\battleplan\docs\DESIGN_DEVLOG.md`
- 设计验收标准：`D:\Sojourn\battleplan\docs\design_acceptance.md`
