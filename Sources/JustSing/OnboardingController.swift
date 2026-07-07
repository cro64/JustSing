import AppKit

enum OnboardingController {
    static func showIfNeeded(preferences: Preferences, captureBackend: CaptureBackend) {
        guard !preferences.hasCompletedOnboarding else { return }

        let alert = NSAlert()
        alert.messageText = "Welcome to JustSing"
        alert.informativeText = """
        JustSing reduces center-panned vocals in live system audio from any app — Music, Spotify, browser playback, and more.

        Capture method on this Mac: \(captureBackend.displayName)

        • Left-click the menu bar icon to toggle vocal reduction
        • Right-click for intensity, makeup gain, and other settings
        • Press ⌘⌥M as a global shortcut

        Audio permissions are requested only when you first enable reduction.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Get Started")
        alert.runModal()
        preferences.hasCompletedOnboarding = true
    }
}
