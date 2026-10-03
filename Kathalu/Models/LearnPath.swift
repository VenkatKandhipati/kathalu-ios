import Foundation

// The Journey's path model (Aksharamala phase 5, see ROADMAP): ordered
// sections of stops down the Godavari. Villages teach a few letters, temples
// are section checkpoints at real landmarks, book milestones celebrate what
// the learner can now read.
//
// Completion is *derived* from the same SM-2 cards the free-practice decks
// use (`AppModel.aksharaCards`) — the path stores only what SM-2 can't tell
// us (checkpoint passes), in `PathProgress` via `PathStore`.

/// One lesson stop: a few letters taught and drilled together.
struct PathUnit: Identifiable, Hashable {
    let id: String
    let aksharas: [Akshara]

    var letters: String { aksharas.map(\.letter).joined(separator: " ") }
    var primary: String { aksharas.first?.letter ?? "" }
}

enum PathStopKind: Hashable {
    case village(PathUnit)
    case milestone(telugu: String, title: String)
    case temple(telugu: String, name: String, caption: String)
}

struct PathStop: Identifiable, Hashable {
    let id: String
    let kind: PathStopKind
}

struct PathSection: Identifiable, Hashable {
    let id: String
    let telugu: String
    let name: String
    let stops: [PathStop]
}

/// Map state of a stop, derived per render by `AppModel.journeyStates`.
enum JourneyStopState {
    case done, current, locked
}

/// Journey state that can't be derived from SM-2 cards: temple checkpoints
/// passed (later: test-outs, seen milestones). Local-only for the same reason
/// as AksharaStore — sign-in rebuilds `UserData` from the server and would
/// wipe any field the backend doesn't know about.
struct PathProgress: Codable {
    var passedCheckpoints: Set<String> = []
}

enum LearnPath {
    /// Sections with working lessons. Stops beyond this render locked on the
    /// map regardless of progress — bump as phases 5d/5e land.
    static let builtSectionCount = 1

    static let sections: [PathSection] = [
        vowelsSection, consonantsSection, guninthaluSection, vatthuluSection, seaSection,
    ]

    static var stops: [PathStop] { sections.flatMap(\.stops) }

    static var builtStops: [PathStop] {
        sections.prefix(builtSectionCount).flatMap(\.stops)
    }

    static func units(in section: PathSection) -> [PathUnit] {
        section.stops.compactMap {
            if case .village(let unit) = $0.kind { return unit }
            return nil
        }
    }

    static func templeStop(in section: PathSection) -> PathStop? {
        section.stops.first {
            if case .temple = $0.kind { return true }
            return false
        }
    }

    static func section(containing stopID: String) -> PathSection? {
        sections.first { $0.stops.contains { $0.id == stopID } }
    }

    // MARK: Section definitions

    private static func vowelVillage(_ id: String, _ letters: [String]) -> PathStop {
        let all = AksharaData.vowels.aksharas
        let unit = PathUnit(id: id, aksharas: letters.compactMap { letter in
            all.first { $0.letter == letter }
        })
        return PathStop(id: id, kind: .village(unit))
    }

    /// Vowels in pedagogical order: short/long pairs first, then diphthongs,
    /// with the rare ఋ ౠ and anusvara/visarga saved for last.
    private static let vowelsSection = PathSection(
        id: "vowels", telugu: "అచ్చులు", name: "Vowels",
        stops: [
            vowelVillage("vow-1", ["అ", "ఆ", "ఇ", "ఈ"]),
            vowelVillage("vow-2", ["ఉ", "ఊ", "ఎ", "ఏ"]),
            vowelVillage("vow-3", ["ఐ", "ఒ", "ఓ", "ఔ"]),
            vowelVillage("vow-4", ["ఋ", "ౠ", "అం", "అః"]),
            PathStop(id: "basara", kind: .temple(
                telugu: "బాసర", name: "Basara",
                caption: "Where children write their first letters")),
        ])

    private static let consonantsSection: PathSection = {
        let groups = AksharaData.consonantGroups
        var stops: [PathStop] = groups.prefix(5).enumerated().map { i, group in
            let id = "con-\(i + 1)"
            return PathStop(id: id, kind: .village(PathUnit(id: id, aksharas: group.aksharas)))
        }
        // The 11 non-plosives split into learnable chunks.
        let rest = groups.last?.aksharas ?? []
        let chunks = [Array(rest.prefix(4)), Array(rest.dropFirst(4).prefix(4)), Array(rest.dropFirst(8))]
        for (i, chunk) in chunks.enumerated() where !chunk.isEmpty {
            let id = "con-\(i + 6)"
            stops.append(PathStop(id: id, kind: .village(PathUnit(id: id, aksharas: chunk))))
        }
        stops.append(PathStop(id: "m-words", kind: .milestone(
            telugu: "మొదటి పదాలు", title: "Your first words")))
        stops.append(PathStop(id: "dharmapuri", kind: .temple(
            telugu: "ధర్మపురి", name: "Dharmapuri", caption: "Temple town above the gorge")))
        return PathSection(id: "consonants", telugu: "హల్లులు", name: "Consonants", stops: stops)
    }()

    /// Display-only until 5e: village markers show the sign forms on క so the
    /// locked map reads right. Their lessons need sign-namespaced SM-2 keys
    /// (`gunintha:<vowel>`), which land with phase 5e.
    private static let guninthaluSection: PathSection = {
        func village(_ id: String, _ vowels: [String]) -> PathStop {
            guard let ka = AksharaData.consonant("క") else {
                return PathStop(id: id, kind: .village(PathUnit(id: id, aksharas: [])))
            }
            let signs = AksharaData.vowelSigns.filter { vowels.contains($0.vowel) }
            let aksharas = signs.map {
                Akshara(letter: $0.apply(to: ka), trans: $0.trans(for: ka), soundHint: $0.name)
            }
            return PathStop(id: id, kind: .village(PathUnit(id: id, aksharas: aksharas)))
        }
        return PathSection(id: "guninthalu", telugu: "గుణింతాలు", name: "Vowel signs", stops: [
            village("gun-1", ["ఆ", "ఇ", "ఈ"]),
            village("gun-2", ["ఉ", "ఊ", "ఋ"]),
            village("gun-3", ["ఎ", "ఏ", "ఐ"]),
            village("gun-4", ["ఒ", "ఓ", "ఔ", "అం"]),
            PathStop(id: "m-flow", kind: .milestone(
                telugu: "పద ప్రవాహం", title: "Hundreds of words open up")),
            PathStop(id: "bhadrachalam", kind: .temple(
                telugu: "భద్రాచలం", name: "Bhadrachalam", caption: "Rama's temple on the river bend")),
        ])
    }()

    /// Display-only until 5e, like guninthalu (keys are `vatthu:<letter>`).
    private static let vatthuluSection: PathSection = {
        func village(_ id: String, _ letters: [String]) -> PathStop {
            let vatthulu = letters.compactMap { letter in
                AksharaData.vatthulu.first { $0.letter == letter }
            }
            let aksharas = vatthulu.map {
                Akshara(letter: $0.doubled, trans: $0.doubledTrans, soundHint: $0.name)
            }
            return PathStop(id: id, kind: .village(PathUnit(id: id, aksharas: aksharas)))
        }
        return PathSection(id: "vatthulu", telugu: "వత్తులు", name: "Conjuncts", stops: [
            village("vat-1", ["క", "ల", "మ"]),
            village("vat-2", ["త", "ద", "న"]),
            village("vat-3", ["ప", "బ", "జ"]),
            village("vat-4", ["ర", "వ", "య"]),
            village("vat-5", ["స", "ష", "ళ"]),
            PathStop(id: "rajahmundry", kind: .temple(
                telugu: "రాజమహేంద్రవరం", name: "Rajahmundry", caption: "Birthplace of Telugu letters")),
        ])
    }()

    private static let seaSection = PathSection(
        id: "sea", telugu: "సాగర సంగమం", name: "The sea",
        stops: [
            PathStop(id: "m-story", kind: .milestone(
                telugu: "మీ మొదటి కథ", title: "Read your first story")),
            PathStop(id: "antarvedi", kind: .temple(
                telugu: "అంతర్వేది", name: "Antarvedi", caption: "Where the Godavari meets the sea")),
        ])
}
