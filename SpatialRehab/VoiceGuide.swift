import AVFoundation
import Observation

/// Warm spoken prompts — many dementia patients won't read floating text,
/// but a calm voice is how a caregiver would actually guide them.
@Observable
@MainActor
final class VoiceGuide {
    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    /// Queues by default so sentences finish naturally; pass
    /// `interrupting: true` only when the new line must land immediately.
    func speak(_ text: String, interrupting: Bool = false) {
        guard isEnabled else { return }
        if interrupting {
            synthesizer.stopSpeaking(at: .word)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-SG")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.02
        utterance.preUtteranceDelay = 0.15
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
