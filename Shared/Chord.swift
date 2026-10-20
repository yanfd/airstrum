import Foundation

enum Chord: String, CaseIterable, Codable, Identifiable {
    case em = "Em"
    case g7 = "G7"
    case c = "C"
    case d = "D"
    case am = "Am"
    case a = "A"
    case e = "E"
    case dm = "Dm"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .em: return "E minor"
        case .g7: return "G dominant 7"
        case .c: return "C major"
        case .d: return "D major"
        case .am: return "A minor"
        case .a: return "A major"
        case .e: return "E major"
        case .dm: return "D minor"
        }
    }
}

enum StrumDirection: String, Codable {
    case down
    case up
}

struct StrumEvent: Codable, Equatable {
    let direction: StrumDirection
    let velocity: Double
    let timestamp: TimeInterval
}
