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
    private let contextMenu = ContextMenuPanel()
    private let speech = Speech()
    private let desktop = Desktop(walkerSize: WalkerWindow.size)
    private let frames = FrameLoop()
    private var walker = Walker()
    private var paused = false

    private var walking: Bool { !paused && !contextMenu.isOpen }

    func applicationDidFinishLaunching(_ notification: Notification) {
        connectInput()
        updateScreen()
        walker.x = desktop.walkingWidth / 2
        render()
        presentWindows()
        speech.prepare()
        NotificationCenter.default.addObserver(self, selector: #selector(updateScreen),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        frames.start { [weak self] frame in self?.advance(frame) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        frames.stop()
        contextMenu.close()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func connectInput() {
        walkerWindow.onDragEnded = { [weak self] origin in self?.dropWalker(at: origin) }
        walkerWindow.onMenuRequested = { [weak self] in self?.showMenu() }
        balloonWindow.onPop = { [weak self] in self?.popBalloon() }
    }

    private func presentWindows() {
        walkerWindow.orderFrontRegardless()
        balloonWindow.order(.below, relativeTo: walkerWindow.windowNumber)
        walkerWindow.addChildWindow(bubbleWindow, ordered: .above)
    }

    private func advance(_ frame: FrameLoop.Frame) {
        advanceWalker(frame)
        walkerWindow.advance(seconds: frame.seconds)
        bubbleWindow.advance(at: frame.time)
        balloonWindow.advance(at: frame.time, elapsed: frame.seconds,
                              anchor: walkerWindow.balloonAnchor(for: walker, on: desktop.ground),
                              sway: walker.sway)
        render()
    }

    private func advanceWalker(_ frame: FrameLoop.Frame) {
        guard !walkerWindow.isDragging else { return }
        desktop.advance(frame)
        walker.speed = Walker.walkingSpeed(load: desktop.load)
        walker.mayLeave = desktop.load <= Walker.idleLoad
        let wasFalling = walker.isFalling
        walker.advance(seconds: frame.seconds, width: desktop.walkingWidth, walking: walking,
                       platforms: desktop.platforms, ceiling: desktop.ceiling)
        if walker.isFalling, !wasFalling, !walker.isFloating { speak() }
    }

    private func render() {
        walkerWindow.render(walker, on: desktop.ground, walking: walking)
        balloonWindow.render()
        let anchor = balloonWindow.attached ? balloonWindow.bubbleAnchor : walkerWindow.bubbleAnchor
        bubbleWindow.render(anchor: anchor, within: desktop.ground)
        contextMenu.follow(walkerWindow.menuAnchor)
    }

    @objc private func updateScreen() {
        desktop.selectScreen(walkerWindow.screen)
        if !walkerWindow.isDragging { walker.constrain(to: desktop.walkingWidth) }
    }

    private func dropWalker(at origin: NSPoint) {
        desktop.selectScreen(at: origin)
        walker.drop(at: desktop.localPosition(origin), within: desktop.walkingWidth)
        if walker.isFalling { speak() }
        frames.resetTime()
    }

    private func popBalloon() {
        guard walker.isFloating, !walkerWindow.isDragging else { return }
        walker.popBalloon()
        balloonWindow.pop(at: CACurrentMediaTime())
    }

    private func speak() {
        guard !bubbleWindow.isPresent, let text = speech.take() else { return }
        bubbleWindow.show(text, at: CACurrentMediaTime(), life: .random(in: 2.2...4.2))
    }

    private func showMenu() {
        bubbleWindow.dismiss()
        contextMenu.open([
            .init(title: paused ? "Resume Walking" : "Pause") { [weak self] in self?.paused.toggle() },
            .init(title: "Quit Pt") { NSApplication.shared.terminate(nil) },
        ], from: walkerWindow.menuAnchor)
    }
}
