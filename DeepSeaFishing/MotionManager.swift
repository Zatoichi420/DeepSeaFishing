import CoreMotion

/// Tilt the phone back (toward yourself) to reel in; tilt it forward (away from
/// yourself) to ease the line out. Calibrates against whatever angle the player
/// is holding the phone at when a fight starts, rather than an absolute "flat."
final class MotionManager {
    enum TiltState {
        case neutral
        case reeling
        case easing
    }

    private(set) var tiltState: TiltState = .neutral

    private let motionManager = CMMotionManager()
    private var baselinePitch: Double?
    private let tiltThreshold = 0.25 // radians, roughly 14 degrees

    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        baselinePitch = nil
        tiltState = .neutral
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        baselinePitch = nil
        tiltState = .neutral
    }

    private func handle(_ motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch
        if baselinePitch == nil {
            baselinePitch = pitch
        }
        let delta = pitch - (baselinePitch ?? pitch)

        if delta > tiltThreshold {
            tiltState = .reeling
        } else if delta < -tiltThreshold {
            tiltState = .easing
        } else {
            tiltState = .neutral
        }
    }
}
