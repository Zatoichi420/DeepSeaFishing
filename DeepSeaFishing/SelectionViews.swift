import SwiftUI

struct SpeciesSelectionView: View {
    var viewModel: GameViewModel

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("What are you targeting?")
                .font(.title)
                .bold()
                .accessibilityFocused($isTitleFocused)

            ForEach(viewModel.targetableSpecies, id: \.self) { species in
                Button {
                    viewModel.selectSpecies(species)
                } label: {
                    HStack(spacing: 12) {
                        Image(species.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(species.displayName)
                                .font(.headline)
                            Text(species.blurb)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let legend = legendHere(species) {
                                Text("\(legend.name.capitalizedFirst) hunts these waters.")
                                    .font(.subheadline)
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }

            Button("Back") {
                viewModel.cancelTargeting()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .onAppear {
            isTitleFocused = true
        }
    }

    private func legendHere(_ species: FishSpecies) -> Legend? {
        guard viewModel.mode == .career, let career = viewModel.career, let ground = career.trip?.ground else { return nil }
        return career.legendInPlay(ground: ground, species: species)
    }
}

struct GearSelectionView: View {
    var viewModel: GameViewModel
    let species: FishSpecies

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(species.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)

                Text("Gearing up for \(species.displayName)")
                    .font(.title2)
                    .bold()
                    .accessibilityFocused($isTitleFocused)

                ForEach(viewModel.availableKits, id: \.self) { kit in
                    Button {
                        viewModel.selectKit(kit)
                    } label: {
                        KitCard(
                            kit: kit,
                            isSelected: viewModel.selectedKit == kit,
                            isRecommended: kit == species.recommendedKit,
                            tier: viewModel.mode == .career ? viewModel.career?.tier(of: kit) : nil
                        )
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.mode == .career, let career = viewModel.career, career.liveBait > 0 {
                    @Bindable var model = viewModel
                    Toggle("Use live bait, \(career.liveBait) left", isOn: $model.useLiveBait)
                        .accessibilityHint(Bait.liveBait.summary)
                }

                if !viewModel.isGearMatched {
                    Text("Wrong gear for this fish — the fight will be tougher.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Button("Cast Line") {
                    viewModel.cast()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Casts your line using the selected gear.")

                Button("Back") {
                    viewModel.beginTargeting()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Choose a different fish.")
            }
            .padding(.bottom)
        }
        // The "Wrong gear" text above appears/disappears as kit buttons are
        // tapped, but nothing told VoiceOver it changed - a blind player only
        // found out by happening to swipe back over that spot afterward.
        .onChange(of: viewModel.selectedKit) { _, _ in
            if !viewModel.isGearMatched {
                AccessibilityNotification.Announcement(
                    AttributedString("Wrong gear for this fish - the fight will be tougher.")
                ).post()
            }
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}

private struct KitCard: View {
    let kit: EquipmentKit
    let isSelected: Bool
    let isRecommended: Bool
    var tier: TackleTier? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tier.map { "\(kit.displayName), \($0.displayName) grade" } ?? kit.displayName)
                    .font(.headline)
                if isRecommended {
                    Text("Recommended")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2), in: Capsule())
                }
            }
            Text(kit.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Group {
                Text("Rod: \(kit.rod)")
                Text("Reel: \(kit.reel)")
                Text("Line: \(kit.line)")
                Text("Bait: \(kit.bait)")
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
