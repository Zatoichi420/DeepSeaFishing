import SwiftUI

private struct OnboardingStep {
    let title: String
    let body: String
}

private func onboardingSteps(for viewModel: GameViewModel) -> [OnboardingStep] {
    #if os(tvOS)
    let ways = "On Apple TV, swipe the Siri Remote to move between buttons and click to press one. In a fight, click the pad to reel in, and press Play/Pause on the remote to ease the line. Or use your iPhone as the controller: choose Controls, then Use an iPhone as the Controller, and it gives you big buttons, tilt and the fight's haptics. A game controller works too - see the next step."
    let pad = "Connect an Xbox or PlayStation controller and the fight is on the triggers and bumpers. A and B stay with the system: A presses the focused button and B goes back. "
    #else
    let ways = "Five ways to play, and you can mix them. One: the Reel In and Ease Line buttons on the screen. With VoiceOver, swipe to a button and double-tap it. Two: tilt the phone back to reel in and forward to ease the line, on phones with motion sensors. Three: with VoiceOver, a two-finger double-tap anywhere repeats the fight status. Four: a game controller - see the next step. Five: use this phone as the controller for the Apple TV version, from Controls."
    let pad = "Connect an Xbox or PlayStation controller and the fight works from its buttons. Hold a reel or ease button to keep going, and any reel button also continues past a result screen. "
    #endif
    let layout = viewModel.controlsSummary
    return [
        OnboardingStep(
            title: "Welcome to Deep Sea Fishing",
            body: "Two ways to play. Career: inherit your grandfather's boat, the Marisol, earn your way out to deep water, and chase the legendary marlin he never landed. Quick Run: four casts to land the biggest fish you can."
        ),
        OnboardingStep(
            title: "Pick Your Target",
            body: "Before every cast, choose which fish you're after. Each one fights differently — marlin, sailfish, mahi, and makos make explosive jumping runs, swordfish dive deep, and tuna and wahoo just pull hard and don't let up. You can feel and hear the difference."
        ),
        OnboardingStep(
            title: "Gear Up",
            body: "Real offshore gear differs by species. After choosing your target, pick a gear loadout — the recommended kit is marked. Picking the wrong gear for your fish makes the fight noticeably harder, so match your gear to your target."
        ),
        OnboardingStep(
            title: "The Fight",
            body: "Once you cast and hook a fish, you'll see two meters: how much line you've reeled in, and how much tension is on the line. Reel In to gain ground, but it raises tension. Ease Line to relieve tension, but the fish gains ground back. Get the fish all the way in before the line snaps."
        ),
        OnboardingStep(title: "Ways to Play", body: ways),
        OnboardingStep(
            title: "Controller Buttons",
            body: pad + "Right now: " + layout + " You can look at these any time and change them: choose Controls on the main menu."
        ),
        OnboardingStep(
            title: "Feel It, Don't Just Watch It",
            body: "You'll feel a haptic hum that rises with tension, distinct bursts when a fish makes a run, and a snap or a triumphant tap when the fight ends. A controller with haptics rumbles the same way. You'll hear the waves, the engine, the reel drag and the rod creaking as the line tightens."
        ),
        OnboardingStep(
            title: "Build Your Career",
            body: "In Career mode, you sell your catch at the dock, fill contracts for bonus pay, and spend your money on better tackle, live bait, and upgrades for the Marisol. Every fish earns experience; every level gives you a skill point. Your career saves itself. Your all-time biggest catch is saved too — beat it next time out."
        )
    ]
}

struct OnboardingView: View {
    var viewModel: GameViewModel

    @State private var stepIndex = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    private var steps: [OnboardingStep] { onboardingSteps(for: viewModel) }
    private var step: OnboardingStep { steps[stepIndex] }
    private var isLastStep: Bool { stepIndex == steps.count - 1 }

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

            Text("Step \(stepIndex + 1) of \(steps.count)")
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
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}
