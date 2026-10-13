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

    /// App Group keys. The first three are app-written; the flash* pair is
    /// owned by the flashcard widget's buttons.
    enum Key {
        /// `[String]` of "yyyy-MM-dd" reading days (DayStamp.description).
        static let readDays = "readDays"
        /// `[String: Int]` story index → best proficiency %.
        static let storyBest = "storyBest"
        /// JSON `[FlashcardSnapshot]`, due cards first.
        static let flashcards = "flashcards"
        static let flashPosition = "flashPosition"
        static let flashRevealed = "flashRevealed"
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
