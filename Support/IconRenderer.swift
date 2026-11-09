import AppKit

// Renders the walker as an app icon set. Built together with WalkerView.swift
// so the icon always matches the character drawn on screen.
@main
@MainActor
enum IconRenderer {
    static let canvas: CGFloat = 1024
    static let tile = NSRect(x: 100, y: 100, width: 824, height: 824)

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: IconRenderer <output.iconset>\n".utf8))
            exit(64)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for factor in [1, 2] {
                let name = "icon_\(points)x\(points)\(factor == 1 ? "" : "@2x").png"
                try render(pixels: points * factor)
                    .write(to: directory.appendingPathComponent(name))
            }
        }
    }

    static func render(pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { throw CocoaError(.fileWriteUnknown) }
        // Draw in 1024-point space regardless of the pixel size.
        // The size must be set before the context is made from the bitmap.
        bitmap.size = NSSize(width: canvas, height: canvas)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        drawTile()
        drawWalker(in: context.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    static func drawTile() {
        NSColor.white.setFill()
        NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).fill()
    }

    static func drawWalker(in context: CGContext) {
        let view = WalkerView(frame: NSRect(origin: .zero, size: WalkerView.size))
        view.standing = true
        let zoom: CGFloat = 16
        context.saveGState()
        context.translateBy(x: tile.midX - view.bounds.midX * zoom, y: 200)
        context.scaleBy(x: zoom, y: zoom)
        // WalkerView clears its bounds first, so keep that inside its own layer.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        view.draw(view.bounds)
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
