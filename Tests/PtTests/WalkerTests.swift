import XCTest
@testable import Pt

final class WalkerTests: XCTestCase {
    func testReflectsAtBothEdges() {
        var walker = Walker(x: 1, direction: -1)
        walker.advance(seconds: 1, width: 100)
        XCTAssertEqual(walker.x, 26, accuracy: 0.0001)
        XCTAssertEqual(walker.direction, 1)
        walker.x = 99
        walker.advance(seconds: 1, width: 100)
        XCTAssertEqual(walker.x, 74, accuracy: 0.0001)
        XCTAssertEqual(walker.direction, -1)
    }

    func testLargeStepRemainsInsideScreen() {
        var walker = Walker(x: 0, direction: 1)
        walker.advance(seconds: 10, width: 100)
        XCTAssertEqual(walker.x, 70, accuracy: 0.0001)
        XCTAssertEqual(walker.direction, 1)
    }

    func testFrameRateDoesNotChangePace() {
        var smooth = Walker(x: 50)
        var single = smooth
        for _ in 0..<60 { smooth.advance(seconds: 1.0 / 60, width: 100) }
        single.advance(seconds: 1, width: 100)
        XCTAssertEqual(smooth.x, single.x, accuracy: 0.0001)
        XCTAssertEqual(smooth.swing, single.swing, accuracy: 0.0001)
    }

    func testScreenResizeAndUnavailableSpace() {
        var walker = Walker(x: 500)
        walker.constrain(to: 100)
        XCTAssertEqual(walker.x, 100)
        walker.constrain(to: -1)
        walker.advance(seconds: 1, width: -1)
        XCTAssertEqual(walker.x, 0)
        XCTAssertEqual(walker.distance, 0)
    }
}
