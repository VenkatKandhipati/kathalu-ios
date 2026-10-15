import Foundation

/// Loads the bundled story catalog (migrated from the web app's stories.js).
struct StoryStore {
    let stories: [Story]

    init() {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var decoded = try? JSONDecoder().decode([Story].self, from: data)
        else {
            assertionFailure("stories.json missing from bundle")
            stories = []
            return
        }
        for i in decoded.indices {
            decoded[i].index = i
            decoded[i].wordCount = decoded[i].words.count
            decoded[i].level = decoded[i].levelOverride.flatMap(StoryLevel.init(rawValue:))
                ?? .forWordCount(decoded[i].wordCount)
        }
        stories = decoded
    }

    func stories(at level: StoryLevel) -> [Story] {
        stories.filter { $0.level == level }
    }

    var todayIndex: Int { index(for: .now) }

    /// The story-of-the-day index for any date (widgets and reminders
    /// schedule ahead with it): dayOfYear % count, like the web app, but drawn
    /// from the reader's current level so it's never too hard or too easy.
    /// The level comes from the App Group (written by `AppModel`), so the app,
    /// widgets and reminders always agree; all stories if it's unset or empty.
    func index(for date: Date) -> Int {
        guard !stories.isEmpty else { return 0 }
        let level = (WidgetShared.defaults?.integer(forKey: WidgetShared.Key.currentLevel))
            .flatMap(StoryLevel.init(rawValue:))
        let atLevel = level.map(stories(at:)) ?? []
        let pool = atLevel.isEmpty ? stories : atLevel
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return pool[dayOfYear % pool.count].index
    }

    var today: Story? { stories.indices.contains(todayIndex) ? stories[todayIndex] : nil }
}
