import AppKit

enum MinusOneIcon {
    /// Waveform glyph from the logo SVG (5-bar variant).
    /// Off: bars with a tall center. On: center collapses to a dot.
    static func waveform(size: CGFloat, color: NSColor, isActive: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // Same scale as the current 7-bar icon; five bars, original heights.
        let designWidth: CGFloat = 108
        let designHeight: CGFloat = 100
        let padding = size * 0.08
        let fitted = min((size - padding * 2) / designWidth, (size - padding * 2) / designHeight)
        let scale = fitted * 1.25
        let offsetX = (size - designWidth * scale) / 2
        let offsetY = (size - designHeight * scale) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY + designHeight * scale)
        context.scaleBy(x: scale, y: -scale)

        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(12)
        context.setLineCap(.round)

        // medium, small, [center], small, medium — tighter spacing
        let bars: [(x: CGFloat, y1: CGFloat, y2: CGFloat)] = [
            (18, 25, 75),
            (36, 35, 65),
            (72, 35, 65),
            (90, 25, 75)
        ]

        for bar in bars {
            context.move(to: CGPoint(x: bar.x, y: bar.y1))
            context.addLine(to: CGPoint(x: bar.x, y: bar.y2))
            context.strokePath()
        }

        if isActive {
            context.addEllipse(in: CGRect(x: 54 - 6, y: 50 - 6, width: 12, height: 12))
            context.fillPath()
        } else {
            context.move(to: CGPoint(x: 54, y: 16.25))
            context.addLine(to: CGPoint(x: 54, y: 83.75))
            context.strokePath()
        }

        context.restoreGState()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
