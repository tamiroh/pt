import XCTest
@testable import Pt

final class BalloonTests: XCTestCase {
    func testReleasedBalloonDriftsFromLastAttachedPositionAndFadesOut() {
        var balloon = Balloon()
        XCTAssertEqual(balloon.opacity(at: 0), 0)
        balloon.advance(at: 0, elapsed: 0, floatingOrigin: CGPoint(x: 100, y: 200), sway: 5)
        XCTAssertTrue(balloon.attached)
        XCTAssertEqual(balloon.sway, 5)

        balloon.advance(at: 1, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        XCTAssertFalse(balloon.attached)
        XCTAssertEqual(balloon.origin, CGPoint(x: 100, y: 207))
        XCTAssertEqual(balloon.opacity(at: 1.75), 0.5)
        balloon.advance(at: 2.5, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        XCTAssertEqual(balloon.opacity(at: 2.5), 0)
    }

    func testPoppedBalloonStaysInPlaceUntilBurstFinishes() {
        var balloon = Balloon()
        let origin = CGPoint(x: 100, y: 200)
        balloon.advance(at: 0, elapsed: 0, floatingOrigin: origin, sway: 0)
        balloon.pop(at: 1)
        balloon.advance(at: 1.125, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        XCTAssertFalse(balloon.attached)
        XCTAssertEqual(balloon.origin, origin)
        XCTAssertEqual(balloon.burst(at: 1.125), 0.5)
        XCTAssertEqual(balloon.opacity(at: 1.125), 1)

        balloon.advance(at: 1.25, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        XCTAssertNil(balloon.burst(at: 1.25))
        XCTAssertEqual(balloon.opacity(at: 1.25), 0)
    }

    func testReattachingCancelsReleaseAndBurst() {
        var balloon = Balloon()
        let origin = CGPoint(x: 100, y: 200)
        balloon.advance(at: 0, elapsed: 0, floatingOrigin: origin, sway: 0)
        balloon.advance(at: 1, elapsed: 0.1, floatingOrigin: nil, sway: 0)
        balloon.advance(at: 2, elapsed: 0.1, floatingOrigin: origin, sway: 3)
        XCTAssertTrue(balloon.attached)
        XCTAssertEqual(balloon.origin, origin)
        XCTAssertEqual(balloon.opacity(at: 2), 1)

        balloon.pop(at: 3)
        balloon.advance(at: 3.1, elapsed: 0.1, floatingOrigin: origin, sway: 4)
        XCTAssertTrue(balloon.attached)
        XCTAssertNil(balloon.burst(at: 3.1))
        XCTAssertEqual(balloon.sway, 4)
    }
}
