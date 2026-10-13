import Foundation

/// Deterministic, seedable RNG for the test suite. SplitMix64 - tiny, fast,
/// well-distributed, and identical output for a given seed on every run and
/// every machine, which is what makes the campaign win-rate assertions stable
/// in CI. Assigned to `GameRandom.generator` at the top of a test and restored to
/// `SystemRandomNumberGenerator()` in tearDown.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
