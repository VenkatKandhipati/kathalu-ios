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
    @Environment(\.scenePhase) private var scenePhase
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
        // iOS 18 `Tab` API (not the bridged `.tabItem` form): the old API's
        // iPad bridge mis-resizes tab content on rotation, leaving part of the
        // screen black until relaunch.
        TabView(selection: $selectedTab) {
            Tab("Read", systemImage: "books.vertical", value: "library") {
                LibraryView()
            }

            Tab("Learn", systemImage: "character.book.closed", value: "learn") {
                LearnView()
            }

            // Review is the single "due today" inbox — story vocab + script.
            Tab("Review", systemImage: "rectangle.on.rectangle", value: "review") {
                ReviewView()
            }
            .badge(reviewDue > 0 ? reviewDue : 0)

            Tab("Profile", systemImage: "person.circle", value: "profile") {
                ProfileView()
            }
        }
        // Widget / Live Activity entry: kathalu://story/<idx>, kathalu://review,
        // kathalu://letter/<letter>.
        .onOpenURL { url in
            if let tab = model.handleDeepLink(url) { selectedTab = tab }
        }
        // A tapped daily reminder opens that day's story (same deep link).
        .onAppear {
            NotificationService.shared.onOpen = { url in
                if let tab = model.handleDeepLink(url) { selectedTab = tab }
            }
        }
        .alert("Want a daily reminder?", isPresented: Binding(
            get: { model.showReminderOffer },
            set: { model.showReminderOffer = $0 })
        ) {
            Button("Remind me") { Task { await model.enableReminders() } }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Each evening at \(AppModel.timeLabel(model.reminderMinute)), a word from that day's story. Skipped on days you've already read. You can change this in Profile.")
        }
        // Fill in missing flashcard meanings each time the app comes back.
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                model.applyWidgetGrades()
                model.rescheduleReminders()
                Task { await model.backfillMeanings() }
            } else if scenePhase == .background {
                // Leave the widgets current before the app is suspended.
                model.refreshWidgets()
            }
        }
    }

    /// Everything due for review today: story vocabulary plus script letters.
    private var reviewDue: Int { model.dueCount + model.aksharaDueTotal }
}

#Preview {
    RootView()
        .environment(AppModel())
}
