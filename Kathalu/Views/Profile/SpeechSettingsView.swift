import SwiftUI
import AVFoundation

/// Voice & speed settings for word pronunciation (roadmap feature #5).
/// Pushed from Profile → Reading, and openable from the reader's Aa menu.
struct SpeechSettingsView: View {
    @Environment(AppModel.self) private var model

    /// Snapshotted once — voice installation only changes outside the app.
    private let voices = SpeechService.teluguVoices
    private let sample = "నమస్కారం! కథలు చదువుదాం."

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Toggle(isOn: $model.soundEnabled) {
                    settingLabel("Pronounce words on tap", systemImage: "speaker.wave.2")
                }
                Button {
                    model.speech.speak(sample)
                } label: {
                    settingLabel("Play a sample", systemImage: "play.circle")
                }
            } footer: {
                Text("“నమస్కారం! కథలు చదువుదాం.” — Hello! Let's read stories.")
            }
            .listRowBackground(Theme.card)

            Section("Speed") {
                HStack(spacing: 12) {
                    Image(systemName: "tortoise")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                    Slider(value: $model.speechRate, in: 0.2...0.65) { editing in
                        if !editing { model.speech.speak(sample) }
                    }
                    .tint(Theme.accent)
                    Image(systemName: "hare")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                }
                if abs(model.speechRate - SpeechService.defaultRate) > 0.001 {
                    Button("Reset to default speed") {
                        model.speechRate = SpeechService.defaultRate
                        model.speech.speak(sample)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                }
            }
            .listRowBackground(Theme.card)

            Section {
                voiceRow(id: nil, name: "System default", quality: nil)
                ForEach(voices, id: \.identifier) { voice in
                    voiceRow(id: voice.identifier, name: voice.name, quality: qualityLabel(voice.quality))
                }
            } header: {
                Text("Voice")
            } footer: {
                Text(voices.count <= 1
                     ? "For a more natural voice, open the iOS Settings app → Accessibility → Spoken Content → Voices → Telugu and download an Enhanced or Premium voice. It will appear here."
                     : "Higher-quality voices sound more natural. More can be downloaded in the iOS Settings app → Accessibility → Spoken Content → Voices → Telugu.")
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Voice & speed")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A selectable voice; tapping it also speaks the sample as a preview.
    private func voiceRow(id: String?, name: String, quality: String?) -> some View {
        Button {
            model.speechVoiceID = id
            model.speech.speak(sample)
        } label: {
            HStack(spacing: 10) {
                Text(name)
                    .foregroundStyle(Theme.textBody)
                if let quality {
                    Text(quality)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                if model.speechVoiceID == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String? {
        switch quality {
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        default: return nil
        }
    }

    private func settingLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(title)
                .foregroundStyle(Theme.textBody)
        }
    }
}

#Preview {
    NavigationStack {
        SpeechSettingsView()
    }
    .environment(AppModel())
}
