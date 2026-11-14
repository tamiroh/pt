import AppKit
import QuartzCore

@main
@MainActor
struct PtApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let walkerView = WalkerView(frame: NSRect(origin: .zero, size: WalkerView.size))
    private let bubbleView = BubbleView(frame: .zero)
    private let balloonView = BalloonView(frame: NSRect(origin: .zero, size: BalloonView.size))
    private let speech = Speech()
    private let contextMenu = ContextMenu()
    private var window: NSWindow!
    private var bubbleWindow: NSWindow!
    private var balloonWindow: NSWindow!
    private var balloon = Balloon()
    private var bubble: Bubble?
    private var timer: Timer?
    private var walker = Walker()
    private var ground = NSRect.zero
    private var screenTop: CGFloat = 0
    private var previousTime = CACurrentMediaTime()
    private var paused = false
    private var dragOrigin: NSPoint?
    private var dragging: Bool { dragOrigin != nil }
    private var platforms: [WindowPlatform] = []
    private var nextPlatformRefresh: CFTimeInterval = 0
    private var systemLoad = SystemLoad()
    private var targetLoad: Double = 0
    private var load: Double = 0
    private var nextLoadSample: CFTimeInterval = 0
    private var flailPhase: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = makeWindow(for: walkerView)
        bubbleWindow = makeWindow(for: bubbleView)
        bubbleWindow.ignoresMouseEvents = true
        bubbleWindow.alphaValue = 0
        balloonWindow = makeWindow(for: balloonView)
        balloonWindow.ignoresMouseEvents = true
        balloonWindow.alphaValue = 0
        balloonView.onPop = { [weak self] in self?.popBalloon() }
        walkerView.onDragStarted = { [weak self] origin in self?.dragOrigin = origin }
        walkerView.onDragMoved = { [weak self] origin in self?.dragOrigin = origin }
        walkerView.onDragEnded = { [weak self] in self?.endDragging() }
        walkerView.onMenuRequested = { [weak self] in self?.showMenu() }
        updateScreen()
        walker.x = max(0, (ground.width - walkerView.bounds.width) / 2)
        render(at: CACurrentMediaTime())
        window.orderFrontRegardless()
        balloonWindow.order(.below, relativeTo: window.windowNumber)
        window.addChildWindow(bubbleWindow, ordered: .above)
        speech.prepare()
        NotificationCenter.default.addObserver(self, selector: #selector(updateScreen),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        previousTime = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60, target: self,
                          selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 1.0 / 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func makeWindow(for view: NSView) -> NSWindow {
        let window = UnconstrainedWindow(contentRect: view.bounds, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.contentView = view
        return window
    }

    private var menuAnchor: NSRect {
        NSRect(x: window.frame.minX, y: window.frame.minY,
               width: window.frame.width, height: WalkerView.headTop)
    }

    private func showMenu() {
        bubble = nil
        contextMenu.open([
            .init(title: paused ? "Resume Walking" : "Pause") { [weak self] in self?.togglePause() },
            .init(title: "Quit Pt") { NSApplication.shared.terminate(nil) },
        ], from: menuAnchor)
    }

    @objc private func updateScreen() {
        guard let screen = window.screen ?? NSScreen.screens.first else { return }
        ground = screen.visibleFrame
        screenTop = screen.frame.maxY
        nextPlatformRefresh = 0
        guard !dragging else { return }
        walker.constrain(to: ground.width - walkerView.bounds.width)
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let elapsed = min(max(0, now - previousTime), 0.1)
        previousTime = now
        advance(at: now, seconds: elapsed)
        if let bubble, bubble.isOver(at: now) { self.bubble = nil }
        let floatingOrigin = walker.isFloating && !dragging ? NSPoint(
            x: ground.minX + walker.x + (WalkerView.size.width - BalloonView.size.width) / 2,
            y: ground.minY + walker.height + WalkerView.headTop) : nil
        balloon.advance(at: now, elapsed: elapsed, floatingOrigin: floatingOrigin, sway: walker.sway)
        render(at: now)
    }

    private func advance(at now: CFTimeInterval, seconds elapsed: Double) {
        guard !dragging else {
            flailPhase = (flailPhase + elapsed * 2 * .pi * 7).truncatingRemainder(dividingBy: 2 * .pi)
            return
        }
        if now >= nextPlatformRefresh {
            platforms = WindowPlatforms().read(ground: ground, walkerSize: walkerView.bounds.size)
            nextPlatformRefresh = now + 0.1
        }
        if now >= nextLoadSample {
            targetLoad = systemLoad.sample()
            nextLoadSample = now + 1
        }
        load += (targetLoad - load) * (1 - exp(-elapsed / 0.8))
        walker.speed = Walker.walkingSpeed(load: load)
        walker.mayLeave = load <= Walker.idleLoad
        let wasFalling = walker.isFalling
        walker.advance(seconds: elapsed,
                       width: ground.width - walkerView.bounds.width,
                       walking: !paused && !contextMenu.isOpen,
                       platforms: platforms,
                       ceiling: screenTop - ground.minY)
        // The balloon already sits where the bubble would go.
        if walker.isFalling, !wasFalling, !walker.isFloating { speak() }
    }

    private func speak() {
        guard bubble == nil, let text = speech.take() else { return }
        bubble = Bubble(text: text, born: CACurrentMediaTime(), life: .random(in: 2.2...4.2))
    }

    private func render(at now: CFTimeInterval) {
        displayWalker()
        displayBalloon(at: now)
        displayBubble(at: now)
        contextMenu.follow(menuAnchor)
    }

    private func displayBubble(at now: CFTimeInterval) {
        bubbleWindow.alphaValue = bubble?.opacity(at: now) ?? 0
        guard let bubble else { return }
        if bubbleView.text != bubble.text {
            bubbleView.text = bubble.text
            bubbleWindow.setContentSize(BubbleView.size(for: bubble.text))
        }
        let width = bubbleWindow.frame.width
        let floating = balloon.attached
        let center = floating ? balloonWindow.frame.midX : window.frame.midX
        let top = floating ? balloonWindow.frame.maxY - BalloonView.burstRoom
            : window.frame.minY + WalkerView.headTop
        let x = max(ground.minX, min(center - width / 2, ground.maxX - width))
        bubbleWindow.setFrameOrigin(NSPoint(
            x: x, y: top + BubbleView.gap - BubbleView.margin))
        bubbleView.tailX = center - x
        bubbleView.needsDisplay = true
    }

    private func popBalloon() {
        guard walker.isFloating, !dragging else { return }
        walker.popBalloon()
        balloon.pop(at: CACurrentMediaTime())
    }

    private func displayBalloon(at now: CFTimeInterval) {
        balloonWindow.ignoresMouseEvents = !balloon.attached
        balloonWindow.setFrameOrigin(balloon.origin)
        balloonWindow.alphaValue = balloon.opacity(at: now)
        balloonView.burst = balloon.burst(at: now)
        balloonView.attached = balloon.attached
        balloonView.sway = balloon.sway
        balloonView.needsDisplay = true
    }

    private func displayWalker() {
        let floating = walker.isFloating && !dragging
        if let dragOrigin {
            window.setFrameOrigin(dragOrigin)
        } else {
            let angle = walker.sway * .pi / 180
            let length = floating ? BalloonView.stringLength : 0
            window.setFrameOrigin(NSPoint(x: ground.minX + walker.x + length * sin(angle),
                                          y: ground.minY + walker.height + length * (1 - cos(angle))))
        }
        walkerView.floating = floating
        walkerView.sway = floating ? walker.sway : 0
        // Offstage, the window would otherwise peek onto a neighbouring display.
        window.alphaValue = walker.isOffstage ? 0 : 1
        window.ignoresMouseEvents = walker.isOffstage
        walkerView.swing = dragging ? sin(flailPhase) * 35 : walker.swing
        walkerView.direction = walker.direction
        walkerView.standing = !dragging && (paused || walker.isFalling || contextMenu.isOpen)
        walkerView.needsDisplay = true
    }

    private func endDragging() {
        guard let dragOrigin else { return }
        let frame = NSRect(origin: dragOrigin, size: WalkerView.size)
        let screen = NSScreen.screens.max {
            let left = $0.frame.intersection(frame)
            let right = $1.frame.intersection(frame)
            return left.width * left.height < right.width * right.height
        }
        if let screen {
            ground = screen.visibleFrame
            screenTop = screen.frame.maxY
        }
        walker.x = dragOrigin.x - ground.minX
        walker.drop(from: dragOrigin.y - ground.minY)
        walker.constrain(to: ground.width - walkerView.bounds.width)
        if walker.isFalling { speak() }
        self.dragOrigin = nil
        nextPlatformRefresh = 0
        previousTime = CACurrentMediaTime()
    }

    private func togglePause() {
        paused.toggle()
    }
}

final class UnconstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
