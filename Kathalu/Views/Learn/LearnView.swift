import SwiftUI

/// Learn tab (phase 1 of the Aksharamala feature): tap-to-hear reference
/// charts for the vowels (అచ్చులు) and consonants (హల్లులు).
struct LearnView: View {
    @Environment(AppModel.self) private var model

    /// The three Learn modes: the guided river path, the reference charts, and
    /// handwriting practice. (SM-2 drills live in the Review tab.)
    enum LearnMode: String, CaseIterable {
        case journey, charts, write
    }

    /// Trace-over writing practice decks (base glyphs only for now).
    enum WritingSession: String, Identifiable {
        case vowels, consonants
        var id: String { rawValue }
        var aksharas: [Akshara] {
            self == .vowels ? AksharaData.vowels.aksharas : AksharaData.consonants
        }
        var telugu: String { self == .vowels ? "అచ్చులు" : "హల్లులు" }
        var titleEn: String { self == .vowels ? "Vowels" : "Consonants" }
        var sessionTitle: String { "\(telugu) · Write" }
        var worksheetTitle: String { "\(telugu) · Worksheet" }
    }

    @State private var selected: AksharaSelection?
    @State private var showingDetail = false
    @State private var writing: WritingSession?
    @State private var worksheet: WritingSession?
    @State private var learnMode: LearnMode = .journey

    // Reference charts start collapsed so Practice stays front and center.
    @State private var vowelsExpanded = false
    @State private var consonantsExpanded = false
    @State private var guninthaluExpanded = false
    @State private var vatthuluExpanded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    Picker("Learn mode", selection: $learnMode) {
                        Text("Journey").tag(LearnMode.journey)
                        Text("Charts").tag(LearnMode.charts)
                        Text("Write").tag(LearnMode.write)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .readableColumn()

                switch learnMode {
                case .journey:
                    JourneyView()
                case .charts:
                    chartsContent
                case .write:
                    writeContent
                }
            }
            .background(Theme.background)
            .fullScreenCover(item: $writing) { session in
                WritingPracticeView(title: session.sessionTitle, aksharas: session.aksharas)
            }
            .fullScreenCover(item: $worksheet) { session in
                WorksheetView(title: session.worksheetTitle, aksharas: session.aksharas)
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

    private var chartsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                    Label(model.soundEnabled
                          ? "Tap any letter to hear it"
                          : "Sound is off — letters won't be spoken",
                          systemImage: model.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.bottom, 24)

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

                    #if DEBUG
                    // Journey-tab design spike — see Prototypes/RiverPrototypeGallery.
                    NavigationLink {
                        RiverPrototypeGallery()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "water.waves")
                            Text("River journey prototypes")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    #endif
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            .readableColumn()
        }
    }

    private var writeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label("Trace letters with your finger or Apple Pencil",
                      systemImage: "hand.draw")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 24)

                sectionHeader("TRACE & CHECK", telugu: "సాధన")
                VStack(spacing: 10) {
                    writingRow(.vowels)
                    writingRow(.consonants)
                }
                .padding(.bottom, 30)

                sectionHeader("WORKSHEET", telugu: "అభ్యాస పత్రం")
                VStack(spacing: 10) {
                    worksheetRow(.vowels)
                    worksheetRow(.consonants)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            .readableColumn()
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

    private func writingRow(_ session: WritingSession) -> some View {
        Button {
            writing = session
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(session.telugu)
                            .font(Theme.sans(16, weight: .semibold))
                            .foregroundStyle(Theme.textHeading)
                        Text(session.titleEn)
                            .font(Theme.latinSerif(13))
                            .italic()
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("Trace \(session.aksharas.count) letters with your finger or Pencil")
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
        .buttonStyle(.plain)
    }

    private func worksheetRow(_ session: WritingSession) -> some View {
        Button {
            worksheet = session
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(session.telugu)
                            .font(Theme.sans(16, weight: .semibold))
                            .foregroundStyle(Theme.textHeading)
                        Text(session.titleEn)
                            .font(Theme.latinSerif(13))
                            .italic()
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("Trace a few at a time, flip the page")
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
