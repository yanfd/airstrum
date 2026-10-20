import Combine
import Foundation

enum CheckFailure: Error { case transport }
enum WCSessionActivationState { case notActivated, activated, inactive }

protocol WCSessionDelegate: AnyObject {
    func session(_ session: WCSession, didReceiveMessage message: [String: Any])
}

final class WCSession: @unchecked Sendable {
    static var `default` = WCSession()
    static func isSupported() -> Bool { true }
    weak var delegate: WCSessionDelegate?
    var activationState = WCSessionActivationState.activated
    var isReachable = true
    var receivedApplicationContext: [String: Any] = [:]
    var context: [String: Any] = [:]
    var sent: [[String: Any]] = []
    var failContext = false
    var failSend = false
    var route: (([String: Any]) -> Void)?
    var requests = 0

    func activate() {}
    func updateApplicationContext(_ value: [String: Any]) throws {
        if failContext { throw CheckFailure.transport }
        context = value
    }
    func sendMessage(_ value: [String: Any], replyHandler: (([String: Any]) -> Void)?, errorHandler: ((Error) -> Void)? = nil) {
        precondition(replyHandler == nil, "No per-event request/reply is allowed")
        requests += 1
        precondition(value["type"] as? String != "validateStrum")
        if failSend { errorHandler?(CheckFailure.transport); return }
        sent.append(value)
        route?(value)
    }
}

final class ChordAudioEngine {
    static var velocities: [Double] = []
    var isReady = true
    func prepare() {}
    func beginChord(_ chord: Chord) {}
    func releaseChord() {}
    func strum(velocity: Double, direction: StrumDirection) { Self.velocities.append(velocity) }
}

final class CMDeviceMotion: @unchecked Sendable {
    struct Acceleration { let y: Double }
    let userAcceleration: Acceleration
    let timestamp: Double
    init(_ acceleration: Double, age: Double = 0) {
        userAcceleration = Acceleration(y: acceleration)
        timestamp = ProcessInfo.processInfo.systemUptime - age
    }
}

final class CMMotionManager {
    static var latest: CMMotionManager?
    var isDeviceMotionAvailable = true
    var deviceMotionUpdateInterval = 0.0
    var callback: ((CMDeviceMotion?, Error?) -> Void)?
    init() { Self.latest = self }
    func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping (CMDeviceMotion?, Error?) -> Void) { callback = handler }
    func stopDeviceMotionUpdates() {}
}

@main struct ConnectivityChecks {
    static let contract = """
    Production controllers run unchanged with CONNECTIVITY_CHECKS hardware mocks.
    Phone publishes a versioned generation/chord context before performance. Watch requests
    context only on connection activation/reconnect, then sends each gesture once, without replies.
    Phone accepts only the active held chord/token/receiver and an increasing sequence.
    A single high-water integer bounds dedup storage; reordered older events are discarded too.
    Chord/release and observed phone transitions rotate tokens. Watch transitions invalidate its
    receiver ID so cached pre-reconnect contexts cannot arm it. No offline queue or retry exists.
    Context synchronization can drop the earliest stroke after a chord change or reconnect.
    Unsynchronized wall timestamps are metadata, not age checks. An unseen brief outage or delayed
    packet in the same active context may pass: there is no cross-device bounded-age guarantee.
    Stopping watch motion cannot retract packets already sent. No zero-latency guarantee is made.
    Mocks do not establish WCSession delivery, OS lifecycle, hardware latency, or audio fidelity.
    Run bash Scripts/check-connectivity.sh; no signing or license mutation is needed.
    """

    @MainActor static func drain() async throws { try await Task.sleep(nanoseconds: 30_000_000) }

    @MainActor static func main() async throws {
        print(contract)
        let phoneLink = WCSession()
        phoneLink.isReachable = false
        WCSession.default = phoneLink
        let phone = AirStrumSession()
        phone.press(chord: .c)
        let offlineContext = phoneLink.context
        precondition(!phone.watchConnected && offlineContext["chord"] as? String == "C")
        phone.releaseChord()
        precondition(phoneLink.context["chord"] as? String == "")
        precondition(phoneLink.context["generation"] as? String != offlineContext["generation"] as? String)
        phone.press(chord: .em)

        let watchLink = WCSession()
        WCSession.default = watchLink
        let watch = WatchMotionController()
        let motion = CMMotionManager.latest!
        phoneLink.route = { watch.session(watchLink, didReceiveMessage: $0) }
        watchLink.route = { message in
            if message["type"] as? String == "requestContext" {
                phone.session(phoneLink, didReceiveMessage: message)
            }
        }
        watch.toggle()
        func emit(_ acceleration: Double, age: Double = 0) async throws {
            motion.callback?(CMDeviceMotion(acceleration, age: age), nil)
            try await drain()
        }
        func deliver(_ message: [String: Any]) async throws {
            let requests = phoneLink.requests
            phone.session(phoneLink, didReceiveMessage: message)
            try await drain()
            precondition(phoneLink.requests == requests, "Strum handling must never send a request before audio (or after)")
        }
        func packet(_ sequence: Int, context: [String: Any]? = nil) -> [String: Any] {
            var message = context ?? phoneLink.context
            message["type"] = "strum"
            message["direction"] = "down"
            message["velocity"] = 0.6
            message["timestamp"] = -123_456.0
            message["sequence"] = sequence
            return message
        }
        try await emit(0)
        try await emit(0.3)
        precondition(watchLink.sent.isEmpty, "No compatible context, no gesture send")
        phoneLink.isReachable = true
        phone.sessionReachabilityDidChange(phoneLink)
        watch.session(watchLink, activationDidCompleteWith: .activated, error: nil)
        try await drain()
        try await drain()
        precondition(watch.currentChord == "Em" && phone.watchConnected)
        try await Task.sleep(nanoseconds: 180_000_000)
        try await emit(-0.3)
        let first = watchLink.sent.last!
        precondition(first["type"] as? String == "strum" && first["sequence"] as? Int == 1)
        try await deliver(first)
        precondition(ChordAudioEngine.velocities.count == 1)
        try await deliver(first)
        precondition(ChordAudioEngine.velocities.count == 1)
        print("PASS: proactive sync, held-context gating, single-hop audio, duplicate rejection")

        let oldContext = phoneLink.context
        phone.press(chord: .d)
        try await deliver(packet(2, context: oldContext))
        precondition(ChordAudioEngine.velocities.count == 1)
        try await drain()
        precondition(watch.currentChord == "D")
        watch.session(watchLink, didReceiveApplicationContext: oldContext)
        try await drain()
        precondition(watch.currentChord == "D")
        try await deliver(packet(2))
        precondition(phone.lastStrum?.timestamp == -123_456)
        let heldContext = phoneLink.context
        phone.releaseChord()
        try await deliver(packet(3, context: heldContext))
        try await deliver(packet(3))
        precondition(ChordAudioEngine.velocities.count == 2 && watch.currentChord == nil)
        try await Task.sleep(nanoseconds: 180_000_000)
        let beforeReleaseStroke = watchLink.sent.count
        try await emit(0.3)
        precondition(watchLink.sent.count == beforeReleaseStroke)
        phone.press(chord: .d)
        try await deliver(packet(4, context: heldContext))
        precondition(ChordAudioEngine.velocities.count == 2)
        print("PASS: stale generation, out-of-order context, release, same-chord repress")

        for invalid in [Double.nan, .infinity, -.infinity] {
            var message = packet(1)
            message["velocity"] = invalid
            try await deliver(message)
        }
        for key in ["generation", "receiverID", "sequence", "protocolVersion", "chord"] {
            var message = packet(1)
            message.removeValue(forKey: key)
            try await deliver(message)
        }
        var malformed = packet(1)
        malformed["timestamp"] = Double.nan
        try await deliver(malformed)
        malformed = packet(1)
        malformed["direction"] = "sideways"
        try await deliver(malformed)
        precondition(ChordAudioEngine.velocities.count == 2)
        var high = packet(1)
        high["velocity"] = 12.0
        try await deliver(high)
        precondition(phone.lastStrum?.velocity == 1)
        var low = packet(2)
        low["velocity"] = -2.0
        try await deliver(low)
        precondition(phone.lastStrum?.velocity == 0)
        for sequence in 3...300 { phone.session(phoneLink, didReceiveMessage: packet(sequence)) }
        try await drain()
        let afterStream = ChordAudioEngine.velocities.count
        try await deliver(packet(1))
        try await deliver(packet(299))
        precondition(ChordAudioEngine.velocities.count == afterStream)
        print("PASS: malformed payloads, arbitrary wall-clock skew, clamping, constant-space replay fence")

        let beforeReconnect = phoneLink.context
        phoneLink.isReachable = false
        phone.sessionReachabilityDidChange(phoneLink)
        watchLink.isReachable = false
        watch.sessionReachabilityDidChange(watchLink)
        try await drain()
        let offlineSent = watchLink.sent.count
        try await Task.sleep(nanoseconds: 180_000_000)
        try await emit(-0.3)
        precondition(watchLink.sent.count == offlineSent && watch.communicationError != nil)
        phoneLink.isReachable = true
        watchLink.isReachable = true
        phone.sessionReachabilityDidChange(phoneLink)
        watchLink.route = nil
        watch.sessionReachabilityDidChange(watchLink)
        try await drain()
        watch.session(watchLink, didReceiveApplicationContext: beforeReconnect)
        try await drain()
        precondition(watch.currentChord == nil)
        try await deliver(packet(301, context: beforeReconnect))
        precondition(ChordAudioEngine.velocities.count == afterStream)
        let request = watchLink.sent.last!
        precondition(request["type"] as? String == "requestContext")
        phone.session(phoneLink, didReceiveMessage: request)
        try await drain()
        try await drain()
        precondition(watch.currentChord == "D")
        try await deliver(packet(1))
        try await deliver(packet(301, context: beforeReconnect))
        precondition(ChordAudioEngine.velocities.count == afterStream + 1)
        print("PASS: observed reconnect invalidates old token and cached context, no queue/retry")

        let delayed = packet(2)
        try await Task.sleep(nanoseconds: 550_000_000)
        try await deliver(delayed)
        precondition(ChordAudioEngine.velocities.count == afterStream + 2)
        try await deliver(delayed)
        precondition(ChordAudioEngine.velocities.count == afterStream + 2)
        print("PASS: delayed same-context packet documents lack of bounded-age guarantee; replay still rejected")

        let oldCallback = motion.callback!
        watch.toggle()
        precondition(!watch.isRunning && watch.lastDirection == nil && watch.lastVelocity == 0)
        watch.toggle()
        oldCallback(nil, CheckFailure.transport)
        try await drain()
        precondition(watch.isRunning && watch.motionError == nil)
        try await emit(8, age: 1)
        try await emit(0)
        precondition(watch.lastDirection == nil)
        watchLink.failSend = true
        try await emit(0.3)
        precondition(watch.communicationError?.contains("send strum") == true)
        watchLink.failSend = false
        motion.callback?(nil, CheckFailure.transport)
        try await drain()
        precondition(!watch.isRunning && watch.motionError != nil)
        motion.isDeviceMotionAvailable = false
        watch.toggle()
        precondition(!watch.isRunning)
        print("PASS: motion baseline/reset/stale sample, late callback, motion and send errors")

        phoneLink.failContext = true
        phone.press(chord: .c)
        precondition(phone.communicationError?.contains("sync chord") == true)
        phoneLink.failContext = false
        phoneLink.failSend = true
        phone.press(chord: .d)
        try await drain()
        precondition(phone.communicationError?.contains("send chord") == true)
        phone.session(phoneLink, activationDidCompleteWith: .notActivated, error: CheckFailure.transport)
        watch.session(watchLink, activationDidCompleteWith: .notActivated, error: CheckFailure.transport)
        try await drain()
        precondition(phone.communicationError?.contains("activation failed") == true)
        precondition(watch.communicationError?.contains("activation failed") == true)
        precondition(!phoneLink.sent.contains { $0["type"] as? String == "validateStrum" })
        print("PASS: explicit context/send/activation errors; no validateStrum or per-event outbound request")
    }
}
