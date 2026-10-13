import XCTest
@testable import DeepSeaFishing

final class FightBalanceTests: XCTestCase {
    func testQuickRunKeepsTheOriginalFight() {
        XCTAssertEqual(FightModifiers.original, FightModifiers())
        XCTAssertEqual(FishSpecies.quickRun, [.tuna, .marlin, .swordfish])
        XCTAssertEqual(EquipmentKit.quickRun, [.tunaTrolling, .marlinTrolling, .swordfishDeepDrop])
        for species in FishSpecies.quickRun {
            XCTAssertGreaterThan(FightBot.landRate(species: species, modifiers: { _ in .original }), 0.85)
        }
    }

    func testWrongGearIsHarderForEverySpecies() {
        let career = Career.newCareer()
        for species in FishSpecies.allCases {
            let right = FightBot.landRate(species: species, modifiers: { career.modifiers(for: $0, kit: species.recommendedKit) }, runs: 300)
            let wrongKit = EquipmentKit.allCases.first { $0 != species.recommendedKit }!
            let wrong = FightBot.landRate(species: species, modifiers: { career.modifiers(for: $0, kit: wrongKit) }, runs: 300)
            XCTAssertGreaterThan(right, wrong, "\(species): right gear \(right) vs wrong \(wrong)")
        }
    }

    func testLegendsNeedUpgradedTackle() {
        for legend in Legend.allCases {
            var stock = Career.newCareer()
            stock.kitTiers[legend.species.recommendedKit.rawValue] = 1
            var tournament = stock
            tournament.kitTiers[legend.species.recommendedKit.rawValue] = 3
            for skill in AnglerSkill.allCases { tournament.skills[skill.rawValue] = 3 }
            let low = FightBot.legendRate(legend, career: stock, kit: legend.species.recommendedKit, runs: 300)
            let high = FightBot.legendRate(legend, career: tournament, kit: legend.species.recommendedKit, runs: 300)
            XCTAssertGreaterThan(high, 0.85, "\(legend) should be very landable with tournament tackle")
            XCTAssertLessThan(low, high - 0.3, "\(legend): upgrades must matter")
        }
        var ironjawStock = Career.newCareer()
        ironjawStock.kitTiers[EquipmentKit.marlinTrolling.rawValue] = 1
        XCTAssertLessThan(FightBot.legendRate(.ironjaw, career: ironjawStock, kit: .marlinTrolling), 0.15,
                          "the final legend should be near-impossible on stock gear")
    }
}

final class CareerTests: XCTestCase {
    override func tearDown() {
        GameRandom.generator = SystemRandomNumberGenerator()
        super.tearDown()
    }

    func testANewCareer() {
        let c = Career.newCareer()
        XCTAssertEqual(c.money, 150)
        XCTAssertEqual(c.chapter, .marisol)
        XCTAssertEqual(c.unlockedGrounds, [.coastalShelf])
        XCTAssertEqual(Set(c.ownedKits), [.lightTackle, .tunaTrolling])
        XCTAssertEqual(c.pendingStory.first?.title, "The Marisol")
        XCTAssertEqual(c.contracts.count, 3)
        XCTAssertTrue(c.contracts.allSatisfy { FishingGround.coastalShelf.species.contains($0.species) })
    }

    func testEveryGroundOffersOnlyKnownSpecies() {
        for ground in FishingGround.allCases {
            XCTAssertFalse(ground.species.isEmpty)
        }
        for legend in Legend.allCases {
            XCTAssertTrue(legend.ground.species.contains(legend.species), "\(legend) must be targetable on its own ground")
        }
    }

    func testLockedGroundsAndFuel() {
        var c = Career.newCareer()
        XCTAssertEqual(c.startTrip(to: .gulfStream), .failure(.locked))
        c.unlockedGrounds.insert(.deepTrench)
        c.money = 10
        XCTAssertEqual(c.startTrip(to: .deepTrench), .failure(.cantAffordFuel))
        guard case .success = c.startTrip(to: .coastalShelf) else { return XCTFail() }
        XCTAssertEqual(c.trip?.castsLeft, 4)
        XCTAssertEqual(c.startTrip(to: .coastalShelf), .failure(.alreadyOut))
    }

    func testTripSellsTheHoldAndPaysContracts() {
        GameRandom.generator = SeededGenerator(seed: 3)
        var c = Career.newCareer()
        c.contracts = [Contract(id: "t", client: "Test", species: .mahiMahi, minimumWeight: 20, reward: 75)]
        _ = c.startTrip(to: .coastalShelf)
        let mahi = Fish(species: .mahiMahi, weight: 30)
        let report = c.recordFight(mahi, landed: true)
        XCTAssertTrue(report.lines.contains { $0.contains("fills Test's contract") })
        XCTAssertEqual(c.trip?.castsLeft, 3)
        _ = c.recordFight(Fish(species: .wahoo, weight: 40), landed: false)
        XCTAssertEqual(c.trip?.lost, 1)

        let before = c.money
        let trip = c.endTrip()
        let expected = Int(30 * FishSpecies.mahiMahi.pricePerPound) + 75
        XCTAssertEqual(trip.earned, expected)
        XCTAssertEqual(c.money, before + expected)
        XCTAssertNil(c.trip)
        XCTAssertEqual(c.contracts.count, 3, "contracts refill at the dock")
        XCTAssertEqual(c.logEntry(.mahiMahi).landed, 1)
        XCTAssertEqual(c.logEntry(.mahiMahi).bestWeight, 30)
    }

    func testBillfishAreReleasedForAFee() {
        let c = Career.newCareer()
        let sail = Fish(species: .sailfish, weight: 100)
        XCTAssertEqual(c.value(of: sail), Int(30 + 0.35 * 100))
        var out = c
        _ = out.startTrip(to: .coastalShelf)
        let report = out.recordFight(sail, landed: true)
        XCTAssertTrue(report.lines.contains { $0.contains("tag and release") })
    }

    func testLevelsGiveSkillPointsAndSkillsCap() {
        var c = Career.newCareer()
        _ = c.startTrip(to: .coastalShelf)
        // A 60 lb mahi is 48 experience.
        for _ in 0..<4 { _ = c.recordFight(Fish(species: .mahiMahi, weight: 60), landed: true) }
        XCTAssertEqual(c.level, 2)
        XCTAssertEqual(c.skillPoints, 1)
        XCTAssertTrue(c.spendSkillPoint(on: .finesse).contains("rank 1"))
        XCTAssertEqual(c.skillPoints, 0)
        XCTAssertTrue(c.spendSkillPoint(on: .finesse).contains("don't have"))
        c.skillPoints = 10
        for _ in 0..<10 { _ = c.spendSkillPoint(on: .strength) }
        XCTAssertEqual(c.rank(.strength), AnglerSkill.maxRank)
        XCTAssertEqual(c.skillPoints, 5)
    }

    func testSkillsAndTiersChangeTheFight() {
        var c = Career.newCareer()
        let fish = Fish(species: .yellowfin, weight: 100)
        let base = c.modifiers(for: fish, kit: .tunaTrolling)
        c.skills[AnglerSkill.strength.rawValue] = 2
        c.kitTiers[EquipmentKit.tunaTrolling.rawValue] = 3
        let better = c.modifiers(for: fish, kit: .tunaTrolling)
        XCTAssertGreaterThan(better.gain, base.gain)
        XCTAssertLessThan(better.tensionPerReel, base.tensionPerReel)
        XCTAssertLessThan(better.runStrength, base.runStrength)
    }

    func testShop() {
        var c = Career.newCareer()
        XCTAssertEqual(c.buyOrUpgrade(.marlinTrolling), .failure(.notEnoughMoney(needed: 450)))
        c.money = 2_000
        guard case .success = c.buyOrUpgrade(.marlinTrolling) else { return XCTFail() }
        XCTAssertEqual(c.tier(of: .marlinTrolling), .stock)
        guard case .success = c.buyOrUpgrade(.marlinTrolling) else { return XCTFail() }
        XCTAssertEqual(c.tier(of: .marlinTrolling), .pro)
        XCTAssertEqual(c.money, 2_000 - 450 - 300)
        guard case .success = c.buyLiveBait() else { return XCTFail() }
        XCTAssertEqual(c.liveBait, 3)
        guard case .success = c.buy(.biggerTank) else { return XCTFail() }
        XCTAssertEqual(c.buy(.biggerTank), .failure(.alreadyOwned))
        XCTAssertEqual(c.castsPerTrip, 5)
        c.kitTiers[EquipmentKit.lightTackle.rawValue] = 4
        XCTAssertEqual(c.buyOrUpgrade(.lightTackle), .failure(.maxed))
    }

    func testLegendsOnlyBiteInTheirChapterAndPlace() {
        var c = Career.newCareer()
        XCTAssertNil(c.legendInPlay(ground: .canyonEdge, species: .tuna), "not before chapter 2")
        c.chapter = .scarback
        XCTAssertEqual(c.legendInPlay(ground: .canyonEdge, species: .tuna), .scarback)
        XCTAssertNil(c.legendInPlay(ground: .gulfStream, species: .tuna))
        XCTAssertNil(c.legendInPlay(ground: .canyonEdge, species: .yellowfin))
        c.legendsLanded.insert(.scarback)
        XCTAssertNil(c.legendInPlay(ground: .canyonEdge, species: .tuna), "a landed legend never bites again")
    }

    func testLandingALegendAdvancesTheStory() {
        var c = Career.newCareer()
        c.pendingStory.removeAll()
        c.chapter = .scarback
        c.unlockedGrounds.insert(.canyonEdge)
        _ = c.startTrip(to: .canyonEdge)
        _ = c.recordFight(Legend.scarback.fish, landed: true)
        XCTAssertEqual(c.chapter, .tournament)
        XCTAssertTrue(c.unlockedGrounds.contains(.gulfStream))
        XCTAssertEqual(c.pendingStory.first?.title, "Old Scarback")
        let trip = c.endTrip()
        XCTAssertGreaterThanOrEqual(trip.earned, Legend.scarback.bounty)
    }

    func testTheTournamentNeedsABigMarlin() {
        var c = Career.newCareer()
        c.chapter = .tournament
        c.unlockedGrounds.insert(.gulfStream)
        c.money = 500
        _ = c.startTrip(to: .gulfStream)
        _ = c.recordFight(Fish(species: .marlin, weight: 400), landed: true)
        XCTAssertEqual(c.chapter, .tournament)
        _ = c.recordFight(Fish(species: .marlin, weight: 600), landed: true)
        XCTAssertEqual(c.chapter, .grayGhost)
        XCTAssertTrue(c.unlockedGrounds.contains(.deepTrench))
    }

    func testChapterOneEndsOnEarnings() {
        var c = Career.newCareer()
        c.totalEarnings = Career.chapterOneEarnings - 10
        _ = c.startTrip(to: .coastalShelf)
        _ = c.recordFight(Fish(species: .mahiMahi, weight: 40), landed: true)
        _ = c.endTrip()
        XCTAssertEqual(c.chapter, .scarback)
        XCTAssertTrue(c.unlockedGrounds.contains(.canyonEdge))
    }

    func testCareerRoundTripsThroughJSON() throws {
        GameRandom.generator = SeededGenerator(seed: 9)
        var c = Career.newCareer()
        c.money = 777
        c.skills[AnglerSkill.instinct.rawValue] = 2
        c.boatUpgrades.insert(.fishFinder)
        _ = c.startTrip(to: .coastalShelf)
        _ = c.recordFight(Fish(species: .wahoo, weight: 55), landed: true)
        let restored = try JSONDecoder().decode(Career.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(restored, c)
    }

    func testWholeCareersCanBeFinished() {
        var trips: [Int] = []
        for seed in UInt64(0)..<20 {
            let result = CareerSim.play(seed: seed)
            XCTAssertFalse(result.stalled, "seed \(seed) stalled")
            XCTAssertTrue(result.finished, "seed \(seed) didn't finish: chapter \(result.career.chapter)")
            trips.append(result.trips)
        }
        trips.sort()
        let median = trips[trips.count / 2]
        XCTAssertGreaterThanOrEqual(median, 8, "the story shouldn't be over in a handful of trips")
        XCTAssertLessThanOrEqual(trips.last ?? 0, 40, "nor should it be a grind")
    }
}
