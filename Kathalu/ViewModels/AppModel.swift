import SwiftUI
import Observation
import WidgetKit

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
    /// Set by a `kathalu://story/<idx>` deep link (from a widget); LibraryView
    /// opens the story and clears it.
    var deepLinkedStoryIndex: Int?
    /// Set by a `kathalu://letter/<letter>` deep link (Letter of the Day
    /// widget); LearnView opens that letter in Charts and clears it.
    var deepLinkedLetter: String?
    @ObservationIgnored private var isBackfillingMeanings = false

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

    // MARK: Daily reminder

    /// Daily reading reminder (local notification). Off until the user opts in
    /// — from Profile, or the one-time offer after their first 3-minute day.
    var reminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
            rescheduleReminders()
        }
    }
    /// Reminder time as minutes after midnight (default 7:00 PM).
    var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: "reminderMinute")
            rescheduleReminders()
        }
    }
    /// The one-time "want a daily reminder?" offer has been shown (or the
    /// user turned reminders on themselves), so it never shows again.
    var hasOfferedReminder: Bool {
        didSet { UserDefaults.standard.set(hasOfferedReminder, forKey: "hasOfferedReminder") }
    }
    /// Drives the offer alert (RootView). Raised when the reader closes after
    /// the first day's reading goal is met — not mid-story.
    var showReminderOffer = false
    @ObservationIgnored private var reminderOfferPending = false

    /// False when no Telugu TTS voice is installed on the device. Without one,
    /// iOS falls back to a non-Telugu voice that can't pronounce the script, so
    /// pronunciation is silent — the UI prompts the user to add one in iOS
    /// Settings (the app can't install voices itself).
    var teluguVoiceInstalled: Bool { !SpeechService.teluguVoices.isEmpty }

    // MARK: Services

    let speech = SpeechService()
    let readingActivity = ReadingActivityController()
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
        reminderEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
        reminderMinute = UserDefaults.standard.object(forKey: "reminderMinute") as? Int ?? 19 * 60
        hasOfferedReminder = UserDefaults.standard.bool(forKey: "hasOfferedReminder")
        let apiClient = APIClient(auth: auth)
        api = apiClient
        sync = SyncEngine(api: apiClient)

        // didSet doesn't fire during init — push the loaded values through.
        speech.voiceIdentifier = speechVoiceID
        speech.rate = Float(speechRate)

        if let session = auth.session {
            Task { await hydrate(userID: session.userID) }
        }

        applyDictionaryMeanings()
        applyWidgetGrades()
        refreshWidgets(force: true)
        readingActivity.endOrphans()
        rescheduleReminders()  // also installs the notification tap delegate
        Task { await backfillMeanings() }
    }

    private func persist() {
        localStore.save(data)
        scheduleWidgetRefresh()
    }

    @ObservationIgnored private var widgetRefreshTask: Task<Void, Never>?

    /// Coalesces widget snapshot writes: a burst of changes (e.g. rating cards
    /// in quick succession) costs one refresh a moment after the last one,
    /// instead of encoding the deck on every tap. Backgrounding flushes it.
    private func scheduleWidgetRefresh() {
        widgetRefreshTask?.cancel()
        widgetRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.refreshWidgets()
        }
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

    /// Active reading time that makes a day count toward the streak.
    static let dailyReadingGoal: TimeInterval = 3 * 60

    /// Adds active reader time to today's total (local, resets each day) and
    /// marks today as a reading day once it reaches `dailyReadingGoal` —
    /// the streak is about time spent reading, not stories finished.
    func addReadingTime(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        let defaults = UserDefaults.standard
        let today = DayStamp.today.description
        var total = defaults.string(forKey: "readingTimeDay") == today
            ? defaults.double(forKey: "readingTimeSeconds") : 0
        total += seconds
        defaults.set(today, forKey: "readingTimeDay")
        defaults.set(total, forKey: "readingTimeSeconds")
        if total >= Self.dailyReadingGoal { markReadingDay() }
    }

    private func markReadingDay() {
        let today = DayStamp.today
        guard !data.readingDates.contains(today) else { return }
        data.readingDates.insert(today, at: 0)
        if data.readingDates.count > 365 { data.readingDates.removeLast() }
        persist()
        if isSignedIn { sync.pushReadingDay() }
        rescheduleReminders()  // today's reminder is no longer needed
        if !hasOfferedReminder && !reminderEnabled { reminderOfferPending = true }
    }

    // MARK: Daily reminder

    /// Rebuilds the scheduled reminders from current state (streak, whether
    /// today is read, the time setting). Cheap; called at launch, on
    /// foreground, when today's goal is met, and on setting changes.
    func rescheduleReminders() {
        let service = NotificationService.shared
        guard reminderEnabled else { return service.reschedule(nil) }
        service.reschedule(reminderPlan)
    }

    private var reminderPlan: NotificationService.Plan {
        let stories = storyStore
        return .init(
            minuteOfDay: reminderMinute,
            streak: data.streak,
            readToday: data.readingDates.contains(.today),
            storyForDate: { date in
                let i = stories.index(for: date)
                return stories.stories.indices.contains(i) ? stories.stories[i] : nil
            })
    }

    #if DEBUG
    func sendTestReminder() {
        Task { await NotificationService.shared.sendTest(reminderPlan) }
    }
    #endif

    /// "7:00 PM" for a minute-of-day, in the user's locale.
    static func timeLabel(_ minuteOfDay: Int) -> String {
        let date = Calendar.current.date(
            bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Turns reminders on, asking for notification permission first. Returns
    /// false (and leaves them off) if the user declines.
    @discardableResult
    func enableReminders() async -> Bool {
        hasOfferedReminder = true
        let granted = await NotificationService.shared.requestAuthorization()
        reminderEnabled = granted
        return granted
    }

    /// Called when the reader closes: shows the one-time reminder offer if
    /// today's goal was just met for the first time.
    func offerReminderIfPending() {
        guard reminderOfferPending, !hasOfferedReminder else { return }
        reminderOfferPending = false
        hasOfferedReminder = true
        Task {
            try? await Task.sleep(for: .milliseconds(600))  // let the reader finish dismissing
            showReminderOffer = true
        }
    }

    // MARK: Resume position

    /// Where each story was left off, as a story-wide paragraph index — stable
    /// across font sizes and reading modes. Local-only (UserDefaults): sign-in
    /// rebuilds `UserData` from the server, which doesn't know this field.
    private static let positionsKey = "readingPositions"

    func readingPosition(storyIdx: Int) -> Int? {
        let positions = UserDefaults.standard.dictionary(forKey: Self.positionsKey) as? [String: Int]
        return positions?[String(storyIdx)]
    }

    /// Saves the paragraph a story is open at; `nil` (or the first paragraph)
    /// clears it so the story opens from the top next time.
    func saveReadingPosition(_ paragraph: Int?, storyIdx: Int) {
        var positions = UserDefaults.standard.dictionary(forKey: Self.positionsKey) as? [String: Int] ?? [:]
        let key = String(storyIdx)
        if let paragraph, paragraph > 0 { positions[key] = paragraph } else { positions[key] = nil }
        UserDefaults.standard.set(positions, forKey: Self.positionsKey)
    }

    /// Records a finished story: best proficiency and a reading session.
    /// (Doesn't touch the streak — see `addReadingTime`.)
    func finishReading(storyIdx: Int, proficiencyPct: Int) {
        let today = DayStamp.today
        let previous = data.storyProgress[storyIdx]?.bestPct ?? 0
        let best = max(previous, proficiencyPct)
        data.storyProgress[storyIdx] = StoryProgressEntry(bestPct: best, lastRead: today)
        persist()
        if isSignedIn {
            sync.pushProgress(storyIdx: storyIdx, bestPct: best)
            sync.pushSession(storyIdx: storyIdx, pct: proficiencyPct)
        }
    }

    // MARK: Widgets & deep links

    /// Writes the App Group snapshot the widgets read (raw reading days, best
    /// scores, deck cards) and reloads only the widget kinds whose data changed.
    /// Called from `persist()`, so it runs on every data change — cheap, and
    /// app-initiated reloads while foregrounded don't spend the widget budget.
    func refreshWidgets(force: Bool = false) {
        guard let defaults = WidgetShared.defaults else { return }
        typealias Key = WidgetShared.Key
        typealias Kind = WidgetShared.Kind
        var changed: Set<String> = []

        let readDays = data.readingDates.map(\.description)
        if force || defaults.stringArray(forKey: Key.readDays) != readDays {
            defaults.set(readDays, forKey: Key.readDays)
            changed.formUnion([Kind.streak, Kind.todayStory])
        }

        let best = Dictionary(uniqueKeysWithValues: data.storyProgress.map { (String($0.key), $0.value.bestPct) })
        if force || (defaults.dictionary(forKey: Key.storyBest) as? [String: Int]) != best {
            defaults.set(best, forKey: Key.storyBest)
            changed.insert(Kind.todayStory)
        }

        if let cards = try? JSONEncoder().encode(flashcardSnapshot()),
           force || defaults.data(forKey: Key.flashcards) != cards {
            defaults.set(cards, forKey: Key.flashcards)
            changed.insert(Kind.flashcard)
        }

        if force {
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            changed.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
        }
    }

    /// Deck cards for the flashcard widget, in the Review tab's session order
    /// (due cards oldest-first, then up to 20 new), followed by upcoming cards
    /// so the widget can surface them itself after midnight. Only cards with a
    /// meaning — Reveal must always show a translation.
    private func flashcardSnapshot() -> [FlashcardSnapshot] {
        let cards = deckCards.filter { !($0.meaning ?? "").isEmpty }
        let due = cards.filter { !$0.isNew && $0.isDue }.sorted { $0.nextReview < $1.nextReview }
        let fresh = cards.filter(\.isNew).sorted { $0.addedAt < $1.addedAt }.prefix(20)
        let upcoming = cards.filter { !$0.isDue }.sorted { $0.nextReview < $1.nextReview }
        return (due + fresh + upcoming).prefix(120).map {
            FlashcardSnapshot(
                telugu: $0.telugu,
                trans: $0.trans ?? Transliterator.transliterate($0.telugu),
                meaning: $0.meaning,
                nextReview: $0.nextReview.description)
        }
    }

    /// The last batch of words graded on the widget, so an open Review
    /// session can drop them.
    private(set) var widgetGradedWords: Set<String> = []

    /// Applies Hard/Good taps from the flashcard widget through the same SM-2
    /// path as the Review tab (`rate`), which also syncs and refreshes widgets.
    /// A grade for a card that's no longer due was already handled (e.g.
    /// graded in the app first) and is dropped.
    func applyWidgetGrades() {
        let pending = FlashcardGrades.pending()
        guard !pending.isEmpty else { return }
        var graded: Set<String> = []
        for grade in pending.sorted(by: { $0.at < $1.at }) {
            guard let card = data.cards[grade.word], card.isDue,
                  (0...5).contains(grade.quality) else { continue }
            rate(card: card, quality: grade.quality)
            graded.insert(grade.word)
        }
        FlashcardGrades.remove(Set(pending.map(\.id)))
        if !graded.isEmpty { widgetGradedWords = graded }
    }

    /// Fetches meanings for deck cards that don't have one yet, so the
    /// flashcard widget can always show a translation. Words tapped once in the
    /// reader join the deck without a meaning (it's only looked up when the
    /// meaning sheet opens). A few per run keeps the free lookup API happy;
    /// runs at launch and whenever the app returns to the foreground.
    func backfillMeanings() async {
        guard !isBackfillingMeanings else { return }
        isBackfillingMeanings = true
        defer { isBackfillingMeanings = false }
        let missing = deckCards
            .filter { ($0.meaning ?? "").isEmpty }
            .sorted { $0.isDue != $1.isDue ? $0.isDue : $0.addedAt > $1.addedAt }
            .prefix(10)
        for card in missing {
            if let meaning = await DictionaryService.meaning(for: card.telugu) {
                cacheMeaning(meaning, for: card.telugu)
            }
        }
    }

    /// Replaces saved meanings with the curated dictionary's wherever they
    /// differ — older cards carry unvalidated MyMemory glosses. Runs at launch
    /// and after sign-in (the server copy still has the old meanings), and
    /// pushes corrected cards so the server catches up.
    private func applyDictionaryMeanings() {
        var changed: [VocabCard] = []
        for (word, card) in data.cards {
            guard let meaning = DictionaryService.entry(for: word)?.meaning,
                  card.meaning != meaning else { continue }
            var updated = card
            updated.meaning = meaning
            data.cards[word] = updated
            changed.append(updated)
        }
        guard !changed.isEmpty else { return }
        persist()
        if isSignedIn { changed.forEach(sync.pushCard) }
    }

    /// Routes a `kathalu://` deep link from a widget or the Live Activity and
    /// returns the tab to show (`nil` for links it doesn't understand).
    func handleDeepLink(_ url: URL) -> String? {
        guard url.scheme == "kathalu" else { return nil }
        switch url.host {
        case "story":
            guard let idx = Int(url.lastPathComponent) else { return nil }
            deepLinkedStoryIndex = idx
            return "library"
        case "review":
            return "review"
        case "letter":
            let letter = url.lastPathComponent
            guard !letter.isEmpty, letter != "/" else { return nil }
            deepLinkedLetter = letter
            return "learn"
        default:
            return nil
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
    /// This calendar week, Monday → Sunday. Days after today are included;
    /// views dim them.
    var weekStrip: [(day: DayStamp, didRead: Bool, isToday: Bool)] {
        let readDays = Set(data.readingDates)
        let today = DayStamp.today
        let weekday = Calendar.current.component(.weekday, from: today.date)  // 1 = Sunday
        let monday = today.adding(days: -((weekday + 5) % 7))
        return (0..<7).map { offset in
            let day = monday.adding(days: offset)
            return (day, readDays.contains(day), day == today)
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
        applyDictionaryMeanings()
    }
}
