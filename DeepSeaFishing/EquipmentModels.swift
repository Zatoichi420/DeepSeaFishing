import Foundation

/// Real-world offshore tackle loadouts. Each maps to how that species is
/// actually targeted, so picking the wrong kit isn't just cosmetic.
enum EquipmentKit: String, CaseIterable, Codable {
    case tunaTrolling
    case marlinTrolling
    case swordfishDeepDrop
    case lightTackle

    /// The three outfits the original arcade run offered.
    static let quickRun: [EquipmentKit] = [.tunaTrolling, .marlinTrolling, .swordfishDeepDrop]

    var displayName: String {
        switch self {
        case .lightTackle: return "Light Tackle Outfit"
        case .tunaTrolling: return "Trolling Outfit"
        case .marlinTrolling: return "Heavy Trolling Outfit"
        case .swordfishDeepDrop: return "Daytime Deep-Drop Outfit"
        }
    }

    var rod: String {
        switch self {
        case .lightTackle: return "20–30 lb class spinning or conventional rod"
        case .tunaTrolling: return "50–80 lb class trolling rod"
        case .marlinTrolling: return "50–130 lb class stand-up or bent-butt rod"
        case .swordfishDeepDrop: return "80–100 lb class rod with a soft tip and bent butt"
        }
    }

    var reel: String {
        switch self {
        case .lightTackle: return "Large spinning reel or small lever-drag reel, smooth drag"
        case .tunaTrolling: return "Lever-drag conventional reel (Shimano Tiagra / Penn International 50)"
        case .marlinTrolling: return "Large-capacity lever-drag reel, 600–900m line capacity"
        case .swordfishDeepDrop: return "Electric deep-drop reel (Lindgren-Pitman / Hooker Electric)"
        }
    }

    var line: String {
        switch self {
        case .lightTackle: return "30 lb braid with a 40–60 lb fluorocarbon leader"
        case .tunaTrolling: return "50–80 lb mono topshot over braided backing"
        case .marlinTrolling: return "Straight braid or mono backing with a long wind-on mono leader"
        case .swordfishDeepDrop: return "80 lb braided line with a 100–150 ft fluorocarbon leader"
        }
    }

    var bait: String {
        switch self {
        case .lightTackle: return "Live pilchards, small skirted lures, or a kite-flown goggle-eye"
        case .tunaTrolling: return "Skirted trolling lure or rigged ballyhoo on a circle hook"
        case .marlinTrolling: return "Large skirted lure spread or rigged ballyhoo"
        case .swordfishDeepDrop: return "Rigged squid or bonito strip bait with glow lights on the leader"
        }
    }

    var summary: String {
        switch self {
        case .lightTackle: return "Lighter gear for mahi, wahoo, and sailfish - more sport, and fish this size can't break it if you're careful."
        case .tunaTrolling: return "Standard offshore trolling gear for running down tuna at speed."
        case .marlinTrolling: return "Stout gear built for a marlin's long, violent runs and jumps."
        case .swordfishDeepDrop: return "Swordfish sit 1,500–2,000 ft down by day — an electric reel does the lifting a hand crank can't."
        }
    }
}

extension FishSpecies {
    var recommendedKit: EquipmentKit {
        switch self {
        case .tuna, .yellowfin: return .tunaTrolling
        case .marlin, .mako: return .marlinTrolling
        case .swordfish: return .swordfishDeepDrop
        case .mahiMahi, .wahoo, .sailfish: return .lightTackle
        }
    }
}

// MARK: - Career tackle

/// How good an outfit is. Every kit starts at Stock and can be upgraded at
/// the tackle shop - better reels gain line faster, better drags and line
/// build tension slower, and better rods soak up a fish's runs.
enum TackleTier: Int, Codable, CaseIterable, Comparable {
    case stock = 1, pro, tournament, custom

    static func < (a: TackleTier, b: TackleTier) -> Bool { a.rawValue < b.rawValue }

    var displayName: String {
        switch self {
        case .stock: return "Stock"
        case .pro: return "Pro"
        case .tournament: return "Tournament"
        case .custom: return "Custom Grander"
        }
    }

    var next: TackleTier? { TackleTier(rawValue: rawValue + 1) }

    /// Price to upgrade *to* this tier.
    var upgradePrice: Int {
        switch self {
        case .stock: return 0
        case .pro: return 300
        case .tournament: return 850
        case .custom: return 1_900
        }
    }

    var reelPowerBonus: Double { 0.12 * Double(rawValue - 1) }
    var dragBonus: Double { 0.08 * Double(rawValue - 1) }
    var rodBonus: Double { 0.07 * Double(rawValue - 1) }

    var effectSummary: String {
        guard self != .stock else { return "Factory gear." }
        return "Reels \(Int(reelPowerBonus * 100)) percent faster, builds \(Int(dragBonus * 100)) percent less tension, and softens runs by \(Int(rodBonus * 100)) percent."
    }
}

extension EquipmentKit {
    /// What it costs to buy this outfit at all, if you don't start with it.
    var purchasePrice: Int {
        switch self {
        case .lightTackle, .tunaTrolling: return 0
        case .marlinTrolling: return 450
        case .swordfishDeepDrop: return 650
        }
    }
}

/// Premium bait - one used per cast when chosen.
enum Bait: String, Codable, CaseIterable {
    case standard
    case liveBait

    var displayName: String {
        switch self {
        case .standard: return "Rigged ballyhoo"
        case .liveBait: return "Live bait"
        }
    }

    var summary: String {
        switch self {
        case .standard: return "Free and always on board."
        case .liveBait: return "Fresh-caught and kicking. Bigger fish bite it, and legends can't resist it."
        }
    }

    /// Price for a pack of three.
    static let livePackPrice = 45
    static let livePackSize = 3
}

/// One-time upgrades to the Marisol herself.
enum BoatUpgrade: String, Codable, CaseIterable {
    case biggerTank
    case fishFinder
    case outriggers
    case fightingChair

    var displayName: String {
        switch self {
        case .biggerTank: return "Long-range fuel tank"
        case .fishFinder: return "Color fish finder"
        case .outriggers: return "Outriggers"
        case .fightingChair: return "Fighting chair"
        }
    }

    var summary: String {
        switch self {
        case .biggerTank: return "One more cast every trip."
        case .fishFinder: return "Shows where the big ones are holding - bigger fish, more often."
        case .outriggers: return "Spreads the bait wider. Legends find your lines more often."
        case .fightingChair: return "A proper chair and harness. Every fight builds a little less tension."
        }
    }

    var price: Int {
        switch self {
        case .biggerTank: return 500
        case .fishFinder: return 700
        case .outriggers: return 400
        case .fightingChair: return 900
        }
    }
}
