import AVFoundation

/// All game audio is synthesized in real time — no bundled sound files, matching
/// the original inspiration's "everything is procedural Web Audio" approach.
/// A quiet ocean ambience loops throughout the app; short one-shot sounds layer
/// on top for bites, reeling, species-specific runs, landing, and snapped lines.
final class AudioManager {
    private let engine = AVAudioEngine()
    private let ambiencePlayer = AVAudioPlayerNode()
    private var effectVoices: [AVAudioPlayerNode] = []
    private var nextVoiceIndex = 0

    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var isRunning = false
    private var interruptionObserver: NSObjectProtocol?

    init() {
        engine.attach(ambiencePlayer)
        engine.connect(ambiencePlayer, to: engine.mainMixerNode, format: format)

        for _ in 0..<4 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            effectVoices.append(voice)
        }

        // Without this, a phone call/Siri/another app interrupting the session
        // stops the engine out from under us, but `isRunning` never notices -
        // every future play() call would silently no-op for the rest of the
        // session, permanently and undiagnosably losing all game audio.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            switch type {
            case .began:
                self.isRunning = false
            case .ended:
                self.start()
            @unknown default:
                break
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func start() {
        guard !isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isRunning = true
            ambiencePlayer.volume = 0.18
            ambiencePlayer.scheduleBuffer(Self.makeOceanAmbienceBuffer(format: format), at: nil, options: .loops)
            ambiencePlayer.play()
        } catch {
            // Audio is a supplementary feedback channel; failures are non-fatal.
        }
    }

    func playBite() { play(Self.makeBiteBuffer(format: format)) }
    func playReelClick() { play(Self.makeClickBuffer(format: format)) }
    func playEase() { play(Self.makeEaseBuffer(format: format)) }
    func playLanded() { play(Self.makeLandedBuffer(format: format)) }
    func playSnap() { play(Self.makeSnapBuffer(format: format)) }
    /// A short click for money changing hands at the dock or the shop.
    func playCash() { play(Self.makeClickBuffer(format: format)) }

    func playRun(for species: FishSpecies) {
        switch species.fightStyle {
        case .burst: play(Self.makeMarlinRunBuffer(format: format))
        case .deep: play(Self.makeSwordfishRunBuffer(format: format))
        case .steady: play(Self.makeTunaRunBuffer(format: format))
        }
    }

    /// A soft, rising-pitch tick played once per game tick during a fight, so
    /// "line to shore" progress - which previously had no audio or haptic
    /// channel at all, only a visual meter - is perceivable in real time, the
    /// same way the tension hum makes tension perceivable. Deliberately quiet
    /// and short so it doesn't compete with run cues or the tension hum.
    func playProgressPulse(_ progress: Double) {
        play(Self.makeProgressPulseBuffer(progress: progress, format: format))
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }
        let voice = effectVoices[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % effectVoices.count
        voice.stop()
        voice.scheduleBuffer(buffer, at: nil)
        voice.play()
    }

    // MARK: - Procedural buffer generation

    private static func makeBuffer(
        format: AVAudioFormat,
        duration: Double,
        generator: (Double) -> Float
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            channel[frame] = generator(t)
        }
        return buffer
    }

    /// Looping brown-noise swell. The loop point isn't seamless (fresh random
    /// noise each call), but it's masked well enough by the noise texture itself.
    private static func makeOceanAmbienceBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        var brown: Float = 0
        return makeBuffer(format: format, duration: 4.0) { t in
            let white = Float.random(in: -1...1)
            brown = (brown + 0.02 * white) / 1.02
            let swell = 0.7 + 0.3 * Float(sin(2 * .pi * 0.15 * t))
            return brown * swell * 0.6
        }
    }

    private static func makeClickBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.05) { t in
            let noise = Float.random(in: -1...1)
            let decay = Float(exp(-t * 90))
            return noise * decay * 0.5
        }
    }

    private static func makeEaseBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.3) { t in
            let noise = Float.random(in: -1...1)
            let sweep = Float(sin(2 * .pi * (600 - 400 * t) * t))
            let envelope = Float(sin(.pi * min(t / 0.3, 1)))
            return (noise * 0.4 + sweep * 0.3) * envelope * 0.4
        }
    }

    private static func makeBiteBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.2) { t in
            let tone = Float(sin(2 * .pi * 220 * t)) * Float(exp(-t * 18))
            let splash = Float.random(in: -1...1) * Float(exp(-t * 60)) * 0.3
            return tone * 0.6 + splash
        }
    }

    /// Three quick rising pings, matching the haptic tailwalk burst pattern.
    private static func makeMarlinRunBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.5) { t in
            var sample: Float = 0
            for i in 0..<3 {
                let start = Double(i) * 0.12
                guard t >= start, t < start + 0.08 else { continue }
                let localT = t - start
                let freq = 500.0 + Double(i) * 120
                sample += Float(sin(2 * .pi * freq * localT)) * Float(exp(-localT * 40))
            }
            return sample * 0.5
        }
    }

    /// Long low descending rumble for a deep dive.
    private static func makeSwordfishRunBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.7) { t in
            let freq = 160.0 - 100.0 * (t / 0.7)
            let tone = Float(sin(2 * .pi * freq * t))
            let noise = Float.random(in: -1...1) * 0.2
            let envelope = Float(sin(.pi * min(t / 0.7, 1)))
            return (tone * 0.6 + noise) * envelope * 0.5
        }
    }

    /// One steady strong pull.
    private static func makeTunaRunBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.35) { t in
            let tone = Float(sin(2 * .pi * 130 * t))
            let envelope = Float(sin(.pi * min(t / 0.35, 1)))
            return tone * envelope * 0.55
        }
    }

    /// Ascending three-note major arpeggio.
    private static func makeLandedBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let notes = [523.25, 659.25, 783.99] // C5, E5, G5
        return makeBuffer(format: format, duration: 0.6) { t in
            var sample: Float = 0
            for (i, freq) in notes.enumerated() {
                let start = Double(i) * 0.12
                guard t >= start else { continue }
                let localT = t - start
                sample += Float(sin(2 * .pi * freq * localT)) * Float(exp(-localT * 4)) * 0.35
            }
            return sample
        }
    }

    /// Pitch rises from 300Hz (no progress) to 800Hz (about to land), like a
    /// sonar ping getting faster/higher as you close in - a continuous-feeling
    /// cue built from short discrete pulses to match this file's one-shot
    /// buffer architecture rather than needing a separate persistent player.
    private static func makeProgressPulseBuffer(progress: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let freq = 300.0 + 500.0 * progress
        return makeBuffer(format: format, duration: 0.12) { t in
            let tone = Float(sin(2 * .pi * freq * t))
            let envelope = Float(exp(-t * 25))
            return tone * envelope * 0.22
        }
    }

    private static func makeSnapBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.4) { t in
            let noise = Float.random(in: -1...1) * Float(exp(-t * 12))
            let twang = Float(sin(2 * .pi * (900 - 700 * t) * t)) * Float(exp(-t * 8))
            return noise * 0.6 + twang * 0.5
        }
    }
}
