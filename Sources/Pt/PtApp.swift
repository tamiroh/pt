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
    private let walkerWindow = WalkerWindow()
    private let bubbleWindow = BubbleWindow()
    private let balloonWindow = BalloonWindow()
    private let speech = Speech()
    private let contextMenu = ContextMenuPanel()
    private var timer: Timer?
    private var walker = Walker()
    private var ground = NSRect.zero
    private var screenTop: CGFloat = 0
    private var previousTime = CACurrentMediaTime()
    private var paused = false
    private var platforms: [WindowPlatform] = []
    private var nextPlatformRefresh: CFTimeInterval = 0
    private var systemLoad = SystemLoad()
    private var targetLoad: Double = 0
    private var load: Double = 0
    private var nextLoadSample: CFTimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        balloonWindow.onPop = { [weak self] in self?.popBalloon() }
        walkerWindow.onDragEnded = { [weak self] origin in self?.endDragging(at: origin) }
        walkerWindow.onMenuRequested = { [weak self] in self?.showMenu() }
        updateScreen()
        walker.x = max(0, (ground.width - WalkerWindow.size.width) / 2)
        render()
        walkerWindow.orderFrontRegardless()
        balloonWindow.order(.below, relativeTo: walkerWindow.windowNumber)
        walkerWindow.addChildWindow(bubbleWindow, ordered: .above)
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

    private func showMenu() {
        bubbleWindow.dismiss()
        contextMenu.open([
            .init(title: paused ? "Resume Walking" : "Pause") { [weak self] in self?.togglePause() },
            .init(title: "Quit Pt") { NSApplication.shared.terminate(nil) },
        ], from: walkerWindow.menuAnchor)
    }

    @objc private func updateScreen() {
        guard let screen = walkerWindow.screen ?? NSScreen.screens.first else { return }
        ground = screen.visibleFrame
        screenTop = screen.frame.maxY
        nextPlatformRefresh = 0
        guard !walkerWindow.isDragging else { return }
        walker.constrain(to: ground.width - WalkerWindow.size.width)
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let elapsed = min(max(0, now - previousTime), 0.1)
        previousTime = now
        walkerWindow.advance(seconds: elapsed)
        advance(at: now, seconds: elapsed)
        bubbleWindow.advance(at: now)
        let floatingOrigin = walker.isFloating && !walkerWindow.isDragging ? NSPoint(
            x: ground.minX + walker.x + (WalkerWindow.size.width - balloonWindow.frame.width) / 2,
            y: ground.minY + walker.height + WalkerWindow.headTop) : nil
        balloonWindow.advance(at: now, elapsed: elapsed, floatingOrigin: floatingOrigin, sway: walker.sway)
        render()
    }

    private func advance(at now: CFTimeInterval, seconds elapsed: Double) {
        guard !walkerWindow.isDragging else { return }
        if now >= nextPlatformRefresh {
            platforms = WindowPlatforms().read(ground: ground, walkerSize: WalkerWindow.size)
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
                       width: ground.width - WalkerWindow.size.width,
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
        walkerWindow.render(walker, on: ground, walking: !paused && !contextMenu.isOpen)
        balloonWindow.render()
        displayBubble()
        contextMenu.follow(walkerWindow.menuAnchor)
    }

    private func displayBubble() {
        let anchor = balloonWindow.attached ? balloonWindow.bubbleAnchor
            : walkerWindow.bubbleAnchor
        bubbleWindow.render(anchor: anchor, within: ground)
    }

    private func popBalloon() {
        guard walker.isFloating, !walkerWindow.isDragging else { return }
        walker.popBalloon()
        balloonWindow.pop(at: CACurrentMediaTime())
    }

    private func endDragging(at dragOrigin: NSPoint) {
        let frame = NSRect(origin: dragOrigin, size: WalkerWindow.size)
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
        walker.constrain(to: ground.width - WalkerWindow.size.width)
        if walker.isFalling { speak() }
        nextPlatformRefresh = 0
        previousTime = CACurrentMediaTime()
    }

    private func togglePause() {
        paused.toggle()
    }
}
