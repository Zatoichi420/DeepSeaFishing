import AVFoundation

/// Game audio. The sea itself is recorded: looping layers (waves, engine, rigging,
/// reel drag) are mixed by scene and fishing ground, and one-shot sounds (casts,
/// jumps, splashes, gaff, snap, rod creak) play from a pool of voices so long
/// samples never cut each other off. The short UI cues (reel tick, ease sweep,
/// progress pulse, cash, landing jingle) are still synthesized.
final class AudioManager {
    /// What the player is doing, which sets the mix.
    enum Scene {
        case harbor
        case atSea
        case fighting
    }

    private enum Layer: CaseIterable {
        case wavesA, wavesB, engine, rigging, drag

        var fileName: String {
            switch self {
            case .wavesA: return "fish_waves_a"
            case .wavesB: return "fish_waves_b"
            case .engine: return "fish_engine"
            case .rigging: return "fish_rigging"
            case .drag: return "fish_drag"
            }
        }
    }

    private enum Clip: String, CaseIterable {
        case cast, clicker, creak, gaff, gulls, jump, slap, snap, tailwalk, thrash

        var fileName: String { "fish_\(rawValue)" }
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var isRunning = false
    private var interruptionObserver: NSObjectProtocol?

    // Looping layers.
    private var layerNodes: [Layer: AVAudioPlayerNode] = [:]
    private var layerBuffers: [Layer: AVAudioPCMBuffer] = [:]
    private var layerTarget: [Layer: Float] = [:]
    private var layerCurrent: [Layer: Float] = [:]

    // One-shot voices.
    private static let voiceCount = 10
    private var voices: [AVAudioPlayerNode] = []
    private var voiceBusy = [Bool](repeating: false, count: voiceCount)
    private var voiceGeneration = [Int](repeating: 0, count: voiceCount)
    private var nextSteal = 0
    private var clips: [Clip: AVAudioPCMBuffer] = [:]

    // Synthesized cues.
    private var clickBuffer: AVAudioPCMBuffer?
    private var coinBuffer: AVAudioPCMBuffer?
    private var landedBuffer: AVAudioPCMBuffer?
    private var easeBuffer: AVAudioPCMBuffer?
    private var deepRumbleBuffer: AVAudioPCMBuffer?
    private var snapTwangBuffer: AVAudioPCMBuffer?

    // Scene state.
    private var scene: Scene = .harbor
    private var ground: FishingGround = .coastalShelf
    private var mixTimer: Timer?
    private var nextGull = Date()
    private var nextSlap = Date()
    private var runBoostUntil = Date.distantPast
    private var lastCreak = Date.distantPast

    init() {
        for layer in Layer.allCases {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            node.volume = 0
            layerNodes[layer] = node
            layerTarget[layer] = 0
            layerCurrent[layer] = 0
        }
        for _ in 0..<Self.voiceCount {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            voices.append(voice)
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
        mixTimer?.invalidate()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func start() {
        guard !isRunning else { return }
        loadAssetsIfNeeded()
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isRunning = true
            for voice in voices { voice.stop() }
            voiceBusy = [Bool](repeating: false, count: Self.voiceCount)
            for layer in Layer.allCases {
                guard let node = layerNodes[layer], let buffer = layerBuffers[layer] else { continue }
                node.stop()
                node.volume = layerCurrent[layer] ?? 0
                node.scheduleBuffer(buffer, at: nil, options: .loops)
                node.play()
            }
            applyScene()
            startMixTimer()
        } catch {
            // Audio is a supplementary feedback channel; failures are non-fatal.
        }
    }

    // MARK: - Scene

    /// Sets the mix for what the player is doing and where.
    func setScene(_ newScene: Scene, ground newGround: FishingGround = .coastalShelf) {
        guard newScene != scene || newGround != ground else { return }
        let wasFighting = scene == .fighting
        scene = newScene
        ground = newGround
        if wasFighting && newScene != .fighting { layerTarget[.drag] = 0 }
        applyScene()
    }

    private func applyScene() {
        let ground = self.ground
        let waveScale: Float
        switch ground {
        case .coastalShelf: waveScale = 0.85
        case .canyonEdge: waveScale = 1.0
        case .gulfStream: waveScale = 1.1
        case .deepTrench: waveScale = 1.15
        }

        switch scene {
        case .harbor:
            layerTarget[.wavesA] = 0.55 * waveScale
            layerTarget[.wavesB] = 0.20
            layerTarget[.engine] = 0
            layerTarget[.rigging] = 0.40
        case .atSea:
            layerTarget[.wavesA] = min(0.60 * waveScale, 1)
            layerTarget[.wavesB] = min(0.45 * waveScale, 1)
            layerTarget[.engine] = ground == .deepTrench ? 0.24 : 0.30
            layerTarget[.rigging] = ground == .deepTrench ? 0.55 : 0.40
        case .fighting:
            layerTarget[.wavesA] = min(0.60 * waveScale, 1)
            layerTarget[.wavesB] = min(0.45 * waveScale, 1)
            layerTarget[.engine] = 0.16
            layerTarget[.rigging] = 0.20
        }
        scheduleNextGull()
        scheduleNextSlap()
    }

    private func startMixTimer() {
        mixTimer?.invalidate()
        mixTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.mixTick()
        }
    }

    /// Eases every loop toward its target volume and fires the random sea sounds.
    private func mixTick() {
        guard isRunning else { return }
        for layer in Layer.allCases {
            let target = layerTarget[layer] ?? 0
            var current = layerCurrent[layer] ?? 0
            // The drag layer must respond fast; the beds fade slowly.
            let rate: Float = layer == .drag ? 0.35 : 0.08
            current += (target - current) * rate
            if abs(target - current) < 0.002 { current = target }
            layerCurrent[layer] = current
            layerNodes[layer]?.volume = current
        }

        let now = Date()
        if now >= nextGull {
            if scene != .fighting, ground != .deepTrench, let clip = clips[.gulls] {
                playBuffer(clip, volume: Float.random(in: 0.35...0.6))
            }
            scheduleNextGull()
        }
        if now >= nextSlap {
            if let clip = clips[.slap] {
                let volume: Float = scene == .harbor ? 0.25 : Float.random(in: 0.4...0.75)
                playBuffer(clip, volume: volume)
            }
            scheduleNextSlap()
        }
    }

    private func scheduleNextGull() {
        let range: ClosedRange<Double>
        switch ground {
        case .coastalShelf: range = 9...18
        case .canyonEdge: range = 14...26
        case .gulfStream: range = 22...40
        case .deepTrench: range = 60...90
        }
        let base = scene == .harbor ? range.lowerBound * 0.6 : Double.random(in: range)
        nextGull = Date().addingTimeInterval(base)
    }

    private func scheduleNextSlap() {
        let range: ClosedRange<Double> = scene == .harbor ? 12...22 : 6...14
        nextSlap = Date().addingTimeInterval(Double.random(in: range))
    }

    // MARK: - Events

    /// The rod whips out and the lure lands.
    func playCast() { playClip(.cast, volume: 0.9) }

    /// The strike: the fish hits the lure a moment after it lands.
    func playBite() {
        guard isRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.playClip(.jump, volume: 0.85)
        }
    }

    func playReelClick() { playBuffer(clickBuffer, volume: 0.8) }
    func playEase() { playBuffer(easeBuffer, volume: 0.8) }
    func playCash() { playBuffer(coinBuffer, volume: 0.9) }

    func playLanded() {
        playClip(.gaff, volume: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playBuffer(self?.landedBuffer, volume: 0.8)
        }
    }

    func playSnap() {
        playClip(.snap, volume: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.playBuffer(self?.snapTwangBuffer, volume: 0.35)
        }
    }

    func playRun(for species: FishSpecies) {
        runBoostUntil = Date().addingTimeInterval(1.8)
        switch species.fightStyle {
        case .burst:
            // Marlin-style: the fish clears the water and tailwalks.
            if Bool.random() { playClip(.jump, volume: 0.95) }
            playClip(.tailwalk, volume: 0.95)
        case .deep:
            playBuffer(deepRumbleBuffer, volume: 0.9)
            playClip(.thrash, volume: 0.5)
        case .steady:
            playClip(.thrash, volume: 0.9)
        }
    }

    /// A soft, rising-pitch tick played once per game tick during a fight, so
    /// "line to shore" progress is perceivable in real time. Deliberately quiet
    /// and short so it doesn't compete with run cues or the line sounds.
    func playProgressPulse(_ progress: Double) {
        playBuffer(Self.makeProgressPulseBuffer(progress: progress, format: format), volume: 0.8)
    }

    /// Line tension drives the reel drag whine, and a rod creak near the limit.
    /// Call every time tension changes during a fight.
    func updateTension(_ tension: Double) {
        guard scene == .fighting else { return }
        let base = Float(max(0, min(1, (tension - 0.4) / 0.6))) * 0.55
        let boosted = Date() < runBoostUntil ? max(base, 0.6) : base
        layerTarget[.drag] = boosted

        let now = Date()
        if tension > 0.72, now.timeIntervalSince(lastCreak) > 4 {
            lastCreak = now
            playClip(.creak, volume: Float(min(1, 0.5 + (tension - 0.72) * 2)))
        }
    }

    /// The fight is over: let the line go quiet.
    func stopFight() {
        layerTarget[.drag] = 0
        runBoostUntil = .distantPast
    }

    // MARK: - Playback

    private func playClip(_ clip: Clip, volume: Float) {
        playBuffer(clips[clip], volume: volume)
    }

    private func playBuffer(_ buffer: AVAudioPCMBuffer?, volume: Float = 1) {
        guard isRunning, let buffer else { return }
        let index: Int
        if let free = voiceBusy.firstIndex(of: false) {
            index = free
        } else {
            index = nextSteal
            nextSteal = (nextSteal + 1) % Self.voiceCount
            voices[index].stop()
        }
        voiceGeneration[index] += 1
        let generation = voiceGeneration[index]
        voiceBusy[index] = true
        let voice = voices[index]
        voice.volume = volume
        voice.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.voiceGeneration[index] == generation else { return }
                self.voiceBusy[index] = false
            }
        }
        voice.play()
    }

    // MARK: - Asset loading

    private func loadAssetsIfNeeded() {
        guard layerBuffers.isEmpty else { return }
        for layer in Layer.allCases {
            if let buffer = Self.loadBuffer(named: layer.fileName, ext: "wav") {
                layerBuffers[layer] = buffer
            }
        }
        for clip in Clip.allCases {
            if let buffer = Self.loadBuffer(named: clip.fileName, ext: "m4a") {
                clips[clip] = buffer
            }
        }
        clickBuffer = Self.makeClickBuffer(format: format)
        easeBuffer = Self.makeEaseBuffer(format: format)
        coinBuffer = Self.makeCoinBuffer(format: format)
        landedBuffer = Self.makeLandedBuffer(format: format)
        deepRumbleBuffer = Self.makeSwordfishRunBuffer(format: format)
        snapTwangBuffer = Self.makeSnapBuffer(format: format)
    }

    private static func loadBuffer(named name: String, ext: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              )
        else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        return buffer
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

    /// Two bright coin pings for money changing hands.
    private static func makeCoinBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.4) { t in
            var sample: Float = 0
            let hits: [(Double, Double)] = [(0, 1319), (0.08, 1760)]
            for (start, freq) in hits where t >= start {
                let localT = t - start
                let ring = Float(sin(2 * .pi * freq * localT) + 0.4 * sin(2 * .pi * freq * 2.7 * localT))
                sample += ring * Float(exp(-localT * 14)) * 0.3
            }
            return sample
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
    /// sonar ping getting faster/higher as you close in.
    private static func makeProgressPulseBuffer(progress: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let freq = 300.0 + 500.0 * progress
        return makeBuffer(format: format, duration: 0.12) { t in
            let tone = Float(sin(2 * .pi * freq * t))
            let envelope = Float(exp(-t * 25))
            return tone * envelope * 0.22
        }
    }

    /// The short recoil twang that follows the recorded line snap.
    private static func makeSnapBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(format: format, duration: 0.4) { t in
            let twang = Float(sin(2 * .pi * (900 - 700 * t) * t)) * Float(exp(-t * 8))
            return twang * 0.5
        }
    }
}
