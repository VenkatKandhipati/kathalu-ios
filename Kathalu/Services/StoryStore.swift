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
        for i in decoded.indices { decoded[i].index = i }
        stories = decoded
    }

    /// Same "story of the day" rule as the web app: dayOfYear % count.
    var todayIndex: Int {
        guard !stories.isEmpty else { return 0 }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return dayOfYear % stories.count
    }

    var today: Story? { stories.indices.contains(todayIndex) ? stories[todayIndex] : nil }
}
