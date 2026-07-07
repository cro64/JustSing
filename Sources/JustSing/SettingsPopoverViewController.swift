import AppKit

final class SettingsPopoverViewController: NSViewController {
    private enum Layout {
        static let width: CGFloat = 220
        static let margin: CGFloat = 10
        static let rowSpacing: CGFloat = 8
        static let rowHeight: CGFloat = 24
        static let iconSize: CGFloat = 15
    }

    private let preferences: Preferences
    private let audioEngine: AudioEngine

    private let intensitySlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let makeupSlider = NSSlider(value: 4.5, minValue: 0, maxValue: 12, target: nil, action: nil)
    private let permissionButton = NSButton(title: "Open Microphone Settings…", target: nil, action: nil)

    var onSettingsChanged: (() -> Void)?
    var onQuit: (() -> Void)?

    init(preferences: Preferences, audioEngine: AudioEngine) {
        self.preferences = preferences
        self.audioEngine = audioEngine
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: Layout.width, height: 108))
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        view = effectView

        configureSlider(intensitySlider, action: #selector(intensityChanged))
        configureSlider(makeupSlider, action: #selector(makeupGainChanged))

        permissionButton.bezelStyle = .inline
        permissionButton.controlSize = .mini
        permissionButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        permissionButton.target = self
        permissionButton.action = #selector(openPermissionSettings)

        let controls = NSStackView(views: [
            controlCenterRow(symbol: "music.mic", slider: intensitySlider),
            controlCenterRow(symbol: "speaker.wave.2.fill", slider: makeupSlider),
            permissionButton
        ])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = Layout.rowSpacing

        let content = NSStackView(views: [controls, quitFooter()])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Layout.rowSpacing
        content.setCustomSpacing(4, after: controls)
        content.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: Layout.margin),
            content.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -Layout.margin),
            content.topAnchor.constraint(equalTo: effectView.topAnchor, constant: Layout.margin),
            content.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -Layout.margin),
            intensitySlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            makeupSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        reloadFromPreferences()
    }

    func reloadFromPreferences() {
        intensitySlider.floatValue = preferences.targetIntensity * 100
        makeupSlider.floatValue = preferences.makeupGainDecibels
    }

    func updatePermissionButton(for status: AudioEngineStatus) {
        switch status {
        case .permissionRequired(.microphone):
            permissionButton.title = "Open Microphone Settings…"
            permissionButton.isHidden = false
        case .permissionRequired(.systemAudioRecording):
            permissionButton.title = "Open System Audio Settings…"
            permissionButton.isHidden = false
        default:
            permissionButton.isHidden = true
        }
    }

    private func configureSlider(_ slider: NSSlider, action: Selector) {
        slider.controlSize = .mini
        slider.isContinuous = true
        slider.target = self
        slider.action = action
    }

    private func controlCenterRow(symbol: String, slider: NSSlider) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [icon, slider])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            icon.heightAnchor.constraint(equalToConstant: Layout.iconSize),
            row.heightAnchor.constraint(equalToConstant: Layout.rowHeight)
        ])
        return row
    }

    private func quitFooter() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "", target: self, action: #selector(quit))
        quitButton.isBordered = false
        quitButton.bezelStyle = .inline
        quitButton.font = .systemFont(ofSize: 12)
        quitButton.attributedTitle = NSAttributedString(
            string: "Quit JustSing",
            attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.systemFont(ofSize: 12)]
        )
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView(views: [separator, quitButton])
        footer.orientation = .vertical
        footer.alignment = .centerX
        footer.spacing = 6
        footer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalTo: footer.widthAnchor),
            quitButton.widthAnchor.constraint(equalTo: footer.widthAnchor),
            quitButton.heightAnchor.constraint(equalToConstant: 22),
            footer.widthAnchor.constraint(equalToConstant: Layout.width - Layout.margin * 2)
        ])
        return footer
    }

    @objc private func intensityChanged() {
        audioEngine.setTargetIntensity(intensitySlider.floatValue / 100)
        onSettingsChanged?()
    }

    @objc private func makeupGainChanged() {
        audioEngine.setMakeupGainDecibels(makeupSlider.floatValue)
    }

    @objc private func openPermissionSettings() {
        switch audioEngine.status {
        case .permissionRequired(.systemAudioRecording):
            AudioPermission.openSystemAudioRecordingSettings()
        default:
            AudioPermission.openMicrophoneSettings()
        }
    }

    @objc private func quit() {
        onQuit?()
    }
}
