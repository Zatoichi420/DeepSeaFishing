import SwiftUI

struct FightView: View {
    var viewModel: GameViewModel

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            if let fish = viewModel.currentFish {
                FightBanner(fish: fish)

                Text(fish.legendName.map { "Fighting \($0)" } ?? "Fighting a \(fish.species.displayName)")
                    .font(.title2)
                    .bold()
                    .accessibilityFocused($isTitleFocused)
            }

            if !viewModel.isGearMatched {
                Text("Wrong gear — harder fight")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if viewModel.isMotionAvailable {
                Text("Tilt the phone back to reel in, forward to ease the line — or use the buttons.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Tilt calibrates once, automatically, when the fight starts -
                // this is the recovery path if it ends up feeling backwards or
                // stuck, without needing to quit and restart the fight.
                Button("Recalibrate Tilt") {
                    viewModel.recalibrateTilt()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Re-zeroes tilt to however you're currently holding the phone.")
            }

            if let name = viewModel.controllerName {
                Text("\(name). \(viewModel.controlsSummary)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            MeterView(title: "Line to shore", value: viewModel.progress, tint: .green)
            MeterView(title: "Line tension", value: viewModel.tension, tint: .red)

            HStack(spacing: 16) {
                Button("Reel In") {
                    viewModel.reelIn()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Pulls the fish closer, but increases line tension.")

                Button("Ease Line") {
                    viewModel.easeLine()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Lets out line to relieve tension, but the fish gains ground.")
            }
        }
        .onAppear {
            isTitleFocused = true
        }
        // A blind player relying on one-shot spoken announcements has no way
        // to recover one that was missed or talked over - a two-finger double
        // tap re-speaks the current tension/progress/gear-match state on demand.
        .accessibilityAction(.magicTap) {
            viewModel.announceCurrentState()
        }
    }
}

struct MeterView: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The ProgressView below already carries this same title as part
            // of its own accessibilityLabel - without this, VoiceOver reads
            // "Line to shore" then "Line to shore, 45 percent" back to back.
            Text(title)
                .font(.subheadline)
                .accessibilityHidden(true)
            ProgressView(value: value)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(value * 100)) percent")
        }
    }
}
