import Foundation

actor SpotifyAuthService {
    private var accessToken: String?
    private var tokenExpiry: Date?

    func getAccessToken() async throws -> String {
        if let token = accessToken, let expiry = tokenExpiry, Date.now < expiry {
            return token
        }
        return try await refreshToken()
    }

    private func refreshToken() async throws -> String {
        guard let spDc = KeychainHelper.load(.spotifySpDc), !spDc.isEmpty else {
            throw AuthError.noSpDcCookie
        }

        var request = URLRequest(url: URL(string: "https://open.spotify.com/get_access_token?reason=transport&productType=web_player")!)
        request.setValue("sp_dc=\(spDc)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.tokenRequestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["accessToken"] as? String else {
            throw AuthError.invalidResponse
        }

        let expiresIn = json?["accessTokenExpirationTimestampMs"] as? Int64 ?? 0
        self.accessToken = token
        self.tokenExpiry = Date(timeIntervalSince1970: Double(expiresIn) / 1000.0)

        return token
    }

    func invalidateToken() {
        accessToken = nil
        tokenExpiry = nil
    }

    enum AuthError: LocalizedError {
        case noSpDcCookie
        case tokenRequestFailed
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .noSpDcCookie: L.errNoSpDcCookie
            case .tokenRequestFailed: L.errTokenRequestFailed
            case .invalidResponse: L.errSpotifyInvalidResponse
            }
        }
    }
}
