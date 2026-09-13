import SwiftUI
import Observation

enum GamePhase: Equatable {
    case onboarding
    case idle
    case selectingSpecies
    case selectingGear(FishSpecies)
    case fighting
    case result(landed: Bool)
    case runOver
}

@Observable
final class GameViewModel {
    let totalCasts = 4

    var castsRemaining: Int
    var phase: GamePhase = .idle
    var currentFish: Fish?
    var hasCompletedOnboarding: Bool
    var selectedKit: EquipmentKit = .tunaTrolling
    var tension: Double = 0
    var progress: Double = 0
    var runBestCatch: Fish?

    private(set) var allTimeBestWeight: Double
    private(set) var allTimeBestSpeciesName: String?

    private var timer: Timer?
    private let bestWeightKey = "DeepSeaFishing.bestWeight"
    private let bestSpeciesKey = "DeepSeaFishing.bestSpecies"
    private let onboardingKey = "DeepSeaFishing.hasCompletedOnboarding"
    // A run in progress (mid-run, not mid-fight) is persisted so an app kill
    // between casts doesn't silently erase how many casts are left and the
    // best catch so far - only landFish() writes these, so a fight that's
    // actively in progress when the app dies is lost, but the surrounding
    // run survives.
    private let runCastsRemainingKey = "DeepSeaFishing.runCastsRemaining"
    private let runBestWeightKey = "DeepSeaFishing.runBestWeight"
    private let runBestSpeciesKey = "DeepSeaFishing.runBestSpecies"

    private let motion = MotionManager()
    private let haptics = HapticsManager()
    private let audio = AudioManager()

    /// Whether the selected gear matches the fish currently being targeted or fought.
    var isGearMatched: Bool {
        guard let species = targetSpecies else { return true }
        return selectedKit == species.recommendedKit
    }

    private var targetSpecies: FishSpecies? {
        if case .selectingGear(let species) = phase { return species }
        return currentFish?.species
    }

    init() {
        allTimeBestWeight = UserDefaults.standard.double(forKey: bestWeightKey)
        allTimeBestSpeciesName = UserDefaults.standard.string(forKey: bestSpeciesKey)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)

        // Only restore a genuinely mid-run state (some casts used, some left).
        // 0 remaining means the run had already finished (RunOverView) when the
        // app died - starting fresh is the right outcome there, not resuming a
        // 0-casts-left idle screen with no valid next action.
        let defaults = UserDefaults.standard
        if let savedCasts = defaults.object(forKey: runCastsRemainingKey) as? Int,
           savedCasts > 0, savedCasts < totalCasts {
            castsRemaining = savedCasts
            if let weight = defaults.object(forKey: runBestWeightKey) as? Double,
               let speciesName = defaults.string(forKey: runBestSpeciesKey),
               let species = FishSpecies.allCases.first(where: { $0.displayName == speciesName }) {
                runBestCatch = Fish(species: species, weight: weight)
            }
        } else {
            castsRemaining = totalCasts
            defaults.removeObject(forKey: runCastsRemainingKey)
            defaults.removeObject(forKey: runBestWeightKey)
            defaults.removeObject(forKey: runBestSpeciesKey)
        }

        phase = hasCompletedOnboarding ? .idle : .onboarding
        audio.start()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
        phase = .idle
    }

    func showOnboarding() {
        phase = .onboarding
    }

    func startRun() {
        castsRemaining = totalCasts
        runBestCatch = nil
        currentFish = nil
        phase = .idle
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: runCastsRemainingKey)
        defaults.removeObject(forKey: runBestWeightKey)
        defaults.removeObject(forKey: runBestSpeciesKey)
    }

    func beginTargeting() {
        phase = .selectingSpecies
    }

    func selectSpecies(_ species: FishSpecies) {
        selectedKit = species.recommendedKit
        phase = .selectingGear(species)
        announce("Gearing up for \(species.displayName).")
    }

    func selectKit(_ kit: EquipmentKit) {
        selectedKit = kit
    }

    /// Whether tilt controls are usable on this device (always false in Simulator).
    var isMotionAvailable: Bool { motion.isAvailable }

    /// Re-zeroes tilt against the phone's current angle - the fallback for a
    /// fight where tilt feels backwards or stuck, since calibration only
    /// happens once automatically, at fight start.
    func recalibrateTilt() {
        motion.recalibrate()
        announce("Tilt recalibrated.")
    }

    func cast() {
        guard case .selectingGear(let species) = phase else { return }
        currentFish = Fish.random(species: species)
        tension = 0
        progress = 0
        phase = .fighting
        let mismatchWarning = isGearMatched ? "" : " Your gear doesn't match this fish, so the fight will be tougher."
        announce("Fish on! A \(species.displayName) takes the bait.\(mismatchWarning)")
        haptics.playBite()
        audio.playBite()
        motion.start()
        startTimer()
    }

    /// Re-speaks the current fight state on demand (VoiceOver magic tap), so a
    /// player who missed or was talked over by a live announcement can recover
    /// it rather than having no way to find out what's happening right now.
    func announceCurrentState() {
        guard phase == .fighting, let fish = currentFish else { return }
        let mismatchNote = isGearMatched ? "" : " Gear mismatched."
        announce(
            "Fighting a \(fish.species.displayName). "
            + "Line to shore \(Int(progress * 100)) percent. "
            + "Tension \(Int(tension * 100)) percent.\(mismatchNote)"
        )
    }

    func reelIn() {
        applyReel(multiplier: 1.0)
        checkOutcome()
    }

    func easeLine() {
        applyEase(multiplier: 1.0)
    }

    private func applyReel(multiplier: Double) {
        guard phase == .fighting else { return }
        let gainMultiplier = isGearMatched ? 1.0 : 0.8
        let tensionMultiplier = isGearMatched ? 1.0 : 1.15
        progress = min(1, progress + 0.09 * gainMultiplier * multiplier)
        tension = min(1, tension + 0.11 * tensionMultiplier * multiplier)
        haptics.updateTension(tension)
        audio.playReelClick()
    }

    private func applyEase(multiplier: Double) {
        guard phase == .fighting else { return }
        tension = max(0, tension - 0.16 * multiplier)
        progress = max(0, progress - 0.02 * multiplier)
        haptics.updateTension(tension)
        audio.playEase()
    }

    func acknowledgeResult() {
        currentFish = nil
        phase = castsRemaining == 0 ? .runOver : .idle
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard phase == .fighting, let species = currentFish?.species else { return }

        tension = max(0, tension - 0.03)

        let aggressionMultiplier = isGearMatched ? 1.0 : 1.3
        let runStrengthMultiplier = isGearMatched ? 1.0 : 1.25

        var runOccurredThisTick = false
        if Double.random(in: 0...1) < species.aggression * aggressionMultiplier {
            let spike = Double.random(in: species.runStrength) * runStrengthMultiplier
            tension = min(1, tension + spike)
            progress = max(0, progress - 0.03)
            announce("The \(species.displayName.lowercased()) \(species.runDescription)!")
            haptics.playRun(for: species)
            audio.playRun(for: species)
            runOccurredThisTick = true
        }

        // Tilt back to reel in, tilt forward to ease the line, alongside the buttons.
        switch motion.tiltState {
        case .reeling: applyReel(multiplier: 0.5)
        case .easing: applyEase(multiplier: 0.5)
        case .neutral: break
        }

        haptics.updateTension(tension)
        audio.playProgressPulse(progress)

        // A run's tension spike used to be able to end the fight in the same
        // tick its haptic/audio cue started - 0ms reaction time. Skip the snap
        // check on the tick a run occurs, so the earliest a run can end the
        // fight is the *next* tick (~0.5s later), giving the player a real
        // chance to perceive the cue and react (ease off) before losing.
        checkOutcome(allowSnap: !runOccurredThisTick)
    }

    private func checkOutcome(allowSnap: Bool = true) {
        guard let fish = currentFish else { return }

        if allowSnap && tension >= 1 {
            landFish(fish, landed: false)
        } else if progress >= 1 {
            landFish(fish, landed: true)
        }
    }

    private func landFish(_ fish: Fish, landed: Bool) {
        stopTimer()
        motion.stop()
        haptics.stopTension()
        castsRemaining -= 1

        if landed {
            if runBestCatch == nil || fish.weight > runBestCatch!.weight {
                runBestCatch = fish
            }
            let isNewRecord = fish.weight > allTimeBestWeight
            if isNewRecord {
                allTimeBestWeight = fish.weight
                allTimeBestSpeciesName = fish.species.displayName
                UserDefaults.standard.set(allTimeBestWeight, forKey: bestWeightKey)
                UserDefaults.standard.set(allTimeBestSpeciesName, forKey: bestSpeciesKey)
            }
            let recordNote = isNewRecord ? " New all-time record!" : ""
            announce("Landed! A \(fish.weightDescription) \(fish.species.displayName).\(recordNote)")
            haptics.playLanded()
            audio.playLanded()
        } else {
            announce("The line snapped. The \(fish.species.displayName) got away.")
            haptics.playSnap()
            audio.playSnap()
        }

        persistRunState()

        phase = .result(landed: landed)
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(AttributedString(text)).post()
    }

    /// Saves how many casts are left and the best catch so far, so a run
    /// survives the app being killed between casts. Called after every cast
    /// resolves (landed or snapped) - never mid-fight, since resuming a fight
    /// in progress would also need to restore the audio/haptic engines'
    /// live state, which isn't worth the complexity for a single abandoned cast.
    private func persistRunState() {
        let defaults = UserDefaults.standard
        defaults.set(castsRemaining, forKey: runCastsRemainingKey)
        if let best = runBestCatch {
            defaults.set(best.weight, forKey: runBestWeightKey)
            defaults.set(best.species.displayName, forKey: runBestSpeciesKey)
        } else {
            defaults.removeObject(forKey: runBestWeightKey)
            defaults.removeObject(forKey: runBestSpeciesKey)
        }
    }
}
