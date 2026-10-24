import SwiftUI

/// A screen title VoiceOver lands on when the screen appears.
private struct ScreenTitle: View {
    let text: String
    var font: Font = .title
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        Text(text)
            .font(font)
            .bold()
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focused)
            .onAppear { focused = true }
    }
}

private struct WideButton: View {
    let title: String
    var prominent = false
    var hint: String? = nil
    let action: () -> Void

    var body: some View {
        Group {
            if prominent {
                Button(action: action) { Text(title).frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { Text(title).frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.bordered)
            }
        }
        .accessibilityHint(hint ?? "")
    }
}

// MARK: - Story

struct StoryView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let beat = viewModel.currentStoryBeat {
                    ScreenTitle(text: beat.title)
                        .frame(maxWidth: .infinity)
                    ForEach(beat.paragraphs.indices, id: \.self) { index in
                        Text(beat.paragraphs[index])
                    }
                }
                WideButton(title: "Continue", prominent: true) { viewModel.dismissStoryBeat() }
            }
        }
    }
}

// MARK: - Dock

struct DockView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LoopingVideoBanner(resource: "dock", fallbackImage: "OceanWaveImage", height: 140)
                ScreenTitle(text: "Port Salvage")
                if let career = viewModel.career {
                    VStack(spacing: 6) {
                        Text("\(career.money) dollars. Level \(career.level) angler.")
                        Text(experienceLine(career))
                        if career.skillPoints > 0 {
                            Text("\(career.skillPoints) skill point\(career.skillPoints == 1 ? "" : "s") to spend.")
                        }
                    }
                    .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(career.chapter.title).font(.headline)
                        Text(career.chapter.goal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)

                    WideButton(title: "Head Out", prominent: true, hint: "Choose a fishing ground and take the Marisol out.") {
                        viewModel.openDockScreen(.groundSelect)
                    }
                    WideButton(title: "Tackle Shop", hint: "Buy and upgrade outfits, live bait, and boat upgrades.") {
                        viewModel.openDockScreen(.shop)
                    }
                    WideButton(title: career.skillPoints > 0 ? "Angler Skills, \(career.skillPoints) to spend" : "Angler Skills") {
                        viewModel.openDockScreen(.skills)
                    }
                    WideButton(title: "Logbook", hint: "Every species you've landed, and your biggest of each.") {
                        viewModel.openDockScreen(.logbook)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contracts").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(career.contracts) { contract in
                            Text(contract.summary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    WideButton(title: "Main Menu") { viewModel.goHome() }
                }
            }
        }
    }

    private func experienceLine(_ career: Career) -> String {
        if let next = AnglerLevels.xpForNext(after: career.level) {
            return "\(career.xp) of \(next) experience."
        }
        return "\(career.xp) experience. Highest level."
    }
}

struct GroundSelectView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LoopingVideoBanner(resource: "dock", fallbackImage: "OceanWaveImage", height: 140)
                ScreenTitle(text: "Where to?")
                if let career = viewModel.career {
                    ForEach(FishingGround.allCases, id: \.self) { ground in
                        let unlocked = career.unlockedGrounds.contains(ground)
                        Button {
                            viewModel.headOut(to: ground)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ground.title).font(.headline)
                                Text(unlocked ? ground.description : "Locked - the story will take you here.")
                                    .font(.subheadline)
                                Text(unlocked ? "Fuel \(ground.fuelCost) dollars. Fish: \(ground.species.map(\.displayName).joined(separator: ", "))." : "")
                                    .font(.caption)
                                if unlocked {
                                    Text("Forecast: \(career.weather(at: ground).report)").font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(unlocked ? "Double-tap to head out." : "")
                    }
                }
                WideButton(title: "Back to the Dock") { viewModel.backToDock() }
            }
        }
    }
}

// MARK: - At sea

struct AtSeaView: View {
    var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 16) {
            if let trip = viewModel.career?.trip {
                LoopingVideoBanner(resource: "rod_wake", fallbackImage: "OceanWaveImage", height: 140)
                ScreenTitle(text: "At \(trip.ground.title)")
                VStack(spacing: 6) {
                    Text("\(trip.castsLeft) cast\(trip.castsLeft == 1 ? "" : "s") left. Weather: \((trip.weather ?? .clear).displayName).")
                    Text(trip.catches.isEmpty ? "Nothing in the hold yet." : "In the hold: \(trip.catches.map { "\($0.weightDescription) \($0.legendName ?? $0.species.displayName)" }.joined(separator: ", ")).")
                    if let career = viewModel.career, career.liveBait > 0 {
                        Text("\(career.liveBait) live bait on board.")
                    }
                }
                .accessibilityElement(children: .combine)

                if trip.castsLeft > 0 {
                    WideButton(title: "Choose Your Target", prominent: true) { viewModel.beginTargeting() }
                }
                WideButton(title: "Return to Port", prominent: trip.castsLeft == 0, hint: "Sell your catch and collect any contracts.") {
                    viewModel.returnToDock()
                }
            }
        }
    }
}

struct TripSummaryView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenTitle(text: "Back in Port")
                ForEach(viewModel.lastTripReport.lines.indices, id: \.self) { i in
                    Text(viewModel.lastTripReport.lines[i])
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                WideButton(title: "Continue", prominent: true) { viewModel.finishTripSummary() }
            }
        }
    }
}

// MARK: - Shop

struct ShopView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LoopingVideoBanner(resource: "dock", fallbackImage: "OceanWaveImage", height: 140)
                ScreenTitle(text: "Tackle Shop")
                    .frame(maxWidth: .infinity)
                if let career = viewModel.career {
                    Text("You have \(career.money) dollars.")
                    if let message = viewModel.shopMessage {
                        Text(message).foregroundStyle(.secondary)
                    }

                    Text("Outfits").font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(EquipmentKit.allCases, id: \.self) { kit in
                        kitRow(kit, career: career)
                    }

                    Text("Bait").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Live bait: you have \(career.liveBait). \(Bait.liveBait.summary)")
                    WideButton(title: "Buy \(Bait.livePackSize) Live Bait for \(Bait.livePackPrice) Dollars") { viewModel.buyLiveBait() }

                    Text("The Marisol").font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(BoatUpgrade.allCases, id: \.self) { upgrade in
                        if career.boatUpgrades.contains(upgrade) {
                            Text("\(upgrade.displayName): installed. \(upgrade.summary)")
                        } else {
                            Text("\(upgrade.displayName): \(upgrade.summary)")
                            WideButton(title: "Buy \(upgrade.displayName) for \(upgrade.price) Dollars") { viewModel.buy(upgrade) }
                        }
                    }
                }
                WideButton(title: "Back to the Dock") { viewModel.backToDock() }
            }
        }
    }

    @ViewBuilder
    private func kitRow(_ kit: EquipmentKit, career: Career) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tier = career.tier(of: kit) {
                Text("\(kit.displayName): \(tier.displayName) grade. \(tier.effectSummary)")
            } else {
                Text("\(kit.displayName): not owned. \(kit.summary)")
            }
            if let price = career.nextUpgradePrice(for: kit) {
                let label = career.owns(kit)
                    ? "Upgrade \(kit.displayName) to \(career.tier(of: kit)!.next!.displayName) for \(price) Dollars"
                    : "Buy \(kit.displayName) for \(price) Dollars"
                WideButton(title: label) { viewModel.buyOrUpgrade(kit) }
            }
        }
    }
}

// MARK: - Skills

struct SkillsView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(text: "Angler Skills")
                    .frame(maxWidth: .infinity)
                if let career = viewModel.career {
                    Text("\(career.skillPoints) skill point\(career.skillPoints == 1 ? "" : "s") to spend. You earn one every level.")
                    if let message = viewModel.shopMessage {
                        Text(message).foregroundStyle(.secondary)
                    }
                    ForEach(AnglerSkill.allCases, id: \.self) { skill in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(skill.displayName), rank \(career.rank(skill)) of \(AnglerSkill.maxRank). \(skill.summary)")
                            if career.skillPoints > 0, career.rank(skill) < AnglerSkill.maxRank {
                                WideButton(title: "Raise \(skill.displayName)") { viewModel.spendSkillPoint(on: skill) }
                            }
                        }
                    }
                }
                WideButton(title: "Back to the Dock") { viewModel.backToDock() }
            }
        }
    }
}

// MARK: - Logbook

struct LogbookView: View {
    var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenTitle(text: "Logbook")
                    .frame(maxWidth: .infinity)
                if let career = viewModel.career {
                    let landedKinds = FishSpecies.allCases.filter { career.logEntry($0).landed > 0 }.count
                    Text("\(landedKinds) of \(FishSpecies.allCases.count) species landed. Total earnings \(career.totalEarnings) dollars.")
                    ForEach(FishSpecies.allCases, id: \.self) { species in
                        let entry = career.logEntry(species)
                        Text(entry.landed > 0
                             ? "\(species.displayName): \(entry.landed) landed, biggest \(Int(entry.bestWeight)) pounds."
                             : "\(species.displayName): not yet landed.")
                    }
                    Text("Legends").font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(Legend.allCases, id: \.self) { legend in
                        Text(career.legendsLanded.contains(legend)
                             ? "\(legend.name.capitalizedFirst): landed, \(Int(legend.weight)) pounds."
                             : "\(legend.name.capitalizedFirst): still out there.")
                    }
                }
                WideButton(title: "Back to the Dock") { viewModel.backToDock() }
            }
        }
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
