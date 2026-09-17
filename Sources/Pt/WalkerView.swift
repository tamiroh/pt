import AppKit

@MainActor
final class WalkerView: NSView {
    var swing: Double = 0
    var direction: Double = -1
    var standing = false

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.saveGState()
        defer { context.restoreGState() }

        context.translateBy(x: bounds.midX, y: 4)
        context.scaleBy(x: direction < 0 ? 0.07 : -0.07, y: -0.07)
        context.setStrokeColor(NSColor(white: 171.0 / 255, alpha: 1).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.setLineWidth(2 / 0.07)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.move(to: CGPoint(x: -200, y: -170))
        context.addLine(to: CGPoint(x: -200, y: -420))
        context.addCurve(to: CGPoint(x: 0, y: -650),
                         control1: CGPoint(x: -200, y: -565),
                         control2: CGPoint(x: -105, y: -650))
        context.addCurve(to: CGPoint(x: 200, y: -420),
                         control1: CGPoint(x: 105, y: -650),
                         control2: CGPoint(x: 200, y: -565))
        context.addLine(to: CGPoint(x: 200, y: -170))
        context.addCurve(to: CGPoint(x: 170, y: -150),
                         control1: CGPoint(x: 200, y: -155),
                         control2: CGPoint(x: 190, y: -150))
        context.addLine(to: CGPoint(x: -170, y: -150))
        context.addCurve(to: CGPoint(x: -200, y: -170),
                         control1: CGPoint(x: -190, y: -150),
                         control2: CGPoint(x: -200, y: -155))
        context.closePath()
        context.drawPath(using: .fillStroke)

        for x in [-130.0, -25.0] {
            context.move(to: CGPoint(x: x, y: -462))
            context.addLine(to: CGPoint(x: x, y: -378))
        }
        context.strokePath()

        drawLeg(context, hip: CGPoint(x: -90, y: -150), angle: swing,
                knee: standing ? CGPoint(x: -90, y: 0) : CGPoint(x: -132, y: -6),
                foot: standing ? CGPoint(x: -140, y: 0) : CGPoint(x: -180, y: -20))
        drawLeg(context, hip: CGPoint(x: 105, y: -150), angle: -swing,
                knee: standing ? CGPoint(x: 105, y: 0) : CGPoint(x: 147, y: -6),
                foot: standing ? CGPoint(x: 55, y: 0) : CGPoint(x: 99, y: 8))
    }

    private func drawLeg(_ context: CGContext, hip: CGPoint, angle: Double,
                         knee: CGPoint, foot: CGPoint) {
        context.saveGState()
        context.translateBy(x: hip.x, y: hip.y)
        context.rotate(by: standing ? 0 : angle * .pi / 180)
        context.translateBy(x: -hip.x, y: -hip.y)
        context.move(to: hip)
        context.addLine(to: knee)
        context.addLine(to: foot)
        context.strokePath()
        context.restoreGState()
    }
}
