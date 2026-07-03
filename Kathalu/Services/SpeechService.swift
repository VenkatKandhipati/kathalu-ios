import AVFoundation

/// Speaks Telugu words aloud — the "Tap ① sound" of the design's onboarding.
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: "te-IN") {
            utterance.voice = voice
        }
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }
}
