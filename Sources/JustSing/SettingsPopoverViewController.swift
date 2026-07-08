import AppKit

final class SettingsPopoverViewController: NSViewController {
    private enum Layout {
        static let width: CGFloat = 220
        static let height: CGFloat = 184
        static let margin: CGFloat = 10
        static let rowSpacing: CGFloat = 8
        static let rowHeight: CGFloat = 24
        static let iconSize: CGFloat = 15
    }

    private let preferences: Preferences
    private let audioEngine: AudioEngine

    private let intensitySlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let makeupSlider = NSSlider(value: 4.5, minValue: 0, maxValue: 12, target: nil, action: nil)
    private let modePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let modelPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
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
        let effectView = NSVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.height)
        )
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        view = effectView

        configureSlider(intensitySlider, action: #selector(intensityChanged))
        configureSlider(makeupSlider, action: #selector(makeupGainChanged))

        modePopUp.controlSize = .mini
        modePopUp.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        modePopUp.target = self
        modePopUp.action = #selector(modeChanged)
        for mode in ProcessingMode.allCases {
            modePopUp.addItem(withTitle: mode.displayName)
        }

        modelPopUp.controlSize = .mini
        modelPopUp.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        modelPopUp.target = self
        modelPopUp.action = #selector(modelChanged)
        for variant in SeparationModelVariant.allCases {
            modelPopUp.addItem(withTitle: variant.displayName)
        }

        permissionButton.bezelStyle = .inline
        permissionButton.controlSize = .mini
        permissionButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        permissionButton.target = self
        permissionButton.action = #selector(openPermissionSettings)

        let controls = NSStackView(views: [
            labeledRow(symbol: "waveform.path", control: modePopUp),
            labeledRow(symbol: "cpu", control: modelPopUp),
            labeledRow(symbol: "music.mic", control: intensitySlider),
            labeledRow(symbol: "speaker.wave.2.fill", control: makeupSlider),
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
            makeupSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            modePopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            modelPopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }

    func reloadFromPreferences() {
        guard isViewLoaded, modePopUp.numberOfItems > 0 else { return }

        if let modeIndex = ProcessingMode.allCases.firstIndex(of: preferences.processingMode) {
            setPopUpSelection(modePopUp, index: modeIndex, action: #selector(modeChanged))
        }
        if let modelIndex = SeparationModelVariant.allCases.firstIndex(of: preferences.separationModelVariant) {
            setPopUpSelection(modelPopUp, index: modelIndex, action: #selector(modelChanged))
        }

        intensitySlider.floatValue = preferences.targetIntensity * 100
        makeupSlider.floatValue = preferences.makeupGainDecibels
        refreshControlStates()
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

    private func refreshControlStates() {
        let neuralAvailable = audioEngine.isNeuralSeparationAvailable
        let mode = preferences.processingMode

        if let neuralIndex = ProcessingMode.allCases.firstIndex(of: .aiVocalSeparation),
           let item = modePopUp.item(at: neuralIndex) {
            item.isEnabled = true
            item.attributedTitle = NSAttributedString(
                string: ProcessingMode.aiVocalSeparation.displayName,
                attributes: neuralAvailable
                    ? [:]
                    : [.foregroundColor: NSColor.secondaryLabelColor]
            )
            item.toolTip = neuralAvailable
                ? ProcessingMode.aiVocalSeparation.detailText
                : SeparationModelFactory.modelInstallHint
        }

        let neuralSelected = mode == .aiVocalSeparation
        modelPopUp.isEnabled = neuralSelected
        modelPopUp.alphaValue = neuralSelected ? 1 : 0.45

        for (index, variant) in SeparationModelVariant.allCases.enumerated() {
            guard let item = modelPopUp.item(at: index) else { continue }
            let installed = audioEngine.isSeparationModelInstalled(variant)
            item.isEnabled = true
            item.attributedTitle = NSAttributedString(
                string: variant.displayName,
                attributes: installed || !variant.hasCoreMLRelease
                    ? (installed ? [:] : [.foregroundColor: NSColor.secondaryLabelColor])
                    : [.foregroundColor: NSColor.secondaryLabelColor]
            )
            item.toolTip = installed
                ? variant.detailText
                : (variant.hasCoreMLRelease
                    ? "Not installed — run Scripts/download-model.sh \(variant.rawValue)"
                    : "CoreML build coming soon")
        }

        let reductionEnabled = mode.supportsVocalReduction
        intensitySlider.isEnabled = reductionEnabled
        makeupSlider.isEnabled = reductionEnabled
        intensitySlider.alphaValue = reductionEnabled ? 1 : 0.45
        makeupSlider.alphaValue = reductionEnabled ? 1 : 0.45
        modePopUp.toolTip = mode.detailText
    }

    private func setPopUpSelection(_ popUp: NSPopUpButton, index: Int, action: Selector) {
        let previousAction = popUp.action
        let previousTarget = popUp.target
        popUp.action = nil
        popUp.target = nil
        popUp.selectItem(at: index)
        popUp.action = previousAction
        popUp.target = previousTarget
    }

    private func labeledRow(symbol: String, control: NSView) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [icon, control])
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

    private func configureSlider(_ slider: NSSlider, action: Selector) {
        slider.controlSize = .mini
        slider.isContinuous = true
        slider.target = self
        slider.action = action
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

    @objc private func modeChanged() {
        let index = modePopUp.indexOfSelectedItem
        guard index >= 0, index < ProcessingMode.allCases.count else { return }

        let mode = ProcessingMode.allCases[index]
        if mode == .aiVocalSeparation, !audioEngine.isNeuralSeparationAvailable {
            if let revert = ProcessingMode.allCases.firstIndex(of: preferences.processingMode) {
                setPopUpSelection(modePopUp, index: revert, action: #selector(modeChanged))
            }
            return
        }

        audioEngine.setProcessingMode(mode)
        if let actual = ProcessingMode.allCases.firstIndex(of: preferences.processingMode) {
            setPopUpSelection(modePopUp, index: actual, action: #selector(modeChanged))
        }
        refreshControlStates()
        onSettingsChanged?()
    }

    @objc private func modelChanged() {
        let index = modelPopUp.indexOfSelectedItem
        guard index >= 0, index < SeparationModelVariant.allCases.count else { return }

        let variant = SeparationModelVariant.allCases[index]
        guard audioEngine.isSeparationModelInstalled(variant) else {
            if let revert = SeparationModelVariant.allCases.firstIndex(of: preferences.separationModelVariant) {
                setPopUpSelection(modelPopUp, index: revert, action: #selector(modelChanged))
            }
            return
        }

        audioEngine.setSeparationModelVariant(variant)
        refreshControlStates()
        onSettingsChanged?()
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
