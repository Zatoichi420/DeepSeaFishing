import Foundation

// MARK: - Skills and levels

enum AnglerSkill: String, Codable, CaseIterable {
    case strength, finesse, instinct, fishSense, salesmanship

    static let maxRank = 5

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .finesse: return "Finesse"
        case .instinct: return "Instinct"
        case .fishSense: return "Fish Sense"
        case .salesmanship: return "Salesmanship"
        }
    }

    var summary: String {
        switch self {
        case .strength: return "Each rank reels in 5 percent faster."
        case .finesse: return "Each rank builds 5 percent less tension when reeling, and easing off relieves 5 percent more."
        case .instinct: return "Each rank softens a fish's runs by 6 percent - you see them coming."
        case .fishSense: return "Each rank makes big fish bite a little more often."
        case .salesmanship: return "Each rank earns 8 percent more at the dock."
        }
    }
}

enum AnglerLevels {
    /// Total experience for each level, index 0 = level 1.
    static let thresholds = [0, 150, 400, 750, 1_200, 1_800, 2_600, 3_600, 4_900, 6_500]
    static var maxLevel: Int { thresholds.count }

    static func xpForNext(after level: Int) -> Int? {
        level < maxLevel ? thresholds[level] : nil
    }
}

// MARK: - Logbook, contracts, story

struct LogEntry: Codable, Equatable {
    var landed = 0
    var bestWeight = 0.0
}

/// A charter client's request posted at the dock: land a fish of a given
/// kind and size, and get paid a bonus on top of the sale.
struct Contract: Codable, Equatable, Identifiable {
    var id: String
    var client: String
    var species: FishSpecies
    var minimumWeight: Double
    var reward: Int

    var summary: String {
        "\(client) wants a \(species.displayName) of at least \(Int(minimumWeight)) pounds. Pays \(reward) dollars."
    }
}

enum Chapter: Int, Codable, CaseIterable, Comparable {
    case marisol = 1
    case scarback
    case tournament
    case grayGhost
    case ironjaw
    case finale

    static func < (a: Chapter, b: Chapter) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .marisol: return "Chapter 1: The Marisol"
        case .scarback: return "Chapter 2: Old Scarback"
        case .tournament: return "Chapter 3: The Harbor Tournament"
        case .grayGhost: return "Chapter 4: The Gray Ghost"
        case .ironjaw: return "Chapter 5: Ironjaw"
        case .finale: return "Epilogue"
        }
    }

    /// The goal, spoken at the dock.
    var goal: String {
        switch self {
        case .marisol: return "Earn \(Career.chapterOneEarnings) dollars at the dock to pay for the Marisol's repairs."
        case .scarback: return "Find Old Scarback, the giant bluefin of the Canyon Edge, and land him."
        case .tournament: return "Win the Harbor Tournament: land a blue marlin over \(Int(Career.tournamentMarlinWeight)) pounds in the Gulf Stream."
        case .grayGhost: return "Land the Gray Ghost, the swordfish of the Deep Trench."
        case .ironjaw: return "Find Ironjaw in the Gulf Stream - and finish what your grandfather started."
        case .finale: return "The sea is yours. Chase records, fill the logbook, and fish for the joy of it."
        }
    }

    var legend: Legend? {
        switch self {
        case .scarback: return .scarback
        case .grayGhost: return .grayGhost
        case .ironjaw: return .ironjaw
        default: return nil
        }
    }
}

struct StoryBeat: Codable, Equatable {
    var title: String
    var paragraphs: [String]
}

// MARK: - Trip

struct Trip: Codable, Equatable {
    var ground: FishingGround
    var castsLeft: Int
    var catches: [Fish] = []
    var lost = 0
    var contractsFilled: [Contract] = []
}

/// What happened when a fight ended - narrated, and shown on the result screen.
struct CatchReport: Equatable {
    var lines: [String] = []
    var leveledUp = false
    var newRecord = false
}

struct TripReport: Equatable {
    var lines: [String] = []
    var earned = 0
}

// MARK: - Career

/// The whole career, saved as one JSON file. Pure rules - no UI, audio, or
/// haptics - so the test suite can play whole seasons headlessly.
struct Career: Codable, Equatable {
    static let startingMoney = 150
    static let chapterOneEarnings = 1_200
    static let tournamentMarlinWeight = 520.0

    var money = Career.startingMoney
    var xp = 0
    var level = 1
    var skillPoints = 0
    var skills: [String: Int] = [:]
    var kitTiers: [String: Int] = [EquipmentKit.lightTackle.rawValue: 1, EquipmentKit.tunaTrolling.rawValue: 1]
    var liveBait = 0
    var boatUpgrades: Set<BoatUpgrade> = []
    var chapter: Chapter = .marisol
    var unlockedGrounds: Set<FishingGround> = [.coastalShelf]
    var legendsLanded: Set<Legend> = []
    var logbook: [String: LogEntry] = [:]
    var totalEarnings = 0
    var contracts: [Contract] = []
    var trip: Trip?
    var pendingStory: [StoryBeat] = []
    var contractCounter = 0

    static func newCareer() -> Career {
        var career = Career()
        career.pendingStory = [StoryBeats.prologue]
        career.refreshContracts()
        return career
    }

    // MARK: Queries

    func rank(_ skill: AnglerSkill) -> Int { skills[skill.rawValue] ?? 0 }
    func tier(of kit: EquipmentKit) -> TackleTier? { kitTiers[kit.rawValue].flatMap(TackleTier.init(rawValue:)) }
    func owns(_ kit: EquipmentKit) -> Bool { tier(of: kit) != nil }
    var ownedKits: [EquipmentKit] { EquipmentKit.allCases.filter(owns) }
    var castsPerTrip: Int { 4 + (boatUpgrades.contains(.biggerTank) ? 1 : 0) }
    func logEntry(_ species: FishSpecies) -> LogEntry { logbook[species.rawValue] ?? LogEntry() }

    var sizeSkew: Double {
        2.5 - 0.15 * Double(rank(.fishSense)) - (boatUpgrades.contains(.fishFinder) ? 0.35 : 0)
    }

    /// The legend that could take the bait right now, if any.
    func legendInPlay(ground: FishingGround, species: FishSpecies) -> Legend? {
        guard let legend = chapter.legend, !legendsLanded.contains(legend),
              legend.ground == ground, legend.species == species else { return nil }
        return legend
    }

    func modifiers(for fish: Fish, kit: EquipmentKit) -> FightModifiers {
        var m = FightModifiers()
        if kit != fish.species.recommendedKit { m.applyMismatch() }
        let tier = tier(of: kit) ?? .stock
        m.gain *= 1 + tier.reelPowerBonus
        m.tensionPerReel *= 1 - tier.dragBonus
        m.runStrength *= 1 - tier.rodBonus

        m.gain *= 1 + 0.05 * Double(rank(.strength))
        m.tensionPerReel *= 1 - 0.05 * Double(rank(.finesse))
        m.easeRelief *= 1 + 0.05 * Double(rank(.finesse))
        m.runStrength *= 1 - 0.06 * Double(rank(.instinct))
        if boatUpgrades.contains(.fightingChair) { m.tensionPerReel *= 0.93 }

        // Bigger fish take longer to bring in.
        m.gain *= 1.1 - 0.35 * fish.sizeFraction
        if let legend = Legend(named: fish.legendName) {
            m.gain *= 0.65
            m.aggression *= 1.3
            m.runStrength *= legend.ferocity
            m.drift = 0.012
        }
        return m
    }

    /// Dollars a fish brings at the dock, before nothing - legends pay a bounty.
    func value(of fish: Fish) -> Int {
        let sales = 1 + 0.08 * Double(rank(.salesmanship))
        if let name = fish.legendName, let legend = Legend.allCases.first(where: { $0.name == name }) {
            return Int(Double(legend.bounty) * sales)
        }
        if fish.species.isCatchAndRelease {
            let fee = fish.species.releaseFee
            return Int((fee.flat + fee.perPound * fish.weight) * sales)
        }
        return Int(fish.weight * fish.species.pricePerPound * sales)
    }

    func experience(for fish: Fish) -> Int {
        if fish.legendName != nil { return 400 }
        return max(8, Int(fish.weight * fish.species.xpPerPound))
    }

    // MARK: Trips

    enum TripError: Error, Equatable { case locked, cantAffordFuel, alreadyOut }

    mutating func startTrip(to ground: FishingGround) -> Result<String, TripError> {
        guard trip == nil else { return .failure(.alreadyOut) }
        guard unlockedGrounds.contains(ground) else { return .failure(.locked) }
        guard money >= ground.fuelCost else { return .failure(.cantAffordFuel) }
        money -= ground.fuelCost
        trip = Trip(ground: ground, castsLeft: castsPerTrip)
        let fuel = ground.fuelCost > 0 ? " Fuel cost \(ground.fuelCost) dollars." : ""
        return .success("The Marisol heads for \(ground.displayName).\(fuel) You have \(castsPerTrip) casts. \(ground.description)")
    }

    /// Picks what bites when you cast for `species`. Uses one live bait if
    /// asked and you have one.
    mutating func hookFish(target species: FishSpecies, useLiveBait: Bool) -> Fish {
        let live = useLiveBait && liveBait > 0
        if live { liveBait -= 1 }
        if let trip, let legend = legendInPlay(ground: trip.ground, species: species) {
            let chance = 0.05 + (live ? 0.10 : 0) + (boatUpgrades.contains(.outriggers) ? 0.05 : 0)
            if GameRandom.unit() < chance { return legend.fish }
        }
        return Fish.random(species: species, sizeSkew: sizeSkew - (live ? 0.5 : 0))
    }

    /// Records a fight's end. Spends the cast; on a landing, logs the fish,
    /// grants experience, checks contracts, and advances the story.
    mutating func recordFight(_ fish: Fish, landed: Bool) -> CatchReport {
        var report = CatchReport()
        if let left = trip?.castsLeft { trip?.castsLeft = max(0, left - 1) }
        guard landed else {
            trip?.lost += 1
            if fish.legendName != nil {
                report.lines.append("\(fish.legendName!) is gone - for now. Legends come back.")
            }
            return report
        }

        trip?.catches.append(fish)
        var entry = logEntry(fish.species)
        entry.landed += 1
        if fish.weight > entry.bestWeight {
            report.newRecord = entry.landed > 1 || entry.bestWeight > 0
            entry.bestWeight = fish.weight
        }
        logbook[fish.species.rawValue] = entry

        let value = value(of: fish)
        if fish.species.isCatchAndRelease && fish.legendName == nil {
            report.lines.append("You tag and release it. The release fee is \(value) dollars.")
        } else {
            report.lines.append("It'll fetch about \(value) dollars at the dock.")
        }
        if report.newRecord { report.lines.append("A new personal best \(fish.species.displayName)!") }

        if let index = contracts.firstIndex(where: { $0.species == fish.species && fish.weight >= $0.minimumWeight }) {
            let contract = contracts.remove(at: index)
            trip?.contractsFilled.append(contract)
            report.lines.append("That fills \(contract.client)'s contract - \(contract.reward) dollars when you dock.")
        }

        let levelLines = gainExperience(experience(for: fish))
        report.leveledUp = !levelLines.isEmpty
        report.lines.append(contentsOf: levelLines)

        if let name = fish.legendName, let legend = Legend.allCases.first(where: { $0.name == name }) {
            legendsLanded.insert(legend)
            advanceStory(after: legend)
        } else if chapter == .tournament, fish.species == .marlin, fish.weight >= Career.tournamentMarlinWeight {
            advance(to: .grayGhost, unlocking: .deepTrench, beat: StoryBeats.tournamentWon)
        }
        if !pendingStory.isEmpty {
            report.lines.append("Something has changed. You'll hear the rest back at the dock.")
        }
        return report
    }

    /// Back at the dock: sell the hold, pay contracts, check the story.
    mutating func endTrip() -> TripReport {
        guard let trip else { return TripReport() }
        var report = TripReport()
        var earned = 0
        for fish in trip.catches { earned += value(of: fish) }
        let contractPay = trip.contractsFilled.map(\.reward).reduce(0, +)
        earned += contractPay
        money += earned
        totalEarnings += earned
        report.earned = earned

        if trip.catches.isEmpty {
            report.lines.append("You come home with an empty hold.\(trip.lost > 0 ? " \(trip.lost) got away." : "")")
        } else {
            let names = trip.catches.map { "a \($0.weightDescription) \($0.legendName ?? $0.species.displayName)" }
            report.lines.append("You bring home \(names.joined(separator: ", ")).")
            if contractPay > 0 { report.lines.append("Contracts pay \(contractPay) dollars.") }
            report.lines.append("You earn \(earned) dollars. You have \(money).")
        }

        if chapter == .marisol, totalEarnings >= Career.chapterOneEarnings {
            advance(to: .scarback, unlocking: .canyonEdge, beat: StoryBeats.marisolRepaired)
        }
        self.trip = nil
        refreshContracts()
        return report
    }

    // MARK: Progression

    private mutating func gainExperience(_ amount: Int) -> [String] {
        xp += amount
        var lines = ["You gain \(amount) experience."]
        while level < AnglerLevels.maxLevel, xp >= AnglerLevels.thresholds[level] {
            level += 1
            skillPoints += 1
            lines.append("Level up! You're now a level \(level) angler, with a skill point to spend at the dock.")
        }
        return lines
    }

    mutating func spendSkillPoint(on skill: AnglerSkill) -> String {
        guard skillPoints > 0 else { return "You don't have a skill point to spend." }
        guard rank(skill) < AnglerSkill.maxRank else { return "\(skill.displayName) is already at its highest rank." }
        skillPoints -= 1
        skills[skill.rawValue] = rank(skill) + 1
        return "\(skill.displayName) is now rank \(rank(skill)). \(skillPoints) point\(skillPoints == 1 ? "" : "s") left."
    }

    private mutating func advanceStory(after legend: Legend) {
        switch legend {
        case .scarback: advance(to: .tournament, unlocking: .gulfStream, beat: StoryBeats.scarbackLanded)
        case .grayGhost: advance(to: .ironjaw, unlocking: nil, beat: StoryBeats.grayGhostLanded)
        case .ironjaw: advance(to: .finale, unlocking: nil, beat: StoryBeats.ironjawLanded)
        }
    }

    private mutating func advance(to next: Chapter, unlocking ground: FishingGround?, beat: StoryBeat) {
        guard next > chapter else { return }
        chapter = next
        if let ground { unlockedGrounds.insert(ground) }
        pendingStory.append(beat)
    }

    // MARK: Shop

    enum ShopError: Error, Equatable { case notEnoughMoney(needed: Int), maxed, notOwned, alreadyOwned }

    func nextUpgradePrice(for kit: EquipmentKit) -> Int? {
        guard let tier = tier(of: kit) else { return kit.purchasePrice }
        return tier.next?.upgradePrice
    }

    mutating func buyOrUpgrade(_ kit: EquipmentKit) -> Result<String, ShopError> {
        guard let price = nextUpgradePrice(for: kit) else { return .failure(.maxed) }
        guard money >= price else { return .failure(.notEnoughMoney(needed: price)) }
        money -= price
        if let tier = tier(of: kit), let next = tier.next {
            kitTiers[kit.rawValue] = next.rawValue
            return .success("Your \(kit.displayName) is now \(next.displayName) grade. \(next.effectSummary) You have \(money) dollars.")
        }
        kitTiers[kit.rawValue] = TackleTier.stock.rawValue
        return .success("You buy a \(kit.displayName). You have \(money) dollars.")
    }

    mutating func buyLiveBait() -> Result<String, ShopError> {
        guard money >= Bait.livePackPrice else { return .failure(.notEnoughMoney(needed: Bait.livePackPrice)) }
        money -= Bait.livePackPrice
        liveBait += Bait.livePackSize
        return .success("You buy \(Bait.livePackSize) live bait. You have \(liveBait), and \(money) dollars.")
    }

    mutating func buy(_ upgrade: BoatUpgrade) -> Result<String, ShopError> {
        guard !boatUpgrades.contains(upgrade) else { return .failure(.alreadyOwned) }
        guard money >= upgrade.price else { return .failure(.notEnoughMoney(needed: upgrade.price)) }
        money -= upgrade.price
        boatUpgrades.insert(upgrade)
        return .success("The \(upgrade.displayName) is installed. \(upgrade.summary) You have \(money) dollars.")
    }

    // MARK: Contracts

    private static let clients = ["Mrs. Okafor's restaurant", "The Harbor Fish Market", "A tourist from Ohio", "Captain Reyes", "The Seaside Hotel", "Old Benny at the bait shop", "A food truck called Fin and Tonic"]

    /// Keeps three open contracts, drawn from the grounds you can reach.
    mutating func refreshContracts() {
        let available = unlockedGrounds.flatMap(\.species).filter { !$0.isCatchAndRelease }
        let pool = Array(Set(available)).sorted { $0.rawValue < $1.rawValue }
        guard !pool.isEmpty else { return }
        while contracts.count < 3 {
            contractCounter += 1
            let species = pool[GameRandom.int(in: 0...(pool.count - 1))]
            let range = species.weightRange
            let fraction = GameRandom.value(in: 0.12...0.4)
            let minimum = (range.lowerBound + (range.upperBound - range.lowerBound) * fraction).rounded()
            let base = minimum * species.pricePerPound
            let reward = Int((base * 0.8 + 40) / 5) * 5
            let client = Self.clients[GameRandom.int(in: 0...(Self.clients.count - 1))]
            contracts.append(Contract(id: "c\(contractCounter)", client: client, species: species, minimumWeight: minimum, reward: reward))
        }
    }
}

extension Legend {
    init?(named name: String?) {
        guard let match = Legend.allCases.first(where: { $0.name == name }) else { return nil }
        self = match
    }

    /// How much harder each legend's runs hit - they get worse as the story goes.
    var ferocity: Double {
        switch self {
        case .scarback: return 1.15
        case .grayGhost: return 1.25
        case .ironjaw: return 1.35
        }
    }

    var bounty: Int {
        switch self {
        case .scarback: return 900
        case .grayGhost: return 1_400
        case .ironjaw: return 2_500
        }
    }
}

// MARK: - The story

enum StoryBeats {
    static let prologue = StoryBeat(title: "The Marisol", paragraphs: [
        "Your grandfather, Elias Vance, fished out of Port Salvage for fifty-one years. When he passed, he left you three things: a forty-foot sportfisher called the Marisol, a logbook full of his handwriting, and a hook he never got back.",
        "The Marisol has more rust than paint. Nell, the harbormaster, looks her over and sighs. \"Engine's sound. Outriggers are shot, and she'll never make the canyon like this. Earn enough to fix her up, and I'll sign her off for deep water.\"",
        "On the last page of Elias's logbook, in shaking capitals: IRONJAW. 1979. GULF STREAM. HE TOOK MY HOOK AND MY BEST YEARS. Under it, smaller: Maybe you'll be luckier.",
        "Start on the Coastal Shelf. Mahi, wahoo, and yellowfin will pay the bills."
    ])

    static let marisolRepaired = StoryBeat(title: "Deep Water", paragraphs: [
        "Nell signs off on the Marisol with a flourish. \"She'll make the canyon now. And listen - the old-timers are talking. Something big has been busting bait at the Canyon Edge. A bluefin with a white scar down his side. They call him Old Scarback.\"",
        "Elias wrote about him too: Scarback, canyon, 2003, straightened two hooks. Bring live bait. He's too smart for dead.",
        "The Canyon Edge is open. Land Old Scarback."
    ])

    static let scarbackLanded = StoryBeat(title: "Old Scarback", paragraphs: [
        "The whole harbor turns out to see Scarback hanging from the scale. Nine hundred and eighty pounds. Somebody's taking photos. Nell is grinning.",
        "Then a voice from the next slip: Dax Ferro, captain of the Black Pearl, all sunglasses and gold chain. \"Nice tuna, kid. Lucky. The Harbor Tournament's next week, out in the Gulf Stream. Real fishermen catch marlin. I landed a five-twenty last year.\"",
        "The Gulf Stream is open. Win the tournament: land a blue marlin bigger than Dax's \(Int(Career.tournamentMarlinWeight)) pounds. You'll want heavy trolling gear from the tackle shop."
    ])

    static let tournamentWon = StoryBeat(title: "The Harbor Tournament", paragraphs: [
        "The tournament board goes up at sunset, and your name is on top. Dax Ferro tears up his entry slip and walks off without a word. Nell buys everyone a round.",
        "Later, an old man you don't know sits down beside you on the dock. \"I fished with Elias,\" he says. \"He told me once that the biggest swordfish he ever saw was in the Deep Trench, at night, pale as a ghost. Never could get one up from two thousand feet. You'd need an electric reel.\"",
        "The Deep Trench is open. Land the Gray Ghost. The tackle shop sells deep-drop outfits."
    ])

    static let grayGhostLanded = StoryBeat(title: "The Gray Ghost", paragraphs: [
        "It takes an hour to bring the Gray Ghost up from the dark. When it finally breaks the surface, pale silver in the deck lights, even you go quiet.",
        "Back at the dock, you open Elias's logbook to the last page and read it again. IRONJAW. 1979. GULF STREAM. You've caught everything else he ever wrote about.",
        "Nell finds you there. \"The charter boats saw a marlin in the Stream yesterday,\" she says carefully. \"Big as a skiff. Something shiny in its jaw.\"",
        "Find Ironjaw in the Gulf Stream. Live bait helps. So does the best gear money can buy."
    ])

    static let ironjawLanded = StoryBeat(title: "Ironjaw", paragraphs: [
        "When Ironjaw finally comes alongside, you can see it plainly: a rusted hook, forty-seven years in that jaw, Elias's own initials still scratched into the shank.",
        "You don't kill him. You work the old hook free, hold him in the water until his color comes back, and let him go. He hangs beside the Marisol for a long moment, then slides down into the blue.",
        "That night you write in the logbook, under your grandfather's last entry: IRONJAW. GULF STREAM. GOT YOUR HOOK BACK. LET HIM GO. I think you'd have done the same.",
        "Your story is done, but the sea isn't. Keep fishing - fill the logbook, chase records, and spend what you've earned."
    ])
}

// MARK: - Saving

/// One career save, as JSON in Application Support, written atomically. A
/// file that won't decode is treated as no save rather than a crash.
enum CareerStore {
    private static var url: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("DeepSeaFishing-career.json")
    }

    static func save(_ career: Career) {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(career).write(to: url, options: .atomic)
        } catch {
            print("[CareerStore] save failed: \(error)")
        }
    }

    static func load() -> Career? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Career.self, from: data)
    }

    static func delete() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
