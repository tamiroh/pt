import AppKit

struct WindowPlatform {
    let id: UInt32
    let frame: CGRect
    let spans: [ClosedRange<Double>]

    func span(at x: Double) -> ClosedRange<Double>? {
        spans.first { $0.contains(x) }
    }

    // Input is ordered front to back, in AppKit screen coordinates.
    static func visible(_ windows: [(id: UInt32, frame: CGRect)],
                        ground: CGRect, walkerSize: CGSize) -> [WindowPlatform] {
        var foreground: [CGRect] = []
        var platforms: [WindowPlatform] = []
        for window in windows {
            defer { foreground.append(window.frame) }
            let top = window.frame.maxY
            guard top > ground.minY, top + walkerSize.height <= ground.maxY else { continue }
            let left = max(window.frame.minX, ground.minX)
            let right = min(window.frame.maxX, ground.maxX)
            guard right > left else { continue }
            var spans = [left...right]
            for cover in foreground where cover.minY < top && cover.maxY >= top {
                spans = spans.flatMap { span -> [ClosedRange<CGFloat>] in
                    guard cover.maxX > span.lowerBound, cover.minX < span.upperBound else { return [span] }
                    var remaining: [ClosedRange<CGFloat>] = []
                    if cover.minX > span.lowerBound { remaining.append(span.lowerBound...cover.minX) }
                    if cover.maxX < span.upperBound { remaining.append(cover.maxX...span.upperBound) }
                    return remaining
                }
            }
            platforms.append(WindowPlatform(
                id: window.id,
                frame: window.frame.offsetBy(dx: -ground.minX, dy: -ground.minY),
                spans: spans.map {
                    Double($0.lowerBound - ground.minX - walkerSize.width / 2)...Double($0.upperBound - ground.minX - walkerSize.width / 2)
                }))
        }
        return platforms
    }
}

@MainActor
struct WindowPlatforms {
    func read(ground: CGRect, walkerSize: CGSize) -> [WindowPlatform] {
        guard let primary = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return [] }
        return WindowPlatform.visible(windows.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let owner = info[kCGWindowOwnerPID as String] as? Int32,
                  owner != ProcessInfo.processInfo.processIdentifier,
                  let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let id = info[kCGWindowNumber as String] as? UInt32,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width > 0, rect.height > 0 else { return nil }
            return (id: id, frame: CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY,
                                         width: rect.width, height: rect.height))
        }, ground: ground, walkerSize: walkerSize)
    }
}
