import AppKit

// A bunch of three balloons whose strings gather at the walker's head below the view's centre.
@MainActor
final class BalloonView: NSView {
    static let stringLength: CGFloat = 34
    static let balloonSize = NSSize(width: 24, height: 28)
    // Knot offsets from the pivot above the walker, back balloons first.
    static let knots = [CGPoint(x: -13, y: 1), CGPoint(x: 13, y: 2), CGPoint(x: 0, y: 7)]
    static var size: NSSize {
        NSSize(width: 80, height: stringLength + 7 + 4 + balloonSize.height + 2)
    }

    // Degrees the walker hangs away from vertical, matching `Walker.sway`.
    var sway: Double = 0
    var attached = true

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let pivot = CGPoint(x: bounds.midX, y: Self.stringLength)
        let angle = attached ? sway * .pi / 180 : 0
        let end = CGPoint(x: pivot.x + Self.stringLength * sin(angle),
                          y: pivot.y - Self.stringLength * cos(angle))
        let knots = Self.knots.map { CGPoint(x: pivot.x + $0.x, y: pivot.y + $0.y) }

        context.setStrokeColor(NSColor(white: 171.0 / 255, alpha: 1).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(1)
        for knot in knots {
            context.move(to: knot)
            // A slight bow keeps the strings from looking like rigid rods.
            context.addQuadCurve(to: end, control: CGPoint(x: (knot.x + end.x) / 2 - 3,
                                                           y: (knot.y + end.y) / 2))
        }
        context.strokePath()

        context.setLineWidth(2)
        for knot in knots {
            context.move(to: CGPoint(x: knot.x, y: knot.y + 4.5))
            context.addLine(to: CGPoint(x: knot.x - 3, y: knot.y))
            context.addLine(to: CGPoint(x: knot.x + 3, y: knot.y))
            context.closePath()
            context.drawPath(using: .fillStroke)
            context.addEllipse(in: CGRect(x: knot.x - Self.balloonSize.width / 2, y: knot.y + 4,
                                          width: Self.balloonSize.width,
                                          height: Self.balloonSize.height))
            context.drawPath(using: .fillStroke)
        }
    }
}
