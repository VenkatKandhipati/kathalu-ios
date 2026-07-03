import Foundation
import Security

/// Supabase email/password auth over REST, matching the web app's
/// username → "username@kathalu.local" scheme. Tokens live in the Keychain.
final class AuthService {
    struct Config {
        var supabaseURL = URL(string: "https://cohsteoqoxnhehpsogqd.supabase.co")!
        var anonKey = "sb_publishable_YTVGfTVdIS9oO8dpTLdkDw_p4WbBqDl"
        var emailDomain = "kathalu.local"
    }

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var username: String
        var userID: String
    }

    enum AuthError: LocalizedError {
        case server(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .server(let message): return message
            case .invalidResponse: return "Unexpected response from the server."
            }
        }
    }

    private let config: Config
    private(set) var session: Session?

    init(config: Config = Config()) {
        self.config = config
        session = Keychain.load()
    }

    var isSignedIn: Bool { session != nil }

    func signUp(username: String, password: String) async throws -> Session {
        try await tokenRequest(
            path: "auth/v1/signup", query: nil,
            body: ["email": email(for: username), "password": password],
            username: username)
    }

    func signIn(username: String, password: String) async throws -> Session {
        try await tokenRequest(
            path: "auth/v1/token", query: "grant_type=password",
            body: ["email": email(for: username), "password": password],
            username: username)
    }

    func refresh() async throws -> Session {
        guard let current = session else { throw AuthError.invalidResponse }
        return try await tokenRequest(
            path: "auth/v1/token", query: "grant_type=refresh_token",
            body: ["refresh_token": current.refreshToken],
            username: current.username)
    }

    func signOut() {
        session = nil
        Keychain.delete()
    }

    private func email(for username: String) -> String {
        "\(username.lowercased())@\(config.emailDomain)"
    }

    private struct TokenResponse: Decodable {
        struct User: Decodable { let id: String }
        let accessToken: String?
        let refreshToken: String?
        let user: User?
        // Supabase error shapes vary across endpoints.
        let msg: String?
        let errorDescription: String?
        let message: String?
    }

    private func tokenRequest(
        path: String, query: String?, body: [String: String], username: String
    ) async throws -> Session {
        var url = config.supabaseURL.appendingPathComponent(path)
        if let query {
            url = URL(string: url.absoluteString + "?" + query) ?? url
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try? decoder.decode(TokenResponse.self, from: data)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = decoded?.msg ?? decoded?.errorDescription ?? decoded?.message
            throw AuthError.server(message ?? "Sign-in failed. Check your username and password.")
        }
        guard let access = decoded?.accessToken,
              let refresh = decoded?.refreshToken,
              let userID = decoded?.user?.id
        else { throw AuthError.invalidResponse }

        let newSession = Session(
            accessToken: access, refreshToken: refresh,
            username: username, userID: userID)
        session = newSession
        Keychain.save(newSession)
        return newSession
    }
}

/// Minimal Keychain wrapper for the auth session.
private enum Keychain {
    private static let service = "me.kathalu.session"

    static func save(_ session: AuthService.Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> AuthService.Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(AuthService.Session.self, from: data)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
