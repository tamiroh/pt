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
        let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.shadowBlurRadius = 20
        shadow.set()
        NSColor.white.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(starting: NSColor(srgbRed: 0.62, green: 0.84, blue: 1, alpha: 1),
                   ending: NSColor(srgbRed: 0.33, green: 0.62, blue: 0.94, alpha: 1))?
            .draw(in: shape, angle: -90)

        let groundShadow = NSRect(x: tile.midX - 190, y: 218, width: 380, height: 56)
        NSColor(white: 0, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: groundShadow).fill()
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
