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
    private var window: NSWindow!
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
        window = NSWindow(contentRect: walkerView.bounds, styleMask: [.borderless],
                          backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.contentView = walkerView
        walkerView.onDragStarted = { [weak self] in self?.beginDragging() }
        walkerView.onDragEnded = { [weak self] in self?.endDragging() }
        updateScreen()
        walker.x = max(0, (ground.width - walkerView.bounds.width) / 2)
        displayWalker()
        window.orderFrontRegardless()
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

    private func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "pt")
        let menu = NSMenu()
        let pause = menu.addItem(withTitle: "Pause", action: #selector(togglePause(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit pt", action: #selector(quit), keyEquivalent: "q")
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
        defer { previousTime = now }
        guard !dragging else { return }
        // Avoid teleporting after sleep or a stalled run loop.
        if now >= nextPlatformRefresh {
            platforms = WindowPlatforms().read(ground: ground, walkerSize: walkerView.bounds.size)
            nextPlatformRefresh = now + 0.1
        }
        walker.advance(seconds: min(max(0, now - previousTime), 0.1),
                       width: ground.width - walkerView.bounds.width, walking: !paused,
                       platforms: platforms)
        displayWalker()
    }

    private func displayWalker() {
        if !dragging {
            window.setFrameOrigin(NSPoint(x: ground.minX + walker.x,
                                          y: ground.minY + walker.height))
        }
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
        walker.constrain(to: ground.width - walkerView.bounds.width)
        walker.drop(from: window.frame.minY - ground.minY)
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
