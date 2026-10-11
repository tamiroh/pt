import AppKit

struct Bubble {
    static let fade: Double = 0.2

    let text: String
    let born: Double
    let life: Double

    func isOver(at now: Double) -> Bool { now - born >= life }

    func opacity(at now: Double) -> Double {
        let age = now - born
        return min(1, max(0, min(age / Self.fade, (life - age) / Self.fade)))
    }
}

@MainActor
final class BubbleView: NSView {
    // Proportions come from the website's bubble, which is drawn for a 0.07 walker.
    static let unit = WalkerView.scale / 0.07
    static let height = 32 * unit
    static let radius = 5 * unit
    static let tail = 7 * unit
    static let gap = 4 * unit
    static let padding = 9 * unit
    static let margin: CGFloat = 1
    static let ink = NSColor(white: 171.0 / 255, alpha: 1)
    static let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15 * unit, weight: .medium),
        .foregroundColor: ink,
    ]

    static func size(for text: String) -> NSSize {
        let width = ceil((text as NSString).size(withAttributes: attributes).width) + 2 * padding
        return NSSize(width: max(height, width) + 2 * margin,
                      height: height + tail + 2 * margin)
    }

    var text = ""
    var tailX: CGFloat = 0

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.saveGState()
        defer { context.restoreGState() }

        let left = Self.margin
        let right = bounds.maxX - Self.margin
        let bottom = Self.margin + Self.tail
        let top = bottom + Self.height
        let radius = Self.radius
        let halfTail = Self.tail / 2
        // Keep the tail on the flat part of the edge when the bubble is pushed sideways.
        let tip = min(max(tailX, left + radius + halfTail), right - radius - halfTail)

        context.setStrokeColor(Self.ink.cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.setLineWidth(2 * Self.margin)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: left + radius, y: top))
        context.addQuadCurve(to: CGPoint(x: left, y: top - radius),
                             control: CGPoint(x: left, y: top))
        context.addLine(to: CGPoint(x: left, y: bottom + radius))
        context.addQuadCurve(to: CGPoint(x: left + radius, y: bottom),
                             control: CGPoint(x: left, y: bottom))
        context.addLine(to: CGPoint(x: tip - halfTail, y: bottom))
        context.addLine(to: CGPoint(x: tip, y: bottom - Self.tail))
        context.addLine(to: CGPoint(x: tip + halfTail, y: bottom))
        context.addLine(to: CGPoint(x: right - radius, y: bottom))
        context.addQuadCurve(to: CGPoint(x: right, y: bottom + radius),
                             control: CGPoint(x: right, y: bottom))
        context.addLine(to: CGPoint(x: right, y: top - radius))
        context.addQuadCurve(to: CGPoint(x: right - radius, y: top),
                             control: CGPoint(x: right, y: top))
        context.closePath()
        context.drawPath(using: .fillStroke)

        let size = (text as NSString).size(withAttributes: Self.attributes)
        (text as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2,
                                            y: (bottom + top) / 2 - size.height / 2),
                                withAttributes: Self.attributes)
    }
}
