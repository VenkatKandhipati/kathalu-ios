import SwiftUI

/// Two-page first launch, matching the design's "First launch" section.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var showAuth = false

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()
            TabView(selection: $page) {
                welcomePage.tag(0)
                tapToReadPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                pageDots.padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthSheetView(startMode: .signIn) {
                model.hasSeenOnboarding = true
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.accent : Theme.gold.opacity(0.45))
                    .frame(width: i == page ? 20 : 7, height: 7)
            }
        }
        .animation(.snappy, value: page)
    }

    // MARK: Page 1 — Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()
            BookshelfMotif()
                .padding(.bottom, 46)
            Text("కథలు")
                .font(Theme.serif(58, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text("K A T H A L U")
                .font(.system(size: 13, weight: .semibold))
                .tracking(6)
                .foregroundStyle(Theme.accent)
                .padding(.top, 8)
            Text("Telugu stories, one page and one word at a time.")
                .font(Theme.serif(17))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
                .padding(.top, 24)
            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation { page = 1 }
                } label: {
                    Text("Start reading")
                        .primaryButton()
                }
                Button("I already have an account") {
                    showAuth = true
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }

    // MARK: Page 2 — Tap to read

    private var tapToReadPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HOW IT WORKS")
                .font(.system(size: 12.5, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 14)
            Text("Stuck on a word? Tap it.")
                .font(Theme.serif(27, weight: .bold))
                .foregroundStyle(Theme.textHeading)
                .padding(.bottom, 10)
            Text("The pronunciation appears above it. Tap once more for the meaning — no dictionary, no leaving the page.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 34)

            sampleSentenceCard

            HStack(spacing: 9) {
                stepChip(title: "Tap ①", subtitle: "sound", color: Theme.accent)
                stepChip(title: "Tap ②", subtitle: "meaning", color: Theme.meaning)
                stepChip(title: "Saved", subtitle: "to review", color: Theme.phonetic)
            }
            .padding(.top, 26)

            Spacer()

            Button {
                model.hasSeenOnboarding = true
            } label: {
                Text("Continue")
                    .primaryButton()
            }
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
    }

    private var sampleSentenceCard: some View {
        VStack {
            // Static rendition of "సుందరవనంలో ఓ నక్క ఉండేది." with నక్క revealed.
            HStack(alignment: .bottom, spacing: 6) {
                Text("సుందరవనంలో ఓ")
                    .font(Theme.serif(23))
                    .foregroundStyle(Theme.textBody)
                VStack(spacing: 2) {
                    Text("nakka · fox")
                        .font(Theme.latinSerif(12))
                        .foregroundStyle(Theme.phonetic)
                    Text("నక్క")
                        .font(Theme.serif(23))
                        .foregroundStyle(Theme.accent)
                }
                Text("ఉండేది.")
                    .font(Theme.serif(23))
                    .foregroundStyle(Theme.textBody)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.divider))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
    }

    private func stepChip(title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

/// The five-spine bookshelf mark from the welcome screen.
struct BookshelfMotif: View {
    private let heights: [CGFloat] = [88, 108, 96, 116, 100]

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(heights.indices, id: \.self) { i in
                UnevenRoundedRectangle(
                    topLeadingRadius: 3, bottomLeadingRadius: 3,
                    bottomTrailingRadius: 5, topTrailingRadius: 5)
                    .fill(Theme.spineGradient(for: i))
                    .frame(width: 26, height: heights[i])
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 3)
            }
        }
        .frame(height: 118, alignment: .bottom)
    }
}

extension Text {
    /// Filled accent CTA button style used across onboarding and sheets.
    func primaryButton() -> some View {
        self.font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.accent.opacity(0.45), radius: 11, y: 6)
    }
}

#Preview {
    OnboardingView()
        .environment(AppModel())
}
