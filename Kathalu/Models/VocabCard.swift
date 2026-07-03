import Foundation

/// A vocabulary flashcard with SM-2 scheduling state.
/// Mirrors the web app's vocabCards entries and the backend Card row.
struct VocabCard: Codable, Identifiable, Hashable {
    var telugu: String
    var trans: String?
    var meaning: String?
    var storyIdx: Int?
    var interval: Int = 0
    var easeFactor: Double = 2.5
    var repetitions: Int = 0
    var nextReview: DayStamp = .today
    var addedAt: Date = .now
    /// How many times the reader looked this word up (drives "Most looked-up").
    var lookups: Int = 1
    /// Server-side row id once synced.
    var serverID: UUID?

    var id: String { telugu }

    var isDue: Bool { nextReview <= .today }
    var isNew: Bool { repetitions == 0 }
}

/// A calendar day (no time), serialized as "yyyy-MM-dd" to match the backend's date fields.
struct DayStamp: Codable, Hashable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    static var today: DayStamp { DayStamp(date: .now) }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    init?(string: String) {
        let parts = string.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let stamp = DayStamp(string: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid day stamp: \(raw)"))
        }
        self = stamp
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    func adding(days: Int) -> DayStamp {
        DayStamp(date: Calendar.current.date(byAdding: .day, value: days, to: date) ?? date)
    }

    static func < (lhs: DayStamp, rhs: DayStamp) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// Per-story reading progress, mirroring the web app's storyProgress entries.
struct StoryProgressEntry: Codable, Hashable {
    var bestPct: Int
    var lastRead: DayStamp
}
