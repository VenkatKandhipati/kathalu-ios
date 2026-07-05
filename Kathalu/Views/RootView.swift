import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasSeenOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
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
