import AppKit
import AVFoundation
import CoreAudio

enum AudioPermission {
  private static let permissionDeniedStatus: OSStatus = 561211770 // '!perm'

  static func isPermissionDeniedStatus(_ status: OSStatus) -> Bool {
    status == permissionDeniedStatus
  }

  static var isMicrophoneDenied: Bool {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .denied, .restricted:
      return true
    default:
      return false
    }
  }

  static func requestMicrophone(_ completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      completion(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async {
          completion(granted)
        }
      }
    case .denied, .restricted:
      completion(false)
    @unknown default:
      completion(false)
    }
  }

  static func openMicrophoneSettings() {
    openSettings(
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    )
  }

  static func openSystemAudioRecordingSettings() {
    openSettings(
      "x-apple.systempreferences:com.apple.preference.security?Privacy_SystemAudioRecording"
    )
  }

  private static func openSettings(_ urlString: String) {
    guard let url = URL(string: urlString) else { return }
    NSWorkspace.shared.open(url)
  }
}
