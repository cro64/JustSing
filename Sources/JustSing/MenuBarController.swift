import AppKit

final class MenuBarController: NSObject, NSPopoverDelegate {
    private let preferences: Preferences
    private let audioEngine: AudioEngine
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let settingsViewController: SettingsPopoverViewController

    private var currentStatus: AudioEngineStatus = .idle
    private var isFilterActive = false

    init(preferences: Preferences, audioEngine: AudioEngine) {
        self.preferences = preferences
        self.audioEngine = audioEngine
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        settingsViewController = SettingsPopoverViewController(
            preferences: preferences,
            audioEngine: audioEngine
        )
        super.init()
        configureStatusItem()
        configurePopover()
    }

    func updateStatus(_ status: AudioEngineStatus) {
        currentStatus = status
        isFilterActive = audioEngine.isReductionEnabled
        if let button = statusItem.button {
            button.toolTip = {
                var text = status.displayText
                if let backend = audioEngine.activeCaptureBackend {
                    text += " — \(backend.displayName)"
                }
                return text
            }()
        }
        updateIcon()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 220, height: 108)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = settingsViewController

        settingsViewController.onSettingsChanged = { [weak self] in
            self?.updateIcon()
        }
        settingsViewController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let size: CGFloat = 18
        let color: NSColor

        if case .error = currentStatus {
            color = .systemRed
        } else if case .permissionRequired = currentStatus {
            color = .systemOrange
        } else if case .monoInput = currentStatus {
            color = .systemYellow
        } else if isFilterActive {
            color = .controlAccentColor
        } else {
            color = .white
        }

        button.image = FeatherIcon.headphones(size: size, color: color)
        button.contentTintColor = nil
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            togglePopover(on: sender)
            return
        }

        audioEngine.toggleReduction()
        updateStatus(audioEngine.status)
    }

    private func togglePopover(on button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        settingsViewController.reloadFromPreferences()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverDidClose(_ notification: Notification) {
        settingsViewController.reloadFromPreferences()
    }
}
