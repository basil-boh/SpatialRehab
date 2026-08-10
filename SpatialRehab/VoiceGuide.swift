import AVFoundation
import Observation

/// Warm spoken prompts — many dementia patients won't read floating text,
/// but a calm voice is how a caregiver would actually guide them.
@Observable
@MainActor
final class VoiceGuide {
    var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    /// Keeps `AmbientMusic` out of the way of the voice. Held here rather than set as the
    /// synthesizer's delegate inline because `AVSpeechSynthesizer` does not retain its
    /// delegate.
    private let duckingObserver = SpeechDuckingObserver()

    init() {
        synthesizer.delegate = duckingObserver
    }

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

/// Bridges the synthesizer's delegate callbacks to the ambient music bed, so the pads dip
/// while the guide is talking and lift again when it stops. Separate from `VoiceGuide`
/// itself because `AVSpeechSynthesizerDelegate` needs an `NSObject`, and the callbacks
/// arrive off the main actor.
private final class SpeechDuckingObserver: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        setSpeaking(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        setSpeaking(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        setSpeaking(false)
    }

    private func setSpeaking(_ speaking: Bool) {
        Task { @MainActor in
            AmbientMusic.shared.setSpeaking(speaking)
        }
    }
}
