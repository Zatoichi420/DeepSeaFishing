import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        VStack(spacing: 24) {
            switch viewModel.phase {
            case .onboarding:
                OnboardingView(viewModel: viewModel)
            case .home:
                HomeView(viewModel: viewModel)
            case .idle:
                IdleView(viewModel: viewModel)
            case .runOver:
                RunOverView(viewModel: viewModel)
            case .story:
                StoryView(viewModel: viewModel)
            case .dock:
                DockView(viewModel: viewModel)
            case .groundSelect:
                GroundSelectView(viewModel: viewModel)
            case .shop:
                ShopView(viewModel: viewModel)
            case .skills:
                SkillsView(viewModel: viewModel)
            case .logbook:
                LogbookView(viewModel: viewModel)
            case .controls:
                ControlsView(viewModel: viewModel)
            case .remotePad:
                PadView(viewModel: viewModel)
            case .atSea:
                AtSeaView(viewModel: viewModel)
            case .tripSummary:
                TripSummaryView(viewModel: viewModel)
            case .selectingSpecies:
                SpeciesSelectionView(viewModel: viewModel)
            case .selectingGear(let species):
                GearSelectionView(viewModel: viewModel, species: species)
            case .fighting:
                FightView(viewModel: viewModel)
            case .result(let landed):
                ResultView(viewModel: viewModel, landed: landed)
            }
        }
        .padding()
        #if os(tvOS)
        .padding(.horizontal, 60)
        #endif
        .animation(.default, value: viewModel.phase)
    }
}

struct HomeView: View {
    var viewModel: GameViewModel

    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var confirmingNewCareer = false

    var body: some View {
        ScrollView {
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
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                if let career = viewModel.career {
                    Text("Captain of the Marisol. Level \(career.level) angler, \(career.money) dollars. \(career.chapter.title).")
                        .multilineTextAlignment(.center)
                    Button("Continue Career") { viewModel.continueCareer() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                    Button("New Career") { confirmingNewCareer = true }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .accessibilityHint("Starts over from chapter one. Your current career will be lost.")
                } else {
                    Text("Inherit your grandfather's boat, work your way out to deep water, and chase the marlin he never landed.")
                        .multilineTextAlignment(.center)
                    Button("Start Career") { viewModel.startNewCareer() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }

                Button("Quick Run") { viewModel.enterQuickRun() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityHint("The classic game: four casts to land the biggest fish you can.")

                if viewModel.allTimeBestWeight > 0, let speciesName = viewModel.allTimeBestSpeciesName {
                    Text("All-time best: \(String(format: "%.0f", viewModel.allTimeBestWeight)) lb \(speciesName)")
                        .foregroundStyle(.secondary)
                }

                Button("How to Play") { viewModel.showOnboarding() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)

                Button("Leaderboards and Achievements") { viewModel.gameCenter.showDashboard() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityHint(viewModel.gameCenter.isSignedIn ? "Opens Game Center." : "You're not signed in to Game Center.")

                Button("Controls") { viewModel.showControls() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityHint("See what every touch, tilt and controller button does, and change the controller buttons.")
            }
        }
        .alert("Start a new career?", isPresented: $confirmingNewCareer) {
            Button("Start Over", role: .destructive) { viewModel.startNewCareer() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your boat, money, gear, and story progress will be erased.")
        }
        .onAppear { isTitleFocused = true }
    }
}

struct IdleView: View {
    var viewModel: GameViewModel

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image("OceanWaveImage")
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)

            Text("Quick Run")
                .font(.largeTitle)
                .bold()
                .accessibilityFocused($isTitleFocused)

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

            Button("Main Menu") {
                viewModel.goHome()
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Your run is kept - come back any time.")
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}

#Preview {
    ContentView()
}
