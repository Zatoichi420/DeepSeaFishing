import SwiftUI

struct ResultView: View {
    var viewModel: GameViewModel
    let landed: Bool

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            if let fish = viewModel.currentFish {
                if landed {
                    Image(fish.species.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)

                    Text("Landed!")
                        .font(.largeTitle)
                        .bold()
                        .accessibilityFocused($isTitleFocused)
                    Text("\(fish.weightDescription) \(fish.species.displayName)")
                        .font(.title2)
                } else {
                    Text("It got away")
                        .font(.largeTitle)
                        .bold()
                        .accessibilityFocused($isTitleFocused)
                    Text("The line snapped fighting that \(fish.species.displayName).")
                        .multilineTextAlignment(.center)
                }
            }

            Button(viewModel.castsRemaining == 0 ? "See Run Results" : "Continue") {
                viewModel.acknowledgeResult()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}

struct RunOverView: View {
    var viewModel: GameViewModel

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Run Complete")
                .font(.largeTitle)
                .bold()
                .accessibilityFocused($isTitleFocused)

            if let best = viewModel.runBestCatch {
                Text("Your biggest catch: \(best.weightDescription) \(best.species.displayName)")
            } else {
                Text("No fish landed this run.")
            }

            Text("All-time best: \(String(format: "%.0f", viewModel.allTimeBestWeight)) lb \(viewModel.allTimeBestSpeciesName ?? "—")")
                .foregroundStyle(.secondary)

            Button("New Run") {
                viewModel.startRun()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}
