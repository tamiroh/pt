import AppKit

@MainActor
final class WalkerWindow: NSWindow {
    static let size = WalkerView.size
    static let headTop = WalkerView.headTop

    private let drawingView = ContentView(frame: NSRect(origin: .zero, size: WalkerView.size))
    private var dragOffset: NSPoint?
    private var dragOrigin: NSPoint?
    private var flailPhase: Double = 0
    var onDragEnded: ((NSPoint) -> Void)?
    var onMenuRequested: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        contentView = drawingView
    }

    required init?(coder: NSCoder) { nil }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    var isDragging: Bool { dragOrigin != nil }

    var menuAnchor: NSRect {
        NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: Self.headTop)
    }

    var bubbleAnchor: NSPoint { NSPoint(x: frame.midX, y: frame.minY + Self.headTop) }

    func balloonAnchor(for walker: Walker, on ground: NSRect) -> NSPoint? {
        guard walker.isFloating, !isDragging else { return nil }
        return NSPoint(x: ground.minX + walker.x + Self.size.width / 2,
                       y: ground.minY + walker.height + Self.headTop)
    }

    func advance(seconds: Double) {
        guard isDragging else { return }
        flailPhase = (flailPhase + seconds * 2 * .pi * 7).truncatingRemainder(dividingBy: 2 * .pi)
    }

    func render(_ walker: Walker, on ground: NSRect, walking: Bool) {
        let floating = walker.isFloating && !isDragging
        if let dragOrigin {
            setFrameOrigin(dragOrigin)
        } else {
            let angle = walker.sway * .pi / 180
            let length = floating ? BalloonWindow.stringLength : 0
            setFrameOrigin(NSPoint(x: ground.minX + walker.x + length * sin(angle),
                                   y: ground.minY + walker.height + length * (1 - cos(angle))))
        }
        alphaValue = walker.isOffstage ? 0 : 1
        ignoresMouseEvents = walker.isOffstage
        drawingView.floating = floating
        drawingView.sway = floating ? walker.sway : 0
        drawingView.swing = isDragging ? sin(flailPhase) * 35 : walker.swing
        drawingView.direction = walker.direction
        drawingView.standing = !isDragging && (!walking || walker.isFalling)
        drawingView.needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        onMenuRequested?()
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { return rightMouseDown(with: event) }
        let pointer = convertPoint(toScreen: event.locationInWindow)
        dragOffset = NSPoint(x: pointer.x - frame.minX, y: pointer.y - frame.minY)
        dragOrigin = frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOffset else { return }
        let pointer = convertPoint(toScreen: event.locationInWindow)
        dragOrigin = NSPoint(x: pointer.x - dragOffset.x, y: pointer.y - dragOffset.y)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOffset != nil else { return }
        mouseDragged(with: event)
        let origin = dragOrigin
        dragOffset = nil
        dragOrigin = nil
        if let origin { onDragEnded?(origin) }
    }

    private final class ContentView: WalkerView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}
