import AppKit

enum FeatherIcon {
    static func headphones(size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let scale = size / 24.0
        context.saveGState()
        context.translateBy(x: 0, y: size)
        context.scaleBy(x: scale, y: -scale)

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Feather "headphones" icon: headband with side stems plus ear cups.
        let headband = CGMutablePath()
        headband.move(to: CGPoint(x: 3, y: 18))
        headband.addLine(to: CGPoint(x: 3, y: 12))
        headband.addArc(
            center: CGPoint(x: 12, y: 12),
            radius: 9,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        headband.addLine(to: CGPoint(x: 21, y: 18))
        context.addPath(headband)
        context.strokePath()

        let leftCup = CGPath(
            roundedRect: CGRect(x: 1, y: 16, width: 4, height: 6),
            cornerWidth: 2,
            cornerHeight: 2,
            transform: nil
        )
        context.addPath(leftCup)
        context.strokePath()

        let rightCup = CGPath(
            roundedRect: CGRect(x: 19, y: 16, width: 4, height: 6),
            cornerWidth: 2,
            cornerHeight: 2,
            transform: nil
        )
        context.addPath(rightCup)
        context.strokePath()

        context.restoreGState()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
