import XCTest
@testable import DeepSeaFishing

final class ControlSchemeTests: XCTestCase {
    func testDefaultsGiveEveryActionAButton() {
        let scheme = ControlScheme.standard
        for action in ControlAction.allCases {
            XCTAssertFalse(scheme.inputs(for: action).isEmpty, "\(action) has no default button")
        }
        XCTAssertEqual(scheme.action(for: .rightTrigger), .reel)
        XCTAssertEqual(scheme.action(for: .leftTrigger), .ease)
        XCTAssertEqual(scheme.action(for: .y), .status)
    }

    func testNoButtonStartsWithTwoJobs() {
        let scheme = ControlScheme.standard
        var seen = Set<ControllerInput>()
        for action in ControlAction.allCases {
            for input in scheme.inputs(for: action) {
                XCTAssertTrue(seen.insert(input).inserted, "\(input) is bound twice")
            }
        }
    }

    func testReplacingDropsTheOldButtons() {
        var scheme = ControlScheme.standard
        scheme.assign(.x, to: .reel, replacing: true)
        XCTAssertEqual(scheme.inputs(for: .reel), [.x])
    }

    func testAddingKeepsTheOldButtons() {
        var scheme = ControlScheme.standard
        let before = scheme.inputs(for: .status)
        scheme.assign(.x, to: .status, replacing: false)
        XCTAssertEqual(scheme.inputs(for: .status), before + [.x])
    }

    func testTakingAButtonFromAnotherActionIsReported() {
        var scheme = ControlScheme.standard
        scheme.assign(.y, to: .reel, replacing: false)
        XCTAssertEqual(scheme.action(for: .y), .reel)
        XCTAssertTrue(scheme.inputs(for: .status).isEmpty)
        // Taking Y back from status left status empty, which is reported.
        var again = ControlScheme.standard
        let displaced = again.assign(.y, to: .ease, replacing: true)
        XCTAssertEqual(displaced, ControlScheme.Displacement(action: .status, nowEmpty: true))
    }

    func testSchemeSurvivesSaveAndLoad() {
        let defaults = UserDefaults(suiteName: "ControlSchemeTests")!
        defaults.removePersistentDomain(forName: "ControlSchemeTests")
        var scheme = ControlScheme.standard
        scheme.assign(.x, to: .ease, replacing: true)
        scheme.save(to: defaults)
        XCTAssertEqual(ControlScheme.load(from: defaults), scheme)
        defaults.removePersistentDomain(forName: "ControlSchemeTests")
        XCTAssertEqual(ControlScheme.load(from: defaults), .standard)
    }

    func testSummaryNamesEveryAction() {
        let text = ControlScheme.standard.summary { $0.defaultName }
        for action in ControlAction.allCases { XCTAssertTrue(text.contains(action.title)) }
    }
}
