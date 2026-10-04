import SwiftUI

/// One Journey session: a village lesson (meet the new letters, then drills),
/// a strengthen practice over a learned village, or a temple checkpoint quiz.
///
/// Exercises are multiple-choice and feed the same SM-2 ledger as the
/// free-practice decks — one rating per letter at session end (perfect → 4,
/// missed-but-recovered → 3; checkpoints rate 5/3 — a checkpoint miss stays
/// at 3 rather than resetting the letter, so a single wrong answer can't
/// un-complete its village and bounce the boat back). Wrong answers requeue
/// the letter with a different exercise type
/// until it's cleared (checkpoints score instead of requeueing).
struct LessonSessionView: View {
    enum Mode {
        case lesson(PathUnit)
        case practice(PathUnit)
        case checkpoint(PathSection)
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var steps: [LessonStep] = []
    @State private var index = 0
    @State private var answer: AnswerFeedback?
    @State private var missed: Set<String> = []
    @State private var practiced: [Akshara] = []
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var correctCount = 0
    @State private var questionCount = 0
    @State private var finished = false
    @State private var ratingsApplied = false
    @State private var built = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var speakTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if finished {
                    summary
                } else if steps.indices.contains(index) {
                    activeSession(steps[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.pageBackground)
            .navigationTitle(title)
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
        .onAppear(perform: buildIfNeeded)
        .onDisappear {
            advanceTask?.cancel()
            speakTask?.cancel()
        }
    }

    private var title: String {
        switch mode {
        case .lesson: return "కొత్త అక్షరాలు · New letters"
        case .practice: return "సాధన · Strengthen"
        case .checkpoint(let section):
            if let temple = LearnPath.templeStop(in: section),
               case .temple(let telugu, let name, _) = temple.kind {
                return "\(telugu) · \(name)"
            }
            return "Checkpoint"
        }
    }

    private var isCheckpoint: Bool {
        if case .checkpoint = mode { return true }
        return false
    }

    // MARK: Session building

    private func buildIfNeeded() {
        guard !built else { return }
        built = true
        switch mode {
        case .lesson(let unit):
            practiced = unit.aksharas
            let fresh = unit.aksharas.filter { (model.aksharaCards[$0.letter]?.repetitions ?? 0) == 0 }
            steps = fresh.map { .intro($0) }
                + makeExercises(for: unit.aksharas, perLetter: 2).map { .exercise($0) }
        case .practice(let unit):
            // Strengthen what's due; if nothing is, run the whole village.
            let due = unit.aksharas.filter {
                model.aksharaCards[$0.letter].map { !$0.isNew && $0.isDue } ?? false
            }
            practiced = due.isEmpty ? unit.aksharas : due
            steps = makeExercises(for: practiced, perLetter: 2).map { .exercise($0) }
        case .checkpoint(let section):
            practiced = LearnPath.units(in: section).flatMap(\.aksharas)
            steps = makeExercises(for: practiced, perLetter: 1).map { .exercise($0) }
        }
    }

    private var availableKinds: [LessonExercise.Kind] {
        // Listening needs sound; the rest work silent.
        model.soundEnabled ? [.recognition, .listening, .reverse] : [.recognition, .reverse]
    }

    private func makeExercises(for letters: [Akshara], perLetter: Int) -> [LessonExercise] {
        letters.flatMap { letter in
            availableKinds.shuffled().prefix(perLetter).map { kind in
                makeExercise(for: letter, kind: kind)
            }
        }
        .shuffled()
    }

    private func makeExercise(for target: Akshara, kind: LessonExercise.Kind) -> LessonExercise {
        LessonExercise(target: target, kind: kind, options: options(for: target))
    }

    /// Three distractors: unit-mates first (the confusable ones), then the
    /// rest of the deck.
    private func options(for target: Akshara) -> [Akshara] {
        let deckPool = AksharaData.vowels.aksharas.contains(target)
            ? AksharaData.vowels.aksharas
            : AksharaData.consonants
        var distractors = practiced.filter { $0 != target }.shuffled()
        distractors += deckPool.filter { $0 != target && !distractors.contains($0) }.shuffled()
        return ([target] + distractors.prefix(3)).shuffled()
    }

    // MARK: Answer flow

    private func choose(_ option: Akshara, in exercise: LessonExercise) {
        guard answer == nil else { return }
        let correct = option == exercise.target
        answer = AnswerFeedback(chosen: option, correct: correct)
        questionCount += 1
        if correct {
            correctCount += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if model.soundEnabled && exercise.kind != .listening {
                model.speech.speak(exercise.target.spokenText)
            }
            advanceTask = Task {
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
                advance()
            }
        } else {
            combo = 0
            missed.insert(exercise.target.letter)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if model.soundEnabled { model.speech.speak(exercise.target.spokenText) }
            if !isCheckpoint {
                // Come back to this letter with a different exercise type.
                let retryKind = availableKinds.filter { $0 != exercise.kind }.randomElement() ?? exercise.kind
                steps.append(.exercise(makeExercise(for: exercise.target, kind: retryKind)))
            }
        }
    }

    /// Pronounce after a beat, so the sound lands once the card has settled
    /// instead of firing mid-transition. Cancelled if the step moves on first.
    private func speakSoon(_ akshara: Akshara, delay: Double) {
        speakTask?.cancel()
        speakTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            model.speech.speak(akshara.spokenText)
        }
    }

    private func advance() {
        speakTask?.cancel()
        answer = nil
        if index + 1 < steps.count {
            index += 1
        } else {
            finish()
        }
    }

    private func finish() {
        guard !ratingsApplied else { return }
        ratingsApplied = true
        switch mode {
        case .lesson, .practice:
            // Requeueing means every letter was eventually answered right:
            // clean letters were "good", missed ones "hard but recovered".
            for letter in practiced {
                model.rate(akshara: letter, quality: missed.contains(letter.letter) ? 3 : 4)
            }
        case .checkpoint(let section):
            for letter in practiced {
                // Misses rate 3, not <3: a sub-3 quality resets SM-2
                // repetitions to 0, which would un-complete the letter's
                // village and bounce the boat backward even on a pass. 3 keeps
                // the village complete but schedules the letter due soon, so it
                // surfaces as a ⚡ strengthen prompt on the map instead.
                model.rate(akshara: letter, quality: missed.contains(letter.letter) ? 3 : 5)
            }
            if checkpointPassed, let temple = LearnPath.templeStop(in: section) {
                model.passCheckpoint(temple.id)
            }
        }
        withAnimation(.spring(duration: 0.5)) { finished = true }
    }

    /// Pass bar: at least 80% of the checkpoint's questions right.
    private var checkpointPassed: Bool {
        correctCount * 5 >= steps.count * 4
    }

    private func restartCheckpoint() {
        advanceTask?.cancel()
        steps = []
        index = 0
        answer = nil
        missed = []
        combo = 0
        bestCombo = 0
        correctCount = 0
        questionCount = 0
        finished = false
        ratingsApplied = false
        built = false
        buildIfNeeded()
    }

    // MARK: Active session

    private func activeSession(_ step: LessonStep) -> some View {
        VStack(spacing: 0) {
            progressBar
            Group {
                switch step {
                case .intro(let akshara):
                    introView(akshara)
                case .exercise(let exercise):
                    exerciseView(exercise)
                }
            }
            .id(index)  // fresh onAppear (and transition) per step
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        }
        .animation(.snappy, value: index)
        .padding(.bottom, 16)
    }

    private var progressBar: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                Capsule().fill(Theme.divider)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * CGFloat(index) / CGFloat(max(1, steps.count)))
                            .animation(.snappy, value: index)
                    }
            }
            .frame(height: 6)
            if combo >= 3 {
                Text("\(combo) in a row ✨")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.gold)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
    }

    // MARK: Intro step

    private func introView(_ akshara: Akshara) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                Text("కొత్త అక్షరం · new letter")
                    .font(Theme.latinSerif(12))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.bottom, 12)
                Text(akshara.letter)
                    .font(Theme.serif(88, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(akshara.trans)
                    .font(Theme.latinSerif(24))
                    .foregroundStyle(Theme.accent)
                Text(akshara.soundHint)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 6)
                Button {
                    model.speech.speak(akshara.spokenText)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 46, height: 46)
                        .background(Theme.accent.opacity(0.1), in: Circle())
                }
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.divider))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 10)
            .padding(.horizontal, 34)
            .onAppear {
                if model.soundEnabled { speakSoon(akshara, delay: 0.7) }
            }
            Spacer()
            Button {
                advance()
            } label: {
                Text("Continue")
                    .primaryButton()
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: Exercise step

    private func exerciseView(_ exercise: LessonExercise) -> some View {
        VStack(spacing: 0) {
            Spacer()
            prompt(exercise)
                .onAppear {
                    switch exercise.kind {
                    case .listening:
                        speakSoon(exercise.target, delay: 0.5)
                    case .reverse:
                        // Reverse pairs the romanization with its sound, so
                        // the ear helps pick the letter — but only when sound
                        // is on (the visible romanization carries it alone).
                        if model.soundEnabled { speakSoon(exercise.target, delay: 0.5) }
                    case .recognition:
                        break
                    }
                }
            Spacer()
            optionsGrid(exercise)
            feedbackFooter(exercise)
        }
    }

    @ViewBuilder
    private func prompt(_ exercise: LessonExercise) -> some View {
        VStack(spacing: 14) {
            Text(promptQuestion(exercise.kind))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            switch exercise.kind {
            case .recognition:
                promptCard {
                    Text(exercise.target.letter)
                        .font(Theme.serif(76, weight: .bold))
                        .foregroundStyle(Theme.textHeading)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
            case .listening:
                promptCard {
                    Button {
                        model.speech.speak(exercise.target.spokenText)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                            .frame(width: 84, height: 84)
                            .background(Theme.accent, in: Circle())
                            .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 5)
                    }
                }
            case .reverse:
                promptCard {
                    VStack(spacing: 14) {
                        Text(exercise.target.trans)
                            .font(Theme.latinSerif(42, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Button {
                            model.speech.speak(exercise.target.spokenText)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 17))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 40, height: 40)
                                .background(Theme.accent.opacity(0.1), in: Circle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 34)
    }

    private func promptQuestion(_ kind: LessonExercise.Kind) -> String {
        switch kind {
        case .recognition: return "What sound does this letter make?"
        case .listening: return "Which letter do you hear?"
        case .reverse: return "Which letter makes this sound?"
        }
    }

    private func promptCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.divider))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }

    private func optionsGrid(_ exercise: LessonExercise) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            ForEach(exercise.options) { option in
                optionButton(option, in: exercise)
            }
        }
        .padding(.horizontal, 22)
    }

    private func optionButton(_ option: Akshara, in exercise: LessonExercise) -> some View {
        let showsGlyph = exercise.kind != .recognition
        return Button {
            choose(option, in: exercise)
        } label: {
            Text(showsGlyph ? option.letter : option.trans)
                .font(showsGlyph ? Theme.serif(30, weight: .semibold) : Theme.latinSerif(21, weight: .semibold))
                .foregroundStyle(optionForeground(option, in: exercise))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .background(optionBackground(option, in: exercise))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(optionBorder(option, in: exercise),
                                      lineWidth: optionIsHighlighted(option, in: exercise) ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(answer != nil)
        .animation(.easeOut(duration: 0.18), value: answer != nil)
    }

    private func optionIsHighlighted(_ option: Akshara, in exercise: LessonExercise) -> Bool {
        guard let answer else { return false }
        return option == exercise.target || (option == answer.chosen && !answer.correct)
    }

    private func optionForeground(_ option: Akshara, in exercise: LessonExercise) -> Color {
        guard let answer else { return Theme.textHeading }
        if option == exercise.target { return Theme.rateEasy }
        if option == answer.chosen && !answer.correct { return Theme.rateAgain }
        return Theme.textTertiary
    }

    private func optionBackground(_ option: Akshara, in exercise: LessonExercise) -> Color {
        guard let answer else { return Theme.card }
        if option == exercise.target { return Theme.rateEasy.opacity(0.12) }
        if option == answer.chosen && !answer.correct { return Theme.rateAgain.opacity(0.12) }
        return Theme.card.opacity(0.6)
    }

    private func optionBorder(_ option: Akshara, in exercise: LessonExercise) -> Color {
        guard let answer else { return Theme.cardBorder }
        if option == exercise.target { return Theme.rateEasy }
        if option == answer.chosen && !answer.correct { return Theme.rateAgain }
        return Theme.cardBorder
    }

    @ViewBuilder
    private func feedbackFooter(_ exercise: LessonExercise) -> some View {
        if let answer, !answer.correct {
            VStack(spacing: 10) {
                (Text("\(exercise.target.letter) ").font(Theme.serif(17, weight: .semibold))
                 + Text("· \(exercise.target.trans) — \(exercise.target.soundHint)")
                    .font(.system(size: 13.5)))
                    .foregroundStyle(Theme.textBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                Button {
                    advance()
                } label: {
                    Text("Continue")
                        .primaryButton()
                }
                .padding(.horizontal, 22)
            }
            .padding(.top, 14)
        } else {
            // Steady footer height so options don't jump on answers.
            Color.clear
                .frame(height: 96)
        }
    }

    // MARK: Summary

    @ViewBuilder
    private var summary: some View {
        switch mode {
        case .lesson(let unit):
            completionSummary(
                icon: "checkmark.seal.fill", tint: Theme.green,
                title: "Village complete!",
                subtitle: missed.isEmpty
                    ? "All \(practiced.count) letters, no misses — the river moves on."
                    : "\(practiced.count - missed.count) of \(practiced.count) letters clean — the tricky ones will come back around.",
                unit: unit)
        case .practice(let unit):
            completionSummary(
                icon: "bolt.circle.fill", tint: Theme.gold,
                title: "Letters strengthened",
                subtitle: missed.isEmpty
                    ? "\(practiced.count) letter\(practiced.count == 1 ? "" : "s") refreshed, no misses."
                    : "The missed ones are scheduled to come back sooner.",
                unit: unit)
        case .checkpoint(let section):
            checkpointSummary(section)
        }
    }

    private func completionSummary(icon: String, tint: Color, title: String, subtitle: String, unit: PathUnit) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(tint)
                .padding(.bottom, 6)
            Text(title)
                .font(Theme.serif(26, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text(subtitle)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            letterChips(practiced)
                .padding(.top, 16)
            if bestCombo >= 3 {
                Text("Best streak: \(bestCombo) in a row")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 6)
            }
            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .primaryButton()
            }
            .padding(.horizontal, 60)
            .padding(.top, 22)
        }
    }

    private func checkpointSummary(_ section: PathSection) -> some View {
        let templeName: String = {
            if let temple = LearnPath.templeStop(in: section),
               case .temple(_, let name, _) = temple.kind { return name }
            return "the checkpoint"
        }()
        let needed = Int((Double(steps.count) * 0.8).rounded(.up))
        return VStack(spacing: 10) {
            Image(systemName: checkpointPassed ? "flag.fill" : "flag")
                .font(.system(size: 52))
                .foregroundStyle(checkpointPassed ? Theme.accent : Theme.textTertiary)
                .padding(.bottom, 6)
            Text(checkpointPassed ? "Checkpoint passed!" : "Almost there")
                .font(Theme.serif(26, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text(checkpointPassed
                 ? "The pennant is raised — \(correctCount) of \(steps.count) right. The river flows on."
                 : "You got \(correctCount) of \(steps.count) right — \(needed) are needed to raise the pennant.")
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if !missed.isEmpty {
                Text(checkpointPassed ? "Saved for extra practice:" : "Worth another look:")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 12)
                letterChips(practiced.filter { missed.contains($0.letter) })
                Text(checkpointPassed
                     ? "You passed, so these are just marked for a quick refresh — tap a glowing ⚡ village on the map whenever you like."
                     : "Practice these first — tap the glowing ⚡ villages on the map — then come back and try \(templeName) again.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                    .padding(.top, 10)
            }
            if checkpointPassed {
                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .primaryButton()
                }
                .padding(.horizontal, 60)
                .padding(.top, 22)
            } else {
                Button {
                    restartCheckpoint()
                } label: {
                    Text("Try again")
                        .primaryButton()
                }
                .padding(.horizontal, 60)
                .padding(.top, 22)
                Button {
                    dismiss()
                } label: {
                    Text("Later")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
    }

    /// Tappable recap chips — hearing the letters once more on the way out.
    private func letterChips(_ letters: [Akshara]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                 count: min(4, max(1, letters.count))),
                  spacing: 8) {
            ForEach(letters) { akshara in
                Button {
                    model.speech.speak(akshara.spokenText)
                } label: {
                    VStack(spacing: 2) {
                        Text(akshara.letter)
                            .font(Theme.serif(24, weight: .semibold))
                            .foregroundStyle(Theme.textHeading)
                        Text(akshara.trans)
                            .font(Theme.latinSerif(11))
                            .foregroundStyle(Theme.phonetic)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.cardBorder))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 44)
    }
}

// MARK: - Session pieces

private enum LessonStep {
    case intro(Akshara)
    case exercise(LessonExercise)
}

private struct LessonExercise: Identifiable {
    enum Kind {
        case recognition  // see the glyph → pick the sound
        case listening    // hear it → pick the glyph
        case reverse      // see the romanization → pick the glyph
    }

    let id = UUID()
    let target: Akshara
    let kind: Kind
    let options: [Akshara]
}

private struct AnswerFeedback {
    let chosen: Akshara
    let correct: Bool
}

#Preview {
    LessonSessionView(mode: .lesson(LearnPath.units(in: LearnPath.sections[0]).first!))
        .environment(AppModel())
}
