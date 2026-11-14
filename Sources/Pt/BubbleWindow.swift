import AppKit

@MainActor
final class BubbleWindow: NSWindow {
    // Proportions come from the website's bubble, which is drawn for a 0.07 walker.
    private static let unit = WalkerView.scale / 0.07
    private static let height = 32 * unit
    private static let radius = 5 * unit
    private static let tail = 7 * unit
    private static let gap = 4 * unit
    private static let padding = 9 * unit
    private static let margin: CGFloat = 1
    private static let ink = NSColor(white: 171.0 / 255, alpha: 1)
    private static let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15 * unit, weight: .medium),
        .foregroundColor: ink,
    ]

    private static func size(for text: String) -> NSSize {
        let width = ceil((text as NSString).size(withAttributes: attributes).width) + 2 * padding
        return NSSize(width: max(height, width) + 2 * margin,
                      height: height + tail + 2 * margin)
    }

    private var content: Content?
    private var time: Double = 0
    private let drawingView = ContentView(frame: .zero)

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: .zero), styleMask: [.borderless],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        alphaValue = 0
        contentView = drawingView
    }

    required init?(coder: NSCoder) { nil }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    var isPresent: Bool { content != nil }

    func show(_ text: String, at now: Double, life: Double) {
        content = Content(text: text, born: now, life: life)
        time = now
    }

    func dismiss() {
        content = nil
    }

    func advance(at now: Double) {
        time = now
        if let content, content.isOver(at: now) { self.content = nil }
    }

    func render(anchor: NSPoint, within ground: NSRect) {
        alphaValue = content?.opacity(at: time) ?? 0
        guard let content else { return }
        if drawingView.text != content.text {
            setContentSize(Self.size(for: content.text))
            drawingView.text = content.text
        }
        let width = frame.width
        let x = max(ground.minX, min(anchor.x - width / 2, ground.maxX - width))
        setFrameOrigin(NSPoint(x: x, y: anchor.y + Self.gap - Self.margin))
        drawingView.tailX = anchor.x - x
        drawingView.needsDisplay = true
    }

    private struct Content {
        private static let fade: Double = 0.2

        let text: String
        let born: Double
        let life: Double

        func isOver(at now: Double) -> Bool { now - born >= life }

        func opacity(at now: Double) -> Double {
            let age = now - born
            return min(1, max(0, min(age / Self.fade, (life - age) / Self.fade)))
        }
    }

    private final class ContentView: NSView {
        var text: String?
        var tailX: CGFloat = 0

        override var isOpaque: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.clear(bounds)
            context.saveGState()
            defer { context.restoreGState() }

            let left = BubbleWindow.margin
            let right = bounds.maxX - BubbleWindow.margin
            let bottom = BubbleWindow.margin + BubbleWindow.tail
            let top = bottom + BubbleWindow.height
            let radius = BubbleWindow.radius
            let halfTail = BubbleWindow.tail / 2
            // Keep the tail on the flat part of the edge when the bubble is pushed sideways.
            let tip = min(max(tailX, left + radius + halfTail), right - radius - halfTail)

            context.setStrokeColor(BubbleWindow.ink.cgColor)
            context.setFillColor(NSColor.white.cgColor)
            context.setLineWidth(2 * BubbleWindow.margin)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: left + radius, y: top))
            context.addQuadCurve(to: CGPoint(x: left, y: top - radius),
                                 control: CGPoint(x: left, y: top))
            context.addLine(to: CGPoint(x: left, y: bottom + radius))
            context.addQuadCurve(to: CGPoint(x: left + radius, y: bottom),
                                 control: CGPoint(x: left, y: bottom))
            context.addLine(to: CGPoint(x: tip - halfTail, y: bottom))
            context.addLine(to: CGPoint(x: tip, y: bottom - BubbleWindow.tail))
            context.addLine(to: CGPoint(x: tip + halfTail, y: bottom))
            context.addLine(to: CGPoint(x: right - radius, y: bottom))
            context.addQuadCurve(to: CGPoint(x: right, y: bottom + radius),
                                 control: CGPoint(x: right, y: bottom))
            context.addLine(to: CGPoint(x: right, y: top - radius))
            context.addQuadCurve(to: CGPoint(x: right - radius, y: top),
                                 control: CGPoint(x: right, y: top))
            context.closePath()
            context.drawPath(using: .fillStroke)

            let text = text ?? ""
            let size = (text as NSString).size(withAttributes: BubbleWindow.attributes)
            (text as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2,
                                                y: (bottom + top) / 2 - size.height / 2),
                                    withAttributes: BubbleWindow.attributes)
        }
    }
}
