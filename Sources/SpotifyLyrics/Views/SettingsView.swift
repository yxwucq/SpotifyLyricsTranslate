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

    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        TabView {
            generalTab.tabItem { Label(L.tabGeneral, systemImage: "gear") }
            appearanceTab.tabItem { Label(L.tabAppearance, systemImage: "paintbrush") }
            credentialsTab.tabItem { Label(L.tabCredentials, systemImage: "key") }
        }
        .frame(width: 450, height: 520)
        .onAppear { loadCredentials() }
    }

    private var generalTab: some View {
        Form {
            Section(L.appLanguageLabel) {
                Picker(L.appLanguageLabel, selection: $appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) {
                        Text($0.displayName).tag($0.rawValue)
                    }
                }
            }

            Section(L.lyricsSource) {
                Picker(L.source, selection: $lyricsSource) {
                    ForEach(LyricsSource.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
            }

            Section(L.translation) {
                Toggle(L.enableTranslationToggle, isOn: $translationEnabled)

                Picker(L.translationService, selection: $translationProvider) {
                    ForEach(TranslationProvider.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }

                Picker(L.targetLanguage, selection: $targetLanguage) {
                    ForEach(AppSettings.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
            }

            Section(L.translationCache) {
                HStack {
                    TextField(L.cachePathPlaceholder, text: $translationCachePath)
                        .textFieldStyle(.roundedBorder)
                    Button(L.choose) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true
                        panel.prompt = L.chooseCacheFolder
                        if panel.runModal() == .OK, let url = panel.url {
                            translationCachePath = url.path
                        }
                    }
                    if !translationCachePath.isEmpty {
                        Button(L.reset) { translationCachePath = "" }
                    }
                }
                Text("\(L.defaultCachePath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(cacheInfo.isEmpty ? L.loading : cacheInfo)
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
                            Text(L.clearCache)
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
            cacheInfo = L.cacheUnavailable
            return
        }
        let info = await cache.cacheSize()
        let sizeStr = ByteCountFormatter.string(fromByteCount: info.totalBytes, countStyle: .file)
        cacheInfo = L.cacheInfo(count: info.fileCount, size: sizeStr)
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
            Section(L.font) {
                Picker(L.fontFamily, selection: $fontFamily) {
                    Text(L.systemDefault).tag("System")
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                HStack {
                    Text(L.fontSize(Int(fontSize)))
                    Slider(value: $fontSize, in: 12...48, step: 1)
                }
            }

            Section(L.lyricsLayout) {
                Picker(L.alignment, selection: $lyricAlignment) {
                    Text(L.alignLeft).tag("leading")
                    Text(L.alignCenter).tag("center")
                    Text(L.alignRight).tag("trailing")
                }

                HStack {
                    Text(L.translationFontScale(Int(translationFontScale * 100)))
                    Slider(value: $translationFontScale, in: 0.6...1.0, step: 0.05)
                }

                HStack {
                    Text(L.lineSpacing(Int(lineSpacing)))
                    Slider(value: $lineSpacing, in: 0...20, step: 1)
                }
            }

            Section(L.activeLineEffects) {
                HStack {
                    Text(L.scaleRatio(String(format: "%.2f", activeLineScale)))
                    Slider(value: $activeLineScale, in: 1.0...1.4, step: 0.05)
                }

                Toggle(L.highlightBackground, isOn: $activeLineHighlight)

                if activeLineHighlight {
                    ColorPicker(L.highlightColor, selection: $highlightColor)
                        .onChange(of: highlightColor) { _, c in activeLineHighlightColorHex = c.hexString }

                    HStack {
                        Text(L.highlightOpacity(Int(activeLineHighlightOpacity * 100)))
                        Slider(value: $activeLineHighlightOpacity, in: 0.02...0.3, step: 0.02)
                    }
                }

                HStack {
                    Text(L.inactiveLineOpacity(Int(inactiveLineOpacity * 100)))
                    Slider(value: $inactiveLineOpacity, in: 0.1...0.8, step: 0.05)
                }
            }

            Section(L.colors) {
                ColorPicker(L.currentLine, selection: $currentLineColor)
                    .onChange(of: currentLineColor) { _, c in currentLineColorHex = c.hexString }
                ColorPicker(L.otherLines, selection: $otherLineColor)
                    .onChange(of: otherLineColor) { _, c in otherLineColorHex = c.hexString }
                ColorPicker(L.translationLine, selection: $translationLineColor)
                    .onChange(of: translationLineColor) { _, c in translationColorHex = c.hexString }
            }

            Section(L.background) {
                HStack {
                    Text(L.opacity(Int(backgroundOpacity * 100)))
                    Slider(value: $backgroundOpacity, in: 0.1...1.0, step: 0.05)
                }
            }

            Section(L.floatingBar) {
                HStack {
                    Text(L.barWidth(Int(barWidth)))
                    Slider(value: $barWidth, in: 300...1200, step: 10)
                }
            }

            Section {
                Button(L.resetAllAppearance, role: .destructive) {
                    showResetConfirm = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .confirmationDialog(L.resetConfirmMessage, isPresented: $showResetConfirm) {
                Button(L.resetDefault, role: .destructive) { resetAppearance() }
                Button(L.cancel, role: .cancel) {}
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
                Text(L.spDcHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                testButton(label: L.testSpotify, key: "spotify") {
                    spotifyTestResult = await APITestHelper.testSpotify()
                }
                testResultView(spotifyTestResult)
            }

            Section("Claude API") {
                SecureField("API Key", text: $claudeKey)
                    .onChange(of: claudeKey) { _, val in KeychainHelper.save(.claudeApiKey, value: val) }
                TextField(L.apiAddress, text: $claudeBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField(L.modelName, text: $claudeModel)
                    .textFieldStyle(.roundedBorder)
                Text(L.claudeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                testButton(label: L.testClaude, key: "claude") {
                    claudeTestResult = await APITestHelper.testClaude()
                }
                testResultView(claudeTestResult)
            }

            Section("OpenAI API") {
                SecureField("API Key", text: $openaiKey)
                    .onChange(of: openaiKey) { _, val in KeychainHelper.save(.openaiApiKey, value: val) }
                TextField(L.apiAddress, text: $openaiBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField(L.modelName, text: $openaiModel)
                    .textFieldStyle(.roundedBorder)
                Text(L.openaiHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                testButton(label: L.testOpenAI, key: "openai") {
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
                    Text(L.testing)
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
