import Foundation

/// How MinusOne processes live system audio. All three ship in the app — no add-ons.
enum ProcessingMode: String, CaseIterable, Codable {
    /// Unmodified system audio, zero latency.
    case directListen = "directListen"
    /// Instant center-channel vocal reduction (`L − R`), low latency.
    case centerVocalCut = "centerVocalCut"
    /// HTDemucs neural stem separation, higher quality, ~10 s delay.
    case aiVocalSeparation = "aiVocalSeparation"

    var displayName: String {
        switch self {
        case .directListen:
            return "Direct"
        case .centerVocalCut:
            return "Center Cut"
        case .aiVocalSeparation:
            return "Neural"
        }
    }

    var detailText: String {
        switch self {
        case .directListen:
            return "Listen to system audio unchanged, zero latency"
        case .centerVocalCut:
            return "Cut center vocals instantly, low latency"
        case .aiVocalSeparation:
            return "Neural vocal separation, ~10 s delay"
        }
    }

    var supportsVocalReduction: Bool {
        switch self {
        case .directListen:
            return false
        case .centerVocalCut, .aiVocalSeparation:
            return true
        }
    }

    /// Maps persisted raw values, including legacy names from earlier builds.
    static func fromPersisted(_ raw: String) -> ProcessingMode? {
        if let mode = ProcessingMode(rawValue: raw) {
            return mode
        }
        switch raw {
        case "passthrough":
            return .directListen
        case "centerCancel":
            return .centerVocalCut
        case "neuralSeparation":
            return .aiVocalSeparation
        default:
            return nil
        }
    }
}
