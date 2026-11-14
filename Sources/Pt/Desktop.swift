import AppKit

@MainActor
final class Desktop {
    private(set) var ground = NSRect.zero
    private(set) var ceiling: Double = 0
    private(set) var platforms: [WindowPlatform] = []
    private(set) var load: Double = 0
    private let walkerSize: NSSize
    private let sampleLoad: () -> Double
    private let readPlatforms: (NSRect, NSSize) -> [WindowPlatform]
    private var nextPlatformRefresh: Double = 0
    private var nextLoadSample: Double = 0
    private var targetLoad: Double = 0

    var walkingWidth: Double { max(0, ground.width - walkerSize.width) }

    convenience init(walkerSize: NSSize) {
        var systemLoad = SystemLoad()
        self.init(walkerSize: walkerSize, sampleLoad: { systemLoad.sample() },
                  readPlatforms: { WindowPlatforms().read(ground: $0, walkerSize: $1) })
    }

    init(walkerSize: NSSize, sampleLoad: @escaping () -> Double,
         readPlatforms: @escaping (NSRect, NSSize) -> [WindowPlatform]) {
        self.walkerSize = walkerSize
        self.sampleLoad = sampleLoad
        self.readPlatforms = readPlatforms
    }

    func selectScreen(_ screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.screens.first else { return }
        ground = screen.visibleFrame
        ceiling = screen.frame.maxY - ground.minY
        nextPlatformRefresh = 0
    }

    func selectScreen(at origin: NSPoint) {
        let frame = NSRect(origin: origin, size: walkerSize)
        selectScreen(NSScreen.screens.max {
            let left = $0.frame.intersection(frame)
            let right = $1.frame.intersection(frame)
            return left.width * left.height < right.width * right.height
        })
    }

    func localPosition(_ position: NSPoint) -> NSPoint {
        NSPoint(x: position.x - ground.minX, y: position.y - ground.minY)
    }

    func advance(_ frame: FrameLoop.Frame) {
        if frame.time >= nextPlatformRefresh {
            platforms = readPlatforms(ground, walkerSize)
            nextPlatformRefresh = frame.time + 0.1
        }
        if frame.time >= nextLoadSample {
            targetLoad = sampleLoad()
            nextLoadSample = frame.time + 1
        }
        load += (targetLoad - load) * (1 - exp(-frame.seconds / 0.8))
    }
}
