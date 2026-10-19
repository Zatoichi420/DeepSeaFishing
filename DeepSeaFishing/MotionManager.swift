#if os(tvOS)
import Foundation

/// Apple TV has no motion sensors; tilt controls simply never engage.
final class MotionManager {
    enum TiltState { case neutral, reeling, easing }
    let tiltState: TiltState = .neutral
    var isAvailable: Bool { false }
    func start() {}
    func stop() {}
    func recalibrate() {}
}
#else
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
    private var calibrationSamples: [Double] = []
    // ~300ms at the 20Hz update interval below - long enough to average out one
    // noisy sample (a finger still adjusting grip when the fight starts), short
    // enough that the player doesn't notice a delay before tilt starts working.
    private let calibrationSampleCount = 6
    private let tiltThreshold = 0.25 // radians, roughly 14 degrees

    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        beginCalibration()
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        beginCalibration()
    }

    /// Re-zeroes against whatever angle the phone is being held at right now.
    /// Exposed so a player can fix a fight where tilt feels backwards/dead -
    /// the original single-sample calibration below had no such recovery path.
    func recalibrate() {
        beginCalibration()
    }

    private func beginCalibration() {
        baselinePitch = nil
        calibrationSamples.removeAll()
        tiltState = .neutral
    }

    private func handle(_ motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch

        if baselinePitch == nil {
            calibrationSamples.append(pitch)
            guard calibrationSamples.count >= calibrationSampleCount else { return }
            baselinePitch = calibrationSamples.reduce(0, +) / Double(calibrationSamples.count)
            calibrationSamples.removeAll()
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
#endif
