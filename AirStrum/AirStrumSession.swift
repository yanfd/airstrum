import AVFoundation
import Combine
import Foundation
import WatchConnectivity

@MainActor
final class AirStrumSession: NSObject, ObservableObject {
    @Published private(set) var heldChord: Chord?
    @Published private(set) var lastStrum: StrumEvent?
    @Published private(set) var watchConnected = false
    @Published private(set) var isAudioReady = false

    private let audio = ChordAudioEngine()
    private let connectivity = WCSession.default

    override init() {
        super.init()
        audio.prepare()
        isAudioReady = audio.isReady
        configureConnectivity()
    }

    func press(chord: Chord) {
        heldChord = chord
        audio.beginChord(chord)
        sendChordToWatch(chord)
    }

    func releaseChord() {
        heldChord = nil
        audio.releaseChord()
        sendChordToWatch(nil)
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else { return }
        connectivity.delegate = self
        connectivity.activate()
    }

    private func sendChordToWatch(_ chord: Chord?) {
        guard connectivity.activationState == .activated else { return }
        var message: [String: Any] = [WatchMessageKey.type: WatchMessageType.watchReady.rawValue]
        message[WatchMessageKey.chord] = chord?.rawValue ?? ""
        if connectivity.isReachable {
            connectivity.sendMessage(message, replyHandler: nil)
        } else {
            connectivity.updateApplicationContext(message)
        }
    }

    private func handleStrum(_ message: [String: Any]) {
        guard let directionRaw = message[WatchMessageKey.direction] as? String,
              let direction = StrumDirection(rawValue: directionRaw),
              let velocity = message[WatchMessageKey.velocity] as? Double else { return }
        let event = StrumEvent(
            direction: direction,
            velocity: velocity,
            timestamp: message[WatchMessageKey.timestamp] as? TimeInterval ?? Date.timeIntervalSinceReferenceDate
        )
        lastStrum = event
        guard heldChord != nil else { return }
        audio.strum(velocity: velocity, direction: direction)
    }
}

extension AirStrumSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.watchConnected = state == .activated && session.isPaired
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if message[WatchMessageKey.type] as? String == WatchMessageType.strum.rawValue {
                self.handleStrum(message)
            }
        }
    }
}
