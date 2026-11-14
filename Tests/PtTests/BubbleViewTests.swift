import AppKit
import XCTest
@testable import Pt

final class BubbleViewTests: XCTestCase {
    @MainActor
    func testFadesInAndOutAroundItsLife() {
        let view = BubbleView(frame: .zero)
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let ground = NSRect(x: 0, y: 0, width: 1_000, height: 800)
        view.show("Whoa", at: 10, life: 3)

        for (time, opacity) in [(10.0, 0.0), (10.1, 0.5), (11, 1), (12.9, 0.5), (13, 0), (14, 0)] {
            view.advance(at: time)
            view.render(anchor: NSPoint(x: 100, y: 100), within: ground)
            XCTAssertEqual(window.alphaValue, opacity, accuracy: 0.000_001)
            XCTAssertEqual(view.isPresent, time < 13)
        }
    }

    @MainActor
    func testSizesAndPositionsNewContentAndDismissesOnRender() {
        let view = BubbleView(frame: .zero)
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let ground = NSRect(x: -300, y: 50, width: 300, height: 400)
        view.show("Whoa", at: 0, life: 3)
        view.advance(at: 1)
        view.render(anchor: NSPoint(x: -300, y: 100), within: ground)
        XCTAssertEqual(view.bounds.width, BubbleView.size(for: "Whoa").width, accuracy: 1)
        XCTAssertEqual(view.bounds.height, BubbleView.size(for: "Whoa").height, accuracy: 1)
        XCTAssertEqual(window.frame.minX, ground.minX)
        XCTAssertEqual(window.frame.minY, 100 + BubbleView.gap - BubbleView.margin, accuracy: 1)
        XCTAssertEqual(window.alphaValue, 1)

        view.show("Whoa, not again", at: 1, life: 3)
        view.advance(at: 2)
        view.render(anchor: NSPoint(x: 0, y: 100), within: ground)
        XCTAssertEqual(view.bounds.width, BubbleView.size(for: "Whoa, not again").width, accuracy: 1)
        XCTAssertEqual(window.frame.maxX, ground.maxX)
        view.dismiss()
        XCTAssertFalse(view.isPresent)
        XCTAssertEqual(window.alphaValue, 1)
        view.render(anchor: .zero, within: ground)
        XCTAssertEqual(window.alphaValue, 0)
    }

    @MainActor
    func testGrowsWithItsTextButNeverNarrowerThanTall() {
        let empty = BubbleView.size(for: "")
        let short = BubbleView.size(for: "Whoa")
        let long = BubbleView.size(for: "Whoa, not again")

        XCTAssertEqual(empty.width, BubbleView.height + 2 * BubbleView.margin)
        XCTAssertGreaterThan(long.width, short.width)
        XCTAssertEqual(long.height, short.height)
    }
}
