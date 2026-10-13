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
    let card: FlashcardSnapshot
    let revealed: Bool
    /// 1-based position within the deck, or nil when showing story words.
    let deckPosition: Int?
    let deckSize: Int
}

struct FlashcardProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlashcardEntry {
        FlashcardEntry(date: .now,
                       card: FlashcardSnapshot(telugu: "కథ", trans: "katha", meaning: "story"),
                       revealed: false, deckPosition: 1, deckSize: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlashcardEntry) -> Void) {
        completion(current())
    }

    /// State only changes via the buttons (which reload the widget) or the app
    /// (which reloads this kind when the deck changes), so no schedule needed.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlashcardEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> FlashcardEntry {
        let defaults = WidgetShared.defaults
        let position = max(0, defaults?.integer(forKey: WidgetShared.Key.flashPosition) ?? 0)
        let revealed = defaults?.bool(forKey: WidgetShared.Key.flashRevealed) ?? false
        let deck = WidgetData.deck
        if !deck.isEmpty {
            let i = position % deck.count
            return FlashcardEntry(date: .now, card: deck[i], revealed: revealed,
                                  deckPosition: i + 1, deckSize: deck.count)
        }
        // Empty deck: practice with words from the stories instead.
        let pool = WidgetData.wordPool
        let pick = pool.isEmpty ? nil : pool[SlotPicker.index(slot: position, salt: 0xF1A5, count: pool.count)]
        let card = FlashcardSnapshot(telugu: pick?.text ?? "కథ", trans: pick?.trans ?? "katha", meaning: nil)
        return FlashcardEntry(date: .now, card: card, revealed: revealed, deckPosition: nil, deckSize: 0)
    }
}

// MARK: - View

struct FlashcardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FlashcardEntry

    private var medium: Bool { family == .systemMedium }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                WidgetCaption(text: entry.deckPosition == nil ? "Story words" : "Flashcards")
                Spacer()
                if let position = entry.deckPosition {
                    Text("\(position)/\(entry.deckSize)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(entry.card.telugu)
                .font(WidgetPalette.telugu(medium ? 36 : 28).weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            if entry.revealed {
                Text(entry.card.trans)
                    .font(.system(size: medium ? 15 : 12, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetPalette.accent)
                    .lineLimit(1)
                if let meaning = entry.card.meaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(.system(size: medium ? 14 : 11))
                        .foregroundStyle(WidgetPalette.green)
                        .multilineTextAlignment(.center)
                        .lineLimit(medium ? 2 : 1)
                        .minimumScaleFactor(0.8)
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetPalette.background, for: .widget)
        .widgetURL(WidgetShared.Link.review)
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
        .description("Flip through your review deck right on the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
