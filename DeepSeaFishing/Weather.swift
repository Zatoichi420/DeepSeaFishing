import Foundation

/// The sea's mood on a given trip. Foul weather makes every fight harder and
/// shortens a stormy day, but big fish feed harder before a front, so it pays
/// to brave it once you have the tackle. All pure rules - the forecast and the
/// effects are testable headlessly, like the rest of the career.
enum Weather: String, Codable, CaseIterable {
    case clear, overcast, rain, squall, storm

    var displayName: String {
        switch self {
        case .clear: return "clear skies"
        case .overcast: return "overcast"
        case .rain: return "steady rain"
        case .squall: return "squalls"
        case .storm: return "a full storm"
        }
    }

    /// One spoken sentence for the forecast and the deck.
    var report: String {
        switch self {
        case .clear: return "Clear skies and a light breeze. Easy fishing."
        case .overcast: return "Overcast and cool. The fish are feeding a little bigger."
        case .rain: return "Steady rain and a short chop. Bigger fish are biting, and runs hit a bit harder."
        case .squall: return "Squalls rolling through. Hard gusts make for heavier runs, but big fish are feeding."
        case .storm: return "A full storm. Huge swells cut the day short by a cast, and every fight is rougher - but monsters are on the bite."
        }
    }

    /// Lower skew means bigger fish (see `Fish.random`).
    var sizeSkewOffset: Double {
        switch self {
        case .clear: return 0
        case .overcast: return -0.15
        case .rain: return -0.3
        case .squall: return -0.35
        case .storm: return -0.5
        }
    }

    /// Extra chance a legend takes the bait.
    var legendBonus: Double {
        switch self {
        case .clear, .overcast: return 0
        case .rain: return 0.01
        case .squall: return 0.02
        case .storm: return 0.04
        }
    }

    var castPenalty: Int { self == .storm ? 1 : 0 }

    func apply(to m: inout FightModifiers) {
        switch self {
        case .clear, .overcast:
            break
        case .rain:
            m.aggression *= 1.08
            m.runStrength *= 1.05
        case .squall:
            m.aggression *= 1.15
            m.runStrength *= 1.10
            m.tensionPerReel *= 1.04
            m.gain *= 0.97
        case .storm:
            m.aggression *= 1.25
            m.runStrength *= 1.15
            m.tensionPerReel *= 1.08
            m.gain *= 0.93
        }
    }

    /// Odds of each weather at a ground; the open ocean is rougher.
    static func weights(at ground: FishingGround) -> [(Weather, Double)] {
        switch ground {
        case .coastalShelf: return [(.clear, 45), (.overcast, 28), (.rain, 17), (.squall, 8), (.storm, 2)]
        case .canyonEdge: return [(.clear, 38), (.overcast, 26), (.rain, 18), (.squall, 12), (.storm, 6)]
        case .gulfStream: return [(.clear, 30), (.overcast, 24), (.rain, 20), (.squall, 16), (.storm, 10)]
        case .deepTrench: return [(.clear, 26), (.overcast, 24), (.rain, 20), (.squall, 18), (.storm, 12)]
        }
    }

    static func roll(at ground: FishingGround) -> Weather {
        let table = weights(at: ground)
        var pick = GameRandom.value(in: 0...table.reduce(0) { $0 + $1.1 })
        for (weather, weight) in table {
            if pick <= weight { return weather }
            pick -= weight
        }
        return .clear
    }
}
