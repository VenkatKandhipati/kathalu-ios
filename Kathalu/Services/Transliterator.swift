import Foundation

/// Telugu → Latin (ISO-15919-style) transliteration, ported verbatim from the
/// web reader's transliterate() in index.html.
enum Transliterator {

    private static let independentVowels: [Character: String] = [
        "అ": "a", "ఆ": "ā", "ఇ": "i", "ఈ": "ī", "ఉ": "u", "ఊ": "ū",
        "ఋ": "ru", "ౠ": "rū", "ఎ": "e", "ఏ": "ē", "ఐ": "ai",
        "ఒ": "o", "ఓ": "ō", "ఔ": "au",
    ]

    private static let matras: [Character: String] = [
        "ా": "ā", "ి": "i", "ీ": "ī", "ు": "u", "ూ": "ū",
        "ృ": "ru", "\u{0C44}": "rū",
        "ె": "e", "ే": "ē", "ై": "ai", "ొ": "o", "ో": "ō", "ౌ": "au",
    ]

    private static let consonants: [Character: String] = [
        "క": "k", "ఖ": "kh", "గ": "g", "ఘ": "gh", "ఙ": "ṅ",
        "చ": "c", "ఛ": "ch", "జ": "j", "ఝ": "jh", "ఞ": "ñ",
        "ట": "ṭ", "ఠ": "ṭh", "డ": "ḍ", "ఢ": "ḍh", "ణ": "ṇ",
        "త": "t", "థ": "th", "ద": "d", "ధ": "dh", "న": "n",
        "ప": "p", "ఫ": "ph", "బ": "b", "భ": "bh", "మ": "m",
        "య": "y", "ర": "r", "ల": "l", "వ": "v",
        "శ": "ś", "ష": "ṣ", "స": "s", "హ": "h",
        "ళ": "ḷ", "ఱ": "rr",
    ]

    private static let velars: Set<Character> = ["క", "ఖ", "గ", "ఘ", "ఙ"]
    private static let palatals: Set<Character> = ["చ", "ఛ", "జ", "ఝ", "ఞ"]
    private static let retroflexes: Set<Character> = ["ట", "ఠ", "డ", "ఢ", "ణ", "ళ", "ఱ"]
    private static let labials: Set<Character> = ["ప", "ఫ", "బ", "భ", "మ"]

    private static let digits: [Character: String] = [
        "౦": "0", "౧": "1", "౨": "2", "౩": "3", "౪": "4",
        "౫": "5", "౬": "6", "౭": "7", "౮": "8", "౯": "9",
    ]

    private static let virama: Character = "\u{0C4D}"
    private static let anusvara: Character = "\u{0C02}"
    private static let visarga: Character = "\u{0C03}"

    static func transliterate(_ text: String) -> String {
        // JS indexes UTF-16 units, but every relevant Telugu scalar is BMP,
        // so a scalar walk is equivalent. Work on scalars to split combining marks.
        let chars = text.unicodeScalars.map { Character($0) }
        var result = ""
        var i = 0
        let n = chars.count

        while i < n {
            let ch = chars[i]

            // క + ్ + ష ligature → kṣ
            if ch == "క", i + 2 < n, chars[i + 1] == virama, chars[i + 2] == "ష" {
                i += 3
                if i < n, let m = matras[chars[i]] {
                    result += "kṣ" + m
                    i += 1
                } else if i < n, chars[i] == virama {
                    result += "kṣ"
                    i += 1
                } else {
                    result += "kṣa"
                }
                continue
            }

            if let base = consonants[ch] {
                i += 1
                if i < n, let m = matras[chars[i]] {
                    result += base + m
                    i += 1
                } else if i < n, chars[i] == virama {
                    result += base
                    i += 1
                } else {
                    result += base + "a"
                }
            } else if let v = independentVowels[ch] {
                result += v
                i += 1
            } else if ch == anusvara {
                let next: Character? = i + 1 < n ? chars[i + 1] : nil
                if let next, retroflexes.contains(next) { result += "ṇ" }
                else if let next, palatals.contains(next) { result += "ñ" }
                else if let next, velars.contains(next) { result += "ṅ" }
                else if let next, labials.contains(next) { result += "m" }
                else if let next, consonants[next] != nil { result += "n" }
                else { result += "ṁ" }
                i += 1
            } else if ch == visarga {
                result += "ḥ"
                i += 1
            } else if let d = digits[ch] {
                result += d
                i += 1
            } else {
                result.append(ch)
                i += 1
            }
        }

        return result
    }
}
