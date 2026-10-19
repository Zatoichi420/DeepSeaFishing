import SwiftUI

/// Every way to play in one place, what each controller button does, and a way
/// to change the buttons. Reached from the main menu.
struct ControlsView: View {
    var viewModel: GameViewModel

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Controls")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                touchSection
                phoneControllerSection
                controllerSection

                Button("Back to Main Menu") { viewModel.goHome() }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { isTitleFocused = true }
    }

    private var touchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(touchHeading)
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)
            ForEach(touchLines, id: \.self) { line in
                Text(line)
            }
        }
    }

    private var touchHeading: String {
        #if os(tvOS)
        return "Siri Remote"
        #else
        return "Touch, VoiceOver and tilt"
        #endif
    }

    private var touchLines: [String] {
        #if os(tvOS)
        return [
            "Swipe to move between buttons and click to press one.",
            "In a fight, the Reel In button is selected for you. Click the pad to reel in, and press Play/Pause to ease the line, wherever the selection is.",
        ]
        #else
        var lines = [
            "In a fight, the Reel In and Ease Line buttons do the work. Tap them as fast as you like.",
            "With VoiceOver, swipe to a button and double-tap it. A two-finger double-tap anywhere repeats the fight status.",
        ]
        if viewModel.isMotionAvailable {
            lines.append("Tilt the phone back to reel in and forward to ease the line. Recalibrate Tilt on the fight screen re-zeroes it.")
        }
        return lines
        #endif
    }

    @ViewBuilder
    private var phoneControllerSection: some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 12) {
            Text("Use an iPhone as the Controller")
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)
            switch viewModel.remoteHost.state {
            case .off:
                Text("Your iPhone can be the controller, with the fight's haptics in your hand. Both devices need to be on the same Wi-Fi, and the Deep Sea Fishing app has to be open on the iPhone.")
                Button("Start Pairing") { viewModel.startWaitingForPhone() }
                    .buttonStyle(.borderedProminent)
            case .waiting:
                Text("Pairing code: \(viewModel.remoteHost.pairingCode.map(String.init).joined(separator: " "))")
                    .font(.title)
                    .bold()
                    .accessibilityLabel("Pairing code: \(viewModel.remoteHost.pairingCode.map(String.init).joined(separator: ", "))")
                Text("On the iPhone, open Controls, choose Use This iPhone as an Apple TV Controller, enter the code, and pick this Apple TV.")
                Button("Stop Pairing") { viewModel.stopWaitingForPhone() }
                    .buttonStyle(.bordered)
            case .connected(let name):
                Text("\(name) is connected as the controller.")
                Button("Disconnect iPhone") { viewModel.stopWaitingForPhone() }
                    .buttonStyle(.bordered)
            }
        }
        #else
        VStack(alignment: .leading, spacing: 12) {
            Text("Use This iPhone as an Apple TV Controller")
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)
            Text("Play the Apple TV version with this phone: big Reel In and Ease Line buttons, tilt, and the fight's haptics in your hand. Both devices need to be on the same Wi-Fi.")
            Button("Set Up Apple TV Controller") { viewModel.showRemotePad() }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        #endif
    }

    private var controllerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Xbox and PlayStation controllers")
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)

            if let name = viewModel.controllerName {
                Text("Connected: \(name).")
            } else {
                Text("No controller connected. Connect one and these buttons work right away. You can only change them while one is connected, because you change a button by pressing the one you want.")
            }

            #if os(tvOS)
            Text("On Apple TV, A presses the focused button and B goes back, so they can't be given to the game.")
                .foregroundStyle(.secondary)
            #else
            Text("Holding a reel or ease button repeats it. Any reel button also continues past a result screen.")
                .foregroundStyle(.secondary)
            #endif

            ForEach(ControlAction.allCases, id: \.self) { action in
                actionRow(action)
            }

            Button("Reset Buttons to Standard") { viewModel.resetControls() }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
    }

    private func actionRow(_ action: ControlAction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(action.title): \(viewModel.buttonNames(for: action))")
                .font(.headline)
            Text(action.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.remapping == action {
                Text("Press the new button on your controller now.")
                    .foregroundStyle(.orange)
                Button("Cancel") { viewModel.cancelRemap() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            } else {
                HStack(spacing: 12) {
                    Button("Change \(action.title) Button") { viewModel.beginRemap(action, adding: false) }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .disabled(!viewModel.canRemap)
                        .accessibilityHint("Then press the controller button you want. It replaces the current ones.")
                    Button("Add Another") { viewModel.beginRemap(action, adding: true) }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .disabled(!viewModel.canRemap)
                        .accessibilityLabel("Add another \(action.title) button")
                        .accessibilityHint("Then press the controller button you want. The current ones stay.")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
