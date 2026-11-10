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
    private var window: NSWindow!
    private var bubbleWindow: NSWindow!
    private var balloonWindow: NSWindow!
    private var balloonHeld = false
    private var balloonReleased: CFTimeInterval?
    private var bubble: Bubble?
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var walker = Walker()
    private var ground = NSRect.zero
    private var previousTime = CACurrentMediaTime()
    private var paused = false
    private var dragging = false
    private var platforms: [WindowPlatform] = []
    private var nextPlatformRefresh: CFTimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = makeWindow(for: walkerView)
        bubbleWindow = makeWindow(for: bubbleView)
        bubbleWindow.ignoresMouseEvents = true
        bubbleWindow.alphaValue = 0
        balloonWindow = makeWindow(for: balloonView)
        balloonWindow.ignoresMouseEvents = true
        balloonWindow.alphaValue = 0
        walkerView.onDragStarted = { [weak self] in self?.beginDragging() }
        walkerView.onDragEnded = { [weak self] in self?.endDragging() }
        updateScreen()
        walker.x = max(0, (ground.width - walkerView.bounds.width) / 2)
        displayWalker()
        window.orderFrontRegardless()
        balloonWindow.order(.below, relativeTo: window.windowNumber)
        // As a child, the bubble follows the walker while it is being dragged.
        window.addChildWindow(bubbleWindow, ordered: .above)
        speech.prepare()
        makeMenu()
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
        let window = NSWindow(contentRect: view.bounds, styleMask: [.borderless],
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

    private func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Pt")
        let menu = NSMenu()
        let pause = menu.addItem(withTitle: "Pause", action: #selector(togglePause(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Pt", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    @objc private func updateScreen() {
        guard let screen = window.screen ?? NSScreen.screens.first else { return }
        ground = screen.visibleFrame
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
        guard !dragging else { return }
        // Avoid teleporting after sleep or a stalled run loop.
        if now >= nextPlatformRefresh {
            platforms = WindowPlatforms().read(ground: ground, walkerSize: walkerView.bounds.size)
            nextPlatformRefresh = now + 0.1
        }
        let wasFalling = walker.isFalling
        walker.advance(seconds: min(max(0, now - previousTime), 0.1),
                       width: ground.width - walkerView.bounds.width, walking: !paused,
                       platforms: platforms,
                       ceiling: ground.height - WalkerView.headTop - BalloonView.size.height)
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
        let center = window.frame.midX
        let x = max(ground.minX, min(center - width / 2, ground.maxX - width))
        bubbleWindow.setFrameOrigin(NSPoint(
            x: x, y: window.frame.minY + WalkerView.headTop + BubbleView.gap - BubbleView.margin))
        bubbleView.tailX = center - x
        bubbleView.needsDisplay = true
    }

    private func displayBalloon(at now: CFTimeInterval, elapsed: CFTimeInterval) {
        if walker.isFloating, !dragging {
            balloonHeld = true
            balloonReleased = nil
            balloonView.attached = true
            balloonView.sway = walker.sway
            balloonView.needsDisplay = true
            balloonWindow.setFrameOrigin(NSPoint(
                x: ground.minX + CGFloat(walker.x) + (walkerView.bounds.width - balloonWindow.frame.width) / 2,
                y: ground.minY + CGFloat(walker.height) + WalkerView.headTop))
            balloonWindow.alphaValue = 1
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
        walkerView.swing = walker.swing
        walkerView.direction = walker.direction
        walkerView.standing = paused || dragging || walker.isFalling
        walkerView.needsDisplay = true
    }

    private func beginDragging() {
        dragging = true
        displayWalker()
    }

    private func endDragging() {
        if let screen = window.screen ?? NSScreen.screens.first {
            ground = screen.visibleFrame
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

    @objc private func togglePause(_ sender: NSMenuItem) {
        paused.toggle()
        sender.title = paused ? "Resume Walking" : "Pause"
        displayWalker()
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
