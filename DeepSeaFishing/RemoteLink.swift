import Foundation
import MultipeerConnectivity
import Observation
import SwiftUI
import UIKit

// An iPhone can act as the Apple TV's controller. The TV advertises itself, the
// phone finds it and joins with a four-digit pairing code, then the phone sends
// button presses and tilt while the TV sends back haptic cues, the tension
// level and the spoken fight updates. Everything stays on the local network (or
// Bluetooth / peer-to-peer Wi-Fi when there is no shared network) and is
// encrypted.

private let serviceType = "dsf-pad"

/// Phone to TV.
enum PadCommand: Codable, Equatable {
    case reel
    case ease
    case status
    /// A tilt-driven half-strength reel or ease, sent while the phone is tilted.
    case tiltReel
    case tiltEase
}

/// TV to phone.
enum TVEvent: Codable, Equatable {
    case bite
    case run(FightStyle)
    case landed
    case snapped
    case tension(Double)
    case stopTension
    /// Whether a fish is on the line.
    case fighting(Bool)
    /// Text for the phone's VoiceOver to speak.
    case speak(String)
}

private func deviceName() -> String { UIDevice.current.name }

// MARK: - Apple TV side

/// Lets one iPhone join as the controller.
@Observable
final class RemoteHost: NSObject {
    enum State: Equatable {
        case off
        case waiting
        case connected(String)
    }

    private(set) var state: State = .off
    /// The code the phone must enter. New each time the app launches.
    let pairingCode = String(format: "%04d", Int.random(in: 0...9999))

    var onCommand: ((PadCommand) -> Void)?
    var onStateChange: ((State) -> Void)?

    @ObservationIgnored private var wanted = false
    @ObservationIgnored private let peer = MCPeerID(displayName: deviceName())
    @ObservationIgnored private lazy var session: MCSession = {
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()
    @ObservationIgnored private lazy var advertiser: MCNearbyServiceAdvertiser = {
        let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        return advertiser
    }()

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    func startWaiting() {
        guard !wanted else { return }
        wanted = true
        advertiser.startAdvertisingPeer()
        update(.waiting)
    }

    func stop() {
        wanted = false
        advertiser.stopAdvertisingPeer()
        session.disconnect()
        update(.off)
    }

    func send(_ event: TVEvent) {
        guard isConnected, !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(event) else { return }
        var mode = MCSessionSendDataMode.reliable
        if case .tension = event { mode = .unreliable }
        try? session.send(data, toPeers: session.connectedPeers, with: mode)
    }

    private func update(_ new: State) {
        DispatchQueue.main.async {
            guard self.state != new else { return }
            self.state = new
            self.onStateChange?(new)
        }
    }
}

extension RemoteHost: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let offered = context.flatMap { String(data: $0, encoding: .utf8) }
        let free = session.connectedPeers.isEmpty
        invitationHandler(free && offered == pairingCode, session)
    }
}

extension RemoteHost: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected: update(.connected(peerID.displayName))
        case .notConnected: update(wanted ? .waiting : .off)
        case .connecting: break
        @unknown default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let command = try? JSONDecoder().decode(PadCommand.self, from: data) else { return }
        DispatchQueue.main.async { self.onCommand?(command) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

/// Forwards haptic cues from the Apple TV to the iPhone controller.
final class RemoteHaptics: HapticSink {
    private weak var host: RemoteHost?
    init(host: RemoteHost) { self.host = host }

    func playBite() { host?.send(.bite) }
    func playRun(for species: FishSpecies) { host?.send(.run(species.fightStyle)) }
    func playLanded() { host?.send(.landed) }
    func playSnap() { host?.send(.snapped) }
    func updateTension(_ level: Double) { host?.send(.tension(level)) }
    func stopTension() { host?.send(.stopTension) }
}

// MARK: - iPhone side

/// The iPhone acting as a controller: finds the Apple TV, joins it, sends
/// presses and tilt, and plays back the TV's haptics.
@Observable
final class PadClient: NSObject {
    enum State: Equatable {
        case idle
        case searching
        case connecting(String)
        case connected(String)
    }

    private(set) var state: State = .idle
    private(set) var foundTVs: [String] = []
    private(set) var fighting = false
    /// A plain-language reason the last attempt failed, to show and speak.
    private(set) var problem: String?
    var speakOnPhone = true

    var onSpeak: ((String) -> Void)?
    var isMotionAvailable: Bool { motion.isAvailable }

    @ObservationIgnored private let peer = MCPeerID(displayName: deviceName())
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var peers: [String: MCPeerID] = [:]
    @ObservationIgnored private let haptics = HapticsManager()
    @ObservationIgnored private let motion = MotionManager()
    @ObservationIgnored private var tiltTimer: Timer?

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    // MARK: Finding and joining

    func startSearching() {
        stopBrowsing()
        problem = nil
        foundTVs = []
        peers = [:]
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        if state == .idle { state = .searching }
    }

    func connect(to tvName: String, code: String) {
        guard let tv = peers[tvName] else {
            problem = "That Apple TV isn't in range any more. Search again."
            return
        }
        problem = nil
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        state = .connecting(tvName)
        browser?.invitePeer(tv, to: session, withContext: code.data(using: .utf8), timeout: 20)
    }

    func disconnect() {
        stopBrowsing()
        stopTilt()
        session?.disconnect()
        session = nil
        haptics.stopTension()
        fighting = false
        state = .idle
        setScreenStaysOn(false)
    }

    /// The phone must not lock mid-fight.
    private func setScreenStaysOn(_ on: Bool) {
        DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    // MARK: Sending

    func send(_ command: PadCommand) {
        guard let session, !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(command) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func recalibrateTilt() { motion.recalibrate() }

    private func startTilt() {
        guard motion.isAvailable else { return }
        motion.start()
        tiltTimer?.invalidate()
        // The same half-second rhythm the phone game uses for tilt.
        tiltTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.fighting else { return }
            switch self.motion.tiltState {
            case .reeling: self.send(.tiltReel)
            case .easing: self.send(.tiltEase)
            case .neutral: break
            }
        }
    }

    private func stopTilt() {
        tiltTimer?.invalidate()
        tiltTimer = nil
        motion.stop()
    }

    // MARK: Receiving

    private func handle(_ event: TVEvent) {
        switch event {
        case .bite: haptics.playBite()
        case .run(let style): haptics.playRun(style: style)
        case .landed: haptics.playLanded()
        case .snapped: haptics.playSnap()
        case .tension(let level): haptics.updateTension(level)
        case .stopTension: haptics.stopTension()
        case .fighting(let on):
            fighting = on
            if !on { haptics.stopTension() }
        case .speak(let text):
            if speakOnPhone { onSpeak?(text) }
        }
    }
}

extension PadClient: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            self.peers[peerID.displayName] = peerID
            if !self.foundTVs.contains(peerID.displayName) { self.foundTVs.append(peerID.displayName) }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.peers[peerID.displayName] = nil
            self.foundTVs.removeAll { $0 == peerID.displayName }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.problem = "Couldn't search for Apple TVs. Check that Local Network access is allowed for this app in Settings."
            self.state = .idle
        }
    }
}

extension PadClient: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange newState: MCSessionState) {
        DispatchQueue.main.async {
            switch newState {
            case .connected:
                self.stopBrowsing()
                self.state = .connected(peerID.displayName)
                self.problem = nil
                self.setScreenStaysOn(true)
                self.startTilt()
            case .notConnected:
                let wasConnected = self.isConnected
                let wasConnecting: Bool
                if case .connecting = self.state { wasConnecting = true } else { wasConnecting = false }
                guard wasConnected || wasConnecting else { return }
                self.stopTilt()
                self.haptics.stopTension()
                self.fighting = false
                self.setScreenStaysOn(false)
                self.problem = wasConnected
                    ? "The Apple TV disconnected."
                    : "The Apple TV didn't accept the connection. Check the pairing code on the TV."
                self.state = .idle
                self.onSpeak?(self.problem ?? "")
                self.startSearching()
            case .connecting: break
            @unknown default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let event = try? JSONDecoder().decode(TVEvent.self, from: data) else { return }
        DispatchQueue.main.async { self.handle(event) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
