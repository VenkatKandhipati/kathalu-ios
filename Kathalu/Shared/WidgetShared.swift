import Foundation
import ActivityKit

/// The contract between the app and the KathaluWidgets extension. This file is
/// a member of BOTH targets: the app writes the App Group snapshot, the widgets
/// read it. Anything time-based (streak, today's story, slot picks) is computed
/// widget-side from raw data so it stays correct even if the app hasn't run.
enum WidgetShared {
    static let appGroupID = "group.me.kathalu.app"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// Widget kinds. Never rename a shipped kind — placed widgets would vanish.
    enum Kind {
        static let streak = "KathaluStreak"
        static let word = "KathaluWord"
        static let todayStory = "KathaluTodayStory"
        static let letter = "KathaluLetter"
        static let sentence = "KathaluSentence"
        static let flashcard = "KathaluFlashcard"
    }

    /// App Group keys. The first three are app-written; the flash* keys are
    /// owned by the flashcard widget's buttons.
    enum Key {
        /// `[String]` of "yyyy-MM-dd" reading days (DayStamp.description).
        static let readDays = "readDays"
        /// `[String: Int]` story index → best proficiency %.
        static let storyBest = "storyBest"
        /// JSON `[FlashcardSnapshot]` in Review-tab order (due, then new),
        /// followed by upcoming cards so the widget stays right past midnight.
        static let flashcards = "flashcards"
        static let flashRevealed = "flashRevealed"
        /// JSON `[FlashcardGrades.Grade]` — Hard/Good taps the app hasn't applied yet.
        static let flashGrades = "flashGrades"
        /// `Int` the reader's current story level (StoryLevel raw value);
        /// today's story is picked from that level.
        static let currentLevel = "currentLevel"
        /// `Int` taps on the Lock Screen word (widget-owned); each one picks another word.
        static let lockWordTaps = "lockWordTaps"
    }

    /// `kathalu://` deep links, routed by `AppModel.handleDeepLink`.
    enum Link {
        static func story(_ index: Int) -> URL { URL(string: "kathalu://story/\(index)")! }
        static let review = URL(string: "kathalu://review")!
        static func letter(_ letter: String) -> URL {
            var components = URLComponents()
            components.scheme = "kathalu"
            components.host = "letter"
            components.path = "/" + letter
            return components.url ?? review
        }
    }
}

/// One deck card as the flashcard widget sees it.
struct FlashcardSnapshot: Codable, Hashable {
    let telugu: String
    let trans: String
    let meaning: String?
    /// "yyyy-MM-dd" (DayStamp.description); the widget shows cards due today.
    var nextReview: String?
}

/// Grades given on the flashcard widget, logged by the widget and applied by
/// the app (same SM-2 path as the Review tab) when it next launches or comes
/// to the foreground.
enum FlashcardGrades {
    struct Grade: Codable, Hashable {
        var id = UUID()
        let word: String
        let quality: Int
        var at = Date()
    }

    static func pending() -> [Grade] {
        guard let data = WidgetShared.defaults?.data(forKey: WidgetShared.Key.flashGrades),
              let grades = try? JSONDecoder().decode([Grade].self, from: data)
        else { return [] }
        return grades
    }

    static func enqueue(word: String, quality: Int) {
        save(pending() + [Grade(word: word, quality: quality)])
    }

    /// Drops applied grades, keeping any logged since they were read.
    static func remove(_ ids: Set<UUID>) {
        save(pending().filter { !ids.contains($0.id) })
    }

    private static func save(_ grades: [Grade]) {
        WidgetShared.defaults?.set(try? JSONEncoder().encode(grades), forKey: WidgetShared.Key.flashGrades)
    }
}

/// The "currently reading" Live Activity (iPhone only — iPadOS has no Live
/// Activities). Started when the reader opens, updated when it's backgrounded.
struct ReadingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var wordsLookedUp: Int
        var secondsRead: Int
        var finished: Bool
    }

    let storyIndex: Int
    let title: String
    let titleEn: String
}
