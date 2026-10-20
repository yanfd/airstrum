#if !CONNECTIVITY_CHECKS
import AVFoundation
import WatchConnectivity
#endif
import Combine
import Foundation

@MainActor
final class AirStrumSession: NSObject, ObservableObject {
    @Published private(set) var heldChord: Chord?
    @Published private(set) var lastStrum: StrumEvent?
    @Published private(set) var watchConnected = false
    @Published private(set) var isAudioReady = false
    @Published private(set) var communicationError: String?

    private let audio = ChordAudioEngine()
    private let connectivity = WCSession.default
    private var strumGeneration = UUID()
    private let contextSession = UUID().uuidString
    private var contextRevision = 0
    private var receiverID: String?
    private var lastSequence = 0

    override init() {
        super.init()
        audio.prepare()
        isAudioReady = audio.isReady
        configureConnectivity()
    }

    func press(chord: Chord) {
        rotateContext()
        heldChord = chord
        audio.beginChord(chord)
        sendChordToWatch(chord)
    }

    func releaseChord() {
        rotateContext()
        heldChord = nil
        audio.releaseChord()
        sendChordToWatch(nil)
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else {
            communicationError = "Watch connectivity is not supported on this device."
            return
        }
        connectivity.delegate = self
        connectivity.activate()
    }

    private func sendChordToWatch(_ chord: Chord?) {
        guard connectivity.activationState == .activated else {
            communicationError = "Watch connectivity is not activated."
            return
        }
        var message: [String: Any] = [WatchMessageKey.type: WatchMessageType.watchReady.rawValue]
        message[WatchMessageKey.chord] = chord?.rawValue ?? ""
        message["protocolVersion"] = 1
        message["generation"] = strumGeneration.uuidString
        message["contextSession"] = contextSession
        message["contextRevision"] = contextRevision
        message["receiverID"] = receiverID ?? ""
        do {
            try connectivity.updateApplicationContext(message)
            communicationError = nil
        } catch {
            communicationError = "Could not sync chord: \(error.localizedDescription)"
        }
        if connectivity.isReachable {
            connectivity.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.communicationError = "Could not send chord: \(error.localizedDescription)"
                }
            }
        }
    }

    private func rotateContext() {
        strumGeneration = UUID()
        contextRevision += 1
        lastSequence = 0
    }

    private func refreshReachability() {
        let reachable = connectivity.activationState == .activated && connectivity.isReachable
        if reachable != watchConnected {
            rotateContext()
        }
        watchConnected = reachable
    }

    private func handleStrum(_ message: [String: Any]) {
        refreshReachability()
        guard watchConnected, heldChord != nil,
              message["protocolVersion"] as? Int == 1,
              message["generation"] as? String == strumGeneration.uuidString,
              let receiverID, message["receiverID"] as? String == receiverID,
              message[WatchMessageKey.chord] as? String == heldChord?.rawValue,
              let sequence = message["sequence"] as? Int, sequence > lastSequence,
              let directionRaw = message[WatchMessageKey.direction] as? String,
              let direction = StrumDirection(rawValue: directionRaw),
              let rawVelocity = message[WatchMessageKey.velocity] as? Double, rawVelocity.isFinite,
              let timestamp = message[WatchMessageKey.timestamp] as? TimeInterval, timestamp.isFinite else { return }
        let velocity = min(max(rawVelocity, 0), 1)
        lastSequence = sequence
        lastStrum = StrumEvent(direction: direction, velocity: velocity, timestamp: timestamp)
        audio.strum(velocity: velocity, direction: direction)
    }
}

extension AirStrumSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.refreshReachability()
            if let error {
                self.communicationError = "Watch activation failed: \(error.localizedDescription)"
            } else if state == .activated {
                self.sendChordToWatch(self.heldChord)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshReachability()
            self.sendChordToWatch(self.heldChord)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in self.refreshReachability() }
    }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.refreshReachability()
            session.activate()
        }
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if message[WatchMessageKey.type] as? String == WatchMessageType.strum.rawValue {
                self.handleStrum(message)
            } else if message[WatchMessageKey.type] as? String == "requestContext",
                      message["protocolVersion"] as? Int == 1,
                      let receiverID = message["receiverID"] as? String,
                      UUID(uuidString: receiverID) != nil,
                      self.connectivity.activationState == .activated, self.connectivity.isReachable {
                self.refreshReachability()
                self.receiverID = receiverID
                self.rotateContext()
                self.sendChordToWatch(self.heldChord)
            }
        }
    }
}
