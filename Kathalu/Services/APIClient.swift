import Foundation

/// Thin async client for the Kathalu FastAPI backend (api.kathalu.me).
final class APIClient {
    enum APIError: LocalizedError {
        case unauthorized
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Your session expired. Please sign in again."
            case .http(let code): return "Server error (\(code))."
            }
        }
    }

    var baseURL = URL(string: "https://api.kathalu.me")!
    private let auth: AuthService

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            // Backend datetimes come with fractional seconds and sometimes without.
            let raw = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: raw) { return date }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: raw + (raw.hasSuffix("Z") || raw.contains("+") ? "" : "Z")) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)"))
        }
        return d
    }()

    init(auth: AuthService) {
        self.auth = auth
    }

    // MARK: Endpoints

    func listCards() async throws -> [CardOut] {
        try await request("GET", "cards")
    }

    func upsertCard(_ card: CardIn) async throws -> CardOut {
        try await request("POST", "cards", body: card)
    }

    func rateCard(id: UUID, quality: Int) async throws -> CardOut {
        try await request("POST", "cards/\(id.uuidString.lowercased())/rate", body: ["quality": quality])
    }

    func syncCardStates(_ batch: CardStateSyncBatch) async throws {
        try await requestVoid("POST", "cards/state-sync", body: batch)
    }

    func listProgress() async throws -> [StoryProgressOut] {
        try await request("GET", "progress")
    }

    func saveProgress(_ progress: StoryProgressIn) async throws -> StoryProgressOut {
        try await request("POST", "progress", body: progress)
    }

    func markReadingDay() async throws {
        try await requestVoid("POST", "reading-days", body: Optional<Int>.none)
    }

    func streak() async throws -> StreakOut {
        try await request("GET", "streak")
    }

    func importData(_ payload: ImportPayload) async throws -> ImportResult {
        try await request("POST", "import", body: payload)
    }

    func recordSession(_ session: ReadingSessionIn) async throws {
        try await requestVoid("POST", "account/sessions", body: session)
    }

    func changePassword(_ newPassword: String) async throws {
        try await requestVoid("POST", "account/password", body: PasswordChangeIn(newPassword: newPassword))
    }

    func deleteAccount() async throws {
        try await requestVoid("DELETE", "account", body: Optional<Int>.none)
    }

    // MARK: Plumbing

    private func request<Response: Decodable>(
        _ method: String, _ path: String, body: (some Encodable)? = Optional<Int>.none
    ) async throws -> Response {
        let data = try await send(method, path, body: body)
        return try decoder.decode(Response.self, from: data)
    }

    private func requestVoid(_ method: String, _ path: String, body: (some Encodable)?) async throws {
        _ = try await send(method, path, body: body)
    }

    private func send(_ method: String, _ path: String, body: (some Encodable)?) async throws -> Data {
        var attempt = 0
        while true {
            guard let session = auth.session else { throw APIError.unauthorized }
            var request = URLRequest(url: baseURL.appendingPathComponent(path))
            request.httpMethod = method
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300:
                return data
            case 401 where attempt == 0:
                attempt += 1
                _ = try await auth.refresh()  // retry once with a fresh token
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.http(status)
            }
        }
    }
}
