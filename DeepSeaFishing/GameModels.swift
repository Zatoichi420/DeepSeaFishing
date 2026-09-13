import Foundation

enum FishSpecies: CaseIterable {
    case tuna
    case marlin
    case swordfish

    var displayName: String {
        switch self {
        case .tuna: return "Bluefin Tuna"
        case .marlin: return "Blue Marlin"
        case .swordfish: return "Swordfish"
        }
    }

    var weightRange: ClosedRange<Double> {
        switch self {
        case .tuna: return 50...800
        case .marlin: return 100...1200
        case .swordfish: return 80...600
        }
    }

    /// Chance per tick that the fish makes a run, spiking line tension.
    var aggression: Double {
        switch self {
        case .tuna: return 0.30
        case .marlin: return 0.45
        case .swordfish: return 0.25
        }
    }

    /// How much tension a single run adds.
    var runStrength: ClosedRange<Double> {
        switch self {
        case .tuna: return 0.08...0.16
        case .marlin: return 0.10...0.22
        case .swordfish: return 0.14...0.28
        }
    }

    var runDescription: String {
        switch self {
        case .tuna: return "digs in and pulls hard"
        case .marlin: return "tailwalks across the surface"
        case .swordfish: return "dives for the depths"
        }
    }

    /// Asset catalog name of this species' reference image.
    var imageName: String {
        switch self {
        case .tuna: return "TunaImage"
        case .marlin: return "MarlinImage"
        case .swordfish: return "SwordfishImage"
        }
    }
}

struct Fish {
    let species: FishSpecies
    let weight: Double

    static func random(species: FishSpecies) -> Fish {
        let range = species.weightRange
        // Skewed low so trophy-size fish stay rare and exciting.
        let skew = pow(Double.random(in: 0...1), 2.5)
        let weight = range.lowerBound + (range.upperBound - range.lowerBound) * skew
        return Fish(species: species, weight: weight)
    }

    var weightDescription: String {
        String(format: "%.0f lb", weight)
    }
}
