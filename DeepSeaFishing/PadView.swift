import SwiftUI

/// The iPhone as the Apple TV's controller: find the TV, enter its pairing
/// code, then big Reel In and Ease Line buttons with the fight's haptics.
struct PadView: View {
    var viewModel: GameViewModel

    @State private var code = ""
    @AccessibilityFocusState private var isTitleFocused: Bool

    private var pad: PadClient { viewModel.pad }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("iPhone Controller")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                if case .connected(let tv) = pad.state {
                    connectedControls(tv)
                } else {
                    pairing
                }

                if let problem = pad.problem {
                    Text(problem).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { isTitleFocused = true }
    }

    // MARK: Finding the TV

    private var pairing: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("On the Apple TV, open Controls and choose Use an iPhone as the Controller. It shows a four-digit pairing code. Put the code in below, then pick the Apple TV from the list. Both devices need to be on the same Wi-Fi.")

            TextField("Pairing code from the Apple TV", text: $code)
                .keyboardType(.numberPad)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .frame(minHeight: 44)
                .onChange(of: code) { _, new in code = String(new.filter(\.isNumber).prefix(4)) }

            if case .connecting(let tv) = pad.state {
                Text("Connecting to \(tv)...")
            } else if pad.foundTVs.isEmpty {
                Text("Looking for Apple TVs. Open the controller screen on the TV and it will show up here.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Apple TVs nearby")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(pad.foundTVs, id: \.self) { tv in
                    Button("Connect to \(tv)") {
                        guard code.count == 4 else {
                            AccessibilityNotification.Announcement("Enter the four-digit code from the Apple TV first.").post()
                            return
                        }
                        pad.connect(to: tv, code: code)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                }
            }

            Button("Search Again") { pad.startSearching() }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            Button("Back to Controls") { viewModel.leaveRemotePad() }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
    }

    // MARK: Playing

    private func connectedControls(_ tv: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected to \(tv).")
            Text(pad.fighting ? "Fish on. Reel and ease." : "Waiting for a fish. Choose your target on the Apple TV.")
                .font(.headline)

            Button { pad.send(.reel) } label: {
                Text("Reel In").font(.title).frame(maxWidth: .infinity, minHeight: 130)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Pulls the fish closer, but increases line tension.")

            Button { pad.send(.ease) } label: {
                Text("Ease Line").font(.title).frame(maxWidth: .infinity, minHeight: 130)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Lets out line to relieve tension, but the fish gains ground.")

            Button("Repeat Status") { pad.send(.status) }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)

            if pad.isMotionAvailable {
                Text("Tilt the phone back to reel in and forward to ease the line during a fight.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Recalibrate Tilt") { pad.recalibrateTilt() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }

            Toggle("Speak fight updates on this phone", isOn: Bindable(pad).speakOnPhone)
                .frame(minHeight: 44)

            Button("Disconnect") { viewModel.leaveRemotePad() }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        // Two-finger double-tap anywhere repeats the status, like on the phone game.
        .accessibilityAction(.magicTap) { pad.send(.status) }
    }
}
