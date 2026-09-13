import Foundation

/// Real-world offshore tackle loadouts. Each maps to how that species is
/// actually targeted, so picking the wrong kit isn't just cosmetic.
enum EquipmentKit: CaseIterable {
    case tunaTrolling
    case marlinTrolling
    case swordfishDeepDrop

    var displayName: String {
        switch self {
        case .tunaTrolling: return "Trolling Outfit"
        case .marlinTrolling: return "Heavy Trolling Outfit"
        case .swordfishDeepDrop: return "Daytime Deep-Drop Outfit"
        }
    }

    var rod: String {
        switch self {
        case .tunaTrolling: return "50–80 lb class trolling rod"
        case .marlinTrolling: return "50–130 lb class stand-up or bent-butt rod"
        case .swordfishDeepDrop: return "80–100 lb class rod with a soft tip and bent butt"
        }
    }

    var reel: String {
        switch self {
        case .tunaTrolling: return "Lever-drag conventional reel (Shimano Tiagra / Penn International 50)"
        case .marlinTrolling: return "Large-capacity lever-drag reel, 600–900m line capacity"
        case .swordfishDeepDrop: return "Electric deep-drop reel (Lindgren-Pitman / Hooker Electric)"
        }
    }

    var line: String {
        switch self {
        case .tunaTrolling: return "50–80 lb mono topshot over braided backing"
        case .marlinTrolling: return "Straight braid or mono backing with a long wind-on mono leader"
        case .swordfishDeepDrop: return "80 lb braided line with a 100–150 ft fluorocarbon leader"
        }
    }

    var bait: String {
        switch self {
        case .tunaTrolling: return "Skirted trolling lure or rigged ballyhoo on a circle hook"
        case .marlinTrolling: return "Large skirted lure spread or rigged ballyhoo"
        case .swordfishDeepDrop: return "Rigged squid or bonito strip bait with glow lights on the leader"
        }
    }

    var summary: String {
        switch self {
        case .tunaTrolling: return "Standard offshore trolling gear for running down tuna at speed."
        case .marlinTrolling: return "Stout gear built for a marlin's long, violent runs and jumps."
        case .swordfishDeepDrop: return "Swordfish sit 1,500–2,000 ft down by day — an electric reel does the lifting a hand crank can't."
        }
    }
}

extension FishSpecies {
    var recommendedKit: EquipmentKit {
        switch self {
        case .tuna: return .tunaTrolling
        case .marlin: return .marlinTrolling
        case .swordfish: return .swordfishDeepDrop
        }
    }

    var blurb: String {
        switch self {
        case .tuna: return "Fast and powerful, usually hooked trolling near the surface."
        case .marlin: return "The showboat — blistering runs and spectacular jumps."
        case .swordfish: return "A deep-dwelling giant that hides 1,500+ feet down by day."
        }
    }
}
