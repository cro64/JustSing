import AppKit

/// First-launch welcome + Neural model download.
enum OnboardingController {
    private static var activeSession: OnboardingSession?

    static func showIfNeeded(preferences: Preferences, captureBackend _: CaptureBackend) {
        guard !preferences.hasCompletedOnboarding else {
            AppLogger.shared.info("Onboarding skipped — already completed")
            return
        }
        guard activeSession == nil else { return }

        let session = OnboardingSession(preferences: preferences) {
            activeSession = nil
        }
        activeSession = session
        session.run()
    }
}

private final class OnboardingSession: NSObject, NSWindowDelegate {
    private let preferences: Preferences
    private let onClose: () -> Void
    private let window: NSWindow
    private let modelInfoButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private let primaryButton = NSButton(title: "Download & Continue", target: nil, action: nil)
    private let skipButton = NSButton(title: "Skip for Now", target: nil, action: nil)
    private var modelInfoPopover: NSPopover?
    private var isBusy = false
    private var previousActivationPolicy: NSApplication.ActivationPolicy = .accessory
    private var downloadTask: Task<Void, Never>?

    private let variant = SeparationModelVariant.balanced

    init(
        preferences: Preferences,
        onClose: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.onClose = onClose

        let size = NSSize(width: 360, height: 260)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MinusOne"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()

        super.init()
        window.delegate = self
        window.contentView = makeContentView(size: size)
    }

    func run() {
        // LSUIElement (.accessory) apps cannot reliably show key windows — flip to regular while open.
        previousActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        AppLogger.shared.info("Onboarding window shown")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isBusy {
            confirmCancelDownload(closingWindow: true)
            return false
        }
        finish(downloaded: false)
        return false
    }

    private func makeContentView(size: NSSize) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: size))

        let brandColor = NSColor(srgbRed: 0.90980, green: 0.27843, blue: 0.35294, alpha: 1)
        let logoImage = MinusOneIcon.waveform(size: 56, color: brandColor, isActive: true)
        let logoView = NSImageView(image: logoImage)
        logoView.imageScaling = .scaleProportionallyUpOrDown
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        logoView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let name = NSTextField(labelWithString: "MinusOne")
        name.font = .systemFont(ofSize: 22, weight: .semibold)
        name.textColor = .labelColor
        name.alignment = .center

        let body = NSTextField(wrappingLabelWithString: """
        Live vocal reduction for system audio. Download the Neural model for best quality (\(variant.approximateDownloadSizeText)), or skip and use Center Cut.
        """)
        body.font = .systemFont(ofSize: NSFont.systemFontSize)
        body.textColor = .secondaryLabelColor
        body.alignment = .center

        configureModelInfoButton()

        let modelLabel = NSTextField(labelWithString: "Neural model · Demucs")
        modelLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        modelLabel.textColor = .secondaryLabelColor

        let modelHeaderSpacer = NSView()
        modelHeaderSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let modelHeader = NSStackView(views: [modelLabel, modelHeaderSpacer, modelInfoButton])
        modelHeader.orientation = .horizontal
        modelHeader.alignment = .centerY
        modelHeader.spacing = 4

        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = defaultStatusText()
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        statusLabel.alignment = .center
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.isHidden = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.heightAnchor.constraint(equalToConstant: 12).isActive = true

        primaryButton.target = self
        primaryButton.action = #selector(primaryClicked)
        primaryButton.keyEquivalent = "\r"
        primaryButton.bezelStyle = .rounded

        skipButton.target = self
        skipButton.action = #selector(skipClicked)
        skipButton.bezelStyle = .rounded

        updatePrimaryButtonTitle()

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = NSStackView(views: [spacer, skipButton, primaryButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .centerY

        let header = NSStackView(views: [logoView, name])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 8

        let stack = NSStackView(views: [
            header, body, modelHeader, statusLabel, progress, buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(12, after: header)
        stack.setCustomSpacing(14, after: body)
        stack.setCustomSpacing(14, after: progress)

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return root
    }

    private func configureModelInfoButton() {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Model source info")?
            .withSymbolConfiguration(config)
        modelInfoButton.image = image
        modelInfoButton.imagePosition = .imageOnly
        modelInfoButton.isBordered = false
        modelInfoButton.bezelStyle = .inline
        modelInfoButton.contentTintColor = .secondaryLabelColor
        modelInfoButton.toolTip = "Where this model comes from"
        modelInfoButton.target = self
        modelInfoButton.action = #selector(showModelInfo)
        modelInfoButton.setContentHuggingPriority(.required, for: .horizontal)
        modelInfoButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        modelInfoButton.widthAnchor.constraint(equalToConstant: 18).isActive = true
        modelInfoButton.heightAnchor.constraint(equalToConstant: 18).isActive = true
    }

    private func defaultStatusText() -> String {
        if SeparationModelFactory.isAvailable(variant) {
            return "Already installed."
        }
        return "One-time download, \(variant.approximateDownloadSizeText)."
    }

    private func updatePrimaryButtonTitle() {
        primaryButton.title = SeparationModelFactory.isAvailable(variant)
            ? "Continue"
            : "Download & Continue"
    }

    @objc private func showModelInfo() {
        if let existing = modelInfoPopover, existing.isShown {
            existing.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let controller = ModelSourceInfoViewController(
            variant: variant,
            onOpenSource: { [weak popover] url in
                NSWorkspace.shared.open(url)
                popover?.performClose(nil)
            }
        )
        popover.contentViewController = controller
        popover.contentSize = controller.preferredContentSize
        modelInfoPopover = popover
        popover.show(relativeTo: modelInfoButton.bounds, of: modelInfoButton, preferredEdge: .maxY)
    }

    @objc private func skipClicked() {
        if isBusy {
            confirmCancelDownload(closingWindow: false)
            return
        }
        finish(downloaded: false)
    }

    @objc private func primaryClicked() {
        guard !isBusy else { return }
        preferences.separationModelVariant = variant

        if SeparationModelFactory.isAvailable(variant) {
            finish(downloaded: true)
            return
        }

        beginDownload()
    }

    private func confirmCancelDownload(closingWindow: Bool) {
        let alert = NSAlert()
        alert.messageText = "Cancel download?"
        alert.informativeText = "The model isn’t installed yet. You can download later with Scripts/download-model.sh, or skip and use Center Cut."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Keep Downloading")
        alert.addButton(withTitle: closingWindow ? "Cancel & Close" : "Cancel Download")
        let response = alert.runModal()
        guard response == .alertSecondButtonReturn else { return }
        cancelDownload(closeAfter: closingWindow)
    }

    private func cancelDownload(closeAfter: Bool) {
        downloadTask?.cancel()
        downloadTask = nil
        ModelDownloadService.cleanupStaging(for: variant)
        isBusy = false
        primaryButton.isEnabled = true
        skipButton.isEnabled = true
        skipButton.title = "Skip for Now"
        progress.isHidden = true
        progress.doubleValue = 0
        statusLabel.stringValue = "Download canceled."
        statusLabel.textColor = .secondaryLabelColor
        updatePrimaryButtonTitle()
        AppLogger.shared.info("Onboarding model download canceled")
        if closeAfter {
            finish(downloaded: false)
        }
    }

    private func beginDownload() {
        isBusy = true
        primaryButton.isEnabled = false
        skipButton.isEnabled = true
        skipButton.title = "Cancel"
        progress.isHidden = false
        progress.doubleValue = 0
        statusLabel.textColor = .secondaryLabelColor

        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await ModelDownloadService.install(self.variant) { [weak self] fraction, message in
                    self?.progress.doubleValue = fraction
                    self?.statusLabel.stringValue = message
                }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.downloadTask = nil
                    self.preferences.separationModelVariant = self.variant
                    self.preferences.processingMode = .aiVocalSeparation
                    self.statusLabel.stringValue = "Model installed. Neural mode is ready."
                    self.statusLabel.textColor = .secondaryLabelColor
                    self.progress.doubleValue = 1
                    self.skipButton.title = "Skip for Now"
                    self.finish(downloaded: true)
                }
            } catch is CancellationError {
                await MainActor.run {
                    if self.isBusy {
                        self.cancelDownload(closeAfter: false)
                    }
                }
            } catch {
                await MainActor.run {
                    self.downloadTask = nil
                    self.isBusy = false
                    self.primaryButton.isEnabled = true
                    self.skipButton.isEnabled = true
                    self.skipButton.title = "Skip for Now"
                    self.progress.isHidden = true
                    self.statusLabel.stringValue = error.localizedDescription
                    self.statusLabel.textColor = .systemRed
                    self.updatePrimaryButtonTitle()
                    AppLogger.shared.error("Onboarding model download failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func finish(downloaded: Bool) {
        preferences.hasCompletedOnboarding = true
        if downloaded {
            AppLogger.shared.info("Onboarding completed with Neural model installed")
        } else {
            AppLogger.shared.info("Onboarding completed without model download")
        }
        modelInfoPopover?.performClose(nil)
        modelInfoPopover = nil
        window.orderOut(nil)
        NSApp.setActivationPolicy(previousActivationPolicy)
        isBusy = false
        downloadTask = nil
        onClose()
    }
}

/// Compact popover explaining where the Neural model comes from.
private final class ModelSourceInfoViewController: NSViewController {
    private let variant: SeparationModelVariant
    private let onOpenSource: (URL) -> Void

    init(variant: SeparationModelVariant, onOpenSource: @escaping (URL) -> Void) {
        self.variant = variant
        self.onOpenSource = onOpenSource
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSView(frame: .zero)

        let title = NSTextField(labelWithString: variant.displayName)
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        title.textColor = .labelColor

        let body = NSTextField(wrappingLabelWithString: variant.sourceAttributionText.trimmingCharacters(in: .whitespacesAndNewlines))
        body.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 0

        var arranged: [NSView] = [title, body]
        if variant.sourcePageURL != nil {
            let link = NSButton(title: "View on Hugging Face", target: self, action: #selector(openSource))
            link.isBordered = false
            link.bezelStyle = .inline
            link.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            link.contentTintColor = .controlAccentColor
            link.alignment = .left
            arranged.append(link)
        }

        let stack = NSStackView(views: arranged)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalToConstant: 252),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        view = root
        root.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(
            width: 280,
            height: ceil(stack.fittingSize.height + 24)
        )
    }

    @objc private func openSource() {
        guard let url = variant.sourcePageURL else { return }
        onOpenSource(url)
    }
}
