import SwiftUI

/// SM-2 flashcard review: deck stack, tap to reveal, four-quality rating bar.
struct ReviewView: View {
    @Environment(AppModel.self) private var model

    /// What's being reviewed: story vocabulary or one of the script decks.
    enum DeckChoice: String, CaseIterable, Identifiable {
        case words, vowels, consonants, guninthalu
        var id: String { rawValue }
    }

    @State private var deckChoice: DeckChoice = .words
    @State private var queue: [VocabCard] = []
    @State private var done = 0
    @State private var revealed = false
    @State private var sessionBuilt = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                deckPicker
                    .padding(.top, 10)
                switch deckChoice {
                case .words:
                    wordsContent
                case .vowels:
                    AksharaReviewView(deck: .vowels, embedded: true)
                case .consonants:
                    AksharaReviewView(deck: .consonants, embedded: true)
                case .guninthalu:
                    GuninthaluReviewView(embedded: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.pageBackground)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SoundToggleButton()
                }
                if model.data.streak > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        StreakBadge(count: model.data.streak)
                    }
                }
            }
        }
        .onAppear(perform: buildSessionIfNeeded)
    }

    private var wordsContent: some View {
        Group {
            if model.deckCards.isEmpty {
                emptyState
            } else if queue.isEmpty {
                doneState
            } else {
                session
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Deck switcher chips; script decks show their due counts inline.
    private var deckPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeckChoice.allCases) { choice in
                    deckChip(choice)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private func deckChip(_ choice: DeckChoice) -> some View {
        let isOn = deckChoice == choice
        return Button {
            withAnimation(.snappy) { deckChoice = choice }
        } label: {
            Text(chipLabel(choice))
                .font(Theme.sans(13, weight: .semibold))
                .foregroundStyle(isOn ? .white : Theme.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(isOn ? Theme.accent : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isOn ? .clear : Theme.cardBorder))
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ choice: DeckChoice) -> String {
        let due: Int
        let name: String
        switch choice {
        case .words:
            name = "Story words"
            due = model.dueCount
        case .vowels:
            name = "అచ్చులు"
            due = model.aksharaDueCount(for: .vowels)
        case .consonants:
            name = "హల్లులు"
            due = model.aksharaDueCount(for: .consonants)
        case .guninthalu:
            name = "గుణింతాలు"
            due = model.guninthaDueCount
        }
        return due > 0 ? "\(name) · \(due)" : name
    }

    /// Due cards first (oldest due first), then up to 20 new cards — same
    /// session rule as the web reviewer.
    private func buildSessionIfNeeded() {
        guard !sessionBuilt else { return }
        sessionBuilt = true
        let cards = model.deckCards
        let due = cards
            .filter { !$0.isNew && $0.isDue }
            .sorted { $0.nextReview < $1.nextReview }
        let fresh = cards
            .filter(\.isNew)
            .sorted { $0.addedAt < $1.addedAt }
            .prefix(20)
        queue = due + fresh
        done = 0
    }

    // MARK: States

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 8)
            Text("No cards yet")
                .font(Theme.serif(24, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text("Tap words while reading and they'll\nland here for review.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var doneState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44))
                .foregroundStyle(Theme.green)
                .padding(.bottom, 8)
            Text("All caught up")
                .font(Theme.serif(24, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text(done > 0
                 ? "\(done) card\(done == 1 ? "" : "s") reviewed · \(model.deckCards.count) in deck"
                 : "Nothing due today · \(model.deckCards.count) cards total")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Active session

    private var session: some View {
        VStack(spacing: 0) {
            sessionBar
            Spacer()
            if let card = queue.first {
                DeckStackView(card: card, revealed: revealed, depth: min(3, queue.count))
                    .onTapGesture { reveal(card) }
                    .padding(.horizontal, 40)
            }
            Spacer()
            controls
        }
        .padding(.bottom, 16)
    }

    private var sessionBar: some View {
        VStack(spacing: 8) {
            HStack {
                (Text("\(queue.count)").bold().foregroundStyle(Theme.textHeading)
                 + Text(" remaining").foregroundStyle(Theme.textSecondary))
                Spacer()
                (Text("\(done)").bold().foregroundStyle(Theme.textHeading)
                 + Text(" done").foregroundStyle(Theme.textSecondary))
            }
            .font(Theme.latinSerif(13))
            GeometryReader { geo in
                Capsule().fill(Theme.divider)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(1, done + queue.count)))
                    }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var controls: some View {
        if revealed, let card = queue.first {
            HStack(spacing: 8) {
                rateButton("Again", preview: "<1m", color: Theme.rateAgain) { rate(card, 0) }
                rateButton("Hard", preview: SM2.intervalPreview(for: card, quality: 3), color: Theme.rateHard) { rate(card, 3) }
                rateButton("Good", preview: SM2.intervalPreview(for: card, quality: 4), color: Theme.rateGood) { rate(card, 4) }
                rateButton("Easy", preview: SM2.intervalPreview(for: card, quality: 5), color: Theme.rateEasy) { rate(card, 5) }
            }
            .padding(.horizontal, 22)
        } else if let card = queue.first {
            Button {
                reveal(card)
            } label: {
                Text("Reveal")
                    .primaryButton()
            }
            .padding(.horizontal, 22)
        }
    }

    /// Revealing also pronounces the word (when sound is on), matching the
    /// script-deck sessions.
    private func reveal(_ card: VocabCard) {
        guard !revealed else { return }
        withAnimation(.spring(duration: 0.45)) { revealed = true }
        if model.soundEnabled { model.speech.speak(card.telugu) }
    }

    private func rateButton(_ label: String, preview: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(preview)
                    .font(Theme.latinSerif(10.5))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func rate(_ card: VocabCard, _ quality: Int) {
        model.rate(card: card, quality: quality)
        withAnimation(.snappy) {
            queue.removeFirst()
            if quality == 0 {
                // "Again" requeues the card at the end of the session.
                if let requeued = model.data.cards[card.telugu] {
                    queue.append(requeued)
                }
            } else {
                done += 1
            }
            revealed = false
        }
    }
}

/// The design's stacked deck with the current card on top.
struct DeckStackView: View {
    @Environment(AppModel.self) private var model

    let card: VocabCard
    let revealed: Bool
    let depth: Int

    var body: some View {
        ZStack {
            if depth >= 3 {
                cardShape(fill: Theme.heatEmpty.opacity(0.55))
                    .offset(y: 16)
                    .scaleEffect(0.92)
            }
            if depth >= 2 {
                cardShape(fill: Theme.card.opacity(0.8))
                    .offset(y: 8)
                    .scaleEffect(0.96)
            }
            face
        }
        .frame(height: 350)
    }

    private func cardShape(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.divider))
    }

    private var face: some View {
        VStack(spacing: 4) {
            Text(card.telugu)
                .font(Theme.serif(48, weight: .bold))
                .foregroundStyle(Theme.textHeading)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 20)
            if revealed {
                Text(card.trans ?? Transliterator.transliterate(card.telugu))
                    .font(Theme.latinSerif(19))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
                if let meaning = card.meaning {
                    Text(meaning)
                        .font(Theme.serif(18))
                        .foregroundStyle(Theme.meaning)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                if let idx = card.storyIdx, let story = model.story(at: idx) {
                    Text("from “\(story.titleEn)”")
                        .font(Theme.latinSerif(12))
                        .italic()
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 14)
                }
            } else {
                Text("tap to reveal")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardShape(fill: Theme.card))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 10)
    }
}

#Preview {
    ReviewView()
        .environment(AppModel())
}
