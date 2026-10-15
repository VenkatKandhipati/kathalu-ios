import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Button intents (run in the widget process; iOS 17+ interactive widgets)

/// Flips the current card. The widget reloads automatically after `perform`.
struct RevealFlashcardIntent: AppIntent {
    static var title: LocalizedStringResource { "Reveal flashcard" }

    func perform() async throws -> some IntentResult {
        let defaults = WidgetShared.defaults
        let revealed = defaults?.bool(forKey: WidgetShared.Key.flashRevealed) ?? false
        defaults?.set(!revealed, forKey: WidgetShared.Key.flashRevealed)
        return .result()
    }
}

/// Hard / Good. Only logs the grade (`FlashcardGrades`) and moves on — the
/// widget redraws instantly. The app applies the log through the Review tab's
/// SM-2 path (and syncs) when it next launches or comes to the foreground;
/// until then the widget hides logged cards.
struct GradeFlashcardIntent: AppIntent {
    static var title: LocalizedStringResource { "Grade flashcard" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Word") var word: String
    /// SM-2 quality: 3 = Hard, 4 = Good (same values as the Review tab).
    @Parameter(title: "Quality") var quality: Int

    init() {}

    init(word: String, quality: Int) {
        self.word = word
        self.quality = quality
    }

    func perform() async throws -> some IntentResult {
        FlashcardGrades.enqueue(word: word, quality: quality)
        WidgetShared.defaults?.set(false, forKey: WidgetShared.Key.flashRevealed)
        return .result()
    }
}

// MARK: - Timeline

struct FlashcardEntry: TimelineEntry {
    let date: Date
    /// The next card due today; nil when caught up or the deck is empty.
    let card: FlashcardSnapshot?
    let revealed: Bool
    /// Cards left today, including `card`.
    let dueCount: Int
    /// No deck card has a meaning yet (the widget shows a hint).
    let deckEmpty: Bool
}

struct FlashcardProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlashcardEntry {
        FlashcardEntry(date: .now,
                       card: FlashcardSnapshot(telugu: "కథ", trans: "katha", meaning: "story"),
                       revealed: true, dueCount: 5, deckEmpty: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlashcardEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    /// State changes via the buttons (which reload the widget) or the app
    /// (which reloads this kind when the deck changes); the midnight refresh
    /// brings in cards that come due tomorrow.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlashcardEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        completion(Timeline(entries: [current()], policy: .after(midnight)))
    }

    /// Today's queue: the app's snapshot (Review-tab order) filtered to cards
    /// due today, minus any graded here that the app hasn't applied yet.
    private func current() -> FlashcardEntry {
        let deck = WidgetData.deck
        guard !deck.isEmpty else {
            return FlashcardEntry(date: .now, card: nil, revealed: false, dueCount: 0, deckEmpty: true)
        }
        let today = DayStamp.today.description
        let graded = Set(FlashcardGrades.pending().map(\.word))
        // Capped like the Review tab (20/day); the app's snapshot already is,
        // this covers cards that came due after midnight.
        let queue = Array(deck.filter { ($0.nextReview ?? today) <= today && !graded.contains($0.telugu) }
            .prefix(20))
        let revealed = WidgetShared.defaults?.bool(forKey: WidgetShared.Key.flashRevealed) ?? false
        return FlashcardEntry(date: .now, card: queue.first, revealed: revealed && !queue.isEmpty,
                              dueCount: queue.count, deckEmpty: false)
    }
}

// MARK: - View

struct FlashcardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FlashcardEntry

    private var medium: Bool { family == .systemMedium }

    var body: some View {
        Group {
            if let card = entry.card {
                cardView(card)
            } else if entry.deckEmpty {
                emptyState
            } else {
                caughtUpState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetPalette.background, for: .widget)
        .widgetURL(entry.card == nil
            ? WidgetShared.Link.story(WidgetData.catalog.index(for: entry.date))
            : WidgetShared.Link.review)
    }

    /// Nothing due today — the Review tab would say the same.
    private var caughtUpState: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetCaption(text: "Flashcards")
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: medium ? 24 : 20))
                .foregroundStyle(WidgetPalette.green)
            Text("All caught up")
                .font(.system(size: medium ? 15 : 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text("No cards due — tap for today's story.")
                .font(.system(size: medium ? 12.5 : 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardView(_ card: FlashcardSnapshot) -> some View {
        VStack(spacing: 4) {
            HStack {
                WidgetCaption(text: "Flashcards")
                Spacer()
                Text("\(entry.dueCount) due")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(card.telugu)
                .font(WidgetPalette.telugu(medium ? 36 : 28).weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            if entry.revealed {
                Text(card.trans)
                    .font(.system(size: medium ? 15 : 12, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetPalette.accent)
                    .lineLimit(1)
                Text(card.meaning ?? "")
                    .font(.system(size: medium ? 15 : 12, weight: .semibold))
                    .foregroundStyle(WidgetPalette.green)
                    .multilineTextAlignment(.center)
                    .lineLimit(medium ? 2 : 1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                // Face down: Reveal · Good. Revealed: Hard · Good — the Review
                // tab's quality 3 and 4.
                if entry.revealed {
                    Button(intent: GradeFlashcardIntent(word: card.telugu, quality: 3)) {
                        pill("Hard", filled: false)
                    }
                } else {
                    Button(intent: RevealFlashcardIntent()) {
                        pill("Reveal", filled: false)
                    }
                }
                Button(intent: GradeFlashcardIntent(word: card.telugu, quality: 4)) {
                    pill("Good", filled: true)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// No deck card has a meaning yet — words join the deck when tapped in a
    /// story, and meanings are filled in when the app is opened.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetCaption(text: "Flashcards")
            Spacer(minLength: 0)
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: medium ? 24 : 20))
                .foregroundStyle(WidgetPalette.accent)
            Text("Tap words while reading a story to build your deck.")
                .font(.system(size: medium ? 14 : 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? .white : WidgetPalette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(filled ? WidgetPalette.accent : WidgetPalette.accent.opacity(0.12), in: Capsule())
    }
}

struct FlashcardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.flashcard, provider: FlashcardProvider()) { entry in
            FlashcardWidgetView(entry: entry)
        }
        .configurationDisplayName("Flashcard")
        .description("Today's review cards — Reveal, then grade Hard or Good. Grades count in the Review tab.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
