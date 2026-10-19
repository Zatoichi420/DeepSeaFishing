import Foundation
import GameKit
import Observation
import UIKit

/// The leaderboards and achievements configured for this app in App Store
/// Connect. The raw values are the identifiers set there.
enum LeaderboardID: String {
    case heaviestCatch = "heaviest_catch"
    case quickRunBest = "quick_run_best"
    case careerEarnings = "career_earnings"
}

enum AchievementID: String, CaseIterable {
    case firstCatch = "first_catch"
    case firstMarlin = "first_marlin"
    case firstSwordfish = "first_swordfish"
    case firstBluefin = "first_bluefin"
    case fullSpread = "full_spread"
    case big500 = "big_500"
    case grander
    case legendScarback = "legend_scarback"
    case legendGrayGhost = "legend_grayghost"
    case legendIronjaw = "legend_ironjaw"
    case groundCanyon = "ground_canyon"
    case groundGulf = "ground_gulf"
    case groundTrench = "ground_trench"
    case level5 = "level_5"
    case level10 = "level_10"
    case quickRunDone = "quick_run_done"
    case earn1000 = "earn_1000"
    case earn10000 = "earn_10000"

    /// What the player hears when it unlocks. Matches the name in App Store Connect.
    var title: String {
        switch self {
        case .firstCatch: "First Fish"
        case .firstMarlin: "Blue Marlin"
        case .firstSwordfish: "Swordfish"
        case .firstBluefin: "Bluefin Tuna"
        case .fullSpread: "Full Spread"
        case .big500: "Five Hundred Pounder"
        case .grander: "Grander"
        case .legendScarback: "Old Scarback"
        case .legendGrayGhost: "The Gray Ghost"
        case .legendIronjaw: "Ironjaw"
        case .groundCanyon: "Canyon Edge"
        case .groundGulf: "Gulf Stream"
        case .groundTrench: "Deep Trench"
        case .level5: "Seasoned Angler"
        case .level10: "Salty Dog"
        case .quickRunDone: "Four Casts"
        case .earn1000: "First Thousand"
        case .earn10000: "Ten Grand"
        }
    }
}

/// Which achievements a given moment of play has earned. Pure, so it can be tested.
enum GameCenterRules {
    /// Earned by landing `fish`, given the species landed before it.
    static func achievements(landing fish: Fish, alreadyLanded: Set<FishSpecies>) -> Set<AchievementID> {
        var earned: Set<AchievementID> = [.firstCatch]
        switch fish.species {
        case .marlin: earned.insert(.firstMarlin)
        case .swordfish: earned.insert(.firstSwordfish)
        case .tuna: earned.insert(.firstBluefin)
        default: break
        }
        if alreadyLanded.union([fish.species]).count == FishSpecies.allCases.count { earned.insert(.fullSpread) }
        if fish.weight >= 500 { earned.insert(.big500) }
        if fish.weight >= 1000 { earned.insert(.grander) }
        if let name = fish.legendName, let legend = Legend.allCases.first(where: { $0.name == name }) {
            switch legend {
            case .scarback: earned.insert(.legendScarback)
            case .grayGhost: earned.insert(.legendGrayGhost)
            case .ironjaw: earned.insert(.legendIronjaw)
            }
        }
        return earned
    }

    /// Earned by where a career stands: grounds opened, level, lifetime earnings.
    static func achievements(for career: Career) -> Set<AchievementID> {
        var earned = Set<AchievementID>()
        if career.unlockedGrounds.contains(.canyonEdge) { earned.insert(.groundCanyon) }
        if career.unlockedGrounds.contains(.gulfStream) { earned.insert(.groundGulf) }
        if career.unlockedGrounds.contains(.deepTrench) { earned.insert(.groundTrench) }
        if career.level >= 5 { earned.insert(.level5) }
        if career.level >= 10 { earned.insert(.level10) }
        if career.totalEarnings >= 1_000 { earned.insert(.earn1000) }
        if career.totalEarnings >= 10_000 { earned.insert(.earn10000) }
        for legend in career.legendsLanded {
            switch legend {
            case .scarback: earned.insert(.legendScarback)
            case .grayGhost: earned.insert(.legendGrayGhost)
            case .ironjaw: earned.insert(.legendIronjaw)
            }
        }
        return earned
    }
}

/// Game Center: sign-in, leaderboards, achievements and the Game Center screens.
/// Everything here is supplementary - the game plays the same signed out.
@Observable
final class GameCenterManager: NSObject, GKGameCenterControllerDelegate {
    private(set) var isSignedIn = false
    private(set) var playerName: String?

    /// Spoken to the player (sign-in, unlocked achievements).
    @ObservationIgnored var onMessage: ((String) -> Void)?

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let landedKey = "DeepSeaFishing.landedSpecies"
    @ObservationIgnored private let reportedKey = "DeepSeaFishing.gameCenterReported"

    // MARK: Sign-in

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                let player = GKLocalPlayer.local
                let wasSignedIn = self.isSignedIn
                self.isSignedIn = player.isAuthenticated
                self.playerName = player.isAuthenticated ? player.displayName : nil
                if player.isAuthenticated, !wasSignedIn {
                    self.onMessage?("Signed in to Game Center as \(player.displayName).")
                    self.syncPending()
                }
            }
        }
    }

    // MARK: Reporting

    /// Submits a score; the leaderboard keeps each player's best.
    func submit(_ score: Int, to leaderboard: LeaderboardID) {
        guard isSignedIn, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard.rawValue]) { _ in }
    }

    /// Reports each achievement once, speaking the ones that are new.
    func earn(_ ids: Set<AchievementID>) {
        var reported = Set(defaults.stringArray(forKey: reportedKey) ?? [])
        let fresh = ids.filter { !reported.contains($0.rawValue) }.sorted { $0.rawValue < $1.rawValue }
        guard isSignedIn else {
            // Signed out: remember nothing, so they are reported after sign-in.
            pending.formUnion(ids)
            return
        }
        guard !fresh.isEmpty else { return }
        let achievements = fresh.map { id -> GKAchievement in
            let a = GKAchievement(identifier: id.rawValue)
            a.percentComplete = 100
            a.showsCompletionBanner = true
            return a
        }
        GKAchievement.report(achievements) { _ in }
        fresh.forEach { reported.insert($0.rawValue) }
        defaults.set(Array(reported), forKey: reportedKey)
        let names = fresh.map(\.title)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.onMessage?("Achievement unlocked: \(names.joined(separator: ", ")).")
        }
    }

    /// A fish was landed in either mode.
    func landed(_ fish: Fish) {
        var landed = Set((defaults.stringArray(forKey: landedKey) ?? []).compactMap(FishSpecies.init(rawValue:)))
        let earned = GameCenterRules.achievements(landing: fish, alreadyLanded: landed)
        landed.insert(fish.species)
        defaults.set(landed.map(\.rawValue), forKey: landedKey)
        submit(Int(fish.weight.rounded()), to: .heaviestCatch)
        earn(earned)
    }

    func quickRunFinished(best: Fish?) {
        if let best { submit(Int(best.weight.rounded()), to: .quickRunBest) }
        earn([.quickRunDone])
    }

    func careerChanged(_ career: Career) {
        submit(career.totalEarnings, to: .careerEarnings)
        earn(GameCenterRules.achievements(for: career))
    }

    // Achievements earned before sign-in finished, reported once it does.
    @ObservationIgnored private var pending = Set<AchievementID>()

    private func syncPending() {
        let ids = pending
        pending = []
        if !ids.isEmpty { earn(ids) }
    }

    // MARK: Screens

    /// Opens Apple's Game Center screen (leaderboards and achievements).
    func showDashboard() {
        guard isSignedIn else {
            onMessage?("You're not signed in to Game Center. Sign in from Settings, then Game Center, and try again.")
            return
        }
        let controller = GKGameCenterViewController(state: .dashboard)
        controller.gameCenterDelegate = self
        Self.topViewController()?.present(controller, animated: true)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
