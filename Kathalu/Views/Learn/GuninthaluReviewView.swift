import SwiftUI

/// SM-2 quiz for the 16 vowel signs. Each card is a sign, but every showing
/// pairs it with a different consonant — the first time with క (the classroom
/// standard), afterwards drawn from consonants the learner has studied — so
/// the pattern is learned, not one memorized form.
struct GuninthaluReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// One queued card: a sign and the consonant it's dressed in this time.
    private struct QuizItem: Identifiable {
        let sign: VowelSign
        let consonant: Akshara
        let id = UUID()

        var form: String { sign.apply(to: consonant) }
    }

    @State private var queue: [QuizItem] = []
    @State private var done = 0
    @State private var revealed = false
    @State private var sessionBuilt = false

    /// Signs change how every consonant reads — introduce them gently.
    private let newPerSession = 8

    var body: some View {
        NavigationStack {
            Group {
                if queue.isEmpty {
                    doneState
                } else {
                    session
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.pageBackground)
            .navigationTitle("గుణింతాలు · Vowel signs")
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
            }
        }
        .onAppear(perform: buildSessionIfNeeded)
    }

    private func buildSessionIfNeeded() {
        guard !sessionBuilt else { return }
        sessionBuilt = true
        let due = AksharaData.vowelSigns
            .filter { model.guninthaCard(for: $0).map { !$0.isNew && $0.isDue } ?? false }
            .sorted { model.guninthaCard(for: $0)!.nextReview < model.guninthaCard(for: $1)!.nextReview }
        let fresh = AksharaData.vowelSigns
            .filter { model.guninthaCard(for: $0)?.isNew ?? true }
            .prefix(newPerSession)
        // Shuffled so canonical order never gives the answer away.
        queue = (due + fresh).shuffled().map { makeItem(for: $0) }
        done = 0
    }

    private func makeItem(for sign: VowelSign) -> QuizItem {
        let isFirstShowing = model.guninthaCard(for: sign) == nil
        let consonant = isFirstShowing
            ? AksharaData.consonants[0]  // క, the classroom example
            : (model.guninthaQuizPool.randomElement() ?? AksharaData.consonants[0])
        return QuizItem(sign: sign, consonant: consonant)
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
                 ? "\(done) sign\(done == 1 ? "" : "s") reviewed · \(model.guninthaLearnedCount) of \(AksharaData.vowelSigns.count) learned"
                 : "Nothing due today · \(model.guninthaLearnedCount) of \(AksharaData.vowelSigns.count) learned")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
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

    // MARK: Active session

    private var session: some View {
        VStack(spacing: 0) {
            sessionBar
            Spacer()
            if let item = queue.first {
                card(for: item)
                    .onTapGesture { reveal(item) }
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

    private func card(for item: QuizItem) -> some View {
        ZStack {
            if queue.count >= 3 {
                cardShape(fill: Theme.heatEmpty.opacity(0.55))
                    .offset(y: 16)
                    .scaleEffect(0.92)
            }
            if queue.count >= 2 {
                cardShape(fill: Theme.card.opacity(0.8))
                    .offset(y: 8)
                    .scaleEffect(0.96)
            }
            face(for: item)
        }
        .frame(height: 350)
    }

    private func cardShape(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.divider))
    }

    private func face(for item: QuizItem) -> some View {
        VStack(spacing: 4) {
            Text(item.form)
                .font(Theme.serif(72, weight: .bold))
                .foregroundStyle(Theme.textHeading)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 20)
            if revealed {
                Text(item.sign.trans(for: item.consonant))
                    .font(Theme.latinSerif(22))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
                Text(item.sign.sign.isEmpty
                     ? "\(item.consonant.letter) — base form, no sign"
                     : "\(item.consonant.letter) + \(item.sign.sign) · \(item.sign.name)")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.textBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .padding(.top, 4)
                Text("carries the \(item.sign.vowel) sound")
                    .font(Theme.latinSerif(12))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 14)
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

    @ViewBuilder
    private var controls: some View {
        if revealed, let item = queue.first {
            HStack(spacing: 8) {
                rateButton("Again", preview: "<1m", color: Theme.rateAgain) { rate(item, 0) }
                rateButton("Hard", preview: preview(item.sign, quality: 3), color: Theme.rateHard) { rate(item, 3) }
                rateButton("Good", preview: preview(item.sign, quality: 4), color: Theme.rateGood) { rate(item, 4) }
                rateButton("Easy", preview: preview(item.sign, quality: 5), color: Theme.rateEasy) { rate(item, 5) }
            }
            .padding(.horizontal, 22)
        } else if let item = queue.first {
            Button {
                reveal(item)
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

    private func preview(_ sign: VowelSign, quality: Int) -> String {
        let card = model.guninthaCard(for: sign) ?? AksharaCard(letter: AppModel.guninthaKey(sign))
        return SM2.intervalPreview(for: card, quality: quality)
    }

    /// Revealing also pronounces the form, pairing sign shape with sound.
    private func reveal(_ item: QuizItem) {
        guard !revealed else { return }
        withAnimation(.spring(duration: 0.45)) { revealed = true }
        model.speech.speak(item.form)
    }

    private func rate(_ item: QuizItem, _ quality: Int) {
        model.rate(sign: item.sign, quality: quality)
        withAnimation(.snappy) {
            queue.removeFirst()
            if quality == 0 {
                // "Again" requeues the sign — dressed in a fresh consonant.
                queue.append(makeItem(for: item.sign))
            } else {
                done += 1
            }
            revealed = false
        }
    }
}

#Preview {
    GuninthaluReviewView()
        .environment(AppModel())
}
