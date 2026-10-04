import SwiftUI
import Observation

/// Root application state: story catalog, user data, settings, auth and sync.
@Observable
@MainActor
final class AppModel {
    // MARK: Content & user data

    let storyStore = StoryStore()
    var data: UserData
    /// Script-deck SM-2 state, keyed by letter (local-only, see AksharaStore).
    var aksharaCards: [String: AksharaCard]
    /// Journey checkpoint state (local-only, see PathStore).
    var pathProgress: PathProgress

    // MARK: Settings (mirrors the web app's theme / storyFontSize keys)

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    enum ReadingFontSize: String, CaseIterable, Identifiable {
        case small, medium, large, extraLarge, extraExtraLarge
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            case .extraExtraLarge: return "Extra Extra Large"
            }
        }
        var points: CGFloat {
            switch self {
            case .small: return 19
            case .medium: return 22
            case .large: return 26
            case .extraLarge: return 30
            case .extraExtraLarge: return 34
            }
        }
    }

    /// How the reader advances through a story: one continuous scroll (default)
    /// or discrete swipe-to-flip pages.
    enum ReadingMode: String, CaseIterable, Identifiable {
        case scroll, paged
        var id: String { rawValue }
        var label: String {
            switch self {
            case .scroll: return "Scroll"
            case .paged: return "Pages"
            }
        }
        var systemImage: String {
            switch self {
            case .scroll: return "arrow.up.arrow.down"
            case .paged: return "book"
            }
        }
    }

    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }
    var fontSize: ReadingFontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "storyFontSize") }
    }
    var readingMode: ReadingMode {
        didSet { UserDefaults.standard.set(readingMode.rawValue, forKey: "readingMode") }
    }
    /// Whether tapping a word plays its pronunciation aloud. On by default.
    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    /// Preferred TTS voice identifier; nil follows the system's Telugu default.
    var speechVoiceID: String? {
        didSet {
            UserDefaults.standard.set(speechVoiceID, forKey: "speechVoiceID")
            speech.voiceIdentifier = speechVoiceID
        }
    }
    /// Speaking rate in AVSpeechUtterance units (0–1).
    var speechRate: Double {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speechRate")
            speech.rate = Float(speechRate)
        }
    }
    /// Whether the reader shows a minimal stopwatch of the current session's
    /// reading time. On by default; kept minimal so it doesn't intrude.
    var showReadingTimer: Bool {
        didSet { UserDefaults.standard.set(showReadingTimer, forKey: "showReadingTimer") }
    }
    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }
    /// Whether the reader has shown the one-time "tap Aa to toggle sound" hint.
    var hasSeenSoundTip: Bool {
        didSet { UserDefaults.standard.set(hasSeenSoundTip, forKey: "hasSeenSoundTip") }
    }

    /// False when no Telugu TTS voice is installed on the device. Without one,
    /// iOS falls back to a non-Telugu voice that can't pronounce the script, so
    /// pronunciation is silent — the UI prompts the user to add one in iOS
    /// Settings (the app can't install voices itself).
    var teluguVoiceInstalled: Bool { !SpeechService.teluguVoices.isEmpty }

    // MARK: Services

    let speech = SpeechService()
    private let localStore = LocalStore()
    private let aksharaStore = AksharaStore()
    private let pathStore = PathStore()
    private let auth = AuthService()
    private let api: APIClient
    private let sync: SyncEngine

    var username: String? { auth.session?.username }
    var isSignedIn: Bool { auth.isSignedIn }
    var syncStatus: SyncEngine.Status { sync.status }

    init() {
        data = localStore.load()
        aksharaCards = aksharaStore.load()
        pathProgress = pathStore.load()
        appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system
        fontSize = ReadingFontSize(rawValue: UserDefaults.standard.string(forKey: "storyFontSize") ?? "") ?? .medium
        readingMode = ReadingMode(rawValue: UserDefaults.standard.string(forKey: "readingMode") ?? "") ?? .scroll
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        speechVoiceID = UserDefaults.standard.string(forKey: "speechVoiceID")
        speechRate = UserDefaults.standard.object(forKey: "speechRate") as? Double ?? SpeechService.defaultRate
        showReadingTimer = UserDefaults.standard.object(forKey: "showReadingTimer") as? Bool ?? true
        hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        hasSeenSoundTip = UserDefaults.standard.bool(forKey: "hasSeenSoundTip")
        let apiClient = APIClient(auth: auth)
        api = apiClient
        sync = SyncEngine(api: apiClient)

        // didSet doesn't fire during init — push the loaded values through.
        speech.voiceIdentifier = speechVoiceID
        speech.rate = Float(speechRate)

        if let session = auth.session {
            Task { await hydrate(userID: session.userID) }
        }
    }

    private func persist() {
        localStore.save(data)
    }

    // MARK: Reading

    func story(at index: Int) -> Story? {
        storyStore.stories.indices.contains(index) ? storyStore.stories[index] : nil
    }

    /// Records a word lookup, creating/refreshing its vocab card entry lazily.
    /// Returns the card (with transliteration filled in).
    @discardableResult
    func recordLookup(word: String, storyIdx: Int) -> VocabCard {
        data.wordTaps[word, default: 0] += 1
        var card = data.cards[word] ?? VocabCard(
            telugu: word,
            trans: Transliterator.transliterate(word),
            storyIdx: storyIdx,
            lookups: 0)
        card.lookups += 1
        if card.trans == nil { card.trans = Transliterator.transliterate(word) }
        data.cards[word] = card
        persist()
        return card
    }

    func cacheMeaning(_ meaning: String, for word: String) {
        guard var card = data.cards[word] else { return }
        card.meaning = meaning
        data.cards[word] = card
        persist()
    }

    /// Adds a word to the review deck (design's "Add to flashcards").
    func addToDeck(word: String, storyIdx: Int) {
        var card = data.cards[word] ?? VocabCard(
            telugu: word,
            trans: Transliterator.transliterate(word),
            storyIdx: storyIdx)
        card.storyIdx = card.storyIdx ?? storyIdx
        data.cards[word] = card
        persist()
        if isSignedIn { sync.pushCard(card) }
    }

    var deckCards: [VocabCard] {
        Array(data.cards.values)
    }

    var dueCount: Int {
        deckCards.filter { $0.isDue }.count
    }

    /// Marks today as read and updates the story's best proficiency.
    func finishReading(storyIdx: Int, proficiencyPct: Int) {
        let today = DayStamp.today
        if !data.readingDates.contains(today) {
            data.readingDates.insert(today, at: 0)
            if data.readingDates.count > 365 { data.readingDates.removeLast() }
        }
        let previous = data.storyProgress[storyIdx]?.bestPct ?? 0
        let best = max(previous, proficiencyPct)
        data.storyProgress[storyIdx] = StoryProgressEntry(bestPct: best, lastRead: today)
        persist()
        if isSignedIn {
            sync.pushProgress(storyIdx: storyIdx, bestPct: best)
            sync.pushReadingDay(storyIdx: storyIdx, pct: proficiencyPct)
        }
    }

    // MARK: Review

    func rate(card: VocabCard, quality: Int) {
        let result = SM2.schedule(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            quality: quality)
        var updated = card
        updated.interval = result.interval
        updated.easeFactor = result.easeFactor
        updated.repetitions = result.repetitions
        updated.nextReview = result.nextReview
        data.cards[card.telugu] = updated
        persist()
        if isSignedIn { sync.pushCard(updated) }
    }

    // MARK: Script decks (Learn tab)

    func rate(akshara: Akshara, quality: Int) {
        rateScriptCard(key: akshara.letter, quality: quality)
    }

    func rate(sign: VowelSign, quality: Int) {
        rateScriptCard(key: Self.guninthaKey(sign), quality: quality)
    }

    func rate(vatthu: Vatthu, quality: Int) {
        rateScriptCard(key: Self.vatthuKey(vatthu), quality: quality)
    }

    /// Writing (tracing) practice is scheduled under its own `write:` namespace
    /// so production mastery never mixes with the recognition decks above —
    /// tracing a glyph well doesn't mean you can read it, and vice versa.
    func rate(writing akshara: Akshara, quality: Int) {
        rateScriptCard(key: Self.writingKey(akshara), quality: quality)
    }

    static func writingKey(_ akshara: Akshara) -> String { "write:\(akshara.letter)" }

    /// One SM-2 update for any script-deck key (letters, vowel signs, …).
    private func rateScriptCard(key: String, quality: Int) {
        var card = aksharaCards[key] ?? AksharaCard(letter: key)
        let result = SM2.schedule(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            quality: quality)
        card.interval = result.interval
        card.easeFactor = result.easeFactor
        card.repetitions = result.repetitions
        card.nextReview = result.nextReview
        aksharaCards[key] = card
        aksharaStore.save(aksharaCards)
    }

    /// Vowel-sign cards are namespaced so they can't collide with letters.
    static func guninthaKey(_ sign: VowelSign) -> String { "gunintha:\(sign.vowel)" }

    func guninthaCard(for sign: VowelSign) -> AksharaCard? {
        aksharaCards[Self.guninthaKey(sign)]
    }

    var guninthaDueCount: Int {
        AksharaData.vowelSigns.filter { guninthaCard(for: $0).map { !$0.isNew && $0.isDue } ?? false }.count
    }

    var guninthaLearnedCount: Int {
        AksharaData.vowelSigns.filter { (guninthaCard(for: $0)?.repetitions ?? 0) >= 2 }.count
    }

    var guninthaNewCount: Int {
        AksharaData.vowelSigns.filter { guninthaCard(for: $0)?.isNew ?? true }.count
    }

    /// Vatthu cards share the store under their own namespace.
    static func vatthuKey(_ vatthu: Vatthu) -> String { "vatthu:\(vatthu.letter)" }

    func vatthuCard(for vatthu: Vatthu) -> AksharaCard? {
        aksharaCards[Self.vatthuKey(vatthu)]
    }

    var vatthuDueCount: Int {
        AksharaData.quizVatthulu.filter { vatthuCard(for: $0).map { !$0.isNew && $0.isDue } ?? false }.count
    }

    var vatthuLearnedCount: Int {
        AksharaData.quizVatthulu.filter { (vatthuCard(for: $0)?.repetitions ?? 0) >= 2 }.count
    }

    var vatthuNewCount: Int {
        AksharaData.quizVatthulu.filter { vatthuCard(for: $0)?.isNew ?? true }.count
    }

    /// Consonants paired with sign cards in the guninthalu quiz: the learner's
    /// studied consonants once there are enough, else a starter set.
    var guninthaQuizPool: [Akshara] {
        let studied = AksharaDeck.consonants.aksharas
            .filter { (aksharaCards[$0.letter]?.repetitions ?? 0) >= 1 }
        return studied.count >= 8 ? studied : AksharaData.starterQuizConsonants
    }

    /// Studied letters that are due again (new letters don't count).
    func aksharaDueCount(for deck: AksharaDeck) -> Int {
        deck.aksharas.filter { aksharaCards[$0.letter].map { !$0.isNew && $0.isDue } ?? false }.count
    }

    /// Letters answered correctly at least twice — same bar as `wordsKnown`.
    func aksharaLearnedCount(for deck: AksharaDeck) -> Int {
        deck.aksharas.filter { (aksharaCards[$0.letter]?.repetitions ?? 0) >= 2 }.count
    }

    /// Letters not yet introduced (or reset by an "Again" rating).
    func aksharaNewCount(for deck: AksharaDeck) -> Int {
        deck.aksharas.filter { aksharaCards[$0.letter]?.isNew ?? true }.count
    }

    var aksharaDueTotal: Int {
        AksharaDeck.allCases.reduce(0) { $0 + aksharaDueCount(for: $1) } + guninthaDueCount + vatthuDueCount
    }

    // MARK: Journey (gamified lesson path)

    /// A village is complete once every letter has been answered correctly at
    /// least once — a finished lesson guarantees this, and existing users'
    /// already-studied letters auto-complete their villages for free.
    func unitComplete(_ unit: PathUnit) -> Bool {
        !unit.aksharas.isEmpty
            && unit.aksharas.allSatisfy { (aksharaCards[$0.letter]?.repetitions ?? 0) >= 1 }
    }

    /// Studied letters in the unit that are due again — the map's
    /// "strengthen" signal on completed villages.
    func unitDueCount(_ unit: PathUnit) -> Int {
        unit.aksharas.filter { aksharaCards[$0.letter].map { !$0.isNew && $0.isDue } ?? false }.count
    }

    func stopComplete(_ stop: PathStop) -> Bool {
        switch stop.kind {
        case .village(let unit): return unitComplete(unit)
        case .temple: return pathProgress.passedCheckpoints.contains(stop.id)
        case .milestone: return false  // milestones become interactive in 5d
        }
    }

    /// Map state for every stop: the first incomplete *built* stop is
    /// current, everything after is locked (stops past the built sections
    /// always are — see `LearnPath.builtSectionCount`).
    var journeyStates: [String: JourneyStopState] {
        var states: [String: JourneyStopState] = [:]
        var currentAssigned = false
        let builtIDs = Set(LearnPath.builtStops.map(\.id))
        for stop in LearnPath.stops {
            if stopComplete(stop) {
                states[stop.id] = .done
            } else if !currentAssigned && builtIDs.contains(stop.id) {
                states[stop.id] = .current
                currentAssigned = true
            } else {
                states[stop.id] = .locked
            }
        }
        return states
    }

    /// Where the boat sits: the first incomplete stop overall, which is the
    /// edge of built content once everything shipped is done.
    var journeyCurrentIndex: Int {
        LearnPath.stops.firstIndex { !stopComplete($0) } ?? LearnPath.stops.count - 1
    }

    func passCheckpoint(_ stopID: String) {
        pathProgress.passedCheckpoints.insert(stopID)
        pathStore.save(pathProgress)
    }

    // MARK: Stats

    var wordsKnown: Int {
        deckCards.filter { $0.repetitions >= 2 }.count
    }

    var storiesRead: Int {
        data.storyProgress.count
    }

    /// Overall "read without help" — average of per-story best percentages.
    var overallProficiency: Int {
        let values = data.storyProgress.values.map(\.bestPct)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    var mostLookedUp: [(word: String, trans: String, count: Int)] {
        data.wordTaps
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, Transliterator.transliterate($0.key), $0.value) }
    }

    /// The trailing 7 days for the library week strip (oldest first).
    var weekStrip: [(day: DayStamp, didRead: Bool, isToday: Bool)] {
        let readDays = Set(data.readingDates)
        return (0..<7).reversed().map { offset in
            let day = DayStamp.today.adding(days: -offset)
            return (day, readDays.contains(day), offset == 0)
        }
    }

    // MARK: Auth

    func signIn(username: String, password: String) async throws {
        let session = try await auth.signIn(username: username, password: password)
        await hydrate(userID: session.userID)
    }

    func signUp(username: String, password: String) async throws {
        let session = try await auth.signUp(username: username, password: password)
        await hydrate(userID: session.userID)
    }

    func signOut() {
        auth.signOut()
    }

    func changePassword(_ newPassword: String) async throws {
        try await api.changePassword(newPassword)
    }

    func deleteAccount() async throws {
        try await api.deleteAccount()
        auth.signOut()
    }

    private func hydrate(userID: String) async {
        data = await sync.activate(userID: userID, local: data)
        persist()
    }
}
