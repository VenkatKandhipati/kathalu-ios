import AVFoundation

/// Speaks Telugu words aloud — the "Tap ① sound" of the design's onboarding.
final class SpeechService {
    static let defaultRate: Double = 0.42

    private let synthesizer = AVSpeechSynthesizer()

    /// Identifier of the user's preferred voice; nil follows the system's
    /// Telugu default. Kept in sync with AppModel's persisted setting.
    var voiceIdentifier: String?
    var rate: Float = Float(SpeechService.defaultRate)

    init() {
        // `.playback` lets pronunciation play even when the ringer is on silent
        // (like a music or video app); `.duckOthers` lowers any background audio
        // while a word is spoken. `.spokenAudio` tunes routing for speech.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: [.duckOthers])
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        synthesizer.speak(utterance)
    }

    /// The chosen voice when it's still installed, else the system's Telugu
    /// default, else nil (system default voice) so tapping still makes sound.
    private var voice: AVSpeechSynthesisVoice? {
        if let voiceIdentifier, let chosen = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return chosen
        }
        return AVSpeechSynthesisVoice(language: "te-IN")
    }

    /// Installed voices that speak Telugu, best quality first. More voices
    /// appear here after downloading them in iOS Settings → Accessibility →
    /// Spoken Content → Voices → Telugu.
    static var teluguVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("te") }
            .sorted {
                ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name)
            }
    }
}
