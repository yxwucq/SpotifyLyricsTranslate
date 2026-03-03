import Foundation

protocol TranslationProviderProtocol {
    func translate(lines: [String], to language: String) async throws -> [String]
    func streamTranslate(lines: [String], to language: String) -> AsyncThrowingStream<(Int, String), Error>
}

final class ClaudeTranslationProvider: TranslationProviderProtocol {
    func translate(lines: [String], to language: String) async throws -> [String] {
        guard let apiKey = KeychainHelper.load(.claudeApiKey), !apiKey.isEmpty else {
            throw TranslationError.noApiKey
        }

        let numberedLines = lines.enumerated().map { "[\($0.offset + 1)] \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Translate the following song lyrics to \(language).

        Rules:
        - Return EXACTLY \(lines.count) lines, one translation per line
        - Each line MUST start with its number in brackets like [1], [2], etc.
        - Translate line by line. Each [N] corresponds to the original [N]. Do NOT merge or split lines
        - If a line is empty, instrumental, or untranslatable, return just the number tag like: [5]
        - Do not add any explanation or extra text

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

    func streamTranslate(lines: [String], to language: String) -> AsyncThrowingStream<(Int, String), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = KeychainHelper.load(.claudeApiKey), !apiKey.isEmpty else {
                        throw TranslationError.noApiKey
                    }

                    let numberedLines = lines.enumerated().map { "[\($0.offset + 1)] \($0.element)" }.joined(separator: "\n")
                    let prompt = """
                    Translate the following song lyrics to \(language).

                    Rules:
                    - Return EXACTLY \(lines.count) lines, one translation per line
                    - Each line MUST start with its number in brackets like [1], [2], etc.
                    - Translate line by line. Each [N] corresponds to the original [N]. Do NOT merge or split lines
                    - If a line is empty, instrumental, or untranslatable, return just the number tag like: [5]
                    - Do not add any explanation or extra text

                    \(numberedLines)
                    """

                    let body: [String: Any] = [
                        "model": AppSettings.claudeModel,
                        "max_tokens": 4096,
                        "stream": true,
                        "messages": [["role": "user", "content": prompt]]
                    ]

                    let baseURL = AppSettings.claudeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    var request = URLRequest(url: URL(string: "\(baseURL)/v1/messages")!)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw TranslationError.apiError
                    }

                    var buffer = ""
                    let tagPattern = try! NSRegularExpression(pattern: #"^\[(\d+)\]\s*(.*)"#)
                    var emittedLines = Set<Int>()

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                        // Claude SSE: {"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
                        guard let delta = json["delta"] as? [String: Any],
                              let text = delta["text"] as? String else { continue }

                        buffer += text

                        // Parse completed lines from buffer
                        while let newlineRange = buffer.range(of: "\n") {
                            let completedLine = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                            buffer = String(buffer[newlineRange.upperBound...])

                            let trimmed = completedLine.trimmingCharacters(in: .whitespaces)
                            let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                            if let match = tagPattern.firstMatch(in: trimmed, range: nsRange),
                               let numRange = Range(match.range(at: 1), in: trimmed),
                               let textRange = Range(match.range(at: 2), in: trimmed),
                               let idx = Int(trimmed[numRange]),
                               idx >= 1, idx <= lines.count,
                               !emittedLines.contains(idx) {
                                emittedLines.insert(idx)
                                continuation.yield((idx - 1, String(trimmed[textRange])))
                            }
                        }
                    }

                    // Handle remaining buffer (last line without trailing newline)
                    if !buffer.isEmpty {
                        let trimmed = buffer.trimmingCharacters(in: .whitespaces)
                        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                        if let match = tagPattern.firstMatch(in: trimmed, range: nsRange),
                           let numRange = Range(match.range(at: 1), in: trimmed),
                           let textRange = Range(match.range(at: 2), in: trimmed),
                           let idx = Int(trimmed[numRange]),
                           idx >= 1, idx <= lines.count,
                           !emittedLines.contains(idx) {
                            continuation.yield((idx - 1, String(trimmed[textRange])))
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

final class OpenAITranslationProvider: TranslationProviderProtocol {
    func translate(lines: [String], to language: String) async throws -> [String] {
        guard let apiKey = KeychainHelper.load(.openaiApiKey), !apiKey.isEmpty else {
            throw TranslationError.noApiKey
        }

        let numberedLines = lines.enumerated().map { "[\($0.offset + 1)] \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Translate the following song lyrics to \(language).

        Rules:
        - Return EXACTLY \(lines.count) lines, one translation per line
        - Each line MUST start with its number in brackets like [1], [2], etc.
        - Translate line by line. Each [N] corresponds to the original [N]. Do NOT merge or split lines
        - If a line is empty, instrumental, or untranslatable, return just the number tag like: [5]
        - Do not add any explanation or extra text

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

    func streamTranslate(lines: [String], to language: String) -> AsyncThrowingStream<(Int, String), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = KeychainHelper.load(.openaiApiKey), !apiKey.isEmpty else {
                        throw TranslationError.noApiKey
                    }

                    let numberedLines = lines.enumerated().map { "[\($0.offset + 1)] \($0.element)" }.joined(separator: "\n")
                    let prompt = """
                    Translate the following song lyrics to \(language).

                    Rules:
                    - Return EXACTLY \(lines.count) lines, one translation per line
                    - Each line MUST start with its number in brackets like [1], [2], etc.
                    - Translate line by line. Each [N] corresponds to the original [N]. Do NOT merge or split lines
                    - If a line is empty, instrumental, or untranslatable, return just the number tag like: [5]
                    - Do not add any explanation or extra text

                    \(numberedLines)
                    """

                    let body: [String: Any] = [
                        "model": AppSettings.openaiModel,
                        "stream": true,
                        "messages": [["role": "user", "content": prompt]]
                    ]

                    let baseURL = AppSettings.openaiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    var request = URLRequest(url: URL(string: "\(baseURL)/v1/chat/completions")!)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw TranslationError.apiError
                    }

                    var buffer = ""
                    let tagPattern = try! NSRegularExpression(pattern: #"^\[(\d+)\]\s*(.*)"#)
                    var emittedLines = Set<Int>()

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                        // OpenAI SSE: {"choices":[{"delta":{"content":"..."}}]}
                        guard let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let text = delta["content"] as? String else { continue }

                        buffer += text

                        while let newlineRange = buffer.range(of: "\n") {
                            let completedLine = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                            buffer = String(buffer[newlineRange.upperBound...])

                            let trimmed = completedLine.trimmingCharacters(in: .whitespaces)
                            let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                            if let match = tagPattern.firstMatch(in: trimmed, range: nsRange),
                               let numRange = Range(match.range(at: 1), in: trimmed),
                               let textRange = Range(match.range(at: 2), in: trimmed),
                               let idx = Int(trimmed[numRange]),
                               idx >= 1, idx <= lines.count,
                               !emittedLines.contains(idx) {
                                emittedLines.insert(idx)
                                continuation.yield((idx - 1, String(trimmed[textRange])))
                            }
                        }
                    }

                    // Handle remaining buffer
                    if !buffer.isEmpty {
                        let trimmed = buffer.trimmingCharacters(in: .whitespaces)
                        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                        if let match = tagPattern.firstMatch(in: trimmed, range: nsRange),
                           let numRange = Range(match.range(at: 1), in: trimmed),
                           let textRange = Range(match.range(at: 2), in: trimmed),
                           let idx = Int(trimmed[numRange]),
                           idx >= 1, idx <= lines.count,
                           !emittedLines.contains(idx) {
                            continuation.yield((idx - 1, String(trimmed[textRange])))
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

private func parseNumberedResponse(_ text: String, expectedCount: Int) -> [String] {
    // Build an array indexed by line number, using [N] tags for alignment
    var result = Array(repeating: "", count: expectedCount)
    let rawLines = text.components(separatedBy: "\n")

    let tagPattern = try! NSRegularExpression(pattern: #"^\[(\d+)\]\s*(.*)"#)

    for rawLine in rawLines {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

        if let match = tagPattern.firstMatch(in: trimmed, range: nsRange),
           let numRange = Range(match.range(at: 1), in: trimmed),
           let textRange = Range(match.range(at: 2), in: trimmed),
           let idx = Int(trimmed[numRange]),
           idx >= 1, idx <= expectedCount {
            result[idx - 1] = String(trimmed[textRange])
        }
    }

    // Fallback: if no tags were parsed (model ignored format), try sequential stripping
    if result.allSatisfy({ $0.isEmpty }) {
        let fallback = rawLines
            .map { line in
                var l = line.trimmingCharacters(in: .whitespaces)
                // Strip "1. " or "1) " style prefixes
                if let range = l.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                    l = String(l[range.upperBound...])
                }
                return l
            }
            .filter { !$0.isEmpty }

        for i in 0..<min(fallback.count, expectedCount) {
            result[i] = fallback[i]
        }
    }

    return result
}

enum APITestHelper {
    static func testClaude() async -> (success: Bool, message: String) {
        guard let apiKey = KeychainHelper.load(.claudeApiKey), !apiKey.isEmpty else {
            return (false, L.noApiKeyConfigured)
        }
        let baseURL = AppSettings.claudeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            return (false, L.invalidApiUrl)
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
                return (false, L.noResponse)
            }
            if http.statusCode == 200 {
                return (true, L.connectionSuccess(baseURL, model: AppSettings.claudeModel))
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errMsg = (json?["error"] as? [String: Any])?["message"] as? String
            return (false, L.httpError(http.statusCode, message: errMsg))
        } catch {
            return (false, L.networkError(error.localizedDescription))
        }
    }

    static func testOpenAI() async -> (success: Bool, message: String) {
        guard let apiKey = KeychainHelper.load(.openaiApiKey), !apiKey.isEmpty else {
            return (false, L.noApiKeyConfigured)
        }
        let baseURL = AppSettings.openaiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            return (false, L.invalidApiUrl)
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
                return (false, L.noResponse)
            }
            if http.statusCode == 200 {
                return (true, L.connectionSuccess(baseURL, model: AppSettings.openaiModel))
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errMsg = (json?["error"] as? [String: Any])?["message"] as? String
            return (false, L.httpError(http.statusCode, message: errMsg))
        } catch {
            return (false, L.networkError(error.localizedDescription))
        }
    }

    static func testSpotify() async -> (success: Bool, message: String) {
        guard let spDc = KeychainHelper.load(.spotifySpDc), !spDc.isEmpty else {
            return (false, L.noSpDcConfigured)
        }
        var request = URLRequest(url: URL(string: "https://open.spotify.com/get_access_token?reason=transport&productType=web_player")!)
        request.setValue("sp_dc=\(spDc)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (false, L.noResponse)
            }
            if http.statusCode == 200 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if json?["accessToken"] as? String != nil {
                    return (true, L.authSuccess)
                }
                return (false, L.abnormalResponse)
            }
            return (false, L.authFailed(http.statusCode))
        } catch {
            return (false, L.networkError(error.localizedDescription))
        }
    }
}

enum TranslationError: LocalizedError {
    case noApiKey, apiError, parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey: L.errNoApiKey
        case .apiError: L.errTranslationApiFailed
        case .parseError: L.errTranslationParseFailed
        }
    }
}
