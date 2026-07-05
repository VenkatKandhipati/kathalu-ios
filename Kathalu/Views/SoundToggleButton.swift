import SwiftUI

/// Speaker button bound to the app-wide "pronounce on tap" setting — the same
/// toggle as the reader's Aa menu, surfaced wherever the app speaks Telugu.
struct SoundToggleButton: View {
    @Environment(AppModel.self) private var model

    /// Draws a circular tinted backdrop (for placement outside toolbars).
    var prominent = false

    var body: some View {
        Button {
            model.soundEnabled.toggle()
        } label: {
            Image(systemName: model.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: prominent ? 16 : 15))
                .foregroundStyle(model.soundEnabled ? Theme.accent : Theme.textTertiary)
                .frame(width: prominent ? 42 : 32, height: prominent ? 42 : 32)
                .background(prominent ? Theme.accent.opacity(model.soundEnabled ? 0.1 : 0.05) : .clear,
                            in: Circle())
        }
        .accessibilityLabel(model.soundEnabled ? "Turn pronunciation off" : "Turn pronunciation on")
    }
}
