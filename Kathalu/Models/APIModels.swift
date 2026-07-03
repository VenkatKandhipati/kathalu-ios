import Foundation

// Wire types mirroring backend/app/schemas.py. Snake_case handled by the
// APIClient's key-decoding strategy.

struct CardOut: Codable {
    var id: UUID
    var telugu: String
    var trans: String?
    var meaning: String?
    var storyIdx: Int?
    var interval: Int
    var easeFactor: Double
    var repetitions: Int
    var nextReview: DayStamp
    var addedAt: Date
}

struct CardIn: Codable {
    var telugu: String
    var trans: String?
    var meaning: String?
    var storyIdx: Int?
}

struct CardStateSync: Codable {
    var telugu: String
    var trans: String?
    var meaning: String?
    var storyIdx: Int?
    var interval: Int
    var easeFactor: Double
    var repetitions: Int
    var nextReview: DayStamp
    var lastQuality: Int?
}

struct CardStateSyncBatch: Codable {
    var cards: [CardStateSync]
}

struct StoryProgressIn: Codable {
    var storyIdx: Int
    var bestPct: Int
}

struct StoryProgressOut: Codable {
    var storyIdx: Int
    var bestPct: Int
    var lastReadAt: Date
}

struct StreakOut: Codable {
    var streak: Int
    var lastRead: DayStamp?
}

struct ImportCard: Codable {
    var telugu: String
    var trans: String?
    var meaning: String?
    var storyIdx: Int?
    var interval: Int
    var easeFactor: Double
    var repetitions: Int
    var nextReview: DayStamp?
    var addedAt: Date?
}

struct ImportPayload: Codable {
    var cards: [ImportCard]
    var storyProgress: [StoryProgressIn]
    var readingDays: [DayStamp]
}

struct ImportResult: Codable {
    var cardsImported: Int
    var storyProgressImported: Int
    var readingDaysImported: Int
}

struct ReadingSessionIn: Codable {
    var storyIdx: Int
    var pct: Int?
}

struct PasswordChangeIn: Codable {
    var newPassword: String
}
