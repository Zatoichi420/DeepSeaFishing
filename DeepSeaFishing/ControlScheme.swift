import Foundation

/// A physical input on an Xbox, PlayStation or other extended gamepad. The names
/// are the Xbox ones; PlayStation pads report their own (Cross, Circle, L1...).
enum ControllerInput: String, CaseIterable, Codable {
    case a, b, x, y
    case leftBumper, rightBumper
    case leftTrigger, rightTrigger

    var defaultName: String {
        switch self {
        case .a: "A"
        case .b: "B"
        case .x: "X"
        case .y: "Y"
        case .leftBumper: "Left Bumper"
        case .rightBumper: "Right Bumper"
        case .leftTrigger: "Left Trigger"
        case .rightTrigger: "Right Trigger"
        }
    }

    /// On Apple TV the system uses A to press the focused button and B to go
    /// back, so those two can't be given to the game.
    var isReserved: Bool {
        #if os(tvOS)
        return self == .a || self == .b
        #else
        return false
        #endif
    }

    static var bindable: [ControllerInput] { allCases.filter { !$0.isReserved } }
}

enum ControlAction: String, CaseIterable, Codable {
    case reel, ease, status

    var title: String {
        switch self {
        case .reel: "Reel In"
        case .ease: "Ease Line"
        case .status: "Repeat Status"
        }
    }

    var explanation: String {
        switch self {
        case .reel: "Pulls the fish closer. Hold it to keep reeling. On the iPhone it also continues past a result screen."
        case .ease: "Lets out line to relieve tension. Hold it to keep easing."
        case .status: "Says the fish, line progress and tension out loud again."
        }
    }
}

/// Which controller inputs do what. Saved on the device; the player can change it.
struct ControlScheme: Codable, Equatable {
    private(set) var reel: [ControllerInput]
    private(set) var ease: [ControllerInput]
    private(set) var status: [ControllerInput]

    /// What `assign` took away from another action, so the screen can say so.
    struct Displacement: Equatable {
        let action: ControlAction
        let nowEmpty: Bool
    }

    static var standard: ControlScheme {
        ControlScheme(
            reel: [.a, .rightTrigger, .rightBumper].filter { !$0.isReserved },
            ease: [.b, .leftTrigger, .leftBumper].filter { !$0.isReserved },
            status: [.y]
        )
    }

    func inputs(for action: ControlAction) -> [ControllerInput] {
        switch action {
        case .reel: reel
        case .ease: ease
        case .status: status
        }
    }

    func action(for input: ControllerInput) -> ControlAction? {
        ControlAction.allCases.first { inputs(for: $0).contains(input) }
    }

    /// Gives `input` to `action`. With `replacing`, the action's other buttons are
    /// dropped; otherwise the button is added. A button only ever does one thing,
    /// so it is taken from whichever action had it.
    @discardableResult
    mutating func assign(_ input: ControllerInput, to action: ControlAction, replacing: Bool) -> Displacement? {
        guard !input.isReserved else { return nil }
        var displaced: Displacement?
        if let owner = self.action(for: input), owner != action {
            set(inputs(for: owner).filter { $0 != input }, for: owner)
            displaced = Displacement(action: owner, nowEmpty: inputs(for: owner).isEmpty)
        }
        var updated = replacing ? [] : inputs(for: action)
        if !updated.contains(input) { updated.append(input) }
        set(updated, for: action)
        return displaced
    }

    private mutating func set(_ inputs: [ControllerInput], for action: ControlAction) {
        switch action {
        case .reel: reel = inputs
        case .ease: ease = inputs
        case .status: status = inputs
        }
    }

    /// "Reel In: A, Right Trigger. Ease Line: ..." using the given button names.
    func summary(name: (ControllerInput) -> String) -> String {
        ControlAction.allCases.map { action in
            let names = inputs(for: action).map(name)
            return "\(action.title): " + (names.isEmpty ? "no button" : names.joined(separator: ", ")) + "."
        }.joined(separator: " ")
    }

    // MARK: - Saving

    private static let key = "DeepSeaFishing.controlScheme"

    static func load(from defaults: UserDefaults = .standard) -> ControlScheme {
        guard let data = defaults.data(forKey: key),
              var scheme = try? JSONDecoder().decode(ControlScheme.self, from: data) else { return .standard }
        // Drop anything this platform reserves, and any button listed twice.
        var seen = Set<ControllerInput>()
        for action in ControlAction.allCases {
            let clean = scheme.inputs(for: action).filter { !$0.isReserved && seen.insert($0).inserted }
            scheme.set(clean, for: action)
        }
        return scheme
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
