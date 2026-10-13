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

/// Moves to the next card, face down. Reveal-only practice: nothing is rated
/// here, so the SM-2 schedule (and sync) stay owned by the app.
struct NextFlashcardIntent: AppIntent {
    static var title: LocalizedStringResource { "Next flashcard" }

    func perform() async throws -> some IntentResult {
        let defaults = WidgetShared.defaults
        let position = defaults?.integer(forKey: WidgetShared.Key.flashPosition) ?? 0
        defaults?.set(position + 1, forKey: WidgetShared.Key.flashPosition)
        defaults?.set(false, forKey: WidgetShared.Key.flashRevealed)
        return .result()
    }
}

// MARK: - Timeline

struct FlashcardEntry: TimelineEntry {
    let date: Date
    /// nil when no deck card has a meaning yet (the widget shows a hint).
    let card: FlashcardSnapshot?
    let revealed: Bool
    let position: Int
    let deckSize: Int
}

struct FlashcardProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlashcardEntry {
        FlashcardEntry(date: .now,
                       card: FlashcardSnapshot(telugu: "కథ", trans: "katha", meaning: "story"),
                       revealed: true, position: 1, deckSize: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlashcardEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    /// State only changes via the buttons (which reload the widget) or the app
    /// (which reloads this kind when the deck or its meanings change).
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlashcardEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    /// The app only snapshots cards that have a meaning, so every card here
    /// can be revealed with its translation.
    private func current() -> FlashcardEntry {
        let defaults = WidgetShared.defaults
        let position = max(0, defaults?.integer(forKey: WidgetShared.Key.flashPosition) ?? 0)
        let revealed = defaults?.bool(forKey: WidgetShared.Key.flashRevealed) ?? false
        let deck = WidgetData.deck
        guard !deck.isEmpty else {
            return FlashcardEntry(date: .now, card: nil, revealed: false, position: 0, deckSize: 0)
        }
        let i = position % deck.count
        return FlashcardEntry(date: .now, card: deck[i], revealed: revealed,
                              position: i + 1, deckSize: deck.count)
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
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetPalette.background, for: .widget)
        .widgetURL(entry.card == nil
            ? WidgetShared.Link.story(WidgetData.catalog.index(for: entry.date))
            : WidgetShared.Link.review)
    }

    private func cardView(_ card: FlashcardSnapshot) -> some View {
        VStack(spacing: 4) {
            HStack {
                WidgetCaption(text: "Flashcards")
                Spacer()
                Text("\(entry.position)/\(entry.deckSize)")
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
                Button(intent: RevealFlashcardIntent()) {
                    pill(entry.revealed ? "Hide" : "Reveal", filled: false)
                }
                Button(intent: NextFlashcardIntent()) {
                    pill("Next", filled: true)
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
        .description("Flip through your review deck — Reveal shows the romanization and English meaning.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
