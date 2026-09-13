import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        VStack(spacing: 24) {
            switch viewModel.phase {
            case .onboarding:
                OnboardingView(viewModel: viewModel)
            case .idle:
                IdleView(viewModel: viewModel)
            case .selectingSpecies:
                SpeciesSelectionView(viewModel: viewModel)
            case .selectingGear(let species):
                GearSelectionView(viewModel: viewModel, species: species)
            case .fighting:
                FightView(viewModel: viewModel)
            case .result(let landed):
                ResultView(viewModel: viewModel, landed: landed)
            case .runOver:
                RunOverView(viewModel: viewModel)
            }
        }
        .padding()
        .animation(.default, value: viewModel.phase)
    }
}

struct IdleView: View {
    var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image("OceanWaveImage")
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)

            Text("Deep Sea Fishing")
                .font(.largeTitle)
                .bold()

            Text("\(viewModel.castsRemaining) cast\(viewModel.castsRemaining == 1 ? "" : "s") left this run")
                .font(.headline)

            if let best = viewModel.runBestCatch {
                Text("Best this run: \(best.weightDescription) \(best.species.displayName)")
            }

            if viewModel.allTimeBestWeight > 0, let speciesName = viewModel.allTimeBestSpeciesName {
                Text("All-time best: \(String(format: "%.0f", viewModel.allTimeBestWeight)) lb \(speciesName)")
                    .foregroundStyle(.secondary)
            }

            Button("Choose Your Target") {
                viewModel.beginTargeting()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Pick which fish to go after and gear up before casting.")

            Button("How to Play") {
                viewModel.showOnboarding()
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    ContentView()
}
