import CoreHaptics

/// Distinct haptic feedback per game moment, so the fight can be felt without
/// looking at the screen: a bite, a species-specific run, a rising tension hum,
/// landing a fish, and a snapped line.
/// Anything that can make the fight felt: the phone's own motor, a game
/// controller's rumble, or an iPhone acting as the Apple TV's controller.
protocol HapticSink: AnyObject {
    func playBite()
    func playRun(for species: FishSpecies)
    func playLanded()
    func playSnap()
    func updateTension(_ level: Double)
    func stopTension()
}

final class HapticsManager: HapticSink {
    private var engine: CHHapticEngine?
    private var tensionPlayer: CHHapticAdvancedPatternPlayer?

    /// True only once the engine has actually started - hardware capability
    /// alone (the old check here) says nothing about whether init's `try
    /// engine.start()` below actually succeeded.
    var isAvailable: Bool {
        engine != nil
    }

    /// The phone's own haptics.
    convenience init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine() else {
            self.init(engine: nil)
            return
        }
        self.init(engine: engine)
    }

    /// Any haptic engine - the phone's, or one created from a game controller.
    init(engine: CHHapticEngine?) {
        guard let engine else { return }
        engine.resetHandler = { [weak engine] in
            try? engine?.start()
        }
        engine.stoppedHandler = { _ in }
        do {
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    func playBite() {
        play(events: [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0)
        ])
    }

    /// Keyed by fight style rather than species, so every species - including
    /// the ones added for the career - has a run you can tell apart by feel.
    func playRun(for species: FishSpecies) {
        playRun(style: species.fightStyle)
    }

    func playRun(style: FightStyle) {
        switch style {
        case .burst:
            // Sharp, staccato bursts for a tailwalk.
            play(events: (0..<3).map { i in
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ], relativeTime: Double(i) * 0.12)
            })
        case .deep:
            // Long, deep, low-sharpness rumble for a dive. A sharp lead-in
            // transient marks it as a distinct *event* rather than letting it
            // read as a continuation of the tension hum, which shares this
            // low sharpness range and is often already playing when a run fires.
            play(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                ], relativeTime: 0.05, duration: 0.55)
            ])
        case .steady:
            // One steady, strong pull.
            play(events: [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ], relativeTime: 0, duration: 0.35)
            ])
        }
    }

    func playLanded() {
        // Marlin's run is 3 uniform sharp transients at a fast, even 0.12s
        // spacing - too close to a flat "landed" burst for the two to be told
        // apart by feel. This is shaped as a rising crescendo instead (climbing
        // intensity, slowing spacing, softer sharpness), so "you won" reads as
        // a distinct triumphant build rather than another staccato run.
        let intensities: [Float] = [0.55, 0.8, 1.0]
        let spacing: [Double] = [0, 0.22, 0.4]
        play(events: zip(intensities, spacing).map { intensity, time in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: time)
        })
    }

    func playSnap() {
        play(events: [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0, duration: 0.5)
        ])
    }

    /// Continuously updates a background hum whose intensity tracks line
    /// tension, so the player can feel how close the line is to snapping.
    func updateTension(_ level: Double) {
        guard let engine else { return }
        do {
            if tensionPlayer == nil {
                let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(level)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0, duration: 120)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                try player.start(atTime: 0)
                tensionPlayer = player
            }
            try tensionPlayer?.sendParameters([
                CHHapticDynamicParameter(
                    parameterID: .hapticIntensityControl,
                    value: Float(level),
                    relativeTime: 0
                )
            ], atTime: 0)
        } catch {
            // Haptics are a supplementary feedback channel; failures are non-fatal.
        }
    }

    func stopTension() {
        try? tensionPlayer?.stop(atTime: 0)
        tensionPlayer = nil
    }

    private func play(events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Haptics are a supplementary feedback channel; failures are non-fatal.
        }
    }
}
