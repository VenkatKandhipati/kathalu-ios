import Foundation

/// A story bundled with the app, mirroring the shape of the web app's stories.js.
struct Story: Decodable, Identifiable, Hashable {
    let title: String
    let titleEn: String
    let collection: String
    let text: String

    /// Optional hand-set level in stories.json (`"level": 2`) for a story
    /// that's harder or easier than its length suggests.
    let levelOverride: Int?

    /// Index within the bundled catalog; assigned by StoryStore after decode.
    var index: Int = 0
    /// Telugu word count and level, computed once by StoryStore after decode.
    var wordCount: Int = 0
    var level: StoryLevel = .stories

    var id: Int { index }

    private enum CodingKeys: String, CodingKey {
        case title, titleEn, collection, text
        case levelOverride = "level"
    }

    var paragraphs: [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Telugu word tokens across the whole story (same tokenization as the web reader).
    var words: [String] {
        TeluguText.words(in: text)
    }

    /// Rough reading time at ~25 Telugu words per minute for a learner.
    var readingMinutes: Int { max(1, Int((Double(wordCount) / 25.0).rounded())) }
}

/// Reading levels, by length: start with very short stories and graduate to
/// longer ones. A story's level comes from its word count unless stories.json
/// overrides it. Shared with the widgets (today's story is picked per level).
enum StoryLevel: Int, CaseIterable, Identifiable, Comparable {
    case firstSteps = 1, little, stories, longer

    var id: Int { rawValue }

    static func < (a: StoryLevel, b: StoryLevel) -> Bool { a.rawValue < b.rawValue }

    static func forWordCount(_ count: Int) -> StoryLevel {
        switch count {
        case ..<41: .firstSteps
        case ..<81: .little
        case ..<151: .stories
        default: .longer
        }
    }

    var name: String {
        switch self {
        case .firstSteps: "First steps"
        case .little: "Little stories"
        case .stories: "Stories"
        case .longer: "Longer stories"
        }
    }

    var teluguName: String {
        switch self {
        case .firstSteps: "మొదటి అడుగు"
        case .little: "చిన్న కథలు"
        case .stories: "కథలు"
        case .longer: "పెద్ద కథలు"
        }
    }

    var lengthHint: String {
        switch self {
        case .firstSteps: "up to 40 words · about 1 min"
        case .little: "40–80 words · 2–3 min"
        case .stories: "80–150 words · 4–6 min"
        case .longer: "150+ words · 7+ min"
        }
    }
}

/// Telugu-script tokenization shared by the reader and stats.
enum TeluguText {
    /// Splits text into runs of Telugu script vs. everything else,
    /// mirroring the web regex /[ఀ-౿]+|[^ఀ-౿]+/g.
    static func tokens(in text: String) -> [(text: String, isTelugu: Bool)] {
        var result: [(String, Bool)] = []
        var current = ""
        var currentIsTelugu: Bool?
        for ch in text {
            let telugu = ch.unicodeScalars.allSatisfy { (0x0C00...0x0C7F).contains($0.value) }
            if telugu == currentIsTelugu {
                current.append(ch)
            } else {
                if let was = currentIsTelugu { result.append((current, was)) }
                current = String(ch)
                currentIsTelugu = telugu
            }
        }
        if let was = currentIsTelugu, !current.isEmpty { result.append((current, was)) }
        return result
    }

    static func words(in text: String) -> [String] {
        tokens(in: text).filter(\.isTelugu).map(\.text)
    }

    /// Splits a paragraph at . ! ? — but never inside quotes (dialogue stays
    /// whole), and ".." is a mid-sentence pause in these stories, not an end.
    static func sentences(in paragraph: String) -> [String] {
        let chars = Array(paragraph)
        var result: [String] = []
        var current = ""
        var quoteDepth = 0
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            current.append(ch)
            switch ch {
            case "‘", "“": quoteDepth += 1
            case "’", "”": quoteDepth = max(0, quoteDepth - 1)
            case "'", "\"": quoteDepth = quoteDepth > 0 ? quoteDepth - 1 : 1
            default: break
            }
            if ".!?".contains(ch) {
                var run = 1
                while i + 1 < chars.count, ".!?".contains(chars[i + 1]) {
                    i += 1
                    run += 1
                    current.append(chars[i])
                }
                let isEllipsis = run >= 2 && chars[i] == "."
                let atBreak = i + 1 >= chars.count || chars[i + 1].isWhitespace
                if quoteDepth == 0, !isEllipsis, atBreak {
                    result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                }
            }
            i += 1
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }
}
