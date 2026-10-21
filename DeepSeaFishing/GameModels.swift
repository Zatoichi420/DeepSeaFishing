import Foundation

/// Every random roll in the game goes through here, so tests can seed it and
/// replay thousands of fights deterministically. The app never sets it.
enum GameRandom {
    static var generator: RandomNumberGenerator = SystemRandomNumberGenerator()

    static func unit() -> Double { Double.random(in: 0...1, using: &generator) }
    static func value(in range: ClosedRange<Double>) -> Double { Double.random(in: range, using: &generator) }
    static func int(in range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &generator) }
}

/// How a fish fights - drives which run haptic and run sound plays, so
/// every species reads by feel and ear, not just by name.
enum FightStyle: String, Codable {
    /// Sharp staccato bursts - jumps and tailwalks.
    case burst
    /// A long, low dive.
    case deep
    /// One hard, steady pull.
    case steady
}

enum FishSpecies: String, CaseIterable, Codable {
    // Order matters: the original three come first, so the Quick Run mode
    // (`FishSpecies.quickRun`) keeps its old choices.
    case tuna
    case marlin
    case swordfish
    case mahiMahi
    case wahoo
    case yellowfin
    case sailfish
    case mako

    /// The three species the original arcade run offered.
    static let quickRun: [FishSpecies] = [.tuna, .marlin, .swordfish]

    var displayName: String {
        switch self {
        case .tuna: return "Bluefin Tuna"
        case .marlin: return "Blue Marlin"
        case .swordfish: return "Swordfish"
        case .mahiMahi: return "Mahi-Mahi"
        case .wahoo: return "Wahoo"
        case .yellowfin: return "Yellowfin Tuna"
        case .sailfish: return "Sailfish"
        case .mako: return "Mako Shark"
        }
    }

    var weightRange: ClosedRange<Double> {
        switch self {
        case .tuna: return 50...800
        case .marlin: return 100...1200
        case .swordfish: return 80...600
        case .mahiMahi: return 10...60
        case .wahoo: return 15...100
        case .yellowfin: return 30...300
        case .sailfish: return 40...140
        case .mako: return 80...700
        }
    }

    /// Chance per tick that the fish makes a run, spiking line tension.
    var aggression: Double {
        switch self {
        case .tuna: return 0.30
        case .marlin: return 0.45
        case .swordfish: return 0.25
        case .mahiMahi: return 0.30
        case .wahoo: return 0.40
        case .yellowfin: return 0.30
        case .sailfish: return 0.42
        case .mako: return 0.38
        }
    }

    /// How much tension a single run adds.
    var runStrength: ClosedRange<Double> {
        switch self {
        case .tuna: return 0.08...0.16
        case .marlin: return 0.10...0.22
        case .swordfish: return 0.14...0.28
        case .mahiMahi: return 0.05...0.11
        case .wahoo: return 0.07...0.14
        case .yellowfin: return 0.07...0.15
        case .sailfish: return 0.08...0.16
        case .mako: return 0.12...0.24
        }
    }

    var fightStyle: FightStyle {
        switch self {
        case .marlin, .sailfish, .mahiMahi, .mako: return .burst
        case .swordfish: return .deep
        case .tuna, .yellowfin, .wahoo: return .steady
        }
    }

    var runDescription: String {
        switch self {
        case .tuna: return "digs in and pulls hard"
        case .marlin: return "tailwalks across the surface"
        case .swordfish: return "dives for the depths"
        case .mahiMahi: return "leaps and flashes gold"
        case .wahoo: return "rips off line at blistering speed"
        case .yellowfin: return "sounds and circles deep"
        case .sailfish: return "jumps with its sail spread wide"
        case .mako: return "launches clear out of the water"
        }
    }

    var blurb: String {
        switch self {
        case .tuna: return "Fast and powerful, usually hooked trolling near the surface."
        case .marlin: return "The showboat — blistering runs and spectacular jumps."
        case .swordfish: return "A deep-dwelling giant that hides 1,500+ feet down by day."
        case .mahiMahi: return "Bright gold and green, acrobatic, and the best eating fish on the coast."
        case .wahoo: return "The fastest fish in the sea. Its first run can empty a reel."
        case .yellowfin: return "Smaller cousin of the bluefin, and twice as stubborn for its size."
        case .sailfish: return "Light-tackle royalty. Tagged and released, never kept."
        case .mako: return "The jumping shark. Fast, fierce, and best handled with heavy gear."
        }
    }

    /// Asset catalog name of this species' reference image. The newer
    /// species borrow the nearest relative's picture until art is sourced.
    var imageName: String {
        switch self {
        case .tuna, .yellowfin, .wahoo: return "TunaImage"
        case .marlin, .sailfish: return "MarlinImage"
        case .swordfish: return "SwordfishImage"
        case .mahiMahi, .mako: return "OceanWaveImage"
        }
    }

    /// Bundled looping clip for this species, if one exists (see Videos/).
    var videoName: String? {
        switch self {
        case .marlin, .sailfish, .swordfish: return "billfish_jump"
        case .tuna, .yellowfin, .wahoo: return "tuna_school"
        case .mahiMahi, .mako: return "fish_splash"
        default: return nil
        }
    }

    /// Billfish are tagged and released, as real sportfishing crews do. They
    /// earn a flat release fee instead of a price by the pound.
    var isCatchAndRelease: Bool { self == .marlin || self == .sailfish }

    /// Dock price per pound for fish that are kept.
    var pricePerPound: Double {
        switch self {
        case .tuna: return 0.45
        case .marlin, .sailfish: return 0
        case .swordfish: return 0.55
        case .mahiMahi: return 1.8
        case .wahoo: return 1.35
        case .yellowfin: return 0.7
        case .mako: return 0.3
        }
    }

    /// Release fee for billfish: a flat amount plus a little per pound.
    var releaseFee: (flat: Double, perPound: Double) {
        switch self {
        case .sailfish: return (30, 0.35)
        case .marlin: return (55, 0.18)
        default: return (0, 0)
        }
    }

    /// Angler experience per pound.
    var xpPerPound: Double {
        switch self {
        case .mahiMahi: return 0.8
        case .wahoo: return 0.65
        case .yellowfin: return 0.35
        case .sailfish: return 0.7
        case .tuna: return 0.18
        case .marlin: return 0.2
        case .swordfish: return 0.28
        case .mako: return 0.25
        }
    }
}

struct Fish: Codable, Equatable {
    let species: FishSpecies
    let weight: Double
    /// Set for a named legendary fish.
    var legendName: String? = nil

    /// - Parameter sizeSkew: the exponent that keeps trophies rare. 2.5 is
    ///   the original arcade feel; Fish Sense and the fish finder lower it.
    static func random(species: FishSpecies, sizeSkew: Double = 2.5) -> Fish {
        let range = species.weightRange
        let skew = pow(GameRandom.unit(), max(1.0, sizeSkew))
        let weight = range.lowerBound + (range.upperBound - range.lowerBound) * skew
        return Fish(species: species, weight: weight)
    }

    var weightDescription: String {
        String(format: "%.0f lb", weight)
    }

    var displayName: String {
        legendName.map { "\($0), a legendary \(species.displayName.lowercased())" } ?? species.displayName
    }

    /// 0 for the smallest of its kind, 1 for the biggest - bigger fish fight longer.
    var sizeFraction: Double {
        let range = species.weightRange
        return min(1, max(0, (weight - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }
}

// MARK: - Legends

/// The named giants of the career story. Each lives on one fishing ground,
/// takes the bait only once its chapter has begun, and fights far harder
/// than anything else of its kind.
enum Legend: String, CaseIterable, Codable {
    case scarback
    case grayGhost
    case ironjaw

    var name: String {
        switch self {
        case .scarback: return "Old Scarback"
        case .grayGhost: return "the Gray Ghost"
        case .ironjaw: return "Ironjaw"
        }
    }

    var species: FishSpecies {
        switch self {
        case .scarback: return .tuna
        case .grayGhost: return .swordfish
        case .ironjaw: return .marlin
        }
    }

    var ground: FishingGround {
        switch self {
        case .scarback: return .canyonEdge
        case .grayGhost: return .deepTrench
        case .ironjaw: return .gulfStream
        }
    }

    var weight: Double {
        switch self {
        case .scarback: return 980
        case .grayGhost: return 710
        case .ironjaw: return 1_420
        }
    }

    var hookLine: String {
        switch self {
        case .scarback: return "The line doesn't run - it just goes, all at once, like you've hooked the bottom of the sea. Something with a white scar down its flank rolls once at the surface. Old Scarback."
        case .grayGhost: return "A thousand feet down, the rod tip bows and doesn't come back up. Whatever this is, it's pale, it's patient, and it's enormous. The Gray Ghost."
        case .ironjaw: return "The water behind the Marisol simply explodes. A blue marlin the length of the boat hangs in the air, bill thrashing, a rusted old hook still in its jaw. Ironjaw. Your grandfather's hook."
        }
    }

    var fish: Fish { Fish(species: species, weight: weight, legendName: name) }
}

// MARK: - Fishing grounds

enum FishingGround: String, CaseIterable, Codable {
    case coastalShelf
    case canyonEdge
    case gulfStream
    case deepTrench

    var displayName: String {
        switch self {
        case .coastalShelf: return "the Coastal Shelf"
        case .canyonEdge: return "the Canyon Edge"
        case .gulfStream: return "the Gulf Stream"
        case .deepTrench: return "the Deep Trench"
        }
    }

    var title: String { displayName.replacingOccurrences(of: "the ", with: "").capitalized }

    var description: String {
        switch self {
        case .coastalShelf: return "Warm, shallow water an hour out of the harbor. Mahi-mahi under every patch of weed, wahoo and yellowfin on the edges."
        case .canyonEdge: return "Where the shelf drops into a submarine canyon. Big yellowfin, bluefin, and the odd sailfish riding the upwelling."
        case .gulfStream: return "A warm blue river in the sea, far offshore. Marlin country - and makos follow the bait."
        case .deepTrench: return "The farthest, darkest water the Marisol can reach. Swordfish sit two thousand feet down, and so do the stories."
        }
    }

    /// Target species available here, in the order offered.
    var species: [FishSpecies] {
        switch self {
        case .coastalShelf: return [.mahiMahi, .wahoo, .yellowfin]
        case .canyonEdge: return [.yellowfin, .tuna, .sailfish, .wahoo]
        case .gulfStream: return [.marlin, .sailfish, .mako, .tuna]
        case .deepTrench: return [.swordfish, .mako, .tuna]
        }
    }

    /// Fuel for the round trip, paid when you head out.
    var fuelCost: Int {
        switch self {
        case .coastalShelf: return 0
        case .canyonEdge: return 40
        case .gulfStream: return 90
        case .deepTrench: return 140
        }
    }
}
