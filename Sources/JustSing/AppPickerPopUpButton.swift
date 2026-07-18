import AppKit
import CoreAudio

@available(macOS 14.2, *)
private enum AppPickerLayout {
    static let menuWidth: CGFloat = 140
    static let rowHeight: CGFloat = 20
}

/// Pull-down menu of checkable apps for selective Process Tap capture.
@available(macOS 14.2, *)
final class AppPickerPopUpButton: NSPopUpButton, NSMenuDelegate {
    private let preferences: Preferences
    private let audioEngine: AudioEngine

    init(preferences: Preferences, audioEngine: AudioEngine) {
        self.preferences = preferences
        self.audioEngine = audioEngine
        super.init(frame: .zero, pullsDown: true)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadFromPreferences() {
        updateSummaryTitle()
    }

    private func configure() {
        PopoverUI.configurePopUp(self)
        autoenablesItems = false
        menu?.delegate = self
        addItem(withTitle: "None")
        updateSummaryTitle()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenuItems()
    }

    private func rebuildMenuItems() {
        let selected = preferences.selectedAppBundleIDs
        let candidates = AudioProcessEnumerator.processesForAppPicker(includingSelected: selected)
        let apps = candidates.filter { process in
            process.objectID != kAudioObjectUnknown
                || process.isRunningOutput
                || selected.contains(process.bundleID)
        }

        while numberOfItems > 1 {
            removeItem(at: 1)
        }

        if apps.isEmpty {
            let empty = NSMenuItem(title: "No audio apps found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu?.addItem(empty)
            let hint = NSMenuItem(
                title: "Open Music or Spotify and play a track",
                action: nil,
                keyEquivalent: ""
            )
            hint.isEnabled = false
            menu?.addItem(hint)
        } else {
            for app in apps {
                let item = NSMenuItem()
                item.isEnabled = true
                item.toolTip = tooltip(for: app)

                let rowView = AppMenuCheckboxView(
                    app: app,
                    isSelected: selected.contains(app.bundleID),
                    width: AppPickerLayout.menuWidth
                ) { [weak self] bundleID, state in
                    self?.handleToggle(bundleID: bundleID, state: state)
                }
                item.view = rowView
                menu?.addItem(item)
            }
        }

        menu?.addItem(.separator())
        let refresh = NSMenuItem(
            title: "Refresh List",
            action: #selector(refreshList(_:)),
            keyEquivalent: "r"
        )
        refresh.target = self
        refresh.keyEquivalentModifierMask = [.command]
        menu?.addItem(refresh)

        AppLogger.shared.info("App picker menu built with \(apps.count) app(s)")
    }

    private func handleToggle(bundleID: String, state: NSControl.StateValue) {
        let shouldSelect = state == .on
        let isSelected = preferences.selectedAppBundleIDs.contains(bundleID)
        guard shouldSelect != isSelected else { return }

        audioEngine.toggleSelectedAppBundleID(bundleID)
        updateSummaryTitle()
    }

    @objc private func refreshList(_ sender: NSMenuItem) {
        menu?.update()
        updateSummaryTitle()
    }

    private func updateSummaryTitle() {
        let selected = preferences.selectedAppBundleIDs.sorted()
        let title: String

        if selected.isEmpty {
            title = "None"
        } else {
            let names = selected.map(displayName(for:))
            if names.count == 1 {
                title = names[0]
            } else if names.count == 2 {
                title = names.joined(separator: ", ")
            } else {
                title = "\(names.count) apps"
            }
        }

        item(at: 0)?.title = title
    }

    private func displayName(for bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = app.localizedName, !name.isEmpty {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            if !name.isEmpty {
                return name
            }
        }
        return bundleID
    }

    private func tooltip(for app: AudioClientProcess) -> String? {
        if app.isRunningOutput {
            return nil
        }
        if app.objectID != kAudioObjectUnknown {
            return "Start playback in this app before enabling reduction"
        }
        return "Play audio once so JustSing can attach to this app"
    }
}

@available(macOS 14.2, *)
private final class AppMenuCheckboxView: NSView {
    private let checkbox: NSButton
    private let bundleID: String
    private var onToggle: ((String, NSControl.StateValue) -> Void)?

    init(
        app: AudioClientProcess,
        isSelected: Bool,
        width: CGFloat,
        onToggle: @escaping (String, NSControl.StateValue) -> Void
    ) {
        bundleID = app.bundleID
        self.onToggle = onToggle
        checkbox = NSButton(checkboxWithTitle: app.displayName, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: AppPickerLayout.rowHeight))

        checkbox.state = isSelected ? .on : .off
        checkbox.font = .systemFont(ofSize: NSFont.systemFontSize)
        checkbox.target = self
        checkbox.action = #selector(checkboxChanged(_:))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.lineBreakMode = .byTruncatingTail

        addSubview(checkbox)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            checkbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func checkboxChanged(_ sender: NSButton) {
        onToggle?(bundleID, sender.state)
    }
}
