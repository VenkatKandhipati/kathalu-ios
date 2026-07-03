import SwiftUI

@main
struct KathaluApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
                .preferredColorScheme(model.appearance.colorScheme)
        }
    }
}
