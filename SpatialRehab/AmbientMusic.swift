import AVFoundation
import Foundation
import Observation

/// The app's ambient music bed: a slow drift of pad chords over a low drone, with the
/// occasional soft bell. It starts with the app and keeps playing across every surface —
/// the baseline assessment, the home screen, Daily Practice, the name card, and all three
/// immersive activities — so a session never drops into silence.
///
/// Synthesized in code rather than streamed from a file, following `MahjongAudio`: nothing
/// to license or ship, and the loop can be seamless by construction rather than by luck.
/// One 60-second pad loop carries a six-chord progression (D – Bm – G – A – F♯m – G) whose
/// voices are written with wrap-around, so the last chord's tail is already the first
/// chord's bed when the buffer repeats. The bells are separate one-shots fired at random
/// intervals, and they are what keep the whole thing from being heard as a 60-second loop.
///
/// Two things shape the sound for this audience specifically. There is no percussion and no
/// melody to follow — nothing that asks for attention or implies a task. And the bed swells
/// six times a minute, the pace of slow resonance breathing, so a person who drifts into
/// breathing along with it lands somewhere useful.
///
/// Levels sit far below `MahjongAudio`'s and the voice guide's; `setSpeaking(_:)` ducks the
/// bed further while `VoiceGuide` talks, because a spoken instruction must always win.
@Observable
@MainActor
final class AmbientMusic {

    /// One bed for the whole process. The music has to outlive any single scene — Remember
    /// the Way dismisses the main window entirely — and two engines playing the same loop
    /// out of phase would be plainly audible. So unlike `MahjongAudio`, which is created
    /// per activity, this is shared.
    static let shared = AmbientMusic()

    // MARK: - Public API

    /// Whether the person wants music at all, persisted across launches. Toggling it starts
    /// or fades out the bed; `AmbientMusicToggle` is the control.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            if isEnabled {
                start()
            } else {
                fadeOutAndPause()
            }
        }
    }

    /// Begins (or resumes) the bed, fading in over several seconds. Safe to call from every
    /// scene's `.task` — repeat calls while already playing do nothing, which is what lets
    /// each surface ask for music without any of them owning it.
    func start() {
        guard isEnabled, !isPlaying else { return }
        isPlaying = true
        Task { await beginPlayback() }
    }

    func toggle() {
        isEnabled.toggle()
    }

    /// Dips the bed while the voice guide speaks, and lifts it again afterwards.
    /// `VoiceGuide` drives this from its synthesizer delegate.
    func setSpeaking(_ speaking: Bool) {
        unduckTask?.cancel()
        unduckTask = nil
        if speaking {
            isDucked = true
            rampGain(to: Self.duckedGain, over: 0.45)
        } else {
            // Queued utterances report `didFinish` and then `didStart` back to back, so
            // lifting immediately would make the bed swell in the gap between two
            // sentences. A short hold rides through it; a new utterance cancels this task.
            unduckTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                self.isDucked = false
                self.rampGain(to: 1, over: 1.8)
            }
        }
    }

    // MARK: - Levels

    /// Quiet enough to sit under speech and under the mahjong table's own sounds — for
    /// reference, `MahjongAudio` plays its tile clacks at 0.5 and its wash at 0.25.
    private static let padVolume: Float = 0.13
    private static let bellVolume: Float = 0.10
    /// How far the bed drops while the guide is speaking.
    private static let duckedGain: Float = 0.3
    private static let enabledDefaultsKey = "ambientMusic.isEnabled"

    // MARK: - Engine state

    nonisolated private static let sampleRate: Double = 22_050

    private var engine: AVAudioEngine?
    private var padPlayer: AVAudioPlayerNode?
    private var padBuffer: AVAudioPCMBuffer?
    private var bellPlayers: [AVAudioPlayerNode] = []
    private var bellBuffers: [AVAudioPCMBuffer] = []
    /// Per-player level for the bell currently ringing on it, so `applyGain()` can keep
    /// ducking a bell that is still decaying when the guide starts talking.
    private var bellVoiceGains: [Float] = []
    private var bellIndex = 0

    private var isPlaying = false
    private var isDucked = false
    /// Master fade level, 0...1, multiplied into every node's volume.
    private var gain: Float = 0 {
        didSet { applyGain() }
    }
    private var gainRampTask: Task<Void, Never>?
    private var unduckTask: Task<Void, Never>?
    private var bellTask: Task<Void, Never>?
    private var configurationObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.enabledDefaultsKey: true])
        isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
    }

    /// Renders the buffers on first use (off the main actor — it is a fraction of a second
    /// of arithmetic, but it has no business blocking a view update), then starts the loop.
    private func beginPlayback() async {
        if engine == nil {
            let rate = Self.sampleRate
            let rendered = await Task.detached(priority: .utility) {
                AmbientMusic.render(sampleRate: rate)
            }.value
            // The music may have been switched off while we were rendering.
            guard isPlaying else { return }
            guard installEngine(with: rendered) else {
                isPlaying = false
                return
            }
        }
        // Checked again after every suspension point above, and once more here to cover the
        // second-play path, which reaches this line one `Task` hop after `start()` set the
        // flag: off-then-on-then-off inside that hop must not leave a fade-out task racing a
        // freshly scheduled loop.
        guard isPlaying, let engine else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                isPlaying = false
                return
            }
        }
        gain = 0
        scheduleAndPlayPad()
        // A long fade in: the music should be already there when someone notices it, never
        // something that arrives.
        rampGain(to: isDucked ? Self.duckedGain : 1, over: 8)
        startBellLoop()
    }

    /// Starts the loop from the top. Kept as a synchronous method on purpose: called
    /// directly from an `async` context, `scheduleBuffer` resolves to its awaitable
    /// overload, which does not resume until the buffer finishes playing — and a looping
    /// buffer never finishes.
    private func scheduleAndPlayPad() {
        guard let padPlayer, let padBuffer else { return }
        padPlayer.scheduleBuffer(padBuffer, at: nil, options: [.loops, .interrupts])
        padPlayer.play()
    }

    private func installEngine(with rendered: RenderedSamples) -> Bool {
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1),
            let pad = Self.makeBuffer(samples: rendered.pad, format: format)
        else { return false }

        var bells: [AVAudioPCMBuffer] = []
        for samples in rendered.bells {
            guard let buffer = Self.makeBuffer(samples: samples, format: format) else { return false }
            bells.append(buffer)
        }

        let engine = AVAudioEngine()
        let padNode = AVAudioPlayerNode()
        // Three bell voices: enough that a new bell never cuts off the tail of the last one
        // at the intervals these are fired at.
        let bellNodes = (0..<3).map { _ in AVAudioPlayerNode() }
        for player in [padNode] + bellNodes {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return false
        }

        self.engine = engine
        padPlayer = padNode
        padBuffer = pad
        bellPlayers = bellNodes
        bellBuffers = bells
        bellVoiceGains = Array(repeating: 1, count: bellNodes.count)
        bellIndex = 0
        applyGain()
        observeAudioDisruptions(for: engine)
        return true
    }

    /// Fades out over a couple of seconds, then parks the engine. The buffers are kept, so
    /// turning the music back on is instant.
    private func fadeOutAndPause() {
        guard isPlaying else { return }
        isPlaying = false
        bellTask?.cancel()
        bellTask = nil
        unduckTask?.cancel()
        unduckTask = nil
        gainRampTask?.cancel()
        gainRampTask = Task { [weak self] in
            await self?.animateGain(to: 0, over: 2.5)
            guard !Task.isCancelled, let self else { return }
            self.padPlayer?.stop()
            for player in self.bellPlayers {
                player.stop()
            }
            self.engine?.pause()
        }
    }

    // MARK: - Level control

    private func rampGain(to target: Float, over duration: Double) {
        gainRampTask?.cancel()
        gainRampTask = Task { [weak self] in
            await self?.animateGain(to: target, over: duration)
        }
    }

    private func animateGain(to target: Float, over duration: Double) async {
        let stepDuration = 0.05
        let steps = max(1, Int(duration / stepDuration))
        let start = gain
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            gain = start + (target - start) * Float(step) / Float(steps)
            try? await Task.sleep(for: .seconds(stepDuration))
        }
        guard !Task.isCancelled else { return }
        gain = target
    }

    private func applyGain() {
        padPlayer?.volume = Self.padVolume * gain
        for (index, player) in bellPlayers.enumerated() {
            player.volume = Self.bellVolume * gain * bellVoiceGains[index]
        }
    }

    // MARK: - Bells

    /// Fires a single bell at irregular intervals. Irregular on purpose: a bell on a fixed
    /// beat becomes a metronome, and a metronome is something to keep up with.
    private func startBellLoop() {
        bellTask?.cancel()
        bellTask = Task { [weak self] in
            // Let the pads settle before the first one.
            try? await Task.sleep(for: .seconds(Double.random(in: 20...35)))
            while !Task.isCancelled {
                guard let self, self.isPlaying else { return }
                self.playBell()
                try? await Task.sleep(for: .seconds(Double.random(in: 13...29)))
            }
        }
    }

    private func playBell() {
        guard isPlaying, !bellPlayers.isEmpty, let buffer = bellBuffers.randomElement() else { return }
        let index = bellIndex
        bellIndex = (bellIndex + 1) % bellPlayers.count
        // Varying the level as well as the note keeps repeats from sounding sampled.
        bellVoiceGains[index] = Float.random(in: 0.5...1)
        applyGain()
        bellPlayers[index].scheduleBuffer(buffer, at: nil, options: .interrupts)
        bellPlayers[index].play()
    }

    // MARK: - Staying alive

    /// Background music that dies the first time someone connects AirPods or asks Siri
    /// something is worse than no background music. Both events stop the engine and discard
    /// everything scheduled on it, so both need the loop put back.
    private func observeAudioDisruptions(for engine: AVAudioEngine) {
        let center = NotificationCenter.default
        configurationObserver = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restartAfterDisruption() }
        }
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            guard
                let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return }
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                AVAudioSession.InterruptionOptions(rawValue: $0)
            }
            Task { @MainActor in self?.handleInterruption(type, options: options) }
        }
    }

    private func handleInterruption(
        _ type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions?
    ) {
        switch type {
        case .began:
            padPlayer?.stop()
            for player in bellPlayers {
                player.stop()
            }
        case .ended:
            // `shouldResume` is the system telling us whether anything else has taken over
            // the output. Coming back over the top of it would be rude.
            guard options?.contains(.shouldResume) ?? false else { return }
            restartAfterDisruption()
        @unknown default:
            break
        }
    }

    private func restartAfterDisruption() {
        guard isPlaying, let engine else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }
        // Restarting from the top of the loop rather than where it left off: with no beat
        // to fall out of, nobody can hear the difference, and there is no seek to get wrong.
        scheduleAndPlayPad()
    }

    // No `deinit` removing the two observers above: `shared` is the only instance and
    // `init` is private, so this object outlives the app rather than being torn down.
    // A `deinit` here could not touch them anyway — it is nonisolated, and they are not.

    // MARK: - Synthesis

    /// Everything the engine plays, as raw samples, so the whole render can cross an actor
    /// boundary back from the background task that built it.
    private struct RenderedSamples: Sendable {
        let pad: [Float]
        let bells: [[Float]]
    }

    nonisolated private static func render(sampleRate: Double) -> RenderedSamples {
        RenderedSamples(
            pad: renderPadLoop(sampleRate: sampleRate),
            bells: bellNotes.map { renderBell(midi: $0, sampleRate: sampleRate) }
        )
    }

    /// D – Bm – G – A – F♯m – G, as MIDI note numbers, voiced low and wide. Every chord
    /// holds at least one note in common with its neighbours, so the progression moves
    /// without ever announcing a change.
    nonisolated private static let progression: [[Double]] = [
        [50, 57, 61, 64, 66],  // Dmaj9
        [47, 54, 62, 66, 69],  // Bm9
        [43, 50, 59, 66, 69],  // Gmaj9
        [45, 52, 57, 61, 64],  // A(add9)
        [42, 49, 57, 64, 66],  // F♯m7
        [43, 50, 59, 66, 69],  // Gmaj9, leaning back towards D
    ]

    /// D major pentatonic, high. A pentatonic set has no semitone in it, so any two bells
    /// that happen to overlap still agree with each other and with any chord underneath.
    nonisolated private static let bellNotes: [Double] = [74, 76, 78, 81, 83]

    nonisolated private static func frequency(midi: Double) -> Double {
        440 * pow(2, (midi - 69) / 12)
    }

    /// How loudly each note of a chord is voiced, plus one extra: a quiet octave above the
    /// top note.
    ///
    /// The balance is set for the device, not for headphones. The Vision Pro's audio pods
    /// have very little output below about 120 Hz, so a bed weighted the obvious way — bass
    /// note loudest — loses most of its energy on the way to the ear and arrives thin. The
    /// bass here is held back, and the octave doubling puts real fundamentals up around
    /// 750-900 Hz where the pods are strong, which is what the shimmer on top is.
    nonisolated private static func voices(for chord: [Double]) -> [(midi: Double, weight: Double)] {
        var voices = chord.enumerated().map { index, midi in
            (midi: midi, weight: index == 0 ? 0.7 : 0.55 - 0.04 * Double(index))
        }
        if let top = chord.last {
            voices.append((midi: top + 12, weight: 0.16))
        }
        return voices
    }

    /// The seamless 60-second bed: six chords, a drone underneath, a breath across the
    /// whole thing, and a band of air around it.
    nonisolated private static func renderPadLoop(sampleRate: Double) -> [Float] {
        let loopDuration = 60.0
        let frames = Int(loopDuration * sampleRate)
        let chordInterval = loopDuration / Double(progression.count)
        // 14 seconds of chord every 10 seconds, so each one is still fading as the next
        // arrives and the bed is never thin.
        let attack = 4.0
        let hold = 3.0
        let release = 7.0

        let table = waveTable()
        let envelope = padEnvelopeCurve(attack: attack, hold: hold, release: release, sampleRate: sampleRate)
        var samples = [Float](repeating: 0, count: frames)

        for (chordIndex, chord) in progression.enumerated() {
            let start = Int(Double(chordIndex) * chordInterval * sampleRate)
            for voice in voices(for: chord) {
                let base = frequency(midi: voice.midi)
                // Two oscillators a few cents apart per voice. Their slow beating against
                // each other is most of what makes a pad sound alive, and it is free.
                for detune in [-3.5, 3.5] {
                    var phase = Double.random(in: 0..<1)
                    let increment = base * pow(2, detune / 1200) / sampleRate
                    for offset in envelope.indices {
                        // Indices wrap, so the sixth chord's tail lands on the head of the
                        // buffer — exactly where the next repeat will play it.
                        samples[(start + offset) % frames] += Float(
                            lookUp(table, phase) * envelope[offset] * voice.weight * 0.5
                        )
                        phase += increment
                        if phase >= 1 { phase -= 1 }
                    }
                }
            }
        }

        // A2 under everything: the one note that belongs in all six chords. Its frequency
        // is snapped to a whole number of cycles per loop so the seam cannot click. Kept
        // light for the same reason the bass voices are — see `voices(for:)`.
        let droneFrequency = (110.0 * loopDuration).rounded() / loopDuration
        let droneIncrement = droneFrequency / sampleRate
        var dronePhase = 0.0
        for index in samples.indices {
            samples[index] += Float(lookUp(table, dronePhase) * 0.18)
            dronePhase += droneIncrement
            if dronePhase >= 1 { dronePhase -= 1 }
        }

        normalize(&samples, toPeak: 0.8)

        // Six swells a minute — slow resonance breathing. Whole cycles per loop, so this
        // too is continuous across the seam.
        for index in samples.indices {
            let phase = 2 * Double.pi * 6 * Double(index) / Double(frames)
            samples[index] *= Float(0.88 + 0.12 * sin(phase))
        }

        var air = airBed(frames: frames, sampleRate: sampleRate)
        normalize(&air, toPeak: 0.06)
        for index in samples.indices {
            samples[index] += air[index]
        }
        return samples
    }

    /// A struck bell: a soft attack, inharmonic upper partials, and each partial dying
    /// faster than the one below it. Harmonic partials with equal decay would be a beep.
    nonisolated private static func renderBell(midi: Double, sampleRate: Double) -> [Float] {
        let duration = 3.2
        let frames = Int(duration * sampleRate)
        let base = frequency(midi: midi)
        let partials: [(ratio: Double, amplitude: Double, decay: Double)] = [
            (1.0, 1.0, 1.5),
            (2.0, 0.32, 0.85),
            (3.01, 0.14, 0.45),
            (4.17, 0.07, 0.28),
        ]
        var samples = [Float](repeating: 0, count: frames)
        for partial in partials {
            let partialFrequency = base * partial.ratio
            for index in 0..<frames {
                let time = Double(index) / sampleRate
                let value = sin(2 * .pi * partialFrequency * time)
                    * exp(-time / partial.decay)
                    * partial.amplitude
                samples[index] += Float(value)
            }
        }
        let attackFrames = max(1, Int(0.015 * sampleRate))
        for index in 0..<min(attackFrames, frames) {
            samples[index] *= Float(index) / Float(attackFrames)
        }
        // Down to true silence, so a bell cut off by a shutdown can never click.
        let fadeFrames = min(frames, Int(0.15 * sampleRate))
        for offset in 0..<fadeFrames {
            samples[frames - fadeFrames + offset] *= Float(fadeFrames - offset) / Float(fadeFrames)
        }
        normalize(&samples, toPeak: 0.9)
        return samples
    }

    /// One cycle of the pad's tone: a sine with two soft overtones. Reading the pad out of
    /// a table instead of calling `sin` once per partial per sample is what keeps building
    /// a 60-second bed down to a fraction of a second.
    nonisolated private static func waveTable() -> [Float] {
        (0..<4_096).map { index in
            let phase = 2 * Double.pi * Double(index) / 4_096
            return Float(sin(phase) + 0.22 * sin(2 * phase) + 0.07 * sin(3 * phase))
        }
    }

    /// Linearly interpolated table read. `phase` is a fraction of one cycle, 0..<1.
    nonisolated private static func lookUp(_ table: [Float], _ phase: Double) -> Double {
        let position = phase * Double(table.count)
        let index = Int(position) % table.count
        let fraction = position - position.rounded(.down)
        let current = Double(table[index])
        let next = Double(table[(index + 1) % table.count])
        return current + fraction * (next - current)
    }

    /// Raised cosine in and out: no corners, so a chord arrives and leaves without an edge
    /// anywhere for the ear to catch on.
    nonisolated private static func padEnvelopeCurve(
        attack: Double,
        hold: Double,
        release: Double,
        sampleRate: Double
    ) -> [Double] {
        let frames = Int((attack + hold + release) * sampleRate)
        return (0..<frames).map { index in
            let time = Double(index) / sampleRate
            if time < attack {
                return 0.5 - 0.5 * cos(.pi * time / attack)
            }
            if time < attack + hold {
                return 1
            }
            let progress = min((time - attack - hold) / release, 1)
            return 0.5 + 0.5 * cos(.pi * progress)
        }
    }

    /// A barely-there band of low-passed noise: the room the chords sit in. Built with the
    /// same self-crossfade `MahjongAudio.washLoopSamples` uses — the filter state is run
    /// past the loop point and blended back over the head, which hides the seam.
    nonisolated private static func airBed(frames: Int, sampleRate: Double) -> [Float] {
        let crossfadeFrames = Int(0.25 * sampleRate)
        var samples = [Float](repeating: 0, count: frames + crossfadeFrames)
        var filtered: Float = 0
        for index in samples.indices {
            filtered += 0.04 * (Float.random(in: -1...1) - filtered)
            samples[index] = filtered
        }
        for offset in 0..<crossfadeFrames {
            let blend = Float(offset) / Float(crossfadeFrames)
            samples[offset] = samples[offset] * blend + samples[frames + offset] * (1 - blend)
        }
        samples.removeLast(crossfadeFrames)
        return samples
    }

    nonisolated private static func normalize(_ samples: inout [Float], toPeak peak: Float) {
        var maximum: Float = 0
        for value in samples {
            maximum = max(maximum, abs(value))
        }
        guard maximum > 0 else { return }
        let scale = peak / maximum
        for index in samples.indices {
            samples[index] *= scale
        }
    }

    /// Copies rendered samples into a mono PCM buffer the engine can play.
    private static func makeBuffer(samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(samples.count)
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount
        for index in samples.indices {
            channel[index] = min(max(samples[index], -1), 1)
        }
        return buffer
    }
}
