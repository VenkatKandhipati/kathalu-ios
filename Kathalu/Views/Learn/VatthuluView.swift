import SwiftUI

/// Vatthulu reference (phase 4 of Aksharamala): every consonant's subscript
/// form, shown as its doubled cluster (క్క) the way textbooks introduce them,
/// grouped by varga with tap-to-hear and real example words.
struct VatthuluView: View {
    @Environment(AppModel.self) private var model

    @State private var selected: Vatthu?
    @State private var showingDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 6)
                Text("When two consonants meet with no vowel between them, the second shrinks into a vatthu — a small mark under the first (a few sit beside it). అక్క is అ + క + క వత్తు. Tap any form to hear it.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)

                ForEach(AksharaData.consonantGroups) { group in
                    vargaHeader(group)
                    vatthuGrid(for: group)
                        .padding(.bottom, 22)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Vatthulu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SoundToggleButton()
            }
        }
        // Same stable-identity pattern as LearnView: a boolean presentation
        // keeps the compact detent while hopping between forms.
        .sheet(isPresented: $showingDetail, onDismiss: { selected = nil }) {
            if let selected {
                VatthuDetailSheet(vatthu: selected)
                    .presentationDetents([.height(380)])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(380)))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Vatthulu")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text("వత్తులు")
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func vargaHeader(_ group: AksharaGroup) -> some View {
        HStack(spacing: 7) {
            Text(group.telugu)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.textHeading)
            Text(group.name)
                .font(Theme.latinSerif(12.5))
                .italic()
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 10)
    }

    private func vatthuGrid(for group: AksharaGroup) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4),
            spacing: 9
        ) {
            ForEach(vatthulu(in: group)) { vatthu in
                Button {
                    selected = vatthu
                    showingDetail = true
                    if model.soundEnabled { model.speech.speak(vatthu.doubled) }
                } label: {
                    AksharaTile(
                        akshara: Akshara(
                            letter: vatthu.doubled,
                            trans: vatthu.doubledTrans,
                            soundHint: ""),
                        isSelected: selected == vatthu)
                }
                .buttonStyle(AksharaTileButtonStyle())
            }
        }
    }

    private func vatthulu(in group: AksharaGroup) -> [Vatthu] {
        let letters = Set(group.aksharas.map(\.letter))
        return AksharaData.vatthulu.filter { letters.contains($0.letter) }
    }
}

/// Drawer for one vatthu: doubled form, formation breakdown, shape/usage
/// note, and tappable example words that speak on touch.
struct VatthuDetailSheet: View {
    @Environment(AppModel.self) private var model

    let vatthu: Vatthu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vatthu.doubled)
                        .font(Theme.serif(52, weight: .bold))
                        .foregroundStyle(Theme.textHeading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(vatthu.doubledTrans)
                        .font(Theme.latinSerif(18))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Button {
                    model.speech.speak(vatthu.doubled)
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
                .padding(.vertical, 16)

            Text("FORMATION")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 6)

            Text("\(vatthu.letter) + \u{0C4D}\(vatthu.letter) = \(vatthu.doubled)")
                .font(Theme.serif(20))
                .foregroundStyle(Theme.textBody)

            Text("\(vatthu.name) — the subscript form of \(vatthu.letter)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)

            if let note = vatthu.note {
                Text(note)
                    .font(Theme.latinSerif(12.5))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if vatthu.rare {
                Text("Rare in modern Telugu — not part of the practice deck.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 14)
            } else {
                Text("IN WORDS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                ForEach(vatthu.usages, id: \.self) { usage in
                    Button {
                        model.speech.speak(usage.word)
                    } label: {
                        HStack(spacing: 8) {
                            Text(usage.word)
                                .font(Theme.serif(17, weight: .semibold))
                                .foregroundStyle(Theme.textHeading)
                            Text(usage.wordTrans)
                                .font(Theme.latinSerif(12.5))
                                .italic()
                                .foregroundStyle(Theme.phonetic)
                            Spacer()
                            Text(usage.meaning)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
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
        VatthuluView()
    }
    .environment(AppModel())
}
