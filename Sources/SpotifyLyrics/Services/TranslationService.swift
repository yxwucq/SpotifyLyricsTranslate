import Foundation

protocol TranslationProviderProtocol {
    func translate(lines: [String], to language: String) async throws -> [String]
}

final class ClaudeTranslationProvider: TranslationProviderProtocol {
    func translate(lines: [String], to language: String) async throws -> [String] {
        guard let apiKey = KeychainHelper.load(.claudeApiKey), !apiKey.isEmpty else {
            throw TranslationError.noApiKey
        }

        let numberedLines = lines.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Translate the following song lyrics to \(language). Return ONLY the translations, one per line, numbered to match. \
        Keep the same number of lines. Do not add explanations. If a line is empty or instrumental, return an empty line with just the number.

        \(numberedLines)
        """

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
            throw TranslationError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw TranslationError.parseError
        }

        return parseNumberedResponse(text, expectedCount: lines.count)
    }
}

final class OpenAITranslationProvider: TranslationProviderProtocol {
    func translate(lines: [String], to language: String) async throws -> [String] {
        guard let apiKey = KeychainHelper.load(.openaiApiKey), !apiKey.isEmpty else {
            throw TranslationError.noApiKey
        }

        let numberedLines = lines.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Translate the following song lyrics to \(language). Return ONLY the translations, one per line, numbered to match. \
        Keep the same number of lines. Do not add explanations.

        \(numberedLines)
        """

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
            throw TranslationError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw TranslationError.parseError
        }

        return parseNumberedResponse(text, expectedCount: lines.count)
    }
}

private func parseNumberedResponse(_ text: String, expectedCount: Int) -> [String] {
    let lines = text.components(separatedBy: "\n")
        .map { line in
            // Strip "1. ", "2. " etc. prefix
            if let range = line.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                return String(line[range.upperBound...])
            }
            return line
        }
        .filter { !$0.isEmpty }

    // Pad or trim to match expected count
    if lines.count >= expectedCount {
        return Array(lines.prefix(expectedCount))
    }
    return lines + Array(repeating: "", count: expectedCount - lines.count)
}

enum APITestHelper {
    static func testClaude() async -> (success: Bool, message: String) {
        guard let apiKey = KeychainHelper.load(.claudeApiKey), !apiKey.isEmpty else {
            return (false, "未配置 API Key")
        }
        let baseURL = AppSettings.claudeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            return (false, "API 地址无效")
        }
        let body: [String: Any] = [
            "model": AppSettings.claudeModel,
            "max_tokens": 16,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "无响应")
            }
            if http.statusCode == 200 {
                return (true, "连接成功 (\(baseURL), 模型: \(AppSettings.claudeModel))")
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errMsg = (json?["error"] as? [String: Any])?["message"] as? String
            return (false, "HTTP \(http.statusCode): \(errMsg ?? "未知错误")")
        } catch {
            return (false, "网络错误: \(error.localizedDescription)")
        }
    }

    static func testOpenAI() async -> (success: Bool, message: String) {
        guard let apiKey = KeychainHelper.load(.openaiApiKey), !apiKey.isEmpty else {
            return (false, "未配置 API Key")
        }
        let baseURL = AppSettings.openaiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            return (false, "API 地址无效")
        }
        let body: [String: Any] = [
            "model": AppSettings.openaiModel,
            "max_tokens": 16,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "无响应")
            }
            if http.statusCode == 200 {
                return (true, "连接成功 (\(baseURL), 模型: \(AppSettings.openaiModel))")
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errMsg = (json?["error"] as? [String: Any])?["message"] as? String
            return (false, "HTTP \(http.statusCode): \(errMsg ?? "未知错误")")
        } catch {
            return (false, "网络错误: \(error.localizedDescription)")
        }
    }

    static func testSpotify() async -> (success: Bool, message: String) {
        guard let spDc = KeychainHelper.load(.spotifySpDc), !spDc.isEmpty else {
            return (false, "未配置 sp_dc Cookie")
        }
        var request = URLRequest(url: URL(string: "https://open.spotify.com/get_access_token?reason=transport&productType=web_player")!)
        request.setValue("sp_dc=\(spDc)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, "无响应")
            }
            if http.statusCode == 200 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if json?["accessToken"] as? String != nil {
                    return (true, "认证成功")
                }
                return (false, "返回数据异常")
            }
            return (false, "HTTP \(http.statusCode): 认证失败，请检查 sp_dc")
        } catch {
            return (false, "网络错误: \(error.localizedDescription)")
        }
    }
}

enum TranslationError: LocalizedError {
    case noApiKey, apiError, parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey: "请在设置中配置 API Key"
        case .apiError: "翻译 API 调用失败"
        case .parseError: "翻译结果解析失败"
        }
    }
}
