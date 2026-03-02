# SpotifyLyrics

macOS 菜单栏歌词应用，实时显示 Spotify 同步歌词，支持 AI 翻译与歌曲解读。

## 功能特性

- **实时同步歌词** — Spotify 官方歌词 + LRCLIB 自动回退
- **AI 翻译** — 支持 Claude / OpenAI，8 种目标语言，本地缓存
- **歌曲大意** — AI 生成歌曲背景与主题解读
- **多种显示模式** — 完整歌词窗口 / 悬浮歌词条 / 隐藏
- **高度自定义** — 字体、颜色、缩放、对齐、透明度等

## 要求

- macOS 14+、Spotify 桌面客户端
- Spotify `sp_dc` Cookie（获取歌词）
- Claude 或 OpenAI API Key（翻译/解读需要）

## 安装与运行

```bash
git clone https://github.com/aspect-build/spotify_lyrics.git
cd spotify_lyrics
./build_app.sh
open SpotifyLyrics.app
```

## 配置

点击菜单栏图标 → **设置…**（`Cmd+,`）：

**sp_dc Cookie** — 浏览器登录 [open.spotify.com](https://open.spotify.com) → 开发者工具 → Application → Cookies → 复制 `sp_dc` 值，粘贴到设置 → 凭证。

**API Key** — 在凭证标签页填入 Claude / OpenAI API Key，支持自定义 Base URL。

## 使用

| 操作 | 快捷键 |
|------|--------|
| 歌词窗口 | `Cmd+Shift+L` |
| 悬浮歌词条 | `Cmd+Shift+B` |
| 设置 | `Cmd+,` |

翻译开关、歌词大意等功能通过菜单栏操作。外观设置（字体、颜色、缩放、透明度等）在设置 → 外观标签页调整。

## 项目结构

```
Sources/SpotifyLyrics/
├── App/          # 应用入口、全局状态
├── Models/       # Track、LyricLine、AppSettings
├── Services/     # 播放监控、歌词获取、翻译、歌曲解读
├── Utilities/    # Keychain、LRC 解析
└── Views/        # 菜单栏、歌词窗口、悬浮条、设置界面
```

## 技术栈

Swift 5.10 · SwiftUI · AppKit · Swift Package Manager

## License

[MIT](LICENSE)
