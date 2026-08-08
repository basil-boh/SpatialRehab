import AVFoundation
import Observation

/// Warm spoken prompts — many dementia patients won't read floating text,
/// but a calm voice is how a caregiver would actually guide them.
@Observable
@MainActor
final class VoiceGuide {
    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        guard isEnabled else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-SG")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func toggle() {
        isEnabled.toggle()
        if !isEnabled {
            stop()
        }
    }
}
