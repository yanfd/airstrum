import Foundation

enum WatchMessageKey {
    static let type = "type"
    static let direction = "direction"
    static let velocity = "velocity"
    static let timestamp = "timestamp"
    static let chord = "chord"
}

enum WatchMessageType: String {
    case strum
    case watchReady
}
