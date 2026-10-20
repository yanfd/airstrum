import CoreMotion
import Foundation
import WatchConnectivity

@MainActor
final class WatchMotionController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastDirection: StrumDirection?
    @Published private(set) var lastVelocity = 0.0
    @Published private(set) var currentChord: String?

    private let motion = CMMotionManager()
    private let connectivity = WCSession.default
    private var lastAcceleration = 0.0
    private var lastEventTime = 0.0
    private var lastSign = 0.0

    override init() {
        super.init()
        configureConnectivity()
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    private func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] data, _ in
            guard let self, let data else { return }
            Task { @MainActor in self.process(data) }
        }
        isRunning = true
    }

    private func stop() {
        motion.stopDeviceMotionUpdates()
        isRunning = false
    }

    private func process(_ data: CMDeviceMotion) {
        let acceleration = data.userAcceleration.y
        let delta = acceleration - lastAcceleration
        lastAcceleration = acceleration
        let now = data.timestamp
        guard abs(delta) > 0.18, now - lastEventTime > 0.16 else { return }
        let sign = delta.sign == .minus ? -1.0 : 1.0
        guard sign != lastSign || now - lastEventTime > 0.28 else { return }
        lastSign = sign
        lastEventTime = now
        let velocity = min(max(abs(delta) * 2.5, 0.15), 1.0)
        let direction: StrumDirection = sign < 0 ? .down : .up
        lastDirection = direction
        lastVelocity = velocity
        send(direction: direction, velocity: velocity, timestamp: now)
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else { return }
        connectivity.delegate = self
        connectivity.activate()
    }

    private func send(direction: StrumDirection, velocity: Double, timestamp: TimeInterval) {
        guard connectivity.activationState == .activated, connectivity.isReachable else { return }
        connectivity.sendMessage([
            WatchMessageKey.type: WatchMessageType.strum.rawValue,
            WatchMessageKey.direction: direction.rawValue,
            WatchMessageKey.velocity: velocity,
            WatchMessageKey.timestamp: timestamp
        ], replyHandler: nil)
    }
}

extension WatchMotionController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            guard message[WatchMessageKey.type] as? String == WatchMessageType.watchReady.rawValue else { return }
            self.currentChord = message[WatchMessageKey.chord] as? String
        }
    }
}
