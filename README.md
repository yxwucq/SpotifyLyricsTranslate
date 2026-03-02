# SpotifyLyrics

macOS menu bar lyrics app — real-time synced Spotify lyrics with AI translation and song interpretation.

macOS 菜单栏歌词应用，实时显示 Spotify 同步歌词，支持 AI 翻译与歌曲解读。

## Features / 功能特性

- **Real-time synced lyrics / 实时同步歌词** — Spotify official lyrics + LRCLIB auto-fallback
- **AI Translation / AI 翻译** — Claude / OpenAI, 8 target languages, local cache
- **Song Meaning / 歌曲大意** — AI-generated background and theme interpretation
- **Multiple display modes / 多种显示模式** — Lyrics window / Floating bar / Hidden
- **Highly customizable / 高度自定义** — Font, color, scale, alignment, opacity, etc.
- **i18n / 多语言** — English & 简体中文 UI, switchable in Settings

## Requirements / 要求

- macOS 14+, Spotify desktop client
- Spotify `sp_dc` Cookie (for lyrics)
- Claude or OpenAI API Key (for translation / interpretation)

## Install & Run / 安装与运行

```bash
git clone https://github.com/aspect-build/spotify_lyrics.git
cd spotify_lyrics
./build_app.sh
open SpotifyLyrics.app
```

## Configuration / 配置

Click menu bar icon → **Settings…** (`Cmd+,`):

**sp_dc Cookie** — Log in to [open.spotify.com](https://open.spotify.com) → DevTools → Application → Cookies → copy `sp_dc` value → paste in Settings → Credentials.

**API Key** — Enter Claude / OpenAI API Key in the Credentials tab. Custom Base URL supported.

**Language** — Switch UI language (English / 简体中文) in Settings → General. The language picker is always bilingual so you can find it even after switching to an unfamiliar language.

## Usage / 使用

| Action | Shortcut |
|--------|----------|
| Lyrics Window | `Cmd+Shift+L` |
| Floating Bar | `Cmd+Shift+B` |
| Settings | `Cmd+,` |

Translation toggle, song meaning, and other features are accessible from the menu bar. Appearance settings (font, color, scale, opacity, etc.) can be adjusted in Settings → Appearance.

## Project Structure / 项目结构

```
Sources/SpotifyLyrics/
├── App/          # Entry point, global state
├── Models/       # Track, LyricLine, AppSettings
├── Services/     # Player monitor, lyrics, translation, song meaning
├── Utilities/    # Keychain, LRC parser, i18n strings
└── Views/        # Menu bar, lyrics window, floating bar, settings
```

## Tech Stack / 技术栈

Swift 5.10 · SwiftUI · AppKit · Swift Package Manager

## License

[MIT](LICENSE)
