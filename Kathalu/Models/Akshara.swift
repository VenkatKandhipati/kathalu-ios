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

/// One of the 16 secondary vowel signs (guninthapu gurthulu). Applied to any
/// consonant it yields one guninthamu form: క + ా = కా.
struct VowelSign: Identifiable, Hashable {
    let vowel: String   // ఆ — the primary vowel this sign carries
    let sign: String    // ా (empty for the bare talakattu form)
    let name: String    // Dheergam
    let suffix: String  // ā — replaces the consonant's inherent "a"

    var id: String { vowel }

    func apply(to consonant: Akshara) -> String {
        consonant.letter + sign
    }

    func trans(for consonant: Akshara) -> String {
        String(consonant.trans.dropLast()) + suffix
    }
}

/// One consonant's subscript form (vatthu). The conjunct glyphs are generated,
/// not stored: base + virama (్) + consonant renders the vatthu automatically,
/// so every cluster comes from this one table.
struct Vatthu: Identifiable, Hashable {
    let letter: String   // క — the consonant this vatthu belongs to
    let trans: String    // ka
    /// Shape or usage callout (special forms, famous pairs, why it's rare).
    var note: String? = nil
    /// Real clusters this vatthu appears in, canonical (doubled) form first.
    /// Empty means the vatthu is chart-only: too rare to drill.
    var usages: [VatthuUsage] = []

    var id: String { letter }
    var rare: Bool { usages.isEmpty }
    var name: String { "\(letter) వత్తు" }

    /// The doubled form (క్క) — how textbooks introduce each vatthu.
    var doubled: String { letter + "\u{0C4D}" + letter }
    var doubledTrans: String { String(trans.dropLast()) + trans }

    func cluster(for usage: VatthuUsage) -> String {
        usage.base + "\u{0C4D}" + letter
    }

    func clusterTrans(for usage: VatthuUsage) -> String {
        let baseTrans = AksharaData.consonant(usage.base)?.trans ?? ""
        return String(baseTrans.dropLast()) + trans
    }
}

/// One real word where a vatthu appears: the base letter it hangs under,
/// and the word for context (shown and spoken on card backs).
struct VatthuUsage: Hashable {
    let base: String     // స — the letter the vatthu sits under
    let word: String     // పుస్తకం
    let meaning: String  // book
    let wordTrans: String  // pustakam
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

    /// The 16 vowel signs in canonical guninthamu order. Forms are generated
    /// by appending the sign to a consonant, so all 36 × 16 combinations come
    /// from this one table.
    static let vowelSigns: [VowelSign] = [
        VowelSign(vowel: "అ", sign: "", name: "Talakattu", suffix: "a"),
        VowelSign(vowel: "ఆ", sign: "ా", name: "Dheergam", suffix: "ā"),
        VowelSign(vowel: "ఇ", sign: "ి", name: "Gudi", suffix: "i"),
        VowelSign(vowel: "ఈ", sign: "ీ", name: "Gudi Dheergam", suffix: "ī"),
        VowelSign(vowel: "ఉ", sign: "ు", name: "Kommu", suffix: "u"),
        VowelSign(vowel: "ఊ", sign: "ూ", name: "Kommu Dheergam", suffix: "ū"),
        VowelSign(vowel: "ఋ", sign: "ృ", name: "Rutvamu", suffix: "ṛ"),
        VowelSign(vowel: "ౠ", sign: "ౄ", name: "Rutva Dheergam", suffix: "ṝ"),
        VowelSign(vowel: "ఎ", sign: "ె", name: "Ethvamu", suffix: "e"),
        VowelSign(vowel: "ఏ", sign: "ే", name: "Yethvamu", suffix: "ē"),
        VowelSign(vowel: "ఐ", sign: "ై", name: "Aithvamu", suffix: "ai"),
        VowelSign(vowel: "ఒ", sign: "ొ", name: "Othvamu", suffix: "o"),
        VowelSign(vowel: "ఓ", sign: "ో", name: "Othvamu Dheergam", suffix: "ō"),
        VowelSign(vowel: "ఔ", sign: "ౌ", name: "Authvamu", suffix: "au"),
        VowelSign(vowel: "అం", sign: "ం", name: "Sunna", suffix: "aṁ"),
        VowelSign(vowel: "అః", sign: "ః", name: "Visarga", suffix: "aḥ"),
    ]

    /// The vowel a sign corresponds to (for its name and sound hint).
    static func vowel(for sign: VowelSign) -> Akshara? {
        vowels.aksharas.first { $0.letter == sign.vowel }
    }

    /// Consonant lookup by glyph (for cluster transliterations).
    static func consonant(_ letter: String) -> Akshara? {
        consonants.first { $0.letter == letter }
    }

    /// All 36 vatthulu in chart order. Usages are curated from everyday words;
    /// vatthulu with no usages are chart-only — too rare in modern Telugu to
    /// be worth drill time.
    static let vatthulu: [Vatthu] = [
        Vatthu(letter: "క", trans: "ka", usages: [
            VatthuUsage(base: "క", word: "అక్క", meaning: "elder sister", wordTrans: "akka"),
            VatthuUsage(base: "క", word: "చుక్క", meaning: "dot · star", wordTrans: "chukka"),
        ]),
        Vatthu(letter: "ఖ", trans: "kha",
               note: "Appears only in a few Sanskrit loanwords."),
        Vatthu(letter: "గ", trans: "ga", usages: [
            VatthuUsage(base: "గ", word: "బుగ్గ", meaning: "cheek", wordTrans: "bugga"),
            VatthuUsage(base: "గ", word: "మొగ్గ", meaning: "bud", wordTrans: "mogga"),
            VatthuUsage(base: "గ", word: "సిగ్గు", meaning: "shyness", wordTrans: "siggu"),
        ]),
        Vatthu(letter: "ఘ", trans: "gha", usages: [
            VatthuUsage(base: "ర", word: "దీర్ఘం", meaning: "long — as in a long vowel", wordTrans: "deergham"),
        ]),
        Vatthu(letter: "ఙ", trans: "ṅa",
               note: "Modern Telugu writes this nasal as ం instead."),
        Vatthu(letter: "చ", trans: "cha", usages: [
            VatthuUsage(base: "చ", word: "పచ్చ", meaning: "green", wordTrans: "pachcha"),
            VatthuUsage(base: "చ", word: "అచ్చు", meaning: "print · mould", wordTrans: "achchu"),
            VatthuUsage(base: "చ", word: "మచ్చ", meaning: "spot · scar", wordTrans: "machcha"),
        ]),
        Vatthu(letter: "ఛ", trans: "chha", usages: [
            VatthuUsage(base: "చ", word: "స్వేచ్ఛ", meaning: "freedom", wordTrans: "swechchha"),
        ]),
        Vatthu(letter: "జ", trans: "ja", usages: [
            VatthuUsage(base: "జ", word: "బుజ్జి", meaning: "little one", wordTrans: "bujji"),
            VatthuUsage(base: "జ", word: "బొజ్జ", meaning: "tummy", wordTrans: "bojja"),
            VatthuUsage(base: "జ", word: "గజ్జె", meaning: "ankle bell", wordTrans: "gajje"),
        ]),
        Vatthu(letter: "ఝ", trans: "jha",
               note: "Appears only in a few Sanskrit loanwords."),
        Vatthu(letter: "ఞ", trans: "ña",
               note: "జ్ఞ is a special pair — most speakers pronounce it gnya.",
               usages: [
            VatthuUsage(base: "జ", word: "జ్ఞానం", meaning: "knowledge", wordTrans: "jnaanam"),
            VatthuUsage(base: "జ", word: "విజ్ఞానం", meaning: "science", wordTrans: "vijnaanam"),
        ]),
        Vatthu(letter: "ట", trans: "ṭa", usages: [
            VatthuUsage(base: "ట", word: "పట్టు", meaning: "silk · grip", wordTrans: "pattu"),
            VatthuUsage(base: "ట", word: "బొట్టు", meaning: "bindi", wordTrans: "bottu"),
            VatthuUsage(base: "ట", word: "అట్టు", meaning: "dosa", wordTrans: "attu"),
        ]),
        Vatthu(letter: "ఠ", trans: "ṭha",
               note: "Appears only in a few Sanskrit loanwords like నిష్ఠ."),
        Vatthu(letter: "డ", trans: "ḍa", usages: [
            VatthuUsage(base: "డ", word: "గడ్డం", meaning: "beard", wordTrans: "gaddam"),
            VatthuUsage(base: "డ", word: "గడ్డి", meaning: "grass", wordTrans: "gaddi"),
            VatthuUsage(base: "డ", word: "అడ్డం", meaning: "across · in the way", wordTrans: "addam"),
        ]),
        Vatthu(letter: "ఢ", trans: "ḍha",
               note: "Appears only in a few Sanskrit loanwords."),
        Vatthu(letter: "ణ", trans: "ṇa", usages: [
            VatthuUsage(base: "ష", word: "ఉష్ణం", meaning: "heat", wordTrans: "ushnam"),
            VatthuUsage(base: "ష", word: "విష్ణువు", meaning: "Vishnu", wordTrans: "vishnuvu"),
        ]),
        Vatthu(letter: "త", trans: "ta", usages: [
            VatthuUsage(base: "త", word: "అత్త", meaning: "aunt", wordTrans: "atta"),
            VatthuUsage(base: "స", word: "పుస్తకం", meaning: "book", wordTrans: "pustakam"),
            VatthuUsage(base: "క", word: "రక్తం", meaning: "blood", wordTrans: "raktam"),
        ]),
        Vatthu(letter: "థ", trans: "tha", usages: [
            VatthuUsage(base: "ర", word: "అర్థం", meaning: "meaning", wordTrans: "artham"),
            VatthuUsage(base: "ర", word: "వ్యర్థం", meaning: "waste", wordTrans: "vyartham"),
        ]),
        Vatthu(letter: "ద", trans: "da", usages: [
            VatthuUsage(base: "ద", word: "పెద్ద", meaning: "big", wordTrans: "pedda"),
            VatthuUsage(base: "ద", word: "ముద్దు", meaning: "kiss", wordTrans: "muddu"),
            VatthuUsage(base: "బ", word: "శబ్దం", meaning: "sound", wordTrans: "shabdam"),
        ]),
        Vatthu(letter: "ధ", trans: "dha", usages: [
            VatthuUsage(base: "ద", word: "బుద్ధి", meaning: "intelligence", wordTrans: "buddhi"),
            VatthuUsage(base: "ద", word: "యుద్ధం", meaning: "war", wordTrans: "yuddham"),
        ]),
        Vatthu(letter: "న", trans: "na", usages: [
            VatthuUsage(base: "న", word: "అన్న", meaning: "elder brother", wordTrans: "anna"),
            VatthuUsage(base: "న", word: "వెన్న", meaning: "butter", wordTrans: "venna"),
            VatthuUsage(base: "త", word: "రత్నం", meaning: "gem", wordTrans: "ratnam"),
        ]),
        Vatthu(letter: "ప", trans: "pa", usages: [
            VatthuUsage(base: "ప", word: "తప్పు", meaning: "mistake", wordTrans: "tappu"),
            VatthuUsage(base: "ప", word: "చెప్పు", meaning: "shoe", wordTrans: "cheppu"),
            VatthuUsage(base: "ష", word: "పుష్పం", meaning: "flower", wordTrans: "pushpam"),
        ]),
        Vatthu(letter: "ఫ", trans: "pha",
               note: "Appears only in a few Sanskrit loanwords."),
        Vatthu(letter: "బ", trans: "ba", usages: [
            VatthuUsage(base: "బ", word: "డబ్బు", meaning: "money", wordTrans: "dabbu"),
            VatthuUsage(base: "బ", word: "దెబ్బ", meaning: "hit · blow", wordTrans: "debba"),
            VatthuUsage(base: "బ", word: "అబ్బాయి", meaning: "boy", wordTrans: "abbaayi"),
        ]),
        Vatthu(letter: "భ", trans: "bha", usages: [
            VatthuUsage(base: "ర", word: "గర్భం", meaning: "womb", wordTrans: "garbham"),
            VatthuUsage(base: "ర", word: "నిర్భయం", meaning: "fearless", wordTrans: "nirbhayam"),
        ]),
        Vatthu(letter: "మ", trans: "ma", usages: [
            VatthuUsage(base: "మ", word: "అమ్మ", meaning: "mother", wordTrans: "amma"),
            VatthuUsage(base: "మ", word: "బొమ్మ", meaning: "doll", wordTrans: "bomma"),
            VatthuUsage(base: "ద", word: "పద్మం", meaning: "lotus", wordTrans: "padmam"),
        ]),
        Vatthu(letter: "య", trans: "ya", usages: [
            VatthuUsage(base: "య", word: "అయ్య", meaning: "father · sir", wordTrans: "ayya"),
            VatthuUsage(base: "ద", word: "విద్య", meaning: "education", wordTrans: "vidya"),
            VatthuUsage(base: "ఖ", word: "ముఖ్యం", meaning: "important", wordTrans: "mukhyam"),
        ]),
        Vatthu(letter: "ర", trans: "ra",
               note: "ర వత్తు has its own slanted shape — it doesn't look like a small ర.",
               usages: [
            VatthuUsage(base: "ర", word: "కర్ర", meaning: "stick", wordTrans: "karra"),
            VatthuUsage(base: "ప", word: "ప్రేమ", meaning: "love", wordTrans: "prema"),
            VatthuUsage(base: "క", word: "చక్రం", meaning: "wheel", wordTrans: "chakram"),
        ]),
        Vatthu(letter: "ల", trans: "la", usages: [
            VatthuUsage(base: "ల", word: "పిల్లి", meaning: "cat", wordTrans: "pilli"),
            VatthuUsage(base: "ల", word: "అల్లం", meaning: "ginger", wordTrans: "allam"),
            VatthuUsage(base: "ల", word: "పల్లె", meaning: "village", wordTrans: "palle"),
        ]),
        Vatthu(letter: "వ", trans: "va", usages: [
            VatthuUsage(base: "వ", word: "నవ్వు", meaning: "laugh", wordTrans: "navvu"),
            VatthuUsage(base: "వ", word: "పువ్వు", meaning: "flower", wordTrans: "puvvu"),
            VatthuUsage(base: "ద", word: "ద్వారం", meaning: "doorway", wordTrans: "dwaaram"),
        ]),
        Vatthu(letter: "శ", trans: "śa", usages: [
            VatthuUsage(base: "శ", word: "నిశ్శబ్దం", meaning: "silence", wordTrans: "nishshabdam"),
            VatthuUsage(base: "ర", word: "స్పర్శ", meaning: "touch", wordTrans: "sparsha"),
        ]),
        Vatthu(letter: "ష", trans: "ṣa",
               note: "క + ష వత్తు makes క్ష — the compound letter at the end of the chart.",
               usages: [
            VatthuUsage(base: "క", word: "అక్షరం", meaning: "letter of the alphabet", wordTrans: "aksharam"),
            VatthuUsage(base: "క", word: "రక్షణ", meaning: "protection", wordTrans: "rakshana"),
            VatthuUsage(base: "క", word: "లక్ష", meaning: "lakh — a hundred thousand", wordTrans: "laksha"),
        ]),
        Vatthu(letter: "స", trans: "sa", usages: [
            VatthuUsage(base: "స", word: "బస్సు", meaning: "bus", wordTrans: "bassu"),
            VatthuUsage(base: "త", word: "సంవత్సరం", meaning: "year", wordTrans: "samvatsaram"),
        ]),
        Vatthu(letter: "హ", trans: "ha",
               note: "Vanishingly rare — హ usually carries other vatthulu instead, as in బ్రహ్మ."),
        Vatthu(letter: "ళ", trans: "ḷa", usages: [
            VatthuUsage(base: "ళ", word: "కళ్ళు", meaning: "eyes", wordTrans: "kallu"),
            VatthuUsage(base: "ళ", word: "పళ్ళు", meaning: "teeth", wordTrans: "pallu"),
            VatthuUsage(base: "ళ", word: "వెళ్ళు", meaning: "go", wordTrans: "vellu"),
        ]),
        Vatthu(letter: "క్ష", trans: "kṣa",
               note: "క్ష is itself క + ష వత్తు — its own vatthu almost never occurs."),
        Vatthu(letter: "ఱ", trans: "ṟa",
               note: "Survives in older spellings like గుఱ్ఱం (horse) — modern Telugu writes గుర్రం."),
    ]

    /// The drillable vatthulu — the ones with real everyday words behind them.
    static var quizVatthulu: [Vatthu] {
        vatthulu.filter { !$0.rare }
    }

    /// Everyday consonants paired with sign cards in the guninthalu quiz
    /// until the learner has studied enough of the consonant deck.
    static let starterQuizConsonants: [Akshara] = {
        let common: Set<String> = ["క", "గ", "చ", "జ", "ట", "డ", "త", "ద",
                                   "న", "ప", "బ", "మ", "ర", "ల", "వ", "స"]
        return consonants.filter { common.contains($0.letter) }
    }()
}
