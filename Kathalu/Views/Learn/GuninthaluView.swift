import SwiftUI

/// Guninthalu explorer (phase 3 of Aksharamala): pick any consonant and see
/// its full 16-form guninthamu chart, tap-to-hear — the classroom "క గుణింతం"
/// recitation as a screen.
struct GuninthaluView: View {
    @Environment(AppModel.self) private var model

    @State private var consonant: Akshara = AksharaData.consonants[0]  // క
    @State private var selectedSign: VowelSign?
    @State private var showingDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 6)
                Text("Every consonant combines with the same 16 vowel signs. Pick a consonant, then tap any form to hear it.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)

                sectionLabel("CONSONANT")
                consonantPicker
                    .padding(.horizontal, -22)  // full-bleed strip; inset inside
                    .padding(.bottom, 24)

                HStack(spacing: 8) {
                    Text("\(consonant.letter) గుణింతం")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.textHeading)
                    Text("\(consonant.trans) forms")
                        .font(Theme.latinSerif(12.5))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.bottom, 12)
                formGrid
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Guninthalu")
        .navigationBarTitleDisplayMode(.inline)
        // Same stable-identity pattern as LearnView: a boolean presentation
        // keeps the compact detent while hopping between forms.
        .sheet(isPresented: $showingDetail, onDismiss: { selectedSign = nil }) {
            if let selectedSign {
                GuninthaDetailSheet(sign: selectedSign, consonant: consonant)
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(320)))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Guninthalu")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text("గుణింతాలు")
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.7)
            .foregroundStyle(Theme.textTertiary)
            .padding(.bottom, 10)
    }

    private var consonantPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AksharaData.consonants) { c in
                    Button {
                        withAnimation(.snappy) { consonant = c }
                    } label: {
                        Text(c.letter)
                            .font(Theme.sans(18, weight: .semibold))
                            .foregroundStyle(consonant == c ? .white : Theme.textHeading)
                            .minimumScaleFactor(0.6)
                            .frame(width: 46, height: 46)
                            .background(consonant == c ? Theme.accent : Theme.card)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(
                                consonant == c ? .clear : Theme.cardBorder))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 2)
        }
    }

    private var formGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4),
            spacing: 9
        ) {
            ForEach(AksharaData.vowelSigns) { sign in
                Button {
                    selectedSign = sign
                    showingDetail = true
                    model.speech.speak(sign.apply(to: consonant))
                } label: {
                    AksharaTile(
                        akshara: Akshara(
                            letter: sign.apply(to: consonant),
                            trans: sign.trans(for: consonant),
                            soundHint: ""),
                        isSelected: selectedSign == sign)
                }
                .buttonStyle(AksharaTileButtonStyle())
            }
        }
    }
}

/// Drawer for one guninthamu form: the form, its formation breakdown,
/// the sign's traditional name, and the vowel sound it carries.
struct GuninthaDetailSheet: View {
    @Environment(AppModel.self) private var model

    let sign: VowelSign
    let consonant: Akshara

    private var form: String { sign.apply(to: consonant) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(form)
                        .font(Theme.serif(52, weight: .bold))
                        .foregroundStyle(Theme.textHeading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(sign.trans(for: consonant))
                        .font(Theme.latinSerif(18))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Button {
                    model.speech.speak(form)
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

            Text("FORMATION")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 6)

            if sign.sign.isEmpty {
                Text("\(consonant.letter) — the base form, no sign added")
                    .font(Theme.serif(20))
                    .foregroundStyle(Theme.textBody)
            } else {
                Text("\(consonant.letter) + \(sign.sign) = \(form)")
                    .font(Theme.serif(20))
                    .foregroundStyle(Theme.textBody)
            }

            Text("\(sign.name) — carries the \(sign.vowel) sound")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)

            if let vowel = AksharaData.vowel(for: sign) {
                Text(vowel.soundHint)
                    .font(Theme.latinSerif(12.5))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
    }
}

#Preview {
    NavigationStack {
        GuninthaluView()
    }
    .environment(AppModel())
}
