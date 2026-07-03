import SwiftUI

/// Progress tab: hero proficiency ring, three stat tiles, most-looked-up words.
struct ProgressDashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Theme.textHeading)
                        Text("మీ ప్రగతి")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.bottom, 24)

                    heroRing
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 26)

                    HStack(spacing: 11) {
                        statTile(value: "\(model.data.streak)", label: "day streak", color: Theme.accent)
                        statTile(value: "\(model.storiesRead)", label: "stories read", color: Theme.textHeading)
                        statTile(value: "\(model.wordsKnown)", label: "words known", color: Theme.textHeading)
                    }
                    .padding(.bottom, 26)

                    if !model.mostLookedUp.isEmpty {
                        Text("MOST LOOKED-UP")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.7)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.bottom, 6)
                        ForEach(Array(model.mostLookedUp.enumerated()), id: \.element.word) { i, entry in
                            wordRow(entry, divider: i < model.mostLookedUp.count - 1)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
        }
    }

    private var heroRing: some View {
        let pct = model.overallProficiency
        return ZStack {
            Circle()
                .stroke(Theme.divider, lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(pct) / 100)
                .stroke(Theme.ringColor(pct: pct), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(pct)%")
                    .font(Theme.latinSerif(38, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                Text("read without help")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 168, height: 168)
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.latinSerif(24, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder))
    }

    private func wordRow(_ entry: (word: String, trans: String, count: Int), divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(entry.word)
                    .font(Theme.serif(17))
                    .foregroundStyle(Theme.textBody)
                Text(entry.trans)
                    .font(Theme.latinSerif(12))
                    .foregroundStyle(Theme.phonetic)
                    .padding(.leading, 4)
                Spacer()
                Text("×\(entry.count)")
                    .font(Theme.latinSerif(12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 10)
            if divider {
                Divider().overlay(Theme.cardBorder)
            }
        }
    }
}

#Preview {
    ProgressDashboardView()
        .environment(AppModel())
}
