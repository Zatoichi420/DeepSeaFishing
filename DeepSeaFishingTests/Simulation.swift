import Foundation
@testable import DeepSeaFishing

/// A stand-in player for headless fights: two actions per half-second tick,
/// reeling until tension *feels* past a comfort line, then easing off. Tension
/// is judged by feel - the haptic hum - so the bot's read of it is noisy, and
/// now and then it reels when it shouldn't, the way an excited human does.
enum FightBot {
    static func fight(_ fish: Fish, modifiers: FightModifiers, comfort: Double = 0.62, actionsPerTick: Int = 2,
                      feelNoise: Double = 0.15, slipChance: Double = 0.12) -> Bool {
        var engine = FightEngine(fish: fish, modifiers: modifiers)
        for _ in 0..<600 {
            for _ in 0..<actionsPerTick {
                let felt = engine.tension + GameRandom.value(in: -feelNoise...feelNoise)
                let slip = GameRandom.unit() < slipChance
                if felt > comfort && !slip {
                    engine.ease()
                } else {
                    engine.reel()
                    switch engine.outcome() {
                    case .landed: return true
                    case .snapped: return false
                    case .ongoing: break
                    }
                }
            }
            let ran = engine.tick()
            switch engine.outcome(allowSnap: !ran) {
            case .landed: return true
            case .snapped: return false
            case .ongoing: break
            }
        }
        return false
    }

    static func landRate(species: FishSpecies, modifiers: (Fish) -> FightModifiers, sizeSkew: Double = 2.5, runs: Int = 400, seed: UInt64 = 1) -> Double {
        GameRandom.generator = SeededGenerator(seed: seed)
        defer { GameRandom.generator = SystemRandomNumberGenerator() }
        var landed = 0
        for _ in 0..<runs {
            let fish = Fish.random(species: species, sizeSkew: sizeSkew)
            if fight(fish, modifiers: modifiers(fish)) { landed += 1 }
        }
        return Double(landed) / Double(runs)
    }

    static func legendRate(_ legend: Legend, career: Career, kit: EquipmentKit, runs: Int = 400, seed: UInt64 = 1) -> Double {
        GameRandom.generator = SeededGenerator(seed: seed)
        defer { GameRandom.generator = SystemRandomNumberGenerator() }
        var landed = 0
        for _ in 0..<runs where fight(legend.fish, modifiers: career.modifiers(for: legend.fish, kit: kit)) { landed += 1 }
        return Double(landed) / Double(runs)
    }
}

/// Plays a whole career headlessly with a sensible shopping and fishing
/// policy, to prove the story can be finished and to measure how long it takes.
enum CareerSim {
    struct Result {
        var career: Career
        var trips: Int
        var chapterStarts: [Int] = []
        var finished: Bool
        var stalled: Bool
    }

    static func play(seed: UInt64, maxTrips: Int = 400) -> Result {
        GameRandom.generator = SeededGenerator(seed: seed)
        defer { GameRandom.generator = SystemRandomNumberGenerator() }
        var career = Career.newCareer()
        var trips = 0
        var brokeTrips = 0
        var chapterStarts: [Int] = []
        var lastChapter = career.chapter

        while career.chapter != .finale, trips < maxTrips {
            career.pendingStory.removeAll()
            spendPoints(&career)
            shop(&career)

            let ground = chooseGround(career)
            guard case .success = career.startTrip(to: ground) else {
                // Can't afford fuel anywhere but the shelf - fish the shelf.
                brokeTrips += 1
                guard case .success = career.startTrip(to: .coastalShelf) else { return Result(career: career, trips: trips, finished: false, stalled: true) }
                continue
            }
            trips += 1
            while let trip = career.trip, trip.castsLeft > 0 {
                let species = chooseTarget(career, ground: trip.ground)
                let kit = career.owns(species.recommendedKit) ? species.recommendedKit : career.ownedKits[0]
                let wantsLegend = career.legendInPlay(ground: trip.ground, species: species) != nil
                let fish = career.hookFish(target: species, useLiveBait: wantsLegend)
                let landed = FightBot.fight(fish, modifiers: career.modifiers(for: fish, kit: kit))
                _ = career.recordFight(fish, landed: landed)
            }
            _ = career.endTrip()
            if career.chapter != lastChapter { chapterStarts.append(trips); lastChapter = career.chapter }
        }
        return Result(career: career, trips: trips, chapterStarts: chapterStarts, finished: career.chapter == .finale, stalled: false)
    }

    private static func spendPoints(_ career: inout Career) {
        let order: [AnglerSkill] = [.finesse, .strength, .instinct, .salesmanship, .fishSense]
        while career.skillPoints > 0 {
            guard let skill = order.min(by: { career.rank($0) < career.rank($1) }), career.rank(skill) < AnglerSkill.maxRank else { break }
            _ = career.spendSkillPoint(on: skill)
        }
    }

    /// Kits the current chapter needs, then upgrades for the chapter's kit,
    /// then boat upgrades, then live bait for a legend hunt. Always keeps
    /// enough back for fuel.
    private static func shop(_ career: inout Career) {
        let reserve = 150
        let neededKit: EquipmentKit? = {
            switch career.chapter {
            case .scarback: return .tunaTrolling
            case .tournament, .ironjaw: return .marlinTrolling
            case .grayGhost: return .swordfishDeepDrop
            default: return nil
            }
        }()
        var bought = true
        while bought {
            bought = false
            if let kit = neededKit, let price = career.nextUpgradePrice(for: kit), career.money - price >= reserve {
                if !career.owns(kit) || (career.tier(of: kit)?.rawValue ?? 0) < 3 || career.money - price > 1500 {
                    if case .success = career.buyOrUpgrade(kit) { bought = true; continue }
                }
            }
            for upgrade in [BoatUpgrade.fightingChair, .outriggers, .fishFinder, .biggerTank] where !career.boatUpgrades.contains(upgrade) && career.money - upgrade.price >= reserve + 300 {
                if case .success = career.buy(upgrade) { bought = true; break }
            }
        }
        if career.chapter.legend != nil, career.liveBait < 3, career.money - Bait.livePackPrice >= reserve {
            _ = career.buyLiveBait()
        }
    }

    private static func chooseGround(_ career: Career) -> FishingGround {
        if let legend = career.chapter.legend, career.owns(legend.species.recommendedKit), career.money >= legend.ground.fuelCost {
            return legend.ground
        }
        if career.chapter == .tournament, career.owns(.marlinTrolling) { return .gulfStream }
        // Otherwise the richest ground the boat can afford to reach.
        return career.unlockedGrounds.filter { career.money >= $0.fuelCost + 60 }.max { $0.fuelCost < $1.fuelCost } ?? .coastalShelf
    }

    private static func chooseTarget(_ career: Career, ground: FishingGround) -> FishSpecies {
        if let legend = career.chapter.legend, legend.ground == ground { return legend.species }
        if career.chapter == .tournament, ground == .gulfStream, career.owns(.marlinTrolling) { return .marlin }
        let owned = ground.species.filter { career.owns($0.recommendedKit) }
        let pool = owned.isEmpty ? ground.species : owned
        return pool.max { expectedValue($0, career) < expectedValue($1, career) } ?? ground.species[0]
    }

    private static func expectedValue(_ species: FishSpecies, _ career: Career) -> Double {
        let mid = (species.weightRange.lowerBound * 2 + species.weightRange.upperBound) / 3
        return Double(career.value(of: Fish(species: species, weight: mid)))
    }
}
