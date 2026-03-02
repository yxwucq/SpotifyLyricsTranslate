import Foundation

enum AppLanguage: String, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en"

    var displayName: String {
        switch self {
        case .zhHans: "简体中文 (Chinese)"
        case .en: "English (英文)"
        }
    }
}

enum L {
    static var lang: AppLanguage {
        AppLanguage(rawValue: AppSettings.appLanguage) ?? .zhHans
    }
    private static var en: Bool { lang == .en }

    // MARK: - Menu Bar
    static var spotifyNotPlaying: String { en ? "Spotify Not Playing" : "Spotify 未在播放" }
    static var lyricsWindow: String { en ? "Lyrics Window" : "歌词窗口" }
    static var floatingBar: String { en ? "Floating Lyrics Bar" : "悬浮歌词条" }
    static var hideLyrics: String { en ? "Hide Lyrics" : "隐藏歌词" }
    static var translating: String { en ? "Translating…" : "正在翻译…" }
    static var disableTranslation: String { en ? "Disable Translation" : "关闭翻译" }
    static var enableTranslation: String { en ? "Enable Translation" : "开启翻译" }
    static var interpreting: String { en ? "Interpreting…" : "正在解读…" }
    static var songMeaning: String { en ? "Song Meaning" : "歌词大意" }
    static var settings: String { en ? "Settings…" : "设置…" }
    static var quit: String { en ? "Quit" : "退出" }

    // MARK: - Settings Tabs
    static var tabGeneral: String { en ? "General" : "通用" }
    static var tabAppearance: String { en ? "Appearance" : "外观" }
    static var tabCredentials: String { en ? "Credentials" : "凭证" }

    // MARK: - Settings > General
    static var lyricsSource: String { en ? "Lyrics Source" : "歌词源" }
    static var source: String { en ? "Source" : "来源" }
    static var translation: String { en ? "Translation" : "翻译" }
    static var enableTranslationToggle: String { en ? "Enable Translation" : "启用翻译" }
    static var translationService: String { en ? "Translation Service" : "翻译服务" }
    static var targetLanguage: String { en ? "Target Language" : "目标语言" }
    static var translationCache: String { en ? "Translation Cache" : "翻译缓存" }
    static var cachePathPlaceholder: String { en ? "Cache path (leave empty for default)" : "缓存路径（留空使用默认）" }
    static var choose: String { en ? "Choose…" : "选择…" }
    static var chooseCacheFolder: String { en ? "Choose Cache Folder" : "选择缓存文件夹" }
    static var reset: String { en ? "Reset" : "重置" }
    static var loading: String { en ? "Loading…" : "加载中…" }
    static var clearCache: String { en ? "Clear Cache" : "清除缓存" }
    static var cacheUnavailable: String { en ? "Cache unavailable" : "缓存不可用" }
    static func cacheInfo(count: Int, size: String) -> String {
        en ? "\(count) songs, \(size) total" : "\(count) 首歌曲，共 \(size)"
    }

    // MARK: - Settings > Language
    static var appLanguageLabel: String { en ? "Language / 语言" : "语言 / Language" }

    // MARK: - Settings > Appearance
    static var font: String { en ? "Font" : "字体" }
    static var fontFamily: String { en ? "Font Family" : "字体族" }
    static var systemDefault: String { en ? "System Default" : "系统默认" }
    static func fontSize(_ size: Int) -> String {
        en ? "Font Size: \(size)pt" : "字号: \(size)pt"
    }
    static var lyricsLayout: String { en ? "Lyrics Layout" : "歌词排版" }
    static var alignment: String { en ? "Alignment" : "对齐方式" }
    static var alignLeft: String { en ? "Left" : "左对齐" }
    static var alignCenter: String { en ? "Center" : "居中" }
    static var alignRight: String { en ? "Right" : "右对齐" }
    static func translationFontScale(_ pct: Int) -> String {
        en ? "Translation Size: \(pct)%" : "翻译字号: \(pct)%"
    }
    static func lineSpacing(_ pt: Int) -> String {
        en ? "Line Spacing: \(pt)pt" : "行间距: \(pt)pt"
    }
    static var activeLineEffects: String { en ? "Active Line Effects" : "当前行效果" }
    static func scaleRatio(_ val: String) -> String {
        en ? "Scale: \(val)x" : "放大比例: \(val)x"
    }
    static var highlightBackground: String { en ? "Highlight Background" : "高亮背景" }
    static var highlightColor: String { en ? "Highlight Color" : "高亮颜色" }
    static func highlightOpacity(_ pct: Int) -> String {
        en ? "Highlight Opacity: \(pct)%" : "高亮不透明度: \(pct)%"
    }
    static func inactiveLineOpacity(_ pct: Int) -> String {
        en ? "Inactive Line Opacity: \(pct)%" : "非当前行透明度: \(pct)%"
    }
    static var colors: String { en ? "Colors" : "颜色" }
    static var currentLine: String { en ? "Current Line" : "当前行" }
    static var otherLines: String { en ? "Other Lines" : "其他行" }
    static var translationLine: String { en ? "Translation Line" : "翻译行" }
    static var background: String { en ? "Background" : "背景" }
    static func opacity(_ pct: Int) -> String {
        en ? "Opacity: \(pct)%" : "透明度: \(pct)%"
    }
    static func barWidth(_ px: Int) -> String {
        en ? "Width: \(px)px" : "宽度: \(px)px"
    }
    static var resetAllAppearance: String { en ? "Reset All Appearance Defaults" : "恢复所有外观默认值" }
    static var resetConfirmMessage: String { en ? "Reset all appearance settings to defaults?" : "确定要恢复所有外观设置为默认值吗？" }
    static var resetDefault: String { en ? "Reset" : "恢复默认" }
    static var cancel: String { en ? "Cancel" : "取消" }

    // MARK: - Settings > Credentials
    static var spDcHint: String { en ? "Get sp_dc from Spotify Web Player cookies in your browser" : "从浏览器 Spotify Web Player 的 Cookie 中获取 sp_dc 值" }
    static var testSpotify: String { en ? "Test Spotify Connection" : "测试 Spotify 连接" }
    static var apiAddress: String { en ? "API URL" : "API 地址" }
    static var modelName: String { en ? "Model Name" : "模型名称" }
    static var claudeHint: String { en ? "For third-party providers, change the API URL. Path /v1/messages is appended automatically" : "第三方平台请修改 API 地址，路径 /v1/messages 会自动拼接" }
    static var testClaude: String { en ? "Test Claude API" : "测试 Claude API" }
    static var openaiHint: String { en ? "For third-party providers, change the API URL. Path /v1/chat/completions is appended automatically" : "第三方平台请修改 API 地址，路径 /v1/chat/completions 会自动拼接" }
    static var testOpenAI: String { en ? "Test OpenAI API" : "测试 OpenAI API" }
    static var testing: String { en ? "Testing…" : "测试中…" }

    // MARK: - AppState
    static var waitingForSpotify: String { en ? "Waiting for Spotify…" : "等待 Spotify 播放…" }
    static var fetchingLyrics: String { en ? "Fetching lyrics…" : "正在获取歌词…" }
    static var noLyricsForTrack: String { en ? "No lyrics for this track" : "该曲目无歌词" }
    static func fetchLyricsFailed(_ msg: String) -> String {
        en ? "Failed to fetch lyrics: \(msg)" : "获取歌词失败: \(msg)"
    }
    static func translationRetrying(_ attempt: Int, _ max: Int) -> String {
        en ? "Translation failed, retrying (\(attempt)/\(max))…" : "翻译失败，正在重试 (\(attempt)/\(max))…"
    }
    static func translationFailed(_ err: String) -> String {
        en ? "Translation failed: \(err)" : "翻译失败: \(err)"
    }
    static func meaningRetrying(_ attempt: Int, _ max: Int) -> String {
        en ? "Interpretation failed, retrying (\(attempt)/\(max))…" : "解读失败，正在重试 (\(attempt)/\(max))…"
    }
    static func meaningFailed(_ err: String) -> String {
        en ? "Interpretation failed: \(err)" : "解读失败: \(err)"
    }
    static var unknownError: String { en ? "Unknown error" : "未知错误" }

    // MARK: - Song Meaning Window
    static var creativeBackground: String { en ? "Creative Background" : "创作背景" }
    static var imageryAndMetaphor: String { en ? "Imagery & Metaphor" : "意象与隐喻" }
    static var noMeaningContent: String { en ? "No interpretation available" : "暂无解读内容" }
    static var settingsWindowTitle: String { en ? "SpotifyLyrics Settings" : "SpotifyLyrics 设置" }
    static var defaultCachePath: String { "~/Library/Caches/SpotifyLyrics/translations/" }

    // MARK: - API Test Results
    static var noApiKeyConfigured: String { en ? "API Key not configured" : "未配置 API Key" }
    static var invalidApiUrl: String { en ? "Invalid API URL" : "API 地址无效" }
    static var noResponse: String { en ? "No response" : "无响应" }
    static func connectionSuccess(_ baseURL: String, model: String) -> String {
        en ? "Connected (\(baseURL), model: \(model))" : "连接成功 (\(baseURL), 模型: \(model))"
    }
    static func httpError(_ code: Int, message: String?) -> String {
        "HTTP \(code): \(message ?? unknownError)"
    }
    static func networkError(_ desc: String) -> String {
        en ? "Network error: \(desc)" : "网络错误: \(desc)"
    }
    static var noSpDcConfigured: String { en ? "sp_dc Cookie not configured" : "未配置 sp_dc Cookie" }
    static var authSuccess: String { en ? "Authentication successful" : "认证成功" }
    static var abnormalResponse: String { en ? "Abnormal response data" : "返回数据异常" }
    static func authFailed(_ code: Int) -> String {
        en ? "HTTP \(code): Authentication failed, check sp_dc" : "HTTP \(code): 认证失败，请检查 sp_dc"
    }

    // MARK: - Translation Errors
    static var errNoApiKey: String { en ? "Please configure API Key in Settings" : "请在设置中配置 API Key" }
    static var errTranslationApiFailed: String { en ? "Translation API call failed" : "翻译 API 调用失败" }
    static var errTranslationParseFailed: String { en ? "Failed to parse translation result" : "翻译结果解析失败" }

    // MARK: - Spotify Lyrics Provider Errors
    static var errNetworkError: String { en ? "Network error" : "网络错误" }
    static var errSpotifyAuthFailed: String { en ? "Spotify authentication failed" : "Spotify 认证失败" }
    static var errLyricsParseError: String { en ? "Failed to parse lyrics" : "歌词解析失败" }

    // MARK: - LRCLIB Errors
    static var errInvalidURL: String { en ? "URL construction failed" : "URL 构造失败" }
    static var errLRCLIBNoLyrics: String { en ? "No lyrics found on LRCLIB" : "LRCLIB 未找到歌词" }

    // MARK: - Spotify Auth Errors
    static var errNoSpDcCookie: String { en ? "Please configure Spotify sp_dc Cookie in Settings" : "请在设置中配置 Spotify sp_dc Cookie" }
    static var errTokenRequestFailed: String { en ? "Failed to get Spotify token, check if sp_dc is valid" : "获取 Spotify Token 失败，请检查 sp_dc 是否有效" }
    static var errSpotifyInvalidResponse: String { en ? "Spotify returned invalid data" : "Spotify 返回格式异常" }

    // MARK: - Song Meaning Errors
    static var errSongMeaningNoApiKey: String { en ? "Please configure API Key in Settings" : "请在设置中配置 API Key" }
    static var errSongMeaningApiFailed: String { en ? "API call failed" : "API 调用失败" }
    static var errSongMeaningParseFailed: String { en ? "Failed to parse result" : "结果解析失败" }
}
