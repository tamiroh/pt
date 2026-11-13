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
    private var balloonHeld = false
    private var balloonReleased: CFTimeInterval?
    private var balloonPopped: CFTimeInterval?
    private var bubble: Bubble?
    private var timer: Timer?
    private var walker = Walker()
    private var ground = NSRect.zero
    private var screenTop: CGFloat = 0
    private var previousTime = CACurrentMediaTime()
    private var paused = false
    private var dragging = false
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
        walkerView.onDragStarted = { [weak self] in self?.beginDragging() }
        walkerView.onDragEnded = { [weak self] in self?.endDragging() }
        walkerView.onMenuRequested = { [weak self] in self?.showMenu() }
        contextMenu.onClose = { [weak self] in self?.displayWalker() }
        updateScreen()
        walker.x = max(0, (ground.width - walkerView.bounds.width) / 2)
        displayWalker()
        window.orderFrontRegardless()
        balloonWindow.order(.below, relativeTo: window.windowNumber)
        // As a child, the bubble follows the walker while it is being dragged.
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
        NotificationCenter.default.removeObserver(self)
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
        displayWalker()
    }

    @objc private func updateScreen() {
        guard let screen = window.screen ?? NSScreen.screens.first else { return }
        ground = screen.visibleFrame
        screenTop = screen.frame.maxY
        nextPlatformRefresh = 0
        guard !dragging else { return }
        walker.constrain(to: ground.width - walkerView.bounds.width)
        displayWalker()
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        defer {
            displayBalloon(at: now, elapsed: now - previousTime)
            previousTime = now
            displayBubble(at: now)
        }
        guard !dragging else {
            let elapsed = min(max(0, now - previousTime), 0.1)
            flailPhase = (flailPhase + elapsed * 2 * .pi * 7).truncatingRemainder(dividingBy: 2 * .pi)
            displayWalker()
            return
        }
        // Avoid teleporting after sleep or a stalled run loop.
        if now >= nextPlatformRefresh {
            platforms = WindowPlatforms().read(ground: ground, walkerSize: walkerView.bounds.size)
            nextPlatformRefresh = now + 0.1
        }
        if now >= nextLoadSample {
            targetLoad = systemLoad.sample()
            nextLoadSample = now + 1
        }
        let elapsed = min(max(0, now - previousTime), 0.1)
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
        displayWalker()
    }

    private func speak() {
        guard bubble == nil, let text = speech.take() else { return }
        bubble = Bubble(text: text, born: CACurrentMediaTime(), life: .random(in: 2.2...4.2))
        bubbleView.text = text
        bubbleWindow.setContentSize(BubbleView.size(for: text))
    }

    private func displayBubble(at now: CFTimeInterval) {
        if let present = bubble, present.isOver(at: now) { bubble = nil }
        bubbleWindow.alphaValue = bubble?.opacity(at: now) ?? 0
        guard bubble != nil, !dragging else { return }
        let width = bubbleWindow.frame.width
        let floating = walker.isFloating
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
        balloonHeld = false
        balloonReleased = nil
        balloonPopped = CACurrentMediaTime()
        balloonView.burst = 0
        balloonView.needsDisplay = true
        displayWalker()
    }

    private func displayBalloon(at now: CFTimeInterval, elapsed: CFTimeInterval) {
        balloonWindow.ignoresMouseEvents = !(walker.isFloating && !dragging)
        if walker.isFloating, !dragging {
            balloonHeld = true
            balloonReleased = nil
            balloonPopped = nil
            balloonView.burst = nil
            balloonView.attached = true
            balloonView.sway = walker.sway
            balloonView.needsDisplay = true
            balloonWindow.setFrameOrigin(NSPoint(
                x: ground.minX + CGFloat(walker.x) + (walkerView.bounds.width - balloonWindow.frame.width) / 2,
                y: ground.minY + CGFloat(walker.height) + WalkerView.headTop))
            balloonWindow.alphaValue = 1
            return
        }
        if let popped = balloonPopped {
            let progress = (now - popped) / 0.25
            guard progress < 1 else {
                balloonPopped = nil
                balloonView.burst = nil
                balloonWindow.alphaValue = 0
                return
            }
            balloonView.burst = progress
            balloonView.needsDisplay = true
            return
        }
        if balloonHeld {
            // Landing or being grabbed lets go of the balloon, which drifts away.
            balloonHeld = false
            balloonReleased = now
            balloonView.attached = false
            balloonView.needsDisplay = true
        }
        guard let released = balloonReleased else { return }
        let progress = (now - released) / 1.5
        guard progress < 1 else {
            balloonReleased = nil
            balloonWindow.alphaValue = 0
            return
        }
        var origin = balloonWindow.frame.origin
        origin.y += 70 * min(max(0, elapsed), 0.1)
        balloonWindow.setFrameOrigin(origin)
        balloonWindow.alphaValue = 1 - progress
    }

    private func displayWalker() {
        let floating = walker.isFloating && !dragging
        if !dragging {
            // Swing as a pendulum hanging from the balloon's knot.
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
        contextMenu.follow(menuAnchor)
    }

    private func beginDragging() {
        dragging = true
        displayWalker()
    }

    private func endDragging() {
        if let screen = window.screen ?? NSScreen.screens.first {
            ground = screen.visibleFrame
            screenTop = screen.frame.maxY
        }
        walker.x = window.frame.minX - ground.minX
        walker.drop(from: window.frame.minY - ground.minY)
        walker.constrain(to: ground.width - walkerView.bounds.width)
        if walker.isFalling { speak() }
        dragging = false
        nextPlatformRefresh = 0
        previousTime = CACurrentMediaTime()
        displayWalker()
    }

    private func togglePause() {
        paused.toggle()
        displayWalker()
    }
}

final class UnconstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
