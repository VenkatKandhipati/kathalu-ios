import SwiftUI

/// Native bottom sheet for a tapped word: pronunciation, meaning, add to deck.
/// The design's screen 1b.
struct WordSheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let word: String
    let story: Story

    @State private var meaning: String?
    @State private var isLoadingMeaning = false
    @State private var added = false

    private var entry: WordEntry? { DictionaryService.entry(for: word) }

    /// Sheet height: the base layout plus room for the dictionary's base-word
    /// and note lines when the entry has them.
    static func height(for word: String) -> CGFloat {
        let entry = DictionaryService.entry(for: word)
        return 400 + (entry?.base != nil ? 26 : 0) + (entry?.note != nil ? 62 : 0)
    }

    private var inDeck: Bool {
        added || model.data.cards[word] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(word)
                        .font(Theme.serif(42, weight: .bold))
                        .foregroundStyle(Theme.textHeading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(Transliterator.transliterate(word))
                        .font(Theme.latinSerif(18))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Button {
                    model.speech.speak(word)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 46, height: 46)
                        .background(Theme.accent.opacity(0.1), in: Circle())
                }
            }
            .padding(.top, 24)

            Divider()
                .overlay(Theme.divider)
                .padding(.vertical, 20)

            Text("MEANING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 6)

            Group {
                if let meaning {
                    Text(meaning)
                        .font(Theme.serif(20))
                        .foregroundStyle(Theme.meaning)
                } else if isLoadingMeaning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Looking it up…")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    Text("No meaning found — check your connection")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(minHeight: 28)

            if let entry, let base = entry.base {
                (Text("from ") + Text(base).font(Theme.serif(14))
                    + Text("  \(Transliterator.transliterate(base))").font(Theme.latinSerif(13.5)).italic()
                    + Text(entry.baseMeaning.map { " · \($0)" } ?? ""))
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 6)
            }
            if let note = entry?.note {
                Text(note)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            Text("from “\(story.titleEn)” · \(story.collection)")
                .font(Theme.latinSerif(12.5))
                .italic()
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 4)
                .padding(.bottom, 22)

            Button {
                model.addToDeck(word: word, storyIdx: story.index)
                added = true
                dismiss()
            } label: {
                Label(
                    inDeck ? "In your review deck" : "Add to flashcards",
                    systemImage: inDeck ? "checkmark" : "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(inDeck ? Theme.green : Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .background(Theme.card)
        .task {
            // The curated dictionary wins over anything cached on the card.
            if let entry {
                meaning = entry.meaning
                if model.data.cards[word]?.meaning != entry.meaning {
                    model.cacheMeaning(entry.meaning, for: word)
                }
                return
            }
            if let cached = model.data.cards[word]?.meaning {
                meaning = cached
                return
            }
            isLoadingMeaning = true
            defer { isLoadingMeaning = false }
            if let fetched = await TranslationService.meaning(for: word) {
                meaning = fetched
                model.cacheMeaning(fetched, for: word)
            }
        }
    }
}
