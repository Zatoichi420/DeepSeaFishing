import Foundation

/// Everything that makes one fight easier or harder than the base numbers:
/// matched gear, tackle tier, angler skills, boat upgrades, fish size, and
/// whether this is a legend. All 1.0 is the original arcade fight exactly.
struct FightModifiers: Equatable {
    var gain = 1.0
    var tensionPerReel = 1.0
    var easeRelief = 1.0
    var aggression = 1.0
    var runStrength = 1.0
    /// Line the fish takes back every tick on its own. Zero for ordinary
    /// fish; a legend never stops pulling, so playing it too safe loses.
    var drift = 0.0

    static let original = FightModifiers()

    /// The original arcade penalty for the wrong outfit.
    mutating func applyMismatch() {
        gain *= 0.8
        tensionPerReel *= 1.15
        aggression *= 1.3
        runStrength *= 1.25
    }
}

/// The pure rules of one fight - no timers, haptics, audio, or speech.
/// `GameViewModel` drives it on a half-second timer and from the Reel In and
/// Ease Line buttons; the test suite drives it with a simple bot to measure
/// how often each kind of fight is won.
struct FightEngine {
    enum Outcome: Equatable { case ongoing, landed, snapped }

    let fish: Fish
    let modifiers: FightModifiers
    private(set) var tension: Double = 0
    private(set) var progress: Double = 0

    init(fish: Fish, modifiers: FightModifiers) {
        self.fish = fish
        self.modifiers = modifiers
    }

    mutating func reel(multiplier: Double = 1.0) {
        progress = min(1, progress + 0.09 * modifiers.gain * multiplier)
        tension = min(1, tension + 0.11 * modifiers.tensionPerReel * multiplier)
    }

    mutating func ease(multiplier: Double = 1.0) {
        tension = max(0, tension - 0.16 * modifiers.easeRelief * multiplier)
        progress = max(0, progress - 0.02 * multiplier)
    }

    /// Passive drift plus a chance of a run. Returns whether the fish ran.
    mutating func tick() -> Bool {
        tension = max(0, tension - 0.03)
        progress = max(0, progress - modifiers.drift)
        let species = fish.species
        if GameRandom.unit() < species.aggression * modifiers.aggression {
            let spike = GameRandom.value(in: species.runStrength) * modifiers.runStrength
            tension = min(1, tension + spike)
            progress = max(0, progress - 0.03)
            return true
        }
        return false
    }

    func outcome(allowSnap: Bool = true) -> Outcome {
        if allowSnap && tension >= 1 { return .snapped }
        if progress >= 1 { return .landed }
        return .ongoing
    }
}
