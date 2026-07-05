import SwiftUI

/// SM-2 flashcard session for one script deck (phase 2 of Aksharamala).
/// Mirrors ReviewView's session flow: due letters first (oldest due first),
/// then a handful of new letters introduced in chart order.
struct AksharaReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let deck: AksharaDeck
    /// When embedded (in the Review tab's deck picker) the view skips its own
    /// navigation chrome and close button.
    var embedded = false

    @State private var queue: [Akshara] = []
    @State private var done = 0
    @State private var revealed = false
    @State private var sessionBuilt = false

    /// Letters are denser than vocabulary — introduce fewer per session so a
    /// beginner isn't handed the whole varnamala at once.
    private let newPerSession = 10

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                NavigationStack {
                    content
                        .navigationTitle("\(deck.telugu) · \(deck.titleEn)")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                SoundToggleButton()
                            }
                        }
                }
            }
        }
        .onAppear(perform: buildSessionIfNeeded)
    }

    private var content: some View {
        Group {
            if queue.isEmpty {
                doneState
            } else {
                session
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.pageBackground)
    }

    private func buildSessionIfNeeded() {
        guard !sessionBuilt else { return }
        sessionBuilt = true
        let cards = model.aksharaCards
        let due = deck.aksharas
            .filter { cards[$0.letter].map { !$0.isNew && $0.isDue } ?? false }
            .sorted { cards[$0.letter]!.nextReview < cards[$1.letter]!.nextReview }
        let fresh = deck.aksharas
            .filter { cards[$0.letter]?.isNew ?? true }
            .prefix(newPerSession)
        // Shuffled so chart order never gives the answer away.
        queue = (due + fresh).shuffled()
        done = 0
    }

    // MARK: States

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
                 ? "\(done) letter\(done == 1 ? "" : "s") reviewed · \(model.aksharaLearnedCount(for: deck)) of \(deck.aksharas.count) learned"
                 : "Nothing due today · \(model.aksharaLearnedCount(for: deck)) of \(deck.aksharas.count) learned")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            if !embedded {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .primaryButton()
                }
                .padding(.horizontal, 60)
                .padding(.top, 18)
            }
        }
    }

    // MARK: Active session

    private var session: some View {
        VStack(spacing: 0) {
            sessionBar
            Spacer()
            if let akshara = queue.first {
                AksharaDeckStackView(akshara: akshara, revealed: revealed, depth: min(3, queue.count))
                    .onTapGesture { reveal(akshara) }
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
        if revealed, let akshara = queue.first {
            HStack(spacing: 8) {
                rateButton("Again", preview: "<1m", color: Theme.rateAgain) { rate(akshara, 0) }
                rateButton("Hard", preview: preview(akshara, quality: 3), color: Theme.rateHard) { rate(akshara, 3) }
                rateButton("Good", preview: preview(akshara, quality: 4), color: Theme.rateGood) { rate(akshara, 4) }
                rateButton("Easy", preview: preview(akshara, quality: 5), color: Theme.rateEasy) { rate(akshara, 5) }
            }
            .padding(.horizontal, 22)
        } else if let akshara = queue.first {
            Button {
                reveal(akshara)
            } label: {
                Text("Reveal")
                    .primaryButton()
            }
            .padding(.horizontal, 22)
        }
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

    private func preview(_ akshara: Akshara, quality: Int) -> String {
        let card = model.aksharaCards[akshara.letter] ?? AksharaCard(letter: akshara.letter)
        return SM2.intervalPreview(for: card, quality: quality)
    }

    /// Revealing also pronounces the letter, pairing the glyph with its sound.
    private func reveal(_ akshara: Akshara) {
        guard !revealed else { return }
        withAnimation(.spring(duration: 0.45)) { revealed = true }
        if model.soundEnabled { model.speech.speak(akshara.spokenText) }
    }

    private func rate(_ akshara: Akshara, _ quality: Int) {
        model.rate(akshara: akshara, quality: quality)
        withAnimation(.snappy) {
            queue.removeFirst()
            if quality == 0 {
                // "Again" requeues the letter at the end of the session.
                queue.append(akshara)
            } else {
                done += 1
            }
            revealed = false
        }
    }
}

/// The stacked deck for script cards: glyph on the front; romanization,
/// sound hint and varga on the back.
struct AksharaDeckStackView: View {
    let akshara: Akshara
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
            Text(akshara.letter)
                .font(Theme.serif(72, weight: .bold))
                .foregroundStyle(Theme.textHeading)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 20)
            if revealed {
                Text(akshara.trans)
                    .font(Theme.latinSerif(22))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
                Text(akshara.soundHint)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.textBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .padding(.top, 4)
                if let group = AksharaData.group(containing: akshara) {
                    Text("\(group.telugu) · \(group.name)")
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
    AksharaReviewView(deck: .vowels)
        .environment(AppModel())
}
