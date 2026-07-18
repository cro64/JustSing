import AppKit

/// Shared layout and control styling for menu bar popovers.
enum PopoverUI {
    enum Metrics {
        static let width: CGFloat = 220
        static let settingsHeight: CGFloat = 278
        static let margin: CGFloat = 10
        static let sectionSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 6
        static let rowHeight: CGFloat = 20
        static let labelWidth: CGFloat = 62
        static let cornerRadius: CGFloat = 8
        static let controlMinWidth: CGFloat = 100
    }

    /// Clear root that owns the soft shadow; rounded vibrancy lives in the returned effect view.
    static func makeMenuRoot(size: NSSize) -> (root: NSView, effect: NSVisualEffectView) {
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        root.layer?.masksToBounds = false
        root.layer?.shadowColor = NSColor.black.cgColor
        root.layer?.shadowOpacity = 0.28
        root.layer?.shadowRadius = 18
        root.layer?.shadowOffset = .zero
        root.layer?.shadowPath = CGPath(
            roundedRect: CGRect(origin: .zero, size: size),
            cornerWidth: Metrics.cornerRadius,
            cornerHeight: Metrics.cornerRadius,
            transform: nil
        )

        let effect = makeEffectView(size: size)
        effect.autoresizingMask = [.width, .height]
        root.addSubview(effect)
        return (root, effect)
    }

    static func makeEffectView(size: NSSize) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        view.wantsLayer = true
        view.layer?.cornerRadius = Metrics.cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    static func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func fieldLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }

    static func valueLabel(initialValue: String = "") -> NSTextField {
        let label = NSTextField(labelWithString: initialValue)
        label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.drawsBackground = true
        label.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.layer?.masksToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = true
        return label
    }

    static func configurePopUp(_ popUp: NSPopUpButton) {
        popUp.controlSize = .small
        popUp.font = .systemFont(ofSize: NSFont.systemFontSize)
        popUp.translatesAutoresizingMaskIntoConstraints = false
    }

    static func configureSlider(_ slider: NSSlider) {
        slider.controlSize = .small
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
    }

    static func formRow(label: String, control: NSView) -> NSView {
        let title = fieldLabel(label)
        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [title, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            title.widthAnchor.constraint(equalToConstant: Metrics.labelWidth),
            row.heightAnchor.constraint(equalToConstant: Metrics.rowHeight)
        ])
        return row
    }

    static func sliderRow(label: String, slider: NSSlider) -> NSView {
        formRow(label: label, control: slider)
    }

    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    static func linkButton(title: String, target: AnyObject? = nil, action: Selector? = nil) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.controlSize = .small
        button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        button.contentTintColor = .controlAccentColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func accessoryButton(title: String, target: AnyObject? = nil, action: Selector? = nil) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .accessoryBar
        button.controlSize = .small
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func statusHeader(title: String, subtitle: String, indicatorColor: NSColor) -> NSView {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = indicatorColor.cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = indicatorColor == .controlAccentColor ? .controlAccentColor : .labelColor

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [titleField, subtitleField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let row = NSStackView(views: [dot, textStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])
        return row
    }

    static func verticalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func pinContent(_ content: NSView, in container: NSView) {
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.margin),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Metrics.margin),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: Metrics.margin),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Metrics.margin)
        ])
    }
}

/// Slider that reports drag begin/end so callers can show a transient value overlay.
final class DragValueSlider: NSSlider {
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onDragBegan?()
        defer { onDragEnded?() }
        super.mouseDown(with: event)
    }
}
