import SwiftUI

/// Learn tab (phase 1 of the Aksharamala feature): tap-to-hear reference
/// charts for the vowels (అచ్చులు) and consonants (హల్లులు).
struct LearnView: View {
    @Environment(AppModel.self) private var model
    /// The quiz decks launchable from the Practice section.
    enum PracticeSession: String, Identifiable {
        case vowels, consonants, guninthalu, vatthulu
        var id: String { rawValue }
    }

    @State private var selected: AksharaSelection?
    @State private var showingDetail = false
    @State private var practice: PracticeSession?

    // Reference charts start collapsed so Practice stays front and center.
    @State private var vowelsExpanded = false
    @State private var consonantsExpanded = false
    @State private var guninthaluExpanded = false
    @State private var vatthuluExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 6)
                    Label(model.soundEnabled
                          ? "Tap any letter to hear it"
                          : "Sound is off — letters won't be spoken",
                          systemImage: model.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.bottom, 24)

                    sectionHeader("PRACTICE", telugu: "సాధన")
                    VStack(spacing: 10) {
                        deckButton(.vowels)
                        deckButton(.consonants)
                        guninthaButton
                        vatthuButton
                    }
                    .padding(.bottom, 30)

                    collapsibleHeader("VOWELS", telugu: AksharaData.vowels.telugu, isExpanded: $vowelsExpanded)
                    if vowelsExpanded {
                        aksharaGrid(AksharaData.vowels)
                            .padding(.bottom, 14)
                    }

                    collapsibleHeader("CONSONANTS", telugu: "హల్లులు", isExpanded: $consonantsExpanded)
                    if consonantsExpanded {
                        ForEach(AksharaData.consonantGroups) { group in
                            vargaHeader(group)
                            aksharaGrid(group)
                                .padding(.bottom, 22)
                        }
                    }

                    collapsibleHeader("GUNINTHALU", telugu: "గుణింతాలు", isExpanded: $guninthaluExpanded)
                    if guninthaluExpanded {
                        NavigationLink {
                            GuninthaluView()
                        } label: {
                            chartRow(sample: "క · కా · కి · కీ · కు …",
                                     subtitle: "Every consonant × 16 vowel signs")
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 14)
                    }

                    collapsibleHeader("VATTHULU", telugu: "వత్తులు", isExpanded: $vatthuluExpanded)
                    if vatthuluExpanded {
                        NavigationLink {
                            VatthuluView()
                        } label: {
                            chartRow(sample: "క్క · స్త · ల్ల · ద్ద …",
                                     subtitle: "The subscript forms consonants take in clusters")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .fullScreenCover(item: $practice) { session in
                switch session {
                case .vowels: AksharaReviewView(deck: .vowels)
                case .consonants: AksharaReviewView(deck: .consonants)
                case .guninthalu: GuninthaluReviewView()
                case .vatthulu: VatthuluReviewView()
                }
            }
            .onAppear {
                #if DEBUG
                // Debug hook: `simctl launch … -openDeck vowels` starts a session.
                if let raw = UserDefaults.standard.string(forKey: "openDeck"),
                   let session = PracticeSession(rawValue: raw) {
                    UserDefaults.standard.removeObject(forKey: "openDeck")
                    practice = session
                }
                #endif
            }
            // Presented with a boolean (not `item:`) so switching letters
            // updates the sheet in place instead of re-presenting it — an
            // item change resets the detent and the sheet pops to full height.
            .sheet(isPresented: $showingDetail, onDismiss: { selected = nil }) {
                if let selected {
                    AksharaDetailSheet(selection: selected)
                        .presentationDetents([.height(300)])
                        .presentationDragIndicator(.visible)
                        // Keep the chart tappable underneath so learners can
                        // browse letter to letter without dismissing the sheet.
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(300)))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Learn")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                Text("అక్షరాలు")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            SoundToggleButton(prominent: true)
                .padding(.top, 8)
        }
    }

    private func sectionHeader(_ title: String, telugu: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.7)
            Text(telugu)
                .font(Theme.sans(12))
        }
        .foregroundStyle(Theme.textTertiary)
        .padding(.bottom, 12)
    }

    /// Section header that folds its chart away; charts start collapsed.
    private func collapsibleHeader(_ title: String, telugu: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.7)
                Text(telugu)
                    .font(Theme.sans(12))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
            }
            .foregroundStyle(Theme.textTertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.bottom, 4)
    }

    private func vargaHeader(_ group: AksharaGroup) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 7) {
                Text(group.telugu)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.textHeading)
                Text(group.name)
                    .font(Theme.latinSerif(12.5))
                    .italic()
                    .foregroundStyle(Theme.textSecondary)
            }
            if let note = group.note {
                Text(note)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.bottom, 10)
    }

    private func deckButton(_ deck: AksharaDeck) -> some View {
        let total = deck.aksharas.count
        let learned = model.aksharaLearnedCount(for: deck)
        return Button {
            practice = PracticeSession(rawValue: deck.rawValue)
        } label: {
            DeckRow(
                telugu: deck.telugu,
                name: deck.titleEn,
                subtitle: learned > 0 ? "\(learned) of \(total) letters learned" : "\(total) letters",
                due: model.aksharaDueCount(for: deck),
                newCount: model.aksharaNewCount(for: deck),
                progressPct: learned * 100 / total)
        }
        .buttonStyle(.plain)
    }

    private var guninthaButton: some View {
        let total = AksharaData.vowelSigns.count
        let learned = model.guninthaLearnedCount
        return Button {
            practice = .guninthalu
        } label: {
            DeckRow(
                telugu: "గుణింతాలు",
                name: "Vowel signs",
                subtitle: learned > 0 ? "\(learned) of \(total) signs learned" : "\(total) signs",
                due: model.guninthaDueCount,
                newCount: model.guninthaNewCount,
                progressPct: learned * 100 / total)
        }
        .buttonStyle(.plain)
    }

    private var vatthuButton: some View {
        let total = AksharaData.quizVatthulu.count
        let learned = model.vatthuLearnedCount
        return Button {
            practice = .vatthulu
        } label: {
            DeckRow(
                telugu: "వత్తులు",
                name: "Conjunct signs",
                subtitle: learned > 0 ? "\(learned) of \(total) vatthulu learned" : "\(total) vatthulu",
                due: model.vatthuDueCount,
                newCount: model.vatthuNewCount,
                progressPct: learned * 100 / total)
        }
        .buttonStyle(.plain)
    }

    /// Row linking a reference explorer (guninthalu, vatthulu) from its section.
    private func chartRow(sample: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sample)
                    .font(Theme.serif(17, weight: .semibold))
                    .foregroundStyle(Theme.textHeading)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder))
    }

    private func aksharaGrid(_ group: AksharaGroup) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4),
            spacing: 9
        ) {
            ForEach(group.aksharas) { akshara in
                Button {
                    selected = AksharaSelection(akshara: akshara, group: group)
                    showingDetail = true
                    if model.soundEnabled { model.speech.speak(akshara.spokenText) }
                } label: {
                    AksharaTile(
                        akshara: akshara,
                        isSelected: selected?.akshara == akshara)
                }
                .buttonStyle(AksharaTileButtonStyle())
            }
        }
    }
}

/// One tappable practice deck: name, learning progress, due count.
struct DeckRow: View {
    let telugu: String
    let name: String
    let subtitle: String
    let due: Int
    let newCount: Int
    let progressPct: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(telugu)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.textHeading)
                    Text(name)
                        .font(Theme.latinSerif(13))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if due > 0 {
                pill("\(due) due", color: Theme.accent)
            }
            if newCount > 0 {
                pill("\(newCount) new", color: Theme.phonetic)
            }
            if due == 0 && newCount == 0 && progressPct > 0 {
                ProficiencyRing(pct: progressPct, size: 22, lineWidth: 3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder))
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

/// Sheet payload: the tapped letter plus its group for context.
struct AksharaSelection: Identifiable {
    let akshara: Akshara
    let group: AksharaGroup
    var id: String { akshara.id }
}

struct AksharaTile: View {
    let akshara: Akshara
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(akshara.letter)
                .font(Theme.serif(27, weight: .semibold))
                .foregroundStyle(Theme.textHeading)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(akshara.trans)
                .font(Theme.latinSerif(11))
                .foregroundStyle(Theme.phonetic)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(isSelected ? Theme.accent.opacity(0.1) : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Theme.accent : Theme.cardBorder,
                              lineWidth: isSelected ? 1.5 : 1))
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// Presses shrink the tile slightly, echoing the bookshelf interaction.
struct AksharaTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Bottom sheet for a tapped akshara: big glyph, romanization, sound hint,
/// and a replay button — the Learn-tab sibling of WordSheetView.
struct AksharaDetailSheet: View {
    @Environment(AppModel.self) private var model

    let selection: AksharaSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selection.akshara.letter)
                        .font(Theme.serif(52, weight: .bold))
                        .foregroundStyle(Theme.textHeading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(selection.akshara.trans)
                        .font(Theme.latinSerif(18))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Button {
                    model.speech.speak(selection.akshara.spokenText)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 46, height: 46)
                        .background(Theme.accent.opacity(0.1), in: Circle())
                }
            }
            .padding(.top, 28)

            Divider()
                .overlay(Theme.divider)
                .padding(.vertical, 18)

            Text("SOUND")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 6)

            Text(selection.akshara.soundHint)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(selection.group.telugu) · \(selection.group.name)")
                .font(Theme.latinSerif(12.5))
                .italic()
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
    }
}

#Preview {
    LearnView()
        .environment(AppModel())
}
