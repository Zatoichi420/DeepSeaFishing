import XCTest
@testable import DeepSeaFishing

final class AudioAssetTests: XCTestCase {
    private let loops = ["fish_waves_a", "fish_waves_b", "fish_engine", "fish_rigging", "fish_drag"]
    private let oneShots = [
        "fish_cast", "fish_clicker", "fish_creak", "fish_gaff", "fish_gulls",
        "fish_jump", "fish_slap", "fish_snap", "fish_tailwalk", "fish_thrash",
    ]

    func testEveryBundledLoopIsPresent() {
        for name in loops {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "wav"), "\(name).wav missing from the app bundle")
        }
    }

    func testEveryBundledOneShotIsPresent() {
        for name in oneShots {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "m4a"), "\(name).m4a missing from the app bundle")
        }
    }

    func testSceneAndEventCallsAreSafeBeforeAndAfterStart() {
        let audio = AudioManager()
        // Before start() nothing may crash.
        audio.setScene(.fighting, ground: .deepTrench)
        audio.playCast()
        audio.updateTension(0.9)
        audio.start()
        for ground in FishingGround.allCases {
            audio.setScene(.harbor, ground: ground)
            audio.setScene(.atSea, ground: ground)
            audio.setScene(.fighting, ground: ground)
            audio.updateTension(0.95)
            audio.playRun(for: .marlin)
            audio.playRun(for: .swordfish)
            audio.playRun(for: .tuna)
        }
        audio.playLanded()
        audio.playSnap()
        audio.stopFight()
    }
}
