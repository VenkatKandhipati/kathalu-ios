import Foundation

/// Everything the web app kept in localStorage, as one codable document
/// persisted to Application Support. Works fully offline; SyncEngine mirrors
/// changes to the cloud when signed in.
struct UserData: Codable {
    /// Keyed by the Telugu word, like the web app's vocabCards object.
    var cards: [String: VocabCard] = [:]
    var storyProgress: [Int: StoryProgressEntry] = [:]
    /// Days with at least one reading session, most recent first (max 365).
    var readingDates: [DayStamp] = []
    /// Tap counts per word, including words never added to the deck.
    var wordTaps: [String: Int] = [:]

    var streak: Int {
        guard !readingDates.isEmpty else { return 0 }
        let days = Set(readingDates)
        var cursor = DayStamp.today
        if !days.contains(cursor) {
            cursor = cursor.adding(days: -1)  // streak survives until today is missed
            guard days.contains(cursor) else { return 0 }
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = cursor.adding(days: -1)
        }
        return count
    }
}

/// Script-deck SM-2 state, stored beside userdata.json but deliberately
/// outside UserData: SyncEngine rebuilds UserData from the server on sign-in,
/// and akshara progress is local-only, so it must not ride along.
final class AksharaStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "aksharacards.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kathalu", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
    }

    func load() -> [String: AksharaCard] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([String: AksharaCard].self, from: data)
        else { return [:] }
        return decoded
    }

    func save(_ cards: [String: AksharaCard]) {
        guard let encoded = try? encoder.encode(cards) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}

final class LocalStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "userdata.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kathalu", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> UserData {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(UserData.self, from: data)
        else { return UserData() }
        return decoded
    }

    func save(_ data: UserData) {
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
