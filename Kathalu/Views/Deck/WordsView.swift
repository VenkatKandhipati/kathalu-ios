import SwiftUI

/// Every word in the story-vocab deck, grouped by the story it came from:
/// meaning, when it's next due, tap the speaker to hear it. Swipe to delete
/// one, or Select → Delete for several. Deletes sync to the server.
struct WordsView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<String>()
    @State private var confirmDelete = false

    private struct StoryGroup: Identifiable {
        let id: Int          // story index; -1 for words without one
        let title: String
        let cards: [VocabCard]
    }

    private var groups: [StoryGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let cards = model.deckCards.filter { card in
            query.isEmpty
                || card.telugu.contains(query)
                || (card.trans ?? "").localizedCaseInsensitiveContains(query)
                || (card.meaning ?? "").localizedCaseInsensitiveContains(query)
        }
        return Dictionary(grouping: cards) { $0.storyIdx ?? -1 }
            .map { idx, cards in
                StoryGroup(id: idx,
                      title: model.story(at: idx)?.titleEn ?? "Other words",
                      cards: cards.sorted { $0.addedAt > $1.addedAt })
            }
            .sorted { ($0.id < 0 ? Int.max : $0.id) < ($1.id < 0 ? Int.max : $1.id) }
    }

    var body: some View {
        Group {
            if model.deckCards.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.background)
        .navigationTitle("Saved words")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { SoundToggleButton() }
            if !model.deckCards.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Select") {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                            selection.removeAll()
                        }
                    }
                }
            }
            if editMode.isEditing {
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete \(selection.count)", role: .destructive) {
                        confirmDelete = true
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .confirmationDialog(
            "Delete \(selection.count) word\(selection.count == 1 ? "" : "s") from your deck?",
            isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                model.removeCards(selection)
                selection.removeAll()
                editMode = .inactive
            }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            Section {
                Text("\(model.deckCards.count) words · up to \(AppModel.dailyReviewCap) reviews a day")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.cards, id: \.telugu) { card in
                        row(card)
                            .listRowBackground(Theme.card)
                            .swipeActions {
                                Button(role: .destructive) {
                                    model.removeCards([card.telugu])
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .scrollContentBackground(.hidden)
        .searchable(text: $search, prompt: "Search words or meanings")
    }

    private func row(_ card: VocabCard) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(card.telugu)
                        .font(Theme.serif(20, weight: .semibold))
                        .foregroundStyle(Theme.textHeading)
                    Text(card.trans ?? Transliterator.transliterate(card.telugu))
                        .font(Theme.latinSerif(14))
                        .foregroundStyle(Theme.accent)
                }
                if let meaning = card.meaning {
                    Text(meaning)
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.meaning)
                }
            }
            Spacer(minLength: 8)
            Text(dueLabel(card))
                .font(Theme.sans(12, weight: .medium))
                .foregroundStyle(card.isDue ? Theme.accent : Theme.textTertiary)
            if !editMode.isEditing && model.soundEnabled {
                Button {
                    model.speech.speak(card.telugu)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Theme.accent.opacity(0.1), in: Circle())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }

    private func dueLabel(_ card: VocabCard) -> String {
        if card.isNew && card.isDue { return "New" }
        if card.isDue { return "Due" }
        let days = card.nextReview.date.timeIntervalSince(DayStamp.today.date) / 86_400
        let n = Int(days.rounded())
        return n == 1 ? "Tomorrow" : "In \(n) days"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 6)
            Text("No saved words yet")
                .font(Theme.serif(22, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text("While reading, tap a word twice and choose “Add to flashcards”. Saved words show up here and in Review.")
                .font(Theme.sans(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
