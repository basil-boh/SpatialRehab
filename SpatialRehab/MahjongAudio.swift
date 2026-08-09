import AVFoundation
import Foundation

/// The sounds of a real mahjong table, synthesized in code — no audio assets.
/// Every sound is rendered into a PCM buffer when the engine first spins up:
/// the sharp clack of a tile set down, a soft pick-up click, a warm two-note
/// chime for a completed set, and the low rumble of tiles being washed.
/// Volumes stay gentle — elderly users, calm environment.
@MainActor
final class MahjongAudio {

    // MARK: - Public API

    /// Sharp tile-on-table clack (~70 ms). Safe to call in rapid succession —
    /// a round-robin pool of player nodes lets clacks overlap without
    /// cutting each other off.
    func clack(volume: Float = 1) {
        guard prepareIfNeeded(), !clackPlayers.isEmpty else { return }
        let index = clackIndex
        clackIndex = (clackIndex + 1) % clackPlayers.count
        let player = clackPlayers[index]
        player.volume = clackMasterVolume * min(max(volume, 0), 1)
        player.scheduleBuffer(clackBuffers[index], at: nil, options: .interrupts)
        player.play()
    }

    /// Softer, shorter (~30 ms) click for picking up or snapping a tile.
    func click() {
        guard prepareIfNeeded(), let clickPlayer, let clickBuffer else { return }
        clickPlayer.scheduleBuffer(clickBuffer, at: nil, options: .interrupts)
        clickPlayer.play()
    }

    /// Warm two-note completion chime (~0.6 s): E5 then A5, each dying away
    /// like a small bell.
    func chime() {
        guard prepareIfNeeded(), let chimePlayer, let chimeBuffer else { return }
        chimePlayer.scheduleBuffer(chimeBuffer, at: nil, options: .interrupts)
        chimePlayer.play()
    }

    /// Starts the continuous low rumble of many tiles being shuffled.
    /// A seamless 2-second loop plays until `stopWash()` is called.
    func startWash() {
        guard prepareIfNeeded(), let washPlayer, let washBuffer else { return }
        guard !isWashing else { return }
        isWashing = true
        washFadeTask?.cancel()
        washFadeTask = nil
        washPlayer.volume = washMasterVolume
        washPlayer.scheduleBuffer(washBuffer, at: nil, options: [.loops, .interrupts])
        washPlayer.play()
    }

    /// Fades the wash rumble out over ~0.3 s and stops it.
    func stopWash() {
        guard isWashing, let washPlayer else { return }
        isWashing = false
        washFadeTask?.cancel()
        washFadeTask = Task { [weak self] in
            let steps = 12
            for step in stride(from: steps - 1, through: 0, by: -1) {
                guard !Task.isCancelled else { return }
                washPlayer.volume = (self?.washMasterVolume ?? 0) * Float(step) / Float(steps)
                try? await Task.sleep(for: .milliseconds(25))
            }
            guard !Task.isCancelled else { return }
            washPlayer.stop()
        }
    }

    /// Stops everything and tears the engine down — permanently for this
    /// instance. Straggler sound calls (a settle's delayed clack landing after
    /// the activity closed) must not resurrect the engine; a fresh activity
    /// gets a fresh `MahjongAudio` anyway.
    func shutdown() {
        isShutdown = true
        washFadeTask?.cancel()
        washFadeTask = nil
        isWashing = false
        guard let engine else { return }
        for player in clackPlayers { player.stop() }
        clickPlayer?.stop()
        chimePlayer?.stop()
        washPlayer?.stop()
        engine.stop()
        self.engine = nil
        clackPlayers = []
        clackBuffers = []
        clackIndex = 0
        clickPlayer = nil
        clickBuffer = nil
        chimePlayer = nil
        chimeBuffer = nil
        washPlayer = nil
        washBuffer = nil
    }

    // MARK: - Engine state

    private let sampleRate: Double = 44_100
    private let clackPoolSize = 5
    private let clackMasterVolume: Float = 0.5
    private let clickMasterVolume: Float = 0.35
    private let chimeMasterVolume: Float = 0.4
    private let washMasterVolume: Float = 0.25

    private var engine: AVAudioEngine?
    private var clackPlayers: [AVAudioPlayerNode] = []
    private var clackBuffers: [AVAudioPCMBuffer] = []
    private var clackIndex = 0
    private var clickPlayer: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?
    private var chimePlayer: AVAudioPlayerNode?
    private var chimeBuffer: AVAudioPCMBuffer?
    private var washPlayer: AVAudioPlayerNode?
    private var washBuffer: AVAudioPCMBuffer?
    private var isWashing = false
    private var washFadeTask: Task<Void, Never>?
    private var isShutdown = false

    /// Builds the engine, players, and all synthesized buffers on first use,
    /// mirroring how `VoiceGuide` defers its setup. Returns false (and stays
    /// silent) if audio cannot start.
    private func prepareIfNeeded() -> Bool {
        guard !isShutdown else { return false }
        if engine != nil { return true }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return false
        }

        var pool: [AVAudioPlayerNode] = []
        var poolBuffers: [AVAudioPCMBuffer] = []
        for _ in 0..<clackPoolSize {
            // A slightly different ping pitch per pool buffer, so rapid
            // repeats don't sound like the same sample replayed.
            let samples = clackSamples(pingFrequency: .random(in: 1_800...2_200))
            guard let buffer = makeBuffer(samples: samples, format: format) else { return false }
            pool.append(AVAudioPlayerNode())
            poolBuffers.append(buffer)
        }
        guard
            let click = makeBuffer(samples: clickSamples(), format: format),
            let chime = makeBuffer(samples: chimeSamples(), format: format),
            let wash = makeBuffer(samples: washLoopSamples(), format: format)
        else { return false }

        let engine = AVAudioEngine()
        let clickNode = AVAudioPlayerNode()
        let chimeNode = AVAudioPlayerNode()
        let washNode = AVAudioPlayerNode()
        for player in pool + [clickNode, chimeNode, washNode] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return false
        }

        clickNode.volume = clickMasterVolume
        chimeNode.volume = chimeMasterVolume
        washNode.volume = washMasterVolume

        self.engine = engine
        clackPlayers = pool
        clackBuffers = poolBuffers
        clackIndex = 0
        clickPlayer = clickNode
        clickBuffer = click
        chimePlayer = chimeNode
        chimeBuffer = chime
        washPlayer = washNode
        washBuffer = wash
        return true
    }

    // MARK: - Synthesis

    /// Copies rendered samples into a mono PCM buffer the engine can play.
    private func makeBuffer(samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
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

    /// Tile hitting the table: a white-noise burst with a very fast decay
    /// (the impact) plus a ~2 kHz sine ping dying in ~50 ms (the ceramic ring).
    private func clackSamples(pingFrequency: Double) -> [Float] {
        let frames = Int(0.07 * sampleRate)
        let attackFrames = max(1, Int(0.001 * sampleRate))
        var samples = [Float](repeating: 0, count: frames)
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            let noise = Float.random(in: -1...1) * Float(exp(-time / 0.006)) * 0.65
            let ping = Float(sin(2 * .pi * pingFrequency * time) * exp(-time / 0.012)) * 0.45
            let attack = min(1, Float(index) / Float(attackFrames))
            samples[index] = (noise + ping) * attack * 0.85
        }
        return samples
    }

    /// Picking a tile up: like the clack but quieter, shorter, and a touch
    /// higher, so it reads as a light touch rather than an impact.
    private func clickSamples() -> [Float] {
        let frames = Int(0.03 * sampleRate)
        let attackFrames = max(1, Int(0.0008 * sampleRate))
        let pingFrequency = Double.random(in: 2_400...2_800)
        var samples = [Float](repeating: 0, count: frames)
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            let noise = Float.random(in: -1...1) * Float(exp(-time / 0.003)) * 0.4
            let ping = Float(sin(2 * .pi * pingFrequency * time) * exp(-time / 0.007)) * 0.3
            let attack = min(1, Float(index) / Float(attackFrames))
            samples[index] = (noise + ping) * attack * 0.8
        }
        return samples
    }

    /// Completed set: E5 then A5, pure sines with a faint octave overtone and
    /// exponential decay, so it feels like a small warm bell rather than a
    /// game-show buzzer.
    private func chimeSamples() -> [Float] {
        let duration = 0.6
        let frames = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: frames)
        let notes: [(frequency: Double, start: Double)] = [
            (659.26, 0.0),   // E5
            (880.0, 0.22),   // A5
        ]
        for note in notes {
            let startFrame = Int(note.start * sampleRate)
            let attackFrames = max(1, Int(0.005 * sampleRate))
            for index in startFrame..<frames {
                let time = Double(index - startFrame) / sampleRate
                let envelope = exp(-time / 0.16)
                let attack = min(1, Float(index - startFrame) / Float(attackFrames))
                let fundamental = sin(2 * .pi * note.frequency * time)
                let overtone = sin(2 * .pi * note.frequency * 2 * time) * 0.15
                samples[index] += Float((fundamental + overtone) * envelope) * attack * 0.45
            }
        }
        // Short fade at the very end so the loop of the buffer never clicks.
        let fadeFrames = min(frames, Int(0.02 * sampleRate))
        for offset in 0..<fadeFrames {
            let index = frames - fadeFrames + offset
            samples[index] *= Float(fadeFrames - offset) / Float(fadeFrames)
        }
        return samples
    }

    /// Tiles being washed: a soft low-passed noise bed with a slow wobble,
    /// plus dozens of quiet randomized micro-clacks scattered across a
    /// 2-second loop. Events wrap around the loop boundary and the bed is
    /// crossfaded into itself, so the loop point is seamless.
    private func washLoopSamples() -> [Float] {
        let loopDuration = 2.0
        let frames = Int(loopDuration * sampleRate)
        let crossfadeFrames = Int(0.1 * sampleRate)
        var samples = [Float](repeating: 0, count: frames + crossfadeFrames)

        // Low-passed noise bed with a gentle wobble. The wobble runs a whole
        // number of cycles per loop so its phase matches at the seam.
        var filtered: Float = 0
        for index in samples.indices {
            let time = Double(index) / sampleRate
            filtered += 0.08 * (Float.random(in: -1...1) - filtered)
            let wobble = 0.85 + 0.15 * sin(2 * .pi * 1.5 * time)
            samples[index] = filtered * Float(wobble) * 0.5
        }
        // Crossfade the extra tail into the head — the tail continues the
        // filter state past the loop point, so blending it in hides the seam.
        for offset in 0..<crossfadeFrames {
            let blend = Float(offset) / Float(crossfadeFrames)
            samples[offset] = samples[offset] * blend + samples[frames + offset] * (1 - blend)
        }
        samples.removeLast(crossfadeFrames)

        // Dozens of quiet micro-clacks: tile edges knocking together under
        // the hands. Indices wrap so events straddling the seam stay intact.
        for _ in 0..<48 {
            let start = Int.random(in: 0..<frames)
            let length = Int(Double.random(in: 0.008...0.03) * sampleRate)
            let amplitude = Float.random(in: 0.05...0.14)
            let pingFrequency = Double.random(in: 900...2_400)
            let noiseTau = Double.random(in: 0.002...0.005)
            for offset in 0..<length {
                let time = Double(offset) / sampleRate
                let noise = Float.random(in: -1...1) * Float(exp(-time / noiseTau)) * 0.7
                let ping = Float(sin(2 * .pi * pingFrequency * time) * exp(-time / 0.008)) * 0.3
                samples[(start + offset) % frames] += (noise + ping) * amplitude
            }
        }
        return samples
    }
}
