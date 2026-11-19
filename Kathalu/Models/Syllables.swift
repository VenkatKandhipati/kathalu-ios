import Foundation

/// Akshara-level (syllable) segmentation of Telugu words, and the script
/// skills each syllable needs. This is the engine behind the word sheet's
/// sound-it-out syllable tiles.
///
/// A syllable starts at each consonant or independent vowel, unless the
/// previous scalar is a virama (్) — then the consonant joins the cluster as
/// a vatthu. Vowel signs, ం ః and the virama attach to the syllable before
/// them. Works on Unicode scalars, not Characters: Swift's grapheme rules
/// already glue some Telugu conjuncts together, which would hide the split.
enum Syllables {
    static let virama: Unicode.Scalar = "\u{0C4D}"
    private static let zwnj: Unicode.Scalar = "\u{200C}"

    static func isConsonant(_ s: Unicode.Scalar) -> Bool {
        (0x0C15...0x0C39).contains(s.value) || (0x0C58...0x0C5A).contains(s.value)
    }

    static func isVowel(_ s: Unicode.Scalar) -> Bool {
        (0x0C05...0x0C14).contains(s.value) || s.value == 0x0C60 || s.value == 0x0C61
    }

    private static func isTelugu(_ s: Unicode.Scalar) -> Bool {
        (0x0C00...0x0C7F).contains(s.value)
    }

    /// అక్కడికి → [అ, క్క, డి, కి]. Non-Telugu characters are dropped.
    static func split(_ word: String) -> [String] {
        var result: [String] = []
        var current = String.UnicodeScalarView()
        var previous: Unicode.Scalar?
        for scalar in word.unicodeScalars {
            if scalar == zwnj {
                // An explicit "no conjunct": the next consonant starts fresh.
                previous = scalar
                continue
            }
            guard isTelugu(scalar) else { continue }
            let starts = isVowel(scalar) || (isConsonant(scalar) && previous != virama)
            if starts, !current.isEmpty {
                result.append(String(current))
                current = String.UnicodeScalarView()
            }
            current.append(scalar)
            previous = scalar
        }
        if !current.isEmpty { result.append(String(current)) }
        return result
    }

    /// What a syllable is made of, for colouring and lesson routing.
    enum Kind: Equatable {
        case vowel      // అ, ఆం
        case consonant  // క (inherent a), కం is a sign
        case sign       // కా, కి, కం
        case conjunct   // క్క, స్తు
    }

    static func kind(of syllable: String) -> Kind {
        var consonants = 0
        var hasSign = false
        var startsWithVowel = false
        for (i, scalar) in syllable.unicodeScalars.enumerated() {
            if i == 0 && isVowel(scalar) { startsWithVowel = true }
            if isConsonant(scalar) { consonants += 1 }
            if signVowel[scalar] != nil || modifierVowel[scalar] != nil { hasSign = true }
        }
        if startsWithVowel { return .vowel }
        if consonants > 1 { return .conjunct }
        return hasSign ? .sign : .consonant
    }

    /// Dependent vowel sign → the vowel it carries (ా → ఆ), from the
    /// guninthalu table so the two can never disagree.
    private static let signVowel: [Unicode.Scalar: String] = {
        var map: [Unicode.Scalar: String] = [:]
        for sign in AksharaData.vowelSigns {
            let scalars = sign.sign.unicodeScalars
            guard scalars.count == 1, let scalar = scalars.first, modifierVowel[scalar] == nil else { continue }
            map[scalar] = sign.vowel
        }
        return map
    }()

    /// ం / ః (and the rare candrabindu forms, read as ం) — signs in the
    /// guninthalu deck, but letters (అం / అః) after an independent vowel.
    private static let modifierVowel: [Unicode.Scalar: String] = [
        "\u{0C02}": "అం", "\u{0C01}": "అం", "\u{0C00}": "అం",
        "\u{0C03}": "అః",
    ]

    /// The script-deck keys (`AppModel.aksharaCards`) needed to decode one
    /// syllable: the base letter, `vatthu:<c>` for each subscript consonant,
    /// and `gunintha:<vowel>` for each vowel sign. స్తు → [స, vatthu:త, gunintha:ఉ].
    static func skills(of syllable: String) -> [String] {
        var keys: [String] = []
        var consonants = 0
        var startsWithVowel = false
        for (i, scalar) in syllable.unicodeScalars.enumerated() {
            let text = String(scalar)
            if isVowel(scalar) {
                if i == 0 { startsWithVowel = true }
                keys.append(text)
            } else if isConsonant(scalar) {
                keys.append(consonants == 0 ? text : "vatthu:\(text)")
                consonants += 1
            } else if let vowel = modifierVowel[scalar] {
                keys.append(startsWithVowel && consonants == 0 ? vowel : "gunintha:\(vowel)")
            } else if let vowel = signVowel[scalar] {
                keys.append("gunintha:\(vowel)")
            }
        }
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }

    /// Every skill a word needs, in reading order without repeats.
    static func skills(ofWord word: String) -> [String] {
        var seen = Set<String>()
        return split(word).flatMap(skills(of:)).filter { seen.insert($0).inserted }
    }

    static func isReadable(_ word: String, known: Set<String>) -> Bool {
        let syllables = split(word)
        return !syllables.isEmpty && syllables.allSatisfy { skills(of: $0).allSatisfy(known.contains) }
    }
}
