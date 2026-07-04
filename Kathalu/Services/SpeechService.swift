import AVFoundation

/// Speaks Telugu words aloud — the "Tap ① sound" of the design's onboarding.
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

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
        // Prefer a Telugu voice; fall back to the system default if none is
        // installed so tapping a word still produces sound.
        utterance.voice = AVSpeechSynthesisVoice(language: "te-IN")
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }
}
