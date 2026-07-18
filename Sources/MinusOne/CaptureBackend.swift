import Foundation

enum CaptureBackend: Int {
    case processTap = 0
    case blackHole = 1

    static var preferred: CaptureBackend {
        if #available(macOS 14.2, *) {
            return .processTap
        }
        return .blackHole
    }

    var displayName: String {
        switch self {
        case .processTap:
            return "Process Tap"
        case .blackHole:
            return "BlackHole"
        }
    }
}
