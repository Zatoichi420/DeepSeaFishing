import SwiftUI
import Observation

enum GameMode: Equatable {
    case quickRun
    case career
}

enum GamePhase: Equatable {
    case onboarding
    case home
    // Quick Run
    case idle
    case runOver
    // Career
    case story
    case dock
    case groundSelect
    case shop
    case skills
    case logbook
    case controls
    case remotePad
    case atSea
    case tripSummary
    // Shared
    case selectingSpecies
    case selectingGear(FishSpecies)
    case fighting
    case result(landed: Bool)
}

@Observable
final class GameViewModel {
    let totalCasts = 4

    var mode: GameMode = .quickRun
    var castsRemaining: Int
    var phase: GamePhase = .home {
        didSet {
            updateAudioScene()
            if case .result = phase { resultShownAt = Date() }
            if remoteHost.isConnected { remoteHost.send(.fighting(phase == .fighting)) }
        }
    }
    var currentFish: Fish?
    var hasCompletedOnboarding: Bool
    var selectedKit: EquipmentKit = .tunaTrolling
    var useLiveBait = false
    var runBestCatch: Fish?

    /// The career, once one has been started or loaded.
    private(set) var career: Career?
    /// The spoken summary of the last fight's consequences (career only).
    private(set) var lastCatchReport = CatchReport()
    private(set) var lastTripReport = TripReport()
    /// The most recent shop or skill message, shown on screen as well as spoken.
    private(set) var shopMessage: String?

    private(set) var allTimeBestWeight: Double
    private(set) var allTimeBestSpeciesName: String?

    private var fight: FightEngine?
    var tension: Double { fight?.tension ?? 0 }
    var progress: Double { fight?.progress ?? 0 }

    private var timer: Timer?
    private let bestWeightKey = "DeepSeaFishing.bestWeight"
    private let bestSpeciesKey = "DeepSeaFishing.bestSpecies"
    private let onboardingKey = "DeepSeaFishing.hasCompletedOnboarding"
    // A quick run in progress (mid-run, not mid-fight) is persisted so an
    // app kill between casts doesn't silently erase how many casts are left
    // and the best catch so far.
    private let runCastsRemainingKey = "DeepSeaFishing.runCastsRemaining"
    private let runBestWeightKey = "DeepSeaFishing.runBestWeight"
    private let runBestSpeciesKey = "DeepSeaFishing.runBestSpecies"

    private let motion = MotionManager()
    private let haptics = HapticsManager()
    private let audio = AudioManager()
    private let controller = ControllerManager()
    /// Apple TV: lets an iPhone join as the controller.
    let remoteHost = RemoteHost()
    /// iPhone: acts as the Apple TV's controller.
    let pad = PadClient()
    @ObservationIgnored private lazy var remoteHaptics = RemoteHaptics(host: remoteHost)
    /// The name of the connected game controller, if any.
    private(set) var controllerName: String?
    /// Which controller buttons do what; changed on the Controls screen.
    private(set) var controls = ControlScheme.load()
    /// The action waiting for the player to press its new button, if any.
    private(set) var remapping: ControlAction?
    /// Stops a mashed button from skipping a result screen the instant it appears.
    private var resultShownAt = Date.distantPast

    /// Whether the selected gear matches the fish currently being targeted or fought.
    var isGearMatched: Bool {
        guard let species = targetSpecies else { return true }
        return selectedKit == species.recommendedKit
    }

    private var targetSpecies: FishSpecies? {
        if case .selectingGear(let species) = phase { return species }
        return currentFish?.species
    }

    var hasSavedCareer: Bool { career != nil }

    /// Species offered on the target screen.
    var targetableSpecies: [FishSpecies] {
        if mode == .career, let ground = career?.trip?.ground { return ground.species }
        return FishSpecies.quickRun
    }

    /// Outfits offered on the gear screen.
    var availableKits: [EquipmentKit] {
        mode == .career ? (career?.ownedKits ?? []) : EquipmentKit.quickRun
    }

    init() {
        allTimeBestWeight = UserDefaults.standard.double(forKey: bestWeightKey)
        allTimeBestSpeciesName = UserDefaults.standard.string(forKey: bestSpeciesKey)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        career = CareerStore.load()

        // Only restore a genuinely mid-run state (some casts used, some left).
        let defaults = UserDefaults.standard
        if let savedCasts = defaults.object(forKey: runCastsRemainingKey) as? Int,
           savedCasts > 0, savedCasts < totalCasts {
            castsRemaining = savedCasts
            if let weight = defaults.object(forKey: runBestWeightKey) as? Double,
               let speciesName = defaults.string(forKey: runBestSpeciesKey),
               let species = FishSpecies.allCases.first(where: { $0.displayName == speciesName }) {
                runBestCatch = Fish(species: species, weight: weight)
            }
        } else {
            castsRemaining = totalCasts
            defaults.removeObject(forKey: runCastsRemainingKey)
            defaults.removeObject(forKey: runBestWeightKey)
            defaults.removeObject(forKey: runBestSpeciesKey)
        }

        phase = hasCompletedOnboarding ? .home : .onboarding
        audio.start()
        configureController()
        configureRemote()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
        phase = .home
    }

    func showOnboarding() {
        phase = .onboarding
    }

    func goHome() {
        if remapping != nil { cancelRemapQuietly() }
        phase = .home
    }

    // MARK: - Quick Run

    func enterQuickRun() {
        mode = .quickRun
        phase = .idle
    }

    func startRun() {
        mode = .quickRun
        castsRemaining = totalCasts
        runBestCatch = nil
        currentFish = nil
        phase = .idle
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: runCastsRemainingKey)
        defaults.removeObject(forKey: runBestWeightKey)
        defaults.removeObject(forKey: runBestSpeciesKey)
    }

    // MARK: - Career

    func continueCareer() {
        guard career != nil else { return startNewCareer() }
        mode = .career
        showNextStoryOr(career?.trip != nil ? .atSea : .dock)
    }

    func startNewCareer() {
        mode = .career
        career = Career.newCareer()
        saveCareer()
        showNextStoryOr(.dock)
    }

    /// The story beat currently on screen.
    var currentStoryBeat: StoryBeat? { career?.pendingStory.first }

    func dismissStoryBeat() {
        guard career?.pendingStory.isEmpty == false else { return showNextStoryOr(.dock) }
        career?.pendingStory.removeFirst()
        saveCareer()
        showNextStoryOr(career?.trip != nil ? .atSea : .dock)
    }

    private func showNextStoryOr(_ next: GamePhase) {
        phase = (career?.pendingStory.isEmpty == false) ? .story : next
    }

    func openDockScreen(_ screen: GamePhase) {
        shopMessage = nil
        phase = screen
    }

    func backToDock() {
        shopMessage = nil
        phase = .dock
    }

    func headOut(to ground: FishingGround) {
        guard var career else { return }
        switch career.startTrip(to: ground) {
        case .success(let message):
            self.career = career
            saveCareer()
            phase = .atSea
            announce(message)
        case .failure(.cantAffordFuel):
            announce("You can't afford the fuel to reach \(ground.displayName). It costs \(ground.fuelCost) dollars.")
        case .failure(.locked):
            announce("\(ground.title) isn't open to you yet.")
        case .failure(.alreadyOut):
            phase = .atSea
        }
    }

    func returnToDock() {
        guard var career else { return }
        lastTripReport = career.endTrip()
        self.career = career
        saveCareer()
        audio.playCash()
        phase = .tripSummary
        announce(lastTripReport.lines.joined(separator: " "))
    }

    func finishTripSummary() {
        showNextStoryOr(.dock)
    }

    func buyOrUpgrade(_ kit: EquipmentKit) { applyShop { $0.buyOrUpgrade(kit) } }
    func buyLiveBait() { applyShop { $0.buyLiveBait() } }
    func buy(_ upgrade: BoatUpgrade) { applyShop { $0.buy(upgrade) } }

    private func applyShop(_ action: (inout Career) -> Result<String, Career.ShopError>) {
        guard var career else { return }
        let message: String
        switch action(&career) {
        case .success(let text):
            message = text
            audio.playCash()
        case .failure(.notEnoughMoney(let needed)):
            message = "That costs \(needed) dollars, and you have \(career.money)."
        case .failure(.maxed):
            message = "That's already the best there is."
        case .failure(.alreadyOwned):
            message = "The Marisol already has that."
        case .failure(.notOwned):
            message = "You don't own that outfit yet."
        }
        self.career = career
        saveCareer()
        shopMessage = message
        announce(message)
    }

    func spendSkillPoint(on skill: AnglerSkill) {
        guard var career else { return }
        let message = career.spendSkillPoint(on: skill)
        self.career = career
        saveCareer()
        shopMessage = message
        announce(message)
    }

    func eraseCareer() {
        CareerStore.delete()
        career = nil
        phase = .home
        announce("Career erased.")
    }

    private func saveCareer() {
        if let career { CareerStore.save(career) }
    }

    // MARK: - Shared casting flow

    func beginTargeting() {
        phase = .selectingSpecies
    }

    func cancelTargeting() {
        phase = mode == .career ? .atSea : .idle
    }

    func selectSpecies(_ species: FishSpecies) {
        let kits = availableKits
        selectedKit = kits.contains(species.recommendedKit) ? species.recommendedKit : (kits.first ?? species.recommendedKit)
        useLiveBait = false
        phase = .selectingGear(species)
        var line = "Gearing up for \(species.displayName)."
        if mode == .career, !kits.contains(species.recommendedKit) {
            line += " You don't own the \(species.recommendedKit.displayName) this fish calls for - the tackle shop sells it."
        }
        announce(line)
    }

    func selectKit(_ kit: EquipmentKit) {
        selectedKit = kit
    }

    /// Whether tilt controls are usable on this device (always false in Simulator).
    var isMotionAvailable: Bool { motion.isAvailable }

    /// Re-zeroes tilt against the phone's current angle.
    func recalibrateTilt() {
        motion.recalibrate()
        announce("Tilt recalibrated.")
    }

    func cast() {
        guard case .selectingGear(let species) = phase else { return }
        let fish: Fish
        let modifiers: FightModifiers
        if mode == .career, var career {
            fish = career.hookFish(target: species, useLiveBait: useLiveBait)
            modifiers = career.modifiers(for: fish, kit: selectedKit)
            self.career = career
            saveCareer()
        } else {
            fish = Fish.random(species: species)
            var m = FightModifiers.original
            if selectedKit != species.recommendedKit { m.applyMismatch() }
            modifiers = m
        }
        currentFish = fish
        fight = FightEngine(fish: fish, modifiers: modifiers)
        phase = .fighting

        let mismatchWarning = isGearMatched ? "" : " Your gear doesn't match this fish, so the fight will be tougher."
        if let name = fish.legendName, let legend = Legend.allCases.first(where: { $0.name == name }) {
            announce("\(legend.hookLine)\(mismatchWarning)")
        } else {
            announce("Fish on! A \(species.displayName) takes the bait.\(mismatchWarning)")
        }
        buzz { $0.playBite() }
        audio.playCast()
        audio.playBite()
        motion.start()
        startTimer()
    }

    /// Re-speaks the current fight state on demand (VoiceOver magic tap).
    func announceCurrentState() {
        guard phase == .fighting, let fish = currentFish else { return }
        let mismatchNote = isGearMatched ? "" : " Gear mismatched."
        announce(
            "Fighting \(fish.legendName ?? "a \(fish.species.displayName)"). "
            + "Line to shore \(Int(progress * 100)) percent. "
            + "Tension \(Int(tension * 100)) percent.\(mismatchNote)"
        )
    }

    func reelIn(multiplier: Double = 1.0) {
        guard phase == .fighting else { return }
        fight?.reel(multiplier: multiplier)
        buzz { $0.updateTension(tension) }
        audio.updateTension(tension)
        audio.playReelClick()
        checkOutcome()
    }

    func easeLine(multiplier: Double = 1.0) {
        guard phase == .fighting else { return }
        fight?.ease(multiplier: multiplier)
        buzz { $0.updateTension(tension) }
        audio.updateTension(tension)
        audio.playEase()
    }

    func acknowledgeResult() {
        currentFish = nil
        fight = nil
        if mode == .career {
            if (career?.trip?.castsLeft ?? 0) == 0 {
                returnToDock()
            } else {
                phase = .atSea
            }
        } else {
            phase = castsRemaining == 0 ? .runOver : .idle
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard phase == .fighting, var fight, let fish = currentFish else { return }

        let ran = fight.tick()
        if ran {
            let who = fish.legendName ?? "The \(fish.species.displayName.lowercased())"
            announce("\(who) \(fish.species.runDescription)!")
            buzz { $0.playRun(for: fish.species) }
            audio.playRun(for: fish.species)
        }

        // Tilt back to reel in, tilt forward to ease the line, alongside the buttons.
        switch motion.tiltState {
        case .reeling:
            fight.reel(multiplier: 0.5)
            audio.playReelClick()
        case .easing:
            fight.ease(multiplier: 0.5)
            audio.playEase()
        case .neutral:
            break
        }
        self.fight = fight

        buzz { $0.updateTension(tension) }
        audio.updateTension(tension)
        audio.playProgressPulse(progress)

        // A run's tension spike used to be able to end the fight in the same
        // tick its haptic/audio cue started - 0ms reaction time. Skip the snap
        // check on the tick a run occurs, so the earliest a run can end the
        // fight is the *next* tick (~0.5s later).
        checkOutcome(allowSnap: !ran)
    }

    private func checkOutcome(allowSnap: Bool = true) {
        guard let fight, let fish = currentFish else { return }
        switch fight.outcome(allowSnap: allowSnap) {
        case .snapped: landFish(fish, landed: false)
        case .landed: landFish(fish, landed: true)
        case .ongoing: break
        }
    }

    private func landFish(_ fish: Fish, landed: Bool) {
        stopTimer()
        motion.stop()
        buzz { $0.stopTension() }
        audio.stopFight()

        var recordNote = ""
        if mode == .career, var career {
            lastCatchReport = career.recordFight(fish, landed: landed)
            self.career = career
            saveCareer()
        } else {
            castsRemaining -= 1
            if landed {
                if runBestCatch == nil || fish.weight > runBestCatch!.weight {
                    runBestCatch = fish
                }
            }
            persistRunState()
        }

        // The all-time record spans both modes.
        if landed, fish.weight > allTimeBestWeight {
            allTimeBestWeight = fish.weight
            allTimeBestSpeciesName = fish.species.displayName
            UserDefaults.standard.set(allTimeBestWeight, forKey: bestWeightKey)
            UserDefaults.standard.set(allTimeBestSpeciesName, forKey: bestSpeciesKey)
            recordNote = " New all-time record!"
        }

        let details = mode == .career ? " " + lastCatchReport.lines.joined(separator: " ") : ""
        if landed {
            announce("Landed! A \(fish.weightDescription) \(fish.legendName ?? fish.species.displayName).\(recordNote)\(details)")
            buzz { $0.playLanded() }
            audio.playLanded()
        } else {
            announce("The line snapped. \(fish.legendName ?? "The \(fish.species.displayName)") got away.\(details)")
            buzz { $0.playSnap() }
            audio.playSnap()
        }

        phase = .result(landed: landed)
    }

    // MARK: - Game controller

    private func configureController() {
        controller.onReel = { [weak self] in self?.reelIn() }
        controller.onEase = { [weak self] in self?.easeLine() }
        controller.onStatus = { [weak self] in self?.announceCurrentState() }
        controller.onConfirm = { [weak self] in
            guard let self, case .result = self.phase,
                  Date().timeIntervalSince(self.resultShownAt) > 1.0 else { return }
            self.acknowledgeResult()
        }
        controller.onConnectionChange = { [weak self] name in
            guard let self else { return }
            self.controllerName = name
            self.remapping = nil
            self.announce(name.map { "\($0) connected. \(self.controlsSummary)" } ?? "Controller disconnected.")
        }
        controller.scheme = controls
        controller.start()
    }

    /// Whether a controller is connected, so buttons can be remapped by pressing them.
    var canRemap: Bool { controllerName != nil }

    /// A spoken-style list of what each button does, in this controller's own names.
    var controlsSummary: String { controls.summary(name: controller.displayName(for:)) }

    func buttonNames(for action: ControlAction) -> String {
        let names = controls.inputs(for: action).map(controller.displayName(for:))
        return names.isEmpty ? "No button" : names.joined(separator: ", ")
    }

    /// Waits for the next controller press and gives that button to `action`.
    func beginRemap(_ action: ControlAction, adding: Bool) {
        guard controller.isConnected else {
            announce("Connect a controller first, then try again.")
            return
        }
        remapping = action
        announce("Press the button you want for \(action.title). Press Cancel to keep things as they are.")
        controller.captureNextPress { [weak self] input in
            guard let self else { return }
            self.remapping = nil
            let name = self.controller.displayName(for: input)
            if let displaced = self.controls.assign(input, to: action, replacing: !adding) {
                let note = displaced.nowEmpty ? "\(displaced.action.title) now has no button, so give it one." : "\(displaced.action.title) lost it."
                self.announce("\(name) now \(adding ? "also does" : "is") \(action.title). \(note)")
            } else {
                self.announce("\(name) now \(adding ? "also does" : "is") \(action.title).")
            }
            self.saveControls()
        }
    }

    private func cancelRemapQuietly() {
        controller.cancelCapture()
        remapping = nil
    }

    func cancelRemap() {
        controller.cancelCapture()
        remapping = nil
        announce("Cancelled. Nothing changed.")
    }

    func resetControls() {
        controller.cancelCapture()
        remapping = nil
        controls = .standard
        saveControls()
        announce("Controller buttons reset. \(controlsSummary)")
    }

    private func saveControls() {
        controller.scheme = controls
        controls.save()
    }

    func showControls() {
        phase = .controls
    }

    /// Runs a haptic cue on the phone and on the controller, when it has haptics.
    private func buzz(_ cue: (any HapticSink) -> Void) {
        cue(haptics)
        if let rumble = controller.rumble { cue(rumble) }
        if remoteHost.isConnected { cue(remoteHaptics) }
    }

    // MARK: - iPhone as the Apple TV's controller

    private func configureRemote() {
        remoteHost.onCommand = { [weak self] command in
            guard let self else { return }
            switch command {
            case .reel:
                reelIn()
                if case .result = phase, Date().timeIntervalSince(resultShownAt) > 1.0 { acknowledgeResult() }
            case .ease: easeLine()
            case .status: announceCurrentState()
            case .tiltReel: reelIn(multiplier: 0.5)
            case .tiltEase: easeLine(multiplier: 0.5)
            }
        }
        remoteHost.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .connected(let name):
                announce("\(name) connected as your controller.")
                remoteHost.send(.fighting(phase == .fighting))
            case .waiting: announce("Waiting for your iPhone. The pairing code is \(remoteHost.pairingCode.map(String.init).joined(separator: " ")).")
            case .off: break
            }
        }
        pad.onSpeak = { text in
            AccessibilityNotification.Announcement(AttributedString(text)).post()
        }
    }

    /// Phone side: open the controller screen.
    func showRemotePad() {
        phase = .remotePad
        pad.startSearching()
    }

    func leaveRemotePad() {
        pad.disconnect()
        phase = .controls
    }

    /// TV side: let an iPhone join.
    func startWaitingForPhone() { remoteHost.startWaiting() }
    func stopWaitingForPhone() { remoteHost.stop() }

    /// Tells the soundscape where the player is: the harbor, out at sea on a
    /// given ground, or locked in a fight.
    private func updateAudioScene() {
        let ground = mode == .career ? (career?.trip?.ground ?? .coastalShelf) : .coastalShelf
        switch phase {
        case .onboarding, .home, .runOver, .story, .dock, .groundSelect, .shop, .skills, .logbook, .tripSummary, .controls:
            audio.setScene(.harbor)
        case .remotePad:
            audio.setScene(.silent)
        case .idle, .atSea, .selectingSpecies, .selectingGear, .result:
            audio.setScene(.atSea, ground: ground)
        case .fighting:
            audio.setScene(.fighting, ground: ground)
        }
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(AttributedString(text)).post()
        remoteHost.send(.speak(text))
    }

    /// Saves how many quick-run casts are left and the best catch so far.
    private func persistRunState() {
        let defaults = UserDefaults.standard
        defaults.set(castsRemaining, forKey: runCastsRemainingKey)
        if let best = runBestCatch {
            defaults.set(best.weight, forKey: runBestWeightKey)
            defaults.set(best.species.displayName, forKey: runBestSpeciesKey)
        } else {
            defaults.removeObject(forKey: runBestWeightKey)
            defaults.removeObject(forKey: runBestSpeciesKey)
        }
    }
}
