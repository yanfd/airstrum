#if !CONNECTIVITY_CHECKS
import CoreMotion
import WatchConnectivity
#endif
import Combine
import Foundation

@MainActor
final class WatchMotionController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastDirection: StrumDirection?
    @Published private(set) var lastVelocity = 0.0
    @Published private(set) var currentChord: String?
    @Published private(set) var communicationError: String?
    @Published private(set) var motionError: String?

    private let motion = CMMotionManager()
    private let connectivity = WCSession.default
    private var lastAcceleration = 0.0
    private var lastEventTime = 0.0
    private var lastSign = 0.0
    private var hasAccelerationSample = false
    private var motionGeneration = UUID()
    private var receiverID = UUID().uuidString
    private var contextSession: String?
    private var contextRevision = -1
    private var strumGeneration: String?
    private var sequence = 0
    private var wasReachable = false

    override init() {
        super.init()
        configureConnectivity()
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    private func start() {
        guard !isRunning else { return }
        guard motion.isDeviceMotionAvailable else {
            motionError = "Device motion is not available."
            return
        }
        resetDetector()
        motionError = nil
        motionGeneration = UUID()
        let generation = motionGeneration
        isRunning = true
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.isRunning, self.motionGeneration == generation else { return }
                if let error {
                    self.motionError = "Motion updates failed: \(error.localizedDescription)"
                    self.stop()
                    return
                }
                guard let data else { return }
                self.process(data)
            }
        }
    }

    private func stop() {
        isRunning = false
        motionGeneration = UUID()
        motion.stopDeviceMotionUpdates()
        resetDetector()
    }

    private func resetDetector() {
        lastAcceleration = 0
        lastEventTime = 0
        lastSign = 0
        hasAccelerationSample = false
        lastDirection = nil
        lastVelocity = 0
    }

    private func process(_ data: CMDeviceMotion) {
        guard isRunning else { return }
        let acceleration = data.userAcceleration.y
        guard acceleration.isFinite, data.timestamp.isFinite else { return }
        let sampleAge = ProcessInfo.processInfo.systemUptime - data.timestamp
        guard sampleAge >= 0, sampleAge <= 0.25 else { return }
        guard hasAccelerationSample else {
            lastAcceleration = acceleration
            hasAccelerationSample = true
            return
        }
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
        send(direction: direction, velocity: velocity)
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else {
            communicationError = "Watch connectivity is not supported on this device."
            return
        }
        connectivity.delegate = self
        connectivity.activate()
    }

    private func send(direction: StrumDirection, velocity: Double) {
        guard connectivity.activationState == .activated, connectivity.isReachable else {
            invalidateContext()
            wasReachable = false
            communicationError = "iPhone is not reachable. Strum was discarded."
            return
        }
        guard wasReachable, let strumGeneration, let currentChord else { return }
        let generation = motionGeneration
        sequence += 1
        connectivity.sendMessage([
            WatchMessageKey.type: WatchMessageType.strum.rawValue,
            WatchMessageKey.direction: direction.rawValue,
            WatchMessageKey.velocity: velocity,
            WatchMessageKey.timestamp: Date.timeIntervalSinceReferenceDate,
            "protocolVersion": 1,
            "generation": strumGeneration,
            "receiverID": receiverID,
            "sequence": sequence,
            WatchMessageKey.chord: currentChord
        ], replyHandler: nil) { [weak self] error in
            Task { @MainActor in
                guard let self, self.isRunning, self.motionGeneration == generation else { return }
                self.communicationError = "Could not send strum: \(error.localizedDescription)"
            }
        }
    }

    private func receiveChord(_ message: [String: Any]) {
        guard message[WatchMessageKey.type] as? String == WatchMessageType.watchReady.rawValue,
              connectivity.activationState == .activated, connectivity.isReachable, wasReachable,
              message["protocolVersion"] as? Int == 1,
              message["receiverID"] as? String == receiverID,
              let session = message["contextSession"] as? String, UUID(uuidString: session) != nil,
              let revision = message["contextRevision"] as? Int, revision >= 0,
              let generation = message["generation"] as? String, UUID(uuidString: generation) != nil,
              let chord = message[WatchMessageKey.chord] as? String,
              chord.isEmpty || Chord(rawValue: chord) != nil else { return }
        guard session != contextSession || revision > contextRevision else { return }
        contextSession = session
        contextRevision = revision
        strumGeneration = generation
        currentChord = chord.isEmpty ? nil : chord
        communicationError = nil
    }

    private func invalidateContext() {
        receiverID = UUID().uuidString
        strumGeneration = nil
        currentChord = nil
        contextSession = nil
        contextRevision = -1
    }

    private func refreshChordContext() {
        let reachable = connectivity.activationState == .activated && connectivity.isReachable
        guard reachable else {
            wasReachable = false
            invalidateContext()
            communicationError = "iPhone is not reachable."
            return
        }
        guard !wasReachable else { return }
        wasReachable = true
        invalidateContext()
        connectivity.sendMessage([
            WatchMessageKey.type: "requestContext", "protocolVersion": 1, "receiverID": receiverID
        ], replyHandler: nil) { [weak self] error in
            Task { @MainActor in
                self?.communicationError = "Could not sync chord: \(error.localizedDescription)"
            }
        }
    }
}

extension WatchMotionController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                self.communicationError = "iPhone connectivity activation failed: \(error.localizedDescription)"
            } else if state == .activated {
                self.refreshChordContext()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshChordContext() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receiveChord(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.receiveChord(message)
        }
    }
}
