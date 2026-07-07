import AudioToolbox
import Foundation

enum AudioEngineStatus: Equatable {
    case idle
    case passthrough
    case active
    case monoInput
    case permissionRequired
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .passthrough:
            return "Ready - passthrough"
        case .active:
            return "Active - reducing vocals"
        case .monoInput:
            return "Mono input - vocal reduction unavailable"
        case .permissionRequired:
            return "Microphone permission required for BlackHole"
        case .error(let message):
            return message
        }
    }
}

enum AudioEngineError: Error, LocalizedError {
    case blackHoleMissing
        case blackHoleDriverInstalledButNotLoaded
        case processTapUnavailable
        case noPhysicalOutput
    case coreAudio(String, OSStatus)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .blackHoleMissing:
            return "BlackHole is not installed or is not available as an input device."
        case .blackHoleDriverInstalledButNotLoaded:
            return "BlackHole is installed, but CoreAudio has not loaded it yet. Restart CoreAudio or reboot, then reopen JustSing."
        case .processTapUnavailable:
            return "System audio capture is unavailable. Grant System Audio Recording permission in System Settings."
        case .noPhysicalOutput:
            return "No compatible physical output device was found."
        case .coreAudio(let message, let status):
            return "\(message) (OSStatus \(status))"
        case .unsupportedFormat(let message):
            return message
        }
    }
}
