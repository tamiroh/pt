import AppKit

// A bunch of three balloons whose strings gather at the walker's head below the view's centre.
@MainActor
final class BalloonView: NSView {
    static let stringLength: CGFloat = 34
    static let balloonSize = NSSize(width: 24, height: 28)
    // Knot offsets from the pivot above the walker, back balloons first.
    static let knots = [CGPoint(x: -13, y: 1), CGPoint(x: 13, y: 2), CGPoint(x: 0, y: 7)]
    static let burstRoom: CGFloat = 16
    static var size: NSSize {
        NSSize(width: 80, height: stringLength + 7 + 4 + balloonSize.height + 2 + burstRoom)
    }

    private enum Animation {
        case hidden
        case attached
        case released(since: Double)
        case popped(since: Double)
    }

    private var animation = Animation.hidden
    private var origin = CGPoint.zero
    private var sway: Double = 0
    private var time: Double = 0
    var onPop: (() -> Void)?

    var attached: Bool {
        if case .attached = animation { return true }
        return false
    }

    private var opacity: Double {
        switch animation {
        case .hidden: 0
        case .attached, .popped: 1
        case .released(let start): max(0, 1 - (time - start) / 1.5)
        }
    }

    private var burst: Double? {
        guard case .popped(let start) = animation else { return nil }
        return min(1, max(0, (time - start) / 0.25))
    }

    func pop(at now: Double) {
        animation = .popped(since: now)
    }

    func advance(at now: Double, elapsed: Double, floatingOrigin: CGPoint?, sway: Double) {
        time = now
        if let floatingOrigin {
            animation = .attached
            origin = floatingOrigin
            self.sway = sway
            return
        }
        switch animation {
        case .hidden:
            break
        case .attached:
            animation = .released(since: now)
            origin.y += 70 * elapsed
        case .released(let start):
            if now - start >= 1.5 {
                animation = .hidden
            } else {
                origin.y += 70 * elapsed
            }
        case .popped(let start):
            if now - start >= 0.25 { animation = .hidden }
        }
    }

    func render() {
        window?.ignoresMouseEvents = !attached
        window?.setFrameOrigin(origin)
        window?.alphaValue = opacity
        needsDisplay = true
    }

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var balloons: [CGRect] {
        Self.knots.map {
            CGRect(x: bounds.midX + $0.x - Self.balloonSize.width / 2, y: Self.stringLength + $0.y + 4,
                   width: Self.balloonSize.width, height: Self.balloonSize.height)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return attached && balloons.contains { $0.contains(local) } ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        onPop?()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        if let burst {
            drawBurst(context, progress: burst)
            return
        }
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

    private func drawBurst(_ context: CGContext, progress: Double) {
        let cluster = balloons.reduce(balloons[0]) { $0.union($1) }
        let center = CGPoint(x: cluster.midX, y: cluster.midY)
        let radius = 14 + 14 * progress
        let dot = 3.5 * (1 - 0.4 * progress)
        context.setFillColor(NSColor(white: 171.0 / 255, alpha: 1 - progress).cgColor)
        for index in 0..<10 {
            let angle = (Double(index) + 0.5) * .pi / 5
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            context.fillEllipse(in: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot))
        }
    }
}
