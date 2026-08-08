import AudioToolbox

/// Light, non-jarring audio feedback for taps/matches across the baseline games.
///
/// Uses built-in system sound IDs via `AudioServicesPlaySystemSound` rather than bundling
/// custom audio assets — a deliberate hackathon-scope simplification. Known limitation:
/// Apple doesn't officially document a stable ID-to-sound mapping across OS versions (this
/// is a widely used but technically informal pattern); if a future pass wants guaranteed
/// consistent sound, bundle short `.caf`/`.wav` assets and play them with `AVAudioPlayer`
/// instead. Kept deliberately soft/short — this app's audience benefits from calm,
/// non-startling feedback, not celebratory fanfare.
enum SoundEffects {
    /// A soft, short click — used for any selection tap (card flip, answer choice).
    static func playTap() {
        AudioServicesPlaySystemSound(1104)
    }

    /// An even lighter, quieter click than `playTap()` — used for word-memory selections,
    /// which happen more rapidly/repeatedly than the other games' taps.
    static func playSoftTap() {
        AudioServicesPlaySystemSound(1103)
    }

    /// A gentle positive chime — used for completing a game or the whole battery.
    static func playSuccess() {
        AudioServicesPlaySystemSound(1025)
    }
}
