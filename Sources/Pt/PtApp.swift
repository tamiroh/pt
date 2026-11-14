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
    private let bubbleWindow = BubbleWindow()
    private let balloonWindow = BalloonWindow()
    private let speech = Speech()
    private let contextMenu = ContextMenuPanel()
    private var window: NSWindow!
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
        balloonWindow.onPop = { [weak self] in self?.popBalloon() }
        walkerView.onDragStarted = { [weak self] origin in self?.dragOrigin = origin }
        walkerView.onDragMoved = { [weak self] origin in self?.dragOrigin = origin }
        walkerView.onDragEnded = { [weak self] in self?.endDragging() }
        walkerView.onMenuRequested = { [weak self] in self?.showMenu() }
        updateScreen()
        walker.x = max(0, (ground.width - walkerView.bounds.width) / 2)
        render()
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
        let window = Window(contentRect: view.bounds, styleMask: [.borderless],
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
        bubbleWindow.dismiss()
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
        bubbleWindow.advance(at: now)
        let floatingOrigin = walker.isFloating && !dragging ? NSPoint(
            x: ground.minX + walker.x + (WalkerView.size.width - balloonWindow.frame.width) / 2,
            y: ground.minY + walker.height + WalkerView.headTop) : nil
        balloonWindow.advance(at: now, elapsed: elapsed, floatingOrigin: floatingOrigin, sway: walker.sway)
        render()
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
        guard !bubbleWindow.isPresent, let text = speech.take() else { return }
        bubbleWindow.show(text, at: CACurrentMediaTime(), life: .random(in: 2.2...4.2))
    }

    private func render() {
        displayWalker()
        balloonWindow.render()
        displayBubble()
        contextMenu.follow(menuAnchor)
    }

    private func displayBubble() {
        let anchor = balloonWindow.attached ? balloonWindow.bubbleAnchor
            : NSPoint(x: window.frame.midX, y: window.frame.minY + WalkerView.headTop)
        bubbleWindow.render(anchor: anchor, within: ground)
    }

    private func popBalloon() {
        guard walker.isFloating, !dragging else { return }
        walker.popBalloon()
        balloonWindow.pop(at: CACurrentMediaTime())
    }

    private func displayWalker() {
        let floating = walker.isFloating && !dragging
        if let dragOrigin {
            window.setFrameOrigin(dragOrigin)
        } else {
            let angle = walker.sway * .pi / 180
            let length = floating ? BalloonWindow.stringLength : 0
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

    private final class Window: NSWindow {
        override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
            frameRect
        }
    }
}
