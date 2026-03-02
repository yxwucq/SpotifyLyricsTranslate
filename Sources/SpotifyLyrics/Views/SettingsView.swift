import SwiftUI

struct SettingsView: View {
    @AppStorage("fontFamily") private var fontFamily = "System"
    @AppStorage("fontSize") private var fontSize: Double = 20
    @AppStorage("currentLineColor") private var currentLineColorHex = "#FFFFFF"
    @AppStorage("otherLineColor") private var otherLineColorHex = "#AAAAAA"
    @AppStorage("translationColor") private var translationColorHex = "#88CCFF"
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.75
    @AppStorage("lyricAlignment") private var lyricAlignment = "leading"
    @AppStorage("translationFontScale") private var translationFontScale: Double = 0.8
    @AppStorage("lineSpacing") private var lineSpacing: Double = 0
    @AppStorage("activeLineScale") private var activeLineScale: Double = 1.15
    @AppStorage("activeLineHighlight") private var activeLineHighlight: Bool = true
    @AppStorage("activeLineHighlightColorHex") private var activeLineHighlightColorHex = "#FFFFFF"
    @AppStorage("activeLineHighlightOpacity") private var activeLineHighlightOpacity: Double = 0.08
    @AppStorage("inactiveLineOpacity") private var inactiveLineOpacity: Double = 0.4
    @AppStorage("barWidth") private var barWidth: Double = 600
    @AppStorage("targetLanguage") private var targetLanguage = "zh-Hans"
    @AppStorage("translationEnabled") private var translationEnabled = true
    @AppStorage("translationProvider") private var translationProvider = TranslationProvider.claude.rawValue
    @AppStorage("lyricsSource") private var lyricsSource = LyricsSource.auto.rawValue

    @AppStorage("claudeModel") private var claudeModel = "claude-sonnet-4-20250514"
    @AppStorage("claudeBaseURL") private var claudeBaseURL = "https://api.anthropic.com"
    @AppStorage("openaiModel") private var openaiModel = "gpt-4o-mini"
    @AppStorage("openaiBaseURL") private var openaiBaseURL = "https://api.openai.com"

    @State private var spDc: String = ""
    @State private var claudeKey: String = ""
    @State private var openaiKey: String = ""
    @State private var currentLineColor: Color = .white
    @State private var otherLineColor: Color = .gray
    @State private var translationLineColor: Color = .blue
    @State private var highlightColor: Color = .white
    @State private var showResetConfirm = false

    @AppStorage("translationCachePath") private var translationCachePath = ""

    @State private var claudeTestResult: (success: Bool, message: String)?
    @State private var openaiTestResult: (success: Bool, message: String)?
    @State private var spotifyTestResult: (success: Bool, message: String)?
    @State private var isTesting: String?  // "claude" | "openai" | "spotify"
    @State private var cacheInfo: String = ""
    @State private var isClearing = false

    var body: some View {
        TabView {
            generalTab.tabItem { Label("通用", systemImage: "gear") }
            appearanceTab.tabItem { Label("外观", systemImage: "paintbrush") }
            credentialsTab.tabItem { Label("凭证", systemImage: "key") }
        }
        .frame(width: 450, height: 520)
        .onAppear { loadCredentials() }
    }

    private var generalTab: some View {
        Form {
            Section("歌词源") {
                Picker("来源", selection: $lyricsSource) {
                    ForEach(LyricsSource.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
            }

            Section("翻译") {
                Toggle("启用翻译", isOn: $translationEnabled)

                Picker("翻译服务", selection: $translationProvider) {
                    ForEach(TranslationProvider.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }

                Picker("目标语言", selection: $targetLanguage) {
                    ForEach(AppSettings.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
            }

            Section("翻译缓存") {
                HStack {
                    TextField("缓存路径（留空使用默认）", text: $translationCachePath)
                        .textFieldStyle(.roundedBorder)
                    Button("选择…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true
                        panel.prompt = "选择缓存文件夹"
                        if panel.runModal() == .OK, let url = panel.url {
                            translationCachePath = url.path
                        }
                    }
                    if !translationCachePath.isEmpty {
                        Button("重置") { translationCachePath = "" }
                    }
                }
                Text("默认: ~/Library/Caches/SpotifyLyrics/translations/")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(cacheInfo.isEmpty ? "加载中…" : cacheInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        isClearing = true
                        Task {
                            await AppState.shared?.translationCache.clearCache()
                            await refreshCacheInfo()
                            isClearing = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isClearing {
                                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                            }
                            Text("清除缓存")
                        }
                    }
                    .disabled(isClearing)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { Task { await refreshCacheInfo() } }
    }

    private func refreshCacheInfo() async {
        guard let cache = AppState.shared?.translationCache else {
            cacheInfo = "缓存不可用"
            return
        }
        let info = await cache.cacheSize()
        let sizeStr = ByteCountFormatter.string(fromByteCount: info.totalBytes, countStyle: .file)
        cacheInfo = "\(info.fileCount) 首歌曲，共 \(sizeStr)"
    }

    private func resetAppearance() {
        fontFamily = "System"
        fontSize = 20
        currentLineColorHex = "#FFFFFF"
        otherLineColorHex = "#AAAAAA"
        translationColorHex = "#88CCFF"
        backgroundOpacity = 0.75
        lyricAlignment = "leading"
        translationFontScale = 0.8
        lineSpacing = 0
        activeLineScale = 1.15
        activeLineHighlight = true
        activeLineHighlightColorHex = "#FFFFFF"
        activeLineHighlightOpacity = 0.08
        inactiveLineOpacity = 0.4
        barWidth = 600
        // sync color pickers
        currentLineColor = .white
        otherLineColor = .gray
        translationLineColor = Color(hex: "#88CCFF") ?? .blue
        highlightColor = .white
    }

    private var appearanceTab: some View {
        Form {
            Section("字体") {
                Picker("字体族", selection: $fontFamily) {
                    Text("系统默认").tag("System")
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                HStack {
                    Text("字号: \(Int(fontSize))pt")
                    Slider(value: $fontSize, in: 12...48, step: 1)
                }
            }

            Section("歌词排版") {
                Picker("对齐方式", selection: $lyricAlignment) {
                    Text("左对齐").tag("leading")
                    Text("居中").tag("center")
                    Text("右对齐").tag("trailing")
                }

                HStack {
                    Text("翻译字号: \(Int(translationFontScale * 100))%")
                    Slider(value: $translationFontScale, in: 0.6...1.0, step: 0.05)
                }

                HStack {
                    Text("行间距: \(Int(lineSpacing))pt")
                    Slider(value: $lineSpacing, in: 0...20, step: 1)
                }
            }

            Section("当前行效果") {
                HStack {
                    Text("放大比例: \(String(format: "%.2f", activeLineScale))x")
                    Slider(value: $activeLineScale, in: 1.0...1.4, step: 0.05)
                }

                Toggle("高亮背景", isOn: $activeLineHighlight)

                if activeLineHighlight {
                    ColorPicker("高亮颜色", selection: $highlightColor)
                        .onChange(of: highlightColor) { _, c in activeLineHighlightColorHex = c.hexString }

                    HStack {
                        Text("高亮不透明度: \(Int(activeLineHighlightOpacity * 100))%")
                        Slider(value: $activeLineHighlightOpacity, in: 0.02...0.3, step: 0.02)
                    }
                }

                HStack {
                    Text("非当前行透明度: \(Int(inactiveLineOpacity * 100))%")
                    Slider(value: $inactiveLineOpacity, in: 0.1...0.8, step: 0.05)
                }
            }

            Section("颜色") {
                ColorPicker("当前行", selection: $currentLineColor)
                    .onChange(of: currentLineColor) { _, c in currentLineColorHex = c.hexString }
                ColorPicker("其他行", selection: $otherLineColor)
                    .onChange(of: otherLineColor) { _, c in otherLineColorHex = c.hexString }
                ColorPicker("翻译行", selection: $translationLineColor)
                    .onChange(of: translationLineColor) { _, c in translationColorHex = c.hexString }
            }

            Section("背景") {
                HStack {
                    Text("透明度: \(Int(backgroundOpacity * 100))%")
                    Slider(value: $backgroundOpacity, in: 0.1...1.0, step: 0.05)
                }
            }

            Section("悬浮歌词条") {
                HStack {
                    Text("宽度: \(Int(barWidth))px")
                    Slider(value: $barWidth, in: 300...1200, step: 10)
                }
            }

            Section {
                Button("恢复所有外观默认值", role: .destructive) {
                    showResetConfirm = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .confirmationDialog("确定要恢复所有外观设置为默认值吗？", isPresented: $showResetConfirm) {
                Button("恢复默认", role: .destructive) { resetAppearance() }
                Button("取消", role: .cancel) {}
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            currentLineColor = Color(hex: currentLineColorHex) ?? .white
            otherLineColor = Color(hex: otherLineColorHex) ?? .gray
            translationLineColor = Color(hex: translationColorHex) ?? .blue
            highlightColor = Color(hex: activeLineHighlightColorHex) ?? .white
        }
    }

    private var credentialsTab: some View {
        Form {
            Section("Spotify") {
                SecureField("sp_dc Cookie", text: $spDc)
                    .onChange(of: spDc) { _, val in KeychainHelper.save(.spotifySpDc, value: val) }
                Text("从浏览器 Spotify Web Player 的 Cookie 中获取 sp_dc 值")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                testButton(label: "测试 Spotify 连接", key: "spotify") {
                    spotifyTestResult = await APITestHelper.testSpotify()
                }
                testResultView(spotifyTestResult)
            }

            Section("Claude API") {
                SecureField("API Key", text: $claudeKey)
                    .onChange(of: claudeKey) { _, val in KeychainHelper.save(.claudeApiKey, value: val) }
                TextField("API 地址", text: $claudeBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("模型名称", text: $claudeModel)
                    .textFieldStyle(.roundedBorder)
                Text("第三方平台请修改 API 地址，路径 /v1/messages 会自动拼接")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                testButton(label: "测试 Claude API", key: "claude") {
                    claudeTestResult = await APITestHelper.testClaude()
                }
                testResultView(claudeTestResult)
            }

            Section("OpenAI API") {
                SecureField("API Key", text: $openaiKey)
                    .onChange(of: openaiKey) { _, val in KeychainHelper.save(.openaiApiKey, value: val) }
                TextField("API 地址", text: $openaiBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("模型名称", text: $openaiModel)
                    .textFieldStyle(.roundedBorder)
                Text("第三方平台请修改 API 地址，路径 /v1/chat/completions 会自动拼接")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                testButton(label: "测试 OpenAI API", key: "openai") {
                    openaiTestResult = await APITestHelper.testOpenAI()
                }
                testResultView(openaiTestResult)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testButton(label: String, key: String, action: @escaping () async -> Void) -> some View {
        Button {
            isTesting = key
            Task {
                await action()
                isTesting = nil
            }
        } label: {
            HStack(spacing: 6) {
                if isTesting == key {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                    Text("测试中…")
                } else {
                    Image(systemName: "network")
                    Text(label)
                }
            }
        }
        .disabled(isTesting != nil)
    }

    @ViewBuilder
    private func testResultView(_ result: (success: Bool, message: String)?) -> some View {
        if let result {
            HStack(spacing: 4) {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.success ? .green : .red)
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(result.success ? .green : .red)
            }
        }
    }

    private func loadCredentials() {
        spDc = KeychainHelper.load(.spotifySpDc) ?? ""
        claudeKey = KeychainHelper.load(.claudeApiKey) ?? ""
        openaiKey = KeychainHelper.load(.openaiApiKey) ?? ""
    }

    private var availableFonts: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }
}
