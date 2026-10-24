import XCTest
@testable import DeepSeaFishing

final class WeatherTests: XCTestCase {
    func testFoulWeatherMakesFightsHarder() {
        var rates: [Weather: Double] = [:]
        for weather in Weather.allCases {
            var career = Career.newCareer()
            career.forecast = [FishingGround.coastalShelf.rawValue: weather]
            _ = career.startTrip(to: .coastalShelf)
            rates[weather] = FightBot.landRate(species: .yellowfin, modifiers: { career.modifiers(for: $0, kit: .tunaTrolling) })
        }
        XCTAssertGreaterThanOrEqual(rates[.clear]! + 0.02, rates[.rain]!, "rain shouldn't be easier than clear: \(rates)")
        XCTAssertGreaterThan(rates[.clear]!, rates[.storm]!, "a storm should cost something: \(rates)")
        XCTAssertGreaterThan(rates[.storm]!, 0.5, "but it shouldn't make fish unlandable on the right gear: \(rates)")
    }

    func testStormsPayOffWithBiggerFish() {
        func averageWeight(_ weather: Weather) -> Double {
            GameRandom.generator = SeededGenerator(seed: 4)
            defer { GameRandom.generator = SystemRandomNumberGenerator() }
            var career = Career.newCareer()
            career.forecast = [FishingGround.coastalShelf.rawValue: weather]
            _ = career.startTrip(to: .coastalShelf)
            let total = (0..<2_000).reduce(0.0) { sum, _ in sum + Fish.random(species: .yellowfin, sizeSkew: career.sizeSkew).weight }
            return total / 2_000
        }
        XCTAssertGreaterThan(averageWeight(.storm), averageWeight(.clear))
        XCTAssertGreaterThan(averageWeight(.rain), averageWeight(.clear))
    }

    func testStormShortensTheTripButNeverBelowTwoCasts() {
        var career = Career.newCareer()
        career.forecast = [FishingGround.coastalShelf.rawValue: .storm]
        _ = career.startTrip(to: .coastalShelf)
        XCTAssertEqual(career.trip?.castsLeft, career.castsPerTrip - 1)
        XCTAssertEqual(career.trip?.weather, .storm)

        var calm = Career.newCareer()
        calm.forecast = [FishingGround.coastalShelf.rawValue: .clear]
        _ = calm.startTrip(to: .coastalShelf)
        XCTAssertEqual(calm.trip?.castsLeft, calm.castsPerTrip)
    }

    func testForecastCoversEveryGroundAndRefreshesAfterATrip() {
        GameRandom.generator = SeededGenerator(seed: 2)
        defer { GameRandom.generator = SystemRandomNumberGenerator() }
        var career = Career.newCareer()
        XCTAssertEqual(Set(career.forecast?.keys ?? [:].keys), Set(FishingGround.allCases.map(\.rawValue)))
        var seen = Set<Weather>()
        for _ in 0..<60 {
            _ = career.startTrip(to: .coastalShelf)
            _ = career.endTrip()
            for ground in FishingGround.allCases { seen.insert(career.weather(at: ground)) }
        }
        XCTAssertEqual(seen, Set(Weather.allCases), "every kind of weather should turn up")
    }

    func testOpenOceanIsRougherThanTheShelf() {
        GameRandom.generator = SeededGenerator(seed: 6)
        defer { GameRandom.generator = SystemRandomNumberGenerator() }
        func stormShare(_ ground: FishingGround) -> Double {
            Double((0..<4_000).filter { _ in Weather.roll(at: ground) == .storm }.count) / 4_000
        }
        XCTAssertGreaterThan(stormShare(.deepTrench), stormShare(.coastalShelf) * 3)
    }

    func testOldSavesWithoutWeatherStillLoad() throws {
        var career = Career.newCareer()
        _ = career.startTrip(to: .coastalShelf)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as? [String: Any])
        json.removeValue(forKey: "forecast")
        var trip = try XCTUnwrap(json["trip"] as? [String: Any])
        trip.removeValue(forKey: "weather")
        json["trip"] = trip
        let restored = try JSONDecoder().decode(Career.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.forecast)
        XCTAssertEqual(restored.weather(at: .canyonEdge), .clear)
        XCTAssertNil(restored.trip?.weather)
        var clear = restored
        clear.trip?.weather = .clear
        let fish = Fish(species: .wahoo, weight: 50)
        XCTAssertEqual(restored.modifiers(for: fish, kit: .lightTackle), clear.modifiers(for: fish, kit: .lightTackle))
    }

    func testWeatherRoundTripsThroughJSON() throws {
        var career = Career.newCareer()
        career.forecast?[FishingGround.coastalShelf.rawValue] = .squall
        _ = career.startTrip(to: .coastalShelf)
        let restored = try JSONDecoder().decode(Career.self, from: JSONEncoder().encode(career))
        XCTAssertEqual(restored, career)
        XCTAssertEqual(restored.trip?.weather, .squall)
    }

    func testLegendsStillFallInAllWeather() {
        for weather in Weather.allCases {
            var career = Career.newCareer()
            career.chapter = .scarback
            career.kitTiers[EquipmentKit.tunaTrolling.rawValue] = TackleTier.tournament.rawValue
            career.unlockedGrounds.insert(.canyonEdge)
            career.forecast = [FishingGround.canyonEdge.rawValue: weather]
            career.money = 500
            _ = career.startTrip(to: .canyonEdge)
            let rate = FightBot.legendRate(.scarback, career: career, kit: .tunaTrolling)
            XCTAssertGreaterThan(rate, 0.3, "Scarback on tournament gear in \(weather): \(rate)")
        }
    }
}
