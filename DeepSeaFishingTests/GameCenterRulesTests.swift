import XCTest
@testable import DeepSeaFishing

final class GameCenterRulesTests: XCTestCase {
    func testAnyFishEarnsFirstFish() {
        let earned = GameCenterRules.achievements(landing: Fish(species: .mahiMahi, weight: 20), alreadyLanded: [])
        XCTAssertEqual(earned, [.firstCatch])
    }

    func testSpeciesAchievements() {
        XCTAssertTrue(GameCenterRules.achievements(landing: Fish(species: .marlin, weight: 200), alreadyLanded: []).contains(.firstMarlin))
        XCTAssertTrue(GameCenterRules.achievements(landing: Fish(species: .swordfish, weight: 200), alreadyLanded: []).contains(.firstSwordfish))
        XCTAssertTrue(GameCenterRules.achievements(landing: Fish(species: .tuna, weight: 200), alreadyLanded: []).contains(.firstBluefin))
    }

    func testWeightMilestones() {
        let big = GameCenterRules.achievements(landing: Fish(species: .marlin, weight: 520), alreadyLanded: [])
        XCTAssertTrue(big.contains(.big500))
        XCTAssertFalse(big.contains(.grander))
        let grander = GameCenterRules.achievements(landing: Fish(species: .marlin, weight: 1_050), alreadyLanded: [])
        XCTAssertTrue(grander.contains(.grander))
    }

    func testFullSpreadNeedsEverySpecies() {
        var seen = Set(FishSpecies.allCases)
        seen.remove(.wahoo)
        XCTAssertFalse(GameCenterRules.achievements(landing: Fish(species: .mako, weight: 100), alreadyLanded: seen).contains(.fullSpread))
        XCTAssertTrue(GameCenterRules.achievements(landing: Fish(species: .wahoo, weight: 30), alreadyLanded: seen).contains(.fullSpread))
    }

    func testLegendAchievements() {
        for legend in Legend.allCases {
            let fish = Fish(species: legend.species, weight: 300, legendName: legend.name)
            let earned = GameCenterRules.achievements(landing: fish, alreadyLanded: [])
            XCTAssertTrue(earned.contains(where: { $0.rawValue.hasPrefix("legend_") }), "\(legend)")
        }
    }

    func testCareerMilestones() {
        var career = Career()
        XCTAssertTrue(GameCenterRules.achievements(for: career).isEmpty)
        career.level = 5
        career.totalEarnings = 10_500
        career.unlockedGrounds.insert(.canyonEdge)
        let earned = GameCenterRules.achievements(for: career)
        XCTAssertTrue(earned.isSuperset(of: [.level5, .earn1000, .earn10000, .groundCanyon]))
        XCTAssertFalse(earned.contains(.level10))
    }

    func testEveryAchievementHasAUniqueIdentifier() {
        let ids = AchievementID.allCases.map(\.rawValue)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.count, 18)
    }
}
