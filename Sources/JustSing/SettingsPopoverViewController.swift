import AppKit

final class SettingsPopoverViewController: NSViewController {
    private let preferences: Preferences
    private let audioEngine: AudioEngine

    private let statusLabel = NSTextField(labelWithString: "")
    private let intensityValueLabel = NSTextField(labelWithString: "")
    private let intensitySlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let makeupValueLabel = NSTextField(labelWithString: "")
    private let makeupSlider = NSSlider(value: 0, minValue: 0, maxValue: 12, target: nil, action: nil)
    private let outputPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let hotkeyLabel = NSTextField(labelWithString: "Toggle: ⌘⌥V")
    private let permissionButton = NSButton(title: "Open Microphone Settings", target: nil, action: nil)

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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 320))
        view.wantsLayer = true

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        intensitySlider.isContinuous = true
        intensitySlider.target = self
        intensitySlider.action = #selector(intensityChanged)

        makeupSlider.isContinuous = true
        makeupSlider.target = self
        makeupSlider.action = #selector(makeupGainChanged)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)

        permissionButton.bezelStyle = .rounded
        permissionButton.target = self
        permissionButton.action = #selector(openMicrophoneSettings)

        hotkeyLabel.font = .systemFont(ofSize: 11)
        hotkeyLabel.textColor = .tertiaryLabelColor

        let quitButton = NSButton(title: "Quit JustSing", target: self, action: #selector(quit))
        quitButton.bezelStyle = .rounded

        let intensityHeader = rowHeader(title: "Intensity", valueLabel: intensityValueLabel)
        let makeupHeader = rowHeader(title: "Makeup Gain", valueLabel: makeupValueLabel)
        let outputLabel = sectionLabel("Output Device")

        let stack = NSStackView(views: [
            statusLabel,
            separator(),
            intensityHeader,
            intensitySlider,
            makeupHeader,
            makeupSlider,
            outputLabel,
            outputPopup,
            launchAtLoginCheckbox,
            hotkeyLabel,
            permissionButton,
            quitButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            intensitySlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            makeupSlider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            outputPopup.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32)
        ])

        reloadFromPreferences()
    }

    func reloadFromPreferences() {
        intensitySlider.floatValue = preferences.targetIntensity * 100
        makeupSlider.floatValue = preferences.makeupGainDecibels
        launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        permissionButton.isHidden = !AudioInputPermission.isDenied
        reloadOutputDevices()
        updateValueLabels()
    }

    func updateStatus(_ status: AudioEngineStatus) {
        var text = status.displayText
        if let backend = audioEngine.activeCaptureBackend {
            text += " (\(backend.displayName))"
        }
        statusLabel.stringValue = text
    }

    func reloadOutputDevices() {
        outputPopup.removeAllItems()
        let devices = audioEngine.availableOutputDevices()

        if devices.isEmpty {
            outputPopup.addItem(withTitle: "No compatible output")
            outputPopup.isEnabled = false
            return
        }

        outputPopup.isEnabled = true
        var selectedIndex = 0
        for (index, device) in devices.enumerated() {
            outputPopup.addItem(withTitle: device.name)
            outputPopup.lastItem?.representedObject = device.uid
            if isSelected(device) {
                selectedIndex = index
            }
        }
        outputPopup.selectItem(at: selectedIndex)
        outputPopup.target = self
        outputPopup.action = #selector(outputDeviceChanged)
    }

    private func isSelected(_ device: AudioDevice) -> Bool {
        if let selected = audioEngine.selectedOutputDevice {
            return selected.uid == device.uid
        }
        return preferences.preferredOutputDeviceUID == device.uid
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func rowHeader(title: String, valueLabel: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right

        let row = NSStackView(views: [titleLabel, valueLabel])
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 268).isActive = true
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 268).isActive = true
        return box
    }

    private func updateValueLabels() {
        intensityValueLabel.stringValue = "\(Int(intensitySlider.floatValue.rounded()))%"
        makeupValueLabel.stringValue = String(format: "%.1f dB", makeupSlider.floatValue)
    }

    @objc private func intensityChanged() {
        audioEngine.setTargetIntensity(intensitySlider.floatValue / 100)
        updateValueLabels()
        onSettingsChanged?()
    }

    @objc private func makeupGainChanged() {
        audioEngine.setMakeupGainDecibels(makeupSlider.floatValue)
        updateValueLabels()
    }

    @objc private func outputDeviceChanged() {
        guard
            let uid = outputPopup.selectedItem?.representedObject as? String,
            let device = CoreAudioDevices.device(withUID: uid)
        else {
            return
        }
        audioEngine.selectOutputDevice(device)
        reloadOutputDevices()
    }

    @objc private func toggleLaunchAtLogin() {
        let shouldEnable = launchAtLoginCheckbox.state == .on
        do {
            try LaunchAtLoginController.setEnabled(shouldEnable)
            preferences.launchAtLogin = shouldEnable
        } catch {
            launchAtLoginCheckbox.state = .off
            AppLogger.shared.error("Failed to update launch-at-login: \(error.localizedDescription)")
        }
    }

    @objc private func openMicrophoneSettings() {
        AudioInputPermission.openMicrophonePrivacySettings()
    }

    @objc private func quit() {
        onQuit?()
    }
}
