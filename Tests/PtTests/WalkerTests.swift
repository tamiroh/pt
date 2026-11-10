import XCTest
@testable import Pt

final class WalkerTests: XCTestCase {
    func testDropAcceleratesThenResumesWalkingAtLanding() {
        var walker = Walker(x: 50, direction: 1)
        walker.drop(from: 150)
        walker.advance(seconds: 0.25, width: 1_000)
        XCTAssertEqual(walker.height, 112.5, accuracy: 0.0001)
        XCTAssertEqual(walker.x, 50)
        XCTAssertEqual(walker.distance, 0)
        walker.advance(seconds: 0.5, width: 1_000)
        XCTAssertEqual(walker.height, 0)
        XCTAssertFalse(walker.isFalling)
        XCTAssertEqual(walker.x, 56.75, accuracy: 0.0001)
    }

    func testFallingIsIndependentOfFrameRate() {
        var smooth = Walker(x: 50, direction: 1)
        smooth.drop(from: 150)
        var single = smooth
        for _ in 0..<60 { smooth.advance(seconds: 1.0 / 60, width: 1_000) }
        single.advance(seconds: 1, width: 1_000)
        XCTAssertEqual(smooth.height, single.height, accuracy: 0.0001)
        XCTAssertEqual(smooth.x, single.x, accuracy: 0.0001)
    }

    func testPausedWalkerStillFallsButDoesNotWalk() {
        var walker = Walker(x: 50)
        walker.drop(from: 150)
        walker.advance(seconds: 1, width: 100, walking: false)
        XCTAssertEqual(walker.height, 0)
        XCTAssertEqual(walker.x, 50)
        XCTAssertEqual(walker.distance, 0)
    }

    func testDroppingAgainResetsFallSpeedAndClampsBelowGround() {
        var walker = Walker()
        walker.drop(from: 600)
        walker.advance(seconds: 0.5, width: 100)
        walker.drop(from: 150)
        walker.advance(seconds: 0.25, width: 100)
        XCTAssertEqual(walker.height, 112.5, accuracy: 0.0001)
        walker.drop(from: -20)
        XCTAssertEqual(walker.height, 0)
        XCTAssertFalse(walker.isFalling)
    }

    func testReflectsAtBothEdges() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: .max))
        walker.advance(seconds: 1, width: 100)
        XCTAssertEqual(walker.x, 26, accuracy: 0.0001)
        XCTAssertEqual(walker.direction, 1)
        walker.x = 99
        walker.advance(seconds: 1, width: 100)
        XCTAssertEqual(walker.x, 74, accuracy: 0.0001)
        XCTAssertEqual(walker.direction, -1)
    }

    func testLargeStepRemainsInsideScreen() {
        var walker = Walker(x: 0, direction: 1, randomNumberGenerator: FixedRandom(value: .max))
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

    func testWalksOffScreenEdgeAndDropsBackInFromAbove() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 1, width: 100, ceiling: 300)
        XCTAssertFalse(walker.isOffstage)
        XCTAssertLessThan(walker.x, 0)
        walker.constrain(to: 100)
        XCTAssertLessThan(walker.x, 0)
        walker.advance(seconds: 1, width: 100, ceiling: 300)
        XCTAssertTrue(walker.isOffstage)
        walker.advance(seconds: 4.9, width: 100, ceiling: 300)
        XCTAssertTrue(walker.isOffstage)
        walker.advance(seconds: 0.2, width: 100, ceiling: 300)
        XCTAssertFalse(walker.isOffstage)
        XCTAssertTrue(walker.isFalling)
        XCTAssertEqual(walker.height, 300)
        XCTAssertEqual(walker.x, 0)
    }

    func testLeavesFromTheRightEdgeToo() {
        var walker = Walker(x: 99, direction: 1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 3, width: 100)
        XCTAssertTrue(walker.isOffstage)
    }

    func testStaysAwayWhilePaused() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 3, width: 100, ceiling: 300)
        XCTAssertTrue(walker.isOffstage)
        walker.advance(seconds: 60, width: 100, walking: false, ceiling: 300)
        XCTAssertTrue(walker.isOffstage)
    }

    func testDraggingBackCancelsLeaving() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 1, width: 100)
        walker.drop(from: 0)
        walker.constrain(to: 100)
        XCTAssertEqual(walker.x, 0)
    }

    func testReturnsUnderBalloonDriftingDownSlowlyAndSwaying() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 3, width: 100, ceiling: 300)
        walker.advance(seconds: 5, width: 100, ceiling: 300)
        XCTAssertTrue(walker.isFloating)
        XCTAssertEqual(walker.sway, 0)
        walker.advance(seconds: 1, width: 100, ceiling: 300)
        XCTAssertEqual(walker.height, 300 - Walker.floatSpeed, accuracy: 0.0001)
        XCTAssertNotEqual(walker.sway, 0)
        XCTAssertEqual(walker.x, 0)
        walker.advance(seconds: 300 / Walker.floatSpeed, width: 100, ceiling: 300)
        XCTAssertEqual(walker.height, 0)
        XCTAssertFalse(walker.isFloating)
        XCTAssertFalse(walker.isFalling)
        XCTAssertEqual(walker.sway, 0)
        XCTAssertGreaterThan(walker.x, 0)
    }

    func testBalloonLandsOnWindowBelow() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        let platform = WindowPlatform(id: 1, frame: CGRect(x: 0, y: 0, width: 50, height: 100),
                                      spans: [0...50])
        walker.advance(seconds: 3, width: 100, ceiling: 300)
        walker.advance(seconds: 5, width: 100, platforms: [platform], ceiling: 300)
        walker.advance(seconds: 4.1, width: 100, walking: false, platforms: [platform], ceiling: 300)
        XCTAssertEqual(walker.height, 100)
        XCTAssertFalse(walker.isFloating)
    }

    func testDroppingWhileFloatingFallsFreely() {
        var walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 3, width: 100, ceiling: 300)
        walker.advance(seconds: 5, width: 100, ceiling: 300)
        walker.drop(from: 150)
        XCTAssertFalse(walker.isFloating)
        walker.advance(seconds: 0.25, width: 100)
        XCTAssertEqual(walker.height, 112.5, accuracy: 0.0001)
    }
}
