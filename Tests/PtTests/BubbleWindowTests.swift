import AppKit
import XCTest
@testable import Pt

final class BubbleWindowTests: XCTestCase {
    @MainActor
    func testFadesInAndOutAroundItsLife() {
        let window = BubbleWindow()
        let ground = NSRect(x: 0, y: 0, width: 1_000, height: 800)
        window.show("Whoa", at: 10, life: 3)

        for (time, opacity) in [(10.0, 0.0), (10.1, 0.5), (11, 1), (12.9, 0.5), (13, 0), (14, 0)] {
            window.advance(at: time)
            window.render(anchor: NSPoint(x: 100, y: 100), within: ground)
            XCTAssertEqual(window.alphaValue, opacity, accuracy: 0.000_001)
            XCTAssertEqual(window.isPresent, time < 13)
        }
    }

    @MainActor
    func testSizesAndPositionsNewContentAndDismissesOnRender() {
        let window = BubbleWindow()
        let ground = NSRect(x: -300, y: 50, width: 300, height: 400)
        window.show("Whoa", at: 0, life: 3)
        window.advance(at: 1)
        window.render(anchor: NSPoint(x: -300, y: 100), within: ground)
        let shortSize = window.frame.size
        XCTAssertGreaterThan(shortSize.width, 0)
        XCTAssertGreaterThan(shortSize.height, 0)
        XCTAssertEqual(window.frame.minX, ground.minX)
        XCTAssertGreaterThan(window.frame.minY, 100)
        XCTAssertEqual(window.alphaValue, 1)

        window.show("Whoa, not again", at: 1, life: 3)
        window.advance(at: 2)
        window.render(anchor: NSPoint(x: 0, y: 100), within: ground)
        XCTAssertGreaterThan(window.frame.width, shortSize.width)
        XCTAssertEqual(window.frame.height, shortSize.height)
        XCTAssertEqual(window.frame.maxX, ground.maxX)
        window.dismiss()
        XCTAssertFalse(window.isPresent)
        XCTAssertEqual(window.alphaValue, 1)
        window.render(anchor: .zero, within: ground)
        XCTAssertEqual(window.alphaValue, 0)
    }

    @MainActor
    func testGrowsWithItsTextAndKeepsItsHeight() {
        let window = BubbleWindow()
        let ground = NSRect(x: 0, y: 0, width: 1_000, height: 800)
        var sizes: [NSSize] = []
        for text in ["", "Whoa", "Whoa, not again"] {
            window.show(text, at: 0, life: 3)
            window.render(anchor: NSPoint(x: 100, y: 100), within: ground)
            sizes.append(window.frame.size)
        }

        XCTAssertGreaterThan(sizes[0].width, 0)
        XCTAssertGreaterThan(sizes[1].width, sizes[0].width)
        XCTAssertGreaterThan(sizes[2].width, sizes[1].width)
        XCTAssertEqual(sizes[0].height, sizes[2].height)
    }
}
