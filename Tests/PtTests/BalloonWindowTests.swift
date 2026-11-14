import AppKit
import XCTest
@testable import Pt

final class BalloonWindowTests: XCTestCase {
    @MainActor
    func testOwnsWindowConfigurationAndForwardsBalloonClicks() throws {
        let window = BalloonWindow()
        XCTAssertFalse(window.isOpaque)
        XCTAssertFalse(window.hasShadow)
        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertEqual(window.alphaValue, 0)
        let outside = NSRect(x: -10_000, y: 10_000, width: 80, height: 90)
        XCTAssertEqual(window.constrainFrameRect(outside, to: NSScreen.main), outside)

        var clicks = 0
        window.onPop = { clicks += 1 }
        window.advance(at: 0, elapsed: 0, anchor: CGPoint(x: 100 + window.frame.width / 2, y: 200), sway: 0)
        window.render()
        let point = NSPoint(x: window.frame.width / 2, y: 55)
        let target = try XCTUnwrap(window.contentView?.hitTest(point))
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        target.mouseDown(with: event)
        XCTAssertEqual(clicks, 1)
        window.pop(at: 1)
        window.advance(at: 1.1, elapsed: 0.1, anchor: nil, sway: 0)
        window.render()
        XCTAssertNil(window.contentView?.hitTest(point))
    }

    @MainActor
    func testReleasedBalloonDriftsFromLastAttachedPositionAndFadesOut() {
        let window = BalloonWindow()
        window.render()
        XCTAssertEqual(window.alphaValue, 0)
        window.advance(at: 0, elapsed: 0, anchor: CGPoint(x: 100 + window.frame.width / 2, y: 200), sway: 5)
        window.render()
        XCTAssertTrue(window.attached)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 200))

        window.advance(at: 1, elapsed: 0.1, anchor: nil, sway: 0)
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 200))
        window.render()
        XCTAssertFalse(window.attached)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 207))
        window.render()
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 207))

        window.advance(at: 1.75, elapsed: 0.1, anchor: nil, sway: 0)
        window.render()
        XCTAssertEqual(window.alphaValue, 0.5)
        window.advance(at: 2.5, elapsed: 0.1, anchor: nil, sway: 0)
        window.render()
        XCTAssertEqual(window.alphaValue, 0)
    }

    @MainActor
    func testPoppedBalloonStaysInPlaceUntilBurstFinishes() {
        let window = BalloonWindow()
        let origin = CGPoint(x: 100, y: 200)
        window.advance(at: 0, elapsed: 0, anchor: CGPoint(x: origin.x + window.frame.width / 2, y: origin.y), sway: 0)
        window.pop(at: 1)
        window.advance(at: 1.125, elapsed: 0.1, anchor: nil, sway: 0)
        window.render()
        XCTAssertFalse(window.attached)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertEqual(window.frame.origin, origin)
        XCTAssertEqual(window.alphaValue, 1)

        window.advance(at: 1.25, elapsed: 0.1, anchor: nil, sway: 0)
        window.render()
        XCTAssertEqual(window.alphaValue, 0)
    }

    @MainActor
    func testReattachingCancelsReleaseAndBurst() {
        let window = BalloonWindow()
        let origin = CGPoint(x: 100, y: 200)
        window.advance(at: 0, elapsed: 0, anchor: CGPoint(x: origin.x + window.frame.width / 2, y: origin.y), sway: 0)
        window.advance(at: 1, elapsed: 0.1, anchor: nil, sway: 0)
        window.advance(at: 2, elapsed: 0.1, anchor: CGPoint(x: origin.x + window.frame.width / 2, y: origin.y), sway: 3)
        window.render()
        XCTAssertTrue(window.attached)
        XCTAssertEqual(window.frame.origin, origin)
        XCTAssertEqual(window.alphaValue, 1)

        window.pop(at: 3)
        window.advance(at: 3.1, elapsed: 0.1,
                       anchor: CGPoint(x: origin.x + window.frame.width / 2, y: origin.y), sway: 4)
        window.render()
        XCTAssertTrue(window.attached)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertEqual(window.alphaValue, 1)
        XCTAssertNotNil(window.contentView?.hitTest(NSPoint(x: window.frame.width / 2, y: 55)))
    }
}
