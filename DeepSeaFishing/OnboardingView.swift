import SwiftUI

private struct OnboardingStep {
    let title: String
    let body: String
}

private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        title: "Welcome to Deep Sea Fishing",
        body: "You're competing to land the single biggest fish you can. Each run gives you a handful of casts — make them count."
    ),
    OnboardingStep(
        title: "Pick Your Target",
        body: "Before every cast, choose which fish you're after: Tuna, Marlin, or Swordfish. Each one fights differently — marlin makes explosive runs, swordfish dives deep and holds steady tension, tuna just pulls hard and doesn't let up."
    ),
    OnboardingStep(
        title: "Gear Up",
        body: "Real offshore gear differs by species. After choosing your target, pick a gear loadout — the recommended kit is marked. Picking the wrong gear for your fish makes the fight noticeably harder, so match your gear to your target."
    ),
    OnboardingStep(
        title: "The Fight",
        body: "Once you cast and hook a fish, you'll see two meters: how much line you've reeled in, and how much tension is on the line. Reel In to gain ground, but it raises tension. Ease Line to relieve tension, but the fish gains ground back. Get the fish all the way in before the line snaps."
    ),
    OnboardingStep(
        title: "Feel It, Don't Just Watch It",
        body: "Tilt your phone back to reel in and forward to ease the line — the on-screen buttons do the same thing, so use whichever feels natural. You'll feel a haptic hum that rises with tension, distinct bursts when a fish makes a run, and a snap or a triumphant tap when the fight ends."
    ),
    OnboardingStep(
        title: "Chase the Record",
        body: "Land a fish and its weight becomes your best catch for the run. Your all-time biggest catch is saved on this device — beat it next time out."
    )
]

struct OnboardingView: View {
    var viewModel: GameViewModel

    @State private var stepIndex = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    private var step: OnboardingStep { onboardingSteps[stepIndex] }
    private var isLastStep: Bool { stepIndex == onboardingSteps.count - 1 }

    var body: some View {
        VStack(spacing: 20) {
            if stepIndex == 0 {
                Image("OceanWaveImage")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
            }

            Text("Step \(stepIndex + 1) of \(onboardingSteps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(step.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityFocused($isTitleFocused)

            Text(step.body)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            HStack(spacing: 16) {
                if stepIndex > 0 {
                    Button("Back") {
                        stepIndex -= 1
                        isTitleFocused = true
                    }
                    .buttonStyle(.bordered)
                }

                if isLastStep {
                    Button("Start Fishing") {
                        viewModel.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Next") {
                        stepIndex += 1
                        isTitleFocused = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if !isLastStep {
                Button("Skip") {
                    viewModel.completeOnboarding()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}
