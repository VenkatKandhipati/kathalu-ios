import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.hasSeenOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        #if DEBUG
        // Debug hook: `simctl launch … -ttsStress 1` speaks continuously so
        // AVSpeechSynthesizer memory behavior can be profiled hands-free.
        .task {
            guard UserDefaults.standard.bool(forKey: "ttsStress") else { return }
            let letters = AksharaData.consonants.map(\.letter)
            for i in 0..<10_000 {
                model.speech.speak(letters[i % letters.count])
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
        #endif
    }
}

/// The app's tabs: Library · Learn · Review · Progress · Profile.
struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab = initialTab

    /// Debug hook: `simctl launch … -openTab review` selects a tab at launch.
    private static var initialTab: String {
        #if DEBUG
        UserDefaults.standard.string(forKey: "openTab") ?? "library"
        #else
        "library"
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag("library")

            LearnView()
                .tabItem { Label("Learn", systemImage: "character.book.closed") }
                .badge(model.aksharaDueTotal > 0 ? model.aksharaDueTotal : 0)
                .tag("learn")

            ReviewView()
                .tabItem { Label("Review", systemImage: "rectangle.on.rectangle") }
                .badge(model.dueCount > 0 ? model.dueCount : 0)
                .tag("review")

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
                .tag("progress")

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag("profile")
        }
    }
}

#Preview {
    RootView()
        .environment(AppModel())
}
