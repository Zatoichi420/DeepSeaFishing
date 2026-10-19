import Foundation
import GameController

/// Xbox and PlayStation (and any other extended gamepad) support. What each
/// button does comes from a `ControlScheme` the player can change.
///
/// On Apple TV, A and B keep their normal menu roles (press the focused button,
/// go back), so they are never given to the game there.
final class ControllerManager {
    var onReel: (() -> Void)?
    var onEase: (() -> Void)?
    var onStatus: (() -> Void)?
    /// A reel button pressed (iPhone only): used to continue past a result screen.
    var onConfirm: (() -> Void)?
    /// Called with the controller's name when one connects, or nil when the last one leaves.
    var onConnectionChange: ((String?) -> Void)?

    var scheme = ControlScheme.standard
    /// Haptics on the active controller, or nil if it has none.
    private(set) var rumble: HapticsManager?
    var isConnected: Bool { active != nil }

    private var active: GCController?
    private var reelHeld = Set<ControllerInput>()
    private var easeHeld = Set<ControllerInput>()
    private var repeatTimer: Timer?
    private var remoteEaseHeld = false
    private var captureHandler: ((ControllerInput) -> Void)?
    /// Held inputs repeat at this interval - close to a brisk tapping pace.
    private let repeatInterval: TimeInterval = 0.3

    func start() {
        let center = NotificationCenter.default
        center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.attach(controller)
        }
        center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.detach(controller)
        }
        for existing in GCController.controllers() { attach(existing) }
    }

    /// The button's name as this controller labels it (Cross on a PlayStation
    /// pad, A on an Xbox pad), falling back to the Xbox name.
    func displayName(for input: ControllerInput) -> String {
        if let name = element(for: input, on: active?.extendedGamepad)?.localizedName, !name.isEmpty {
            return name
        }
        return input.defaultName
    }

    /// The next press of any bindable button is handed to `handler` instead of
    /// being played, so the player can remap by pressing the button they want.
    func captureNextPress(_ handler: @escaping (ControllerInput) -> Void) { captureHandler = handler }
    func cancelCapture() { captureHandler = nil }

    // MARK: - Connection

    private func attach(_ controller: GCController) {
        #if os(tvOS)
        // The Siri Remote: its click already presses the focused button (Reel In
        // in a fight), so Play/Pause is free to ease the line from anywhere.
        if controller.extendedGamepad == nil, let remote = controller.microGamepad {
            remote.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                guard let self else { return }
                self.remoteEaseHeld = pressed
                if pressed { self.onEase?() }
                self.updateRepeat()
            }
            return
        }
        #endif
        guard active == nil, let pad = controller.extendedGamepad else { return }
        active = controller

        for input in ControllerInput.bindable {
            element(for: input, on: pad)?.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.handle(input, pressed: pressed)
            }
        }

        if let engine = controller.haptics?.createEngine(withLocality: .default) {
            rumble = HapticsManager(engine: engine)
        }
        onConnectionChange?(controller.vendorName ?? "Game controller")
    }

    private func detach(_ controller: GCController) {
        guard controller === active else { return }
        active = nil
        rumble?.stopTension()
        rumble = nil
        captureHandler = nil
        reelHeld.removeAll()
        easeHeld.removeAll()
        updateRepeat()
        // A second pad may already be connected.
        if let other = GCController.controllers().first(where: { $0 !== controller && $0.extendedGamepad != nil }) {
            attach(other)
        } else {
            onConnectionChange?(nil)
        }
    }

    private func element(for input: ControllerInput, on pad: GCExtendedGamepad?) -> GCControllerButtonInput? {
        guard let pad else { return nil }
        switch input {
        case .a: return pad.buttonA
        case .b: return pad.buttonB
        case .x: return pad.buttonX
        case .y: return pad.buttonY
        case .leftBumper: return pad.leftShoulder
        case .rightBumper: return pad.rightShoulder
        case .leftTrigger: return pad.leftTrigger
        case .rightTrigger: return pad.rightTrigger
        }
    }

    // MARK: - Input

    private func handle(_ input: ControllerInput, pressed: Bool) {
        if pressed, let capture = captureHandler {
            captureHandler = nil
            capture(input)
            return
        }
        guard pressed else {
            reelHeld.remove(input)
            easeHeld.remove(input)
            updateRepeat()
            return
        }
        switch scheme.action(for: input) {
        case .reel:
            reelHeld.insert(input)
            onReel?()
            #if !os(tvOS)
            onConfirm?()
            #endif
        case .ease:
            easeHeld.insert(input)
            onEase?()
        case .status:
            onStatus?()
        case nil:
            break
        }
        updateRepeat()
    }

    private func updateRepeat() {
        let holding = !reelHeld.isEmpty || !easeHeld.isEmpty || remoteEaseHeld
        if holding, repeatTimer == nil {
            repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                if !self.reelHeld.isEmpty { self.onReel?() }
                if !self.easeHeld.isEmpty || self.remoteEaseHeld { self.onEase?() }
            }
        } else if !holding {
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
    }
}
