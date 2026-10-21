import SwiftUI

struct ResultView: View {
    var viewModel: GameViewModel
    let landed: Bool

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            if let fish = viewModel.currentFish {
                if landed {
                    SpeciesBanner(species: fish.species)

                    Text("Landed!")
                        .font(.largeTitle)
                        .bold()
                        .accessibilityFocused($isTitleFocused)
                    Text("\(fish.weightDescription) \(fish.legendName ?? fish.species.displayName)")
                        .font(.title2)
                } else {
                    Text("It got away")
                        .font(.largeTitle)
                        .bold()
                        .accessibilityFocused($isTitleFocused)
                    Text("The line snapped fighting \(fish.legendName ?? "that \(fish.species.displayName)").")
                        .multilineTextAlignment(.center)
                }
            }

            if viewModel.mode == .career {
                ForEach(viewModel.lastCatchReport.lines.indices, id: \.self) { i in
                    Text(viewModel.lastCatchReport.lines[i])
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button(continueTitle) {
                viewModel.acknowledgeResult()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}

extension ResultView {
    fileprivate var continueTitle: String {
        if viewModel.mode == .career {
            return (viewModel.career?.trip?.castsLeft ?? 0) == 0 ? "Head Back to Port" : "Continue"
        }
        return viewModel.castsRemaining == 0 ? "See Run Results" : "Continue"
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

            Button("Main Menu") {
                viewModel.startRun()
                viewModel.goHome()
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}
