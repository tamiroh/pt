import AppKit
import XCTest
@testable import Pt

final class BalloonViewTests: XCTestCase {
    @MainActor
    private func makeBalloon() -> (BalloonView, NSWindow) {
        let view = BalloonView(frame: NSRect(origin: .zero, size: BalloonView.size))
        let window = NSWindow(contentRect: view.bounds, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        return (view, window)
    }

    @MainActor
    func testReleasedBalloonDriftsFromLastAttachedPositionAndFadesOut() {
        let (view, window) = makeBalloon()
        view.render()
        XCTAssertEqual(window.alphaValue, 0)
        view.advance(at: 0, elapsed: 0, floatingOrigin: CGPoint(x: 100, y: 200), sway: 5)
        view.render()
        XCTAssertTrue(view.attached)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 200))

        view.advance(at: 1, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 200))
        view.render()
        XCTAssertFalse(view.attached)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 207))
        view.render()
        XCTAssertEqual(window.frame.origin, CGPoint(x: 100, y: 207))

        view.advance(at: 1.75, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        view.render()
        XCTAssertEqual(window.alphaValue, 0.5)
        view.advance(at: 2.5, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        view.render()
        XCTAssertEqual(window.alphaValue, 0)
    }

    @MainActor
    func testPoppedBalloonStaysInPlaceUntilBurstFinishes() {
        let (view, window) = makeBalloon()
        let origin = CGPoint(x: 100, y: 200)
        view.advance(at: 0, elapsed: 0, floatingOrigin: origin, sway: 0)
        view.pop(at: 1)
        view.advance(at: 1.125, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        view.render()
        XCTAssertFalse(view.attached)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertEqual(window.frame.origin, origin)
        XCTAssertEqual(window.alphaValue, 1)

        view.advance(at: 1.25, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        view.render()
        XCTAssertEqual(window.alphaValue, 0)
    }

    @MainActor
    func testReattachingCancelsReleaseAndBurst() {
        let (view, window) = makeBalloon()
        let origin = CGPoint(x: 100, y: 200)
        view.advance(at: 0, elapsed: 0, floatingOrigin: origin, sway: 0)
        view.advance(at: 1, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        view.advance(at: 2, elapsed: 0.1, floatingOrigin: origin, sway: 3)
        view.render()
        XCTAssertTrue(view.attached)
        XCTAssertEqual(window.frame.origin, origin)
        XCTAssertEqual(window.alphaValue, 1)

        view.pop(at: 3)
        view.advance(at: 3.1, elapsed: 0.1, floatingOrigin: origin, sway: 4)
        view.render()
        XCTAssertTrue(view.attached)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertEqual(window.alphaValue, 1)
        XCTAssertNotNil(view.hitTest(NSPoint(x: view.bounds.midX, y: 55)))
    }
}
