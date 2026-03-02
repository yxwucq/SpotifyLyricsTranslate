import Foundation

// MARK: - DuckDuckGo Search

enum DuckDuckGoSearch {
    static func search(track: Track) async -> String {
        let query = "\"\(track.name)\" \"\(track.artist)\" song meaning background"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return ""
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return ""
            }
            return extractSnippets(from: html)
        } catch {
            return ""
        }
    }

    private static func extractSnippets(from html: String) -> String {
        // Extract text from result__snippet class elements
        let pattern = #"class="result__snippet"[^>]*>(.*?)</[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return ""
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        let snippets = matches.prefix(5).compactMap { match -> String? in
            guard let snippetRange = Range(match.range(at: 1), in: html) else { return nil }
            var text = String(html[snippetRange])
            // Strip HTML tags
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            // Decode common HTML entities
            text = text.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#x27;", with: "'")
                .replacingOccurrences(of: "&#39;", with: "'")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        return snippets.joined(separator: "\n")
    }
}

// MARK: - Song Meaning Model

struct SongMeaning {
    let summary: String
    var background: String = ""
    var metaphors: String = ""

    static func parse(_ text: String) -> SongMeaning {
        var summary = ""
        var background = ""
        var metaphors = ""

        // Split by section markers: [歌曲大意] [创作背景] [意象与隐喻]
        let sections = text.components(separatedBy: "\n")
        var current = ""
        var buffer: [String] = []

        func flush() {
            let content = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            switch current {
            case "summary": summary = content
            case "background": background = content
            case "metaphors": metaphors = content
            default: if summary.isEmpty { summary = content }
            }
            buffer = []
        }

        for line in sections {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[歌曲大意]") {
                flush()
                current = "summary"
                let rest = trimmed.replacingOccurrences(of: "[歌曲大意]", with: "").trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { buffer.append(rest) }
            } else if trimmed.hasPrefix("[创作背景]") {
                flush()
                current = "background"
                let rest = trimmed.replacingOccurrences(of: "[创作背景]", with: "").trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { buffer.append(rest) }
            } else if trimmed.hasPrefix("[意象与隐喻]") {
                flush()
                current = "metaphors"
                let rest = trimmed.replacingOccurrences(of: "[意象与隐喻]", with: "").trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { buffer.append(rest) }
            } else {
                buffer.append(line)
            }
        }
        flush()

        return SongMeaning(summary: summary, background: background, metaphors: metaphors)
    }
}

// MARK: - Song Meaning Generator

enum SongMeaningError: LocalizedError {
    case noApiKey, apiError, parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey: "请在设置中配置 API Key"
        case .apiError: "API 调用失败"
        case .parseError: "结果解析失败"
        }
    }
}

enum SongMeaningGenerator {
    static func generate(track: Track, lyrics: [LyricLine], searchContext: String) async throws -> String {
        let lyricsText = lyrics.map(\.text).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
        let language = AppSettings.targetLanguage

        let contextSection: String
        if searchContext.isEmpty {
            contextSection = "（无搜索结果，请基于你的知识和歌词内容分析）"
        } else {
            contextSection = "以下是关于这首歌的搜索参考资料：\n\(searchContext)"
        }

        let prompt = """
        你是一位有亲和力的音乐评论家。请为以下歌曲撰写解读。

        写作要求：
        - 语言流畅自然，可以有文艺感但必须通俗易懂，像跟朋友聊天一样讲清楚
        - 全程使用中文表达，不要夹杂英文单词或短语
        - 遇到歌词中的外语关键词时，用括号附上简要释义，例如「歌词中的 'nevermore'（永不再来）表达了……」
        - 用自己的话阐述含义，不要大段引用或反复摘录原歌词
        - 不要使用 Markdown 格式符号

        严格按以下格式输出三个段落，每段以方括号标记开头：

        [歌曲大意]
        用 2-3 句话概括这首歌在讲什么、传达怎样的情感。

        [创作背景]
        介绍歌曲的创作背景、灵感来源、发行故事等。如果不确定，可以简要说明并侧重歌词分析。

        [意象与隐喻]
        分析歌词中值得玩味的意象和深层含义，如有外语歌词请解释关键词含义。

        歌曲：\(track.name)
        歌手：\(track.artist)
        专辑：\(track.album)

        歌词：
        \(lyricsText)

        \(contextSection)

        请用\(languageName(for: language))输出。
        """

        switch AppSettings.translationProviderEnum {
        case .claude:
            return try await callClaude(prompt: prompt)
        case .openai:
            return try await callOpenAI(prompt: prompt)
        }
    }

    private static func callClaude(prompt: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(.claudeApiKey), !apiKey.isEmpty else {
            throw SongMeaningError.noApiKey
        }

        let body: [String: Any] = [
            "model": AppSettings.claudeModel,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": prompt]]
        ]

        let baseURL = AppSettings.claudeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SongMeaningError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw SongMeaningError.parseError
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func callOpenAI(prompt: String) async throws -> String {
        guard let apiKey = KeychainHelper.load(.openaiApiKey), !apiKey.isEmpty else {
            throw SongMeaningError.noApiKey
        }

        let body: [String: Any] = [
            "model": AppSettings.openaiModel,
            "messages": [["role": "user", "content": prompt]]
        ]

        let baseURL = AppSettings.openaiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SongMeaningError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw SongMeaningError.parseError
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func languageName(for code: String) -> String {
        AppSettings.supportedLanguages.first { $0.code == code }?.name ?? "中文"
    }
}
