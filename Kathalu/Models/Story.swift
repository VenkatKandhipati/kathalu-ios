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
