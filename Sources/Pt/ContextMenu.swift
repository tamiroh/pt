import AppKit

@MainActor
final class ContextMenu {
    struct Item {
        let title: String
        let action: () -> Void
    }

    static let gap: CGFloat = 4

    private var panel: NSPanel?
    private var view: View?
    private var monitors: [Any] = []

    var isOpen: Bool { panel != nil }

    func open(_ items: [Item], from anchor: NSRect) {
        close()
        let view = View(items: items) { [weak self] item in
            self?.close()
            item.action()
        }
        view.onCancel = { [weak self] in self?.close() }
        let panel = Panel(contentRect: view.frame,
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = view
        self.panel = panel
        self.view = view
        follow(anchor)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            },
            NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
                MainActor.assumeIsolated {
                    if let self, event.window !== self.panel { self.close() }
                }
                return event
            },
        ].compactMap { $0 }
    }

    func follow(_ anchor: NSRect) {
        guard let panel, let view else { return }
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .infinite
        let size = view.frame.size
        let above = anchor.maxY + Self.gap + size.height <= bounds.maxY
        let y = above ? anchor.maxY + Self.gap : anchor.minY - Self.gap - size.height
        let x = min(max(bounds.minX, anchor.midX - size.width / 2),
                    max(bounds.minX, bounds.maxX - size.width))
        view.tailUp = !above
        view.tailX = anchor.midX - x
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func close() {
        guard let panel else { return }
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        panel.orderOut(nil)
        self.panel = nil
        view = nil
    }

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    @MainActor
    private final class View: NSView {
        static let width: CGFloat = 170
        static let itemHeight: CGFloat = 28
        static let stroke: CGFloat = 2
        static let cornerRadius: CGFloat = 10
        static let padding: CGFloat = 12
        static let tail: CGFloat = 8
        static let ink = NSColor(srgbRed: 0xab / 255.0, green: 0xab / 255.0, blue: 0xab / 255.0, alpha: 1)
        static let paper = NSColor.white

        var onCancel: (() -> Void)?
        var tailUp = false {
            didSet { if tailUp != oldValue { needsDisplay = true } }
        }
        var tailX: CGFloat = width / 2 {
            didSet { if tailX != oldValue { needsDisplay = true } }
        }
        var hovered: Int? {
            didSet { if hovered != oldValue { needsDisplay = true } }
        }
        private let items: [Item]
        private let onChoose: (Item) -> Void

        init(items: [Item], onChoose: @escaping (Item) -> Void) {
            self.items = items
            self.onChoose = onChoose
            super.init(frame: NSRect(x: 0, y: 0, width: Self.width,
                                     height: Self.itemHeight * CGFloat(items.count) + 2 * Self.stroke
                                         + Self.tail + Self.stroke))
            addTrackingArea(NSTrackingArea(rect: .zero,
                                           options: [
                                               .mouseMoved, .mouseEnteredAndExited,
                                               .activeAlways, .inVisibleRect,
                                           ],
                                           owner: self))
        }

        required init?(coder: NSCoder) { nil }

        override var isFlipped: Bool { true }
        override var isOpaque: Bool { false }
        override var acceptsFirstResponder: Bool { true }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        private var body: NSRect {
            let height = Self.itemHeight * CGFloat(items.count) + 2 * Self.stroke
            return NSRect(x: 0, y: tailUp ? bounds.height - height : 0, width: bounds.width, height: height)
        }

        private func itemRect(_ index: Int) -> NSRect {
            NSRect(x: body.minX + Self.stroke, y: body.minY + Self.stroke + Self.itemHeight * CGFloat(index),
                   width: body.width - 2 * Self.stroke, height: Self.itemHeight)
        }

        private func item(at point: NSPoint) -> Int? {
            items.indices.first { itemRect($0).contains(point) }
        }

        private func outline() -> NSBezierPath {
            let half = Self.stroke / 2
            let edge = body.insetBy(dx: half, dy: half)
            let radius = Self.cornerRadius - half
            let halfTail = Self.tail / 2
            let tip = min(max(tailX, edge.minX + radius + halfTail), edge.maxX - radius - halfTail)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: edge.minX + radius, y: edge.minY))
            if tailUp {
                path.line(to: NSPoint(x: tip - halfTail, y: edge.minY))
                path.line(to: NSPoint(x: tip, y: edge.minY - Self.tail))
                path.line(to: NSPoint(x: tip + halfTail, y: edge.minY))
            }
            path.appendArc(from: NSPoint(x: edge.maxX, y: edge.minY),
                           to: NSPoint(x: edge.maxX, y: edge.maxY), radius: radius)
            path.appendArc(from: NSPoint(x: edge.maxX, y: edge.maxY),
                           to: NSPoint(x: edge.minX, y: edge.maxY), radius: radius)
            if !tailUp {
                path.line(to: NSPoint(x: tip + halfTail, y: edge.maxY))
                path.line(to: NSPoint(x: tip, y: edge.maxY + Self.tail))
                path.line(to: NSPoint(x: tip - halfTail, y: edge.maxY))
            }
            path.appendArc(from: NSPoint(x: edge.minX, y: edge.maxY),
                           to: NSPoint(x: edge.minX, y: edge.minY), radius: radius)
            path.appendArc(from: NSPoint(x: edge.minX, y: edge.minY),
                           to: NSPoint(x: edge.maxX, y: edge.minY), radius: radius)
            path.close()
            path.lineWidth = Self.stroke
            path.lineJoinStyle = .round
            return path
        }

        override func draw(_ dirtyRect: NSRect) {
            let border = outline()
            Self.paper.setFill()
            border.fill()

            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let inner = body.insetBy(dx: Self.stroke, dy: Self.stroke)
            for (index, item) in items.enumerated() {
                let rect = itemRect(index)
                let selected = index == hovered
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(roundedRect: inner, xRadius: Self.cornerRadius - Self.stroke,
                             yRadius: Self.cornerRadius - Self.stroke).addClip()
                NSBezierPath(rect: rect).addClip()
                if selected {
                    Self.ink.setFill()
                    rect.fill()
                }
                let title = NSAttributedString(string: item.title, attributes: [
                    .font: font,
                    .kern: 1,
                    .foregroundColor: selected ? Self.paper : Self.ink,
                ])
                let height = title.size().height
                title.draw(at: NSPoint(x: rect.minX + Self.padding, y: rect.midY - height / 2))
                NSGraphicsContext.restoreGraphicsState()
            }

            Self.ink.setStroke()
            border.stroke()
        }

        override func mouseMoved(with event: NSEvent) {
            hovered = item(at: convert(event.locationInWindow, from: nil))
        }

        override func mouseEntered(with event: NSEvent) {
            mouseMoved(with: event)
        }

        override func mouseExited(with event: NSEvent) {
            hovered = nil
        }

        override func mouseDown(with event: NSEvent) {}

        override func mouseUp(with event: NSEvent) {
            guard let index = item(at: convert(event.locationInWindow, from: nil)) else { return }
            onChoose(items[index])
        }

        override func keyDown(with event: NSEvent) {
            guard event.keyCode == 53 else { return super.keyDown(with: event) }
            onCancel?()
        }
    }
}
