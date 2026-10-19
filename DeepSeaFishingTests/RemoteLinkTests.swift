import XCTest
@testable import DeepSeaFishing

final class RemoteLinkTests: XCTestCase {
    func testMessagesSurviveEncoding() throws {
        for command in [PadCommand.reel, .ease, .status, .tiltReel, .tiltEase] {
            let data = try JSONEncoder().encode(command)
            XCTAssertEqual(try JSONDecoder().decode(PadCommand.self, from: data), command)
        }
        let events: [TVEvent] = [.bite, .run(.deep), .landed, .snapped, .tension(0.42), .stopTension, .fighting(true), .speak("Fish on")]
        for event in events {
            let data = try JSONEncoder().encode(event)
            XCTAssertEqual(try JSONDecoder().decode(TVEvent.self, from: data), event)
        }
    }

    func testPairingCodeIsFourDigits() {
        let code = RemoteHost().pairingCode
        XCTAssertEqual(code.count, 4)
        XCTAssertTrue(code.allSatisfy(\.isNumber))
    }

    /// A phone and a TV in one process find each other, pair with the code,
    /// and pass a command and an event. Skipped if discovery isn't available
    /// in the environment running the tests.
    @MainActor
    func testPhoneAndTVPairAndTalk() async throws {
        let host = RemoteHost()
        let pad = PadClient()
        let gotCommand = expectation(description: "TV got the command")
        host.onCommand = { if $0 == .reel { gotCommand.fulfill() } }
        let spoken = expectation(description: "phone got the speech")
        pad.onSpeak = { if $0 == "Fish on" { spoken.fulfill() } }

        host.startWaiting()
        pad.startSearching()
        defer { pad.disconnect(); host.stop() }

        var found = false
        for _ in 0..<40 where !found {
            try await Task.sleep(nanoseconds: 250_000_000)
            found = !pad.foundTVs.isEmpty
        }
        try XCTSkipUnless(found, "Local discovery isn't available here")

        // A wrong code is refused.
        pad.connect(to: pad.foundTVs[0], code: "not-it")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertFalse(pad.isConnected)
        XCTAssertFalse(host.isConnected)

        pad.startSearching()
        for _ in 0..<40 where pad.foundTVs.isEmpty { try await Task.sleep(nanoseconds: 250_000_000) }
        pad.connect(to: pad.foundTVs[0], code: host.pairingCode)
        for _ in 0..<60 where !(pad.isConnected && host.isConnected) { try await Task.sleep(nanoseconds: 250_000_000) }
        XCTAssertTrue(pad.isConnected)
        XCTAssertTrue(host.isConnected)

        pad.send(.reel)
        host.send(.speak("Fish on"))
        await fulfillment(of: [gotCommand, spoken], timeout: 5)
    }
}
