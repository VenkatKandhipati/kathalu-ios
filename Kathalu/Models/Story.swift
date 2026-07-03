import Foundation

/// A story bundled with the app, mirroring the shape of the web app's stories.js.
struct Story: Decodable, Identifiable, Hashable {
    let title: String
    let titleEn: String
    let collection: String
    let text: String

    /// Index within the bundled catalog; assigned by StoryStore after decode.
    var index: Int = 0

    var id: Int { index }

    private enum CodingKeys: String, CodingKey {
        case title, titleEn, collection, text
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

    var wordCount: Int { words.count }

    /// Rough reading time at ~25 Telugu words per minute for a learner.
    var readingMinutes: Int { max(1, Int((Double(wordCount) / 25.0).rounded())) }
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
}
