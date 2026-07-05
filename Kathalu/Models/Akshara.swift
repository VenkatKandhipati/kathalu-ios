import Foundation

/// A single Telugu letter for the Learn tab's reference charts:
/// the glyph, its romanization, and a plain-English sound hint.
struct Akshara: Identifiable, Hashable {
    let letter: String     // అ
    let trans: String      // a
    let soundHint: String  // Sounds like the a in "about".
    /// Substitute text for TTS when the glyph itself is mispronounced
    /// (rare letters the te-IN voice doesn't handle).
    var spoken: String? = nil

    var id: String { letter }
    var spokenText: String { spoken ?? letter }
}

/// SM-2 scheduling state for one letter in a script deck. Kept apart from
/// VocabCard: script progress is device-local and never synced.
struct AksharaCard: Codable, Hashable {
    var letter: String
    var interval: Int = 0
    var easeFactor: Double = 2.5
    var repetitions: Int = 0
    var nextReview: DayStamp = .today

    var isDue: Bool { nextReview <= .today }
    var isNew: Bool { repetitions == 0 }
}

/// The two phase-2 script decks. Later phases add guninthalu and vatthulu.
enum AksharaDeck: String, CaseIterable, Identifiable {
    case vowels, consonants

    var id: String { rawValue }

    var titleEn: String {
        switch self {
        case .vowels: return "Vowels"
        case .consonants: return "Consonants"
        }
    }

    var telugu: String {
        switch self {
        case .vowels: return "అచ్చులు"
        case .consonants: return "హల్లులు"
        }
    }

    /// Deck contents in chart order — new cards are introduced in this order.
    var aksharas: [Akshara] {
        switch self {
        case .vowels: return AksharaData.vowels.aksharas
        case .consonants: return AksharaData.consonants
        }
    }
}

/// A titled row of the chart — the vowels, or one consonant varga.
struct AksharaGroup: Identifiable {
    let name: String       // Ka varga
    let telugu: String     // క వర్గం
    let note: String?      // Velar — made at the back of the throat
    let aksharas: [Akshara]
    var id: String { name }
}

/// Static seed data for phase 1 of the Aksharamala feature (see ROADMAP.md).
/// Later phases (guninthalu, vatthulu, drills) will extend this.
enum AksharaData {
    static let vowels = AksharaGroup(
        name: "Vowels",
        telugu: "అచ్చులు",
        note: "Vowels stand on their own and begin words.",
        aksharas: [
            Akshara(letter: "అ", trans: "a", soundHint: "Sounds like the a in about."),
            Akshara(letter: "ఆ", trans: "ā", soundHint: "Sounds like the a in father."),
            Akshara(letter: "ఇ", trans: "i", soundHint: "Sounds like the i in bit."),
            Akshara(letter: "ఈ", trans: "ī", soundHint: "Sounds like the ee in meet."),
            Akshara(letter: "ఉ", trans: "u", soundHint: "Sounds like the u in put."),
            Akshara(letter: "ఊ", trans: "ū", soundHint: "Sounds like the oo in boot."),
            Akshara(letter: "ఋ", trans: "ru", soundHint: "Sounds like the ri in ribbon."),
            Akshara(letter: "ౠ", trans: "rū", soundHint: "Long form of ఋ — rare in modern Telugu.", spoken: "రూ"),
            Akshara(letter: "ఎ", trans: "e", soundHint: "Sounds like the e in pen."),
            Akshara(letter: "ఏ", trans: "ē", soundHint: "Sounds like the a in same."),
            Akshara(letter: "ఐ", trans: "ai", soundHint: "Sounds like the y in my."),
            Akshara(letter: "ఒ", trans: "o", soundHint: "Sounds like the o in for."),
            Akshara(letter: "ఓ", trans: "ō", soundHint: "Sounds like the o in note."),
            Akshara(letter: "ఔ", trans: "au", soundHint: "Sounds like the ow in now."),
            Akshara(letter: "అం", trans: "aṁ", soundHint: "Sounds like the um in drum."),
            Akshara(letter: "అః", trans: "aḥ", soundHint: "A sharp, breathy aha."),
        ])

    static let consonantGroups: [AksharaGroup] = [
        AksharaGroup(
            name: "Ka varga",
            telugu: "క వర్గం",
            note: "Gutturals — made at the back of the throat",
            aksharas: [
                Akshara(letter: "క", trans: "ka", soundHint: "Sounds like the k in kite."),
                Akshara(letter: "ఖ", trans: "kha", soundHint: "Aspirated — k with a heavy puff of air."),
                Akshara(letter: "గ", trans: "ga", soundHint: "Sounds like the g in go."),
                Akshara(letter: "ఘ", trans: "gha", soundHint: "Aspirated — g with a heavy puff of air."),
                Akshara(letter: "ఙ", trans: "ṅa", soundHint: "Nasal — the ng in sing; rarely used alone."),
            ]),
        AksharaGroup(
            name: "Cha varga",
            telugu: "చ వర్గం",
            note: "Palatals — tongue at the roof of the mouth",
            aksharas: [
                Akshara(letter: "చ", trans: "cha", soundHint: "Sounds like the ch in chair."),
                Akshara(letter: "ఛ", trans: "chha", soundHint: "Aspirated — ch with a heavy puff of air."),
                Akshara(letter: "జ", trans: "ja", soundHint: "Sounds like the j in jeep."),
                Akshara(letter: "ఝ", trans: "jha", soundHint: "Aspirated — j with a heavy puff of air."),
                Akshara(letter: "ఞ", trans: "ña", soundHint: "Nasal — the ny in canyon."),
            ]),
        AksharaGroup(
            name: "Ta varga",
            telugu: "ట వర్గం",
            note: "Retroflexes — tongue curled back",
            aksharas: [
                Akshara(letter: "ట", trans: "ṭa", soundHint: "Hard t — tongue curls back to the roof of the mouth."),
                Akshara(letter: "ఠ", trans: "ṭha", soundHint: "Aspirated hard t with a heavy puff of air."),
                Akshara(letter: "డ", trans: "ḍa", soundHint: "Hard d — tongue curls back to the roof of the mouth."),
                Akshara(letter: "ఢ", trans: "ḍha", soundHint: "Aspirated hard d with a heavy puff of air."),
                Akshara(letter: "ణ", trans: "ṇa", soundHint: "Hard n — tongue curls back on an n sound."),
            ]),
        AksharaGroup(
            name: "Tha varga",
            telugu: "త వర్గం",
            note: "Dentals — tongue against the upper teeth",
            aksharas: [
                Akshara(letter: "త", trans: "ta", soundHint: "Soft t — like the th in thank you."),
                Akshara(letter: "థ", trans: "tha", soundHint: "Aspirated soft t with a heavy puff of air."),
                Akshara(letter: "ద", trans: "da", soundHint: "Soft d — like the th in the."),
                Akshara(letter: "ధ", trans: "dha", soundHint: "Aspirated soft d with a heavy puff of air."),
                Akshara(letter: "న", trans: "na", soundHint: "Soft n — like the n in net."),
            ]),
        AksharaGroup(
            name: "Pa varga",
            telugu: "ప వర్గం",
            note: "Labials — made with the lips",
            aksharas: [
                Akshara(letter: "ప", trans: "pa", soundHint: "Sounds like the p in pen."),
                Akshara(letter: "ఫ", trans: "pha", soundHint: "Aspirated p — often sounds like the f in fan."),
                Akshara(letter: "బ", trans: "ba", soundHint: "Sounds like the b in bat."),
                Akshara(letter: "భ", trans: "bha", soundHint: "Aspirated — b with a heavy puff of air."),
                Akshara(letter: "మ", trans: "ma", soundHint: "Sounds like the m in mat."),
            ]),
        AksharaGroup(
            name: "Non-plosives & liquids",
            telugu: "అంతస్థలు · ఊష్మాలు",
            note: "Semivowels, sibilants and the rest",
            aksharas: [
                Akshara(letter: "య", trans: "ya", soundHint: "Sounds like the y in yak."),
                Akshara(letter: "ర", trans: "ra", soundHint: "A lightly rolled or tapped r."),
                Akshara(letter: "ల", trans: "la", soundHint: "Sounds like the l in lip."),
                Akshara(letter: "వ", trans: "va", soundHint: "Between the v in van and the w in wet."),
                Akshara(letter: "శ", trans: "śa", soundHint: "Soft sh — tongue flat against the palate, as in she."),
                Akshara(letter: "ష", trans: "ṣa", soundHint: "Hard sh — tongue curled back to the roof of the mouth."),
                Akshara(letter: "స", trans: "sa", soundHint: "Sounds like the s in sit."),
                Akshara(letter: "హ", trans: "ha", soundHint: "Sounds like the h in hat."),
                Akshara(letter: "ళ", trans: "ḷa", soundHint: "Hard l — tongue curls back to the roof of the mouth."),
                Akshara(letter: "క్ష", trans: "kṣa", soundHint: "Compound sound — the ksh in Lakshmi."),
                Akshara(letter: "ఱ", trans: "ṟa", soundHint: "Hard, trilled r — rare in modern Telugu."),
            ]),
    ]

    /// Every consonant, flattened (for counts and future drills).
    static var consonants: [Akshara] {
        consonantGroups.flatMap(\.aksharas)
    }

    /// The chart group a letter belongs to (for context on card backs).
    static func group(containing akshara: Akshara) -> AksharaGroup? {
        if vowels.aksharas.contains(akshara) { return vowels }
        return consonantGroups.first { $0.aksharas.contains(akshara) }
    }
}
