import XCTest
@testable import Pt

final class WindowPlatformTests: XCTestCase {
    private func platform(_ id: UInt32 = 1, x: Double = 20, y: Double = 100) -> WindowPlatform {
        WindowPlatform(id: id, frame: CGRect(x: x, y: 0, width: 100, height: y),
                       spans: [x...(x + 100)])
    }

    func testLandsOnHighestPlatformAndWalksAlongIt() {
        var walker = Walker(x: 50, direction: 1)
        walker.drop(from: 300)
        walker.advance(seconds: 1, width: 500, platforms: [platform(), platform(2, y: 200)])
        XCTAssertEqual(walker.height, 200)
        XCTAssertFalse(walker.isFalling)
        XCTAssertGreaterThan(walker.x, 50)
        walker.advance(seconds: 10, width: 500, platforms: [platform(), platform(2, y: 200)])
        XCTAssertTrue((20...120).contains(walker.x))
        XCTAssertEqual(walker.height, 200)
    }

    func testMovesWithPlatformAndFallsWhenItDisappears() {
        var walker = Walker(x: 50)
        walker.drop(from: 100)
        walker.advance(seconds: 0.01, width: 500, walking: false, platforms: [platform()])
        walker.advance(seconds: 0.01, width: 500, walking: false, platforms: [platform(x: 40, y: 150)])
        XCTAssertEqual(walker.x, 70)
        XCTAssertEqual(walker.height, 150)
        walker.advance(seconds: 0.1, width: 500, walking: false)
        XCTAssertTrue(walker.isFalling)
        XCTAssertLessThan(walker.height, 150)
        walker.advance(seconds: 1, width: 500)
        XCTAssertEqual(walker.height, 0)
    }

    func testDoesNotLandOnPlatformAboveOrBesideWalker() {
        var walker = Walker(x: 200)
        walker.drop(from: 50)
        walker.advance(seconds: 1, width: 500, platforms: [platform()])
        XCTAssertEqual(walker.height, 0)
        walker.x = 50
        walker.drop(from: 50)
        walker.advance(seconds: 1, width: 500, platforms: [platform()])
        XCTAssertEqual(walker.height, 0)
    }

    func testOcclusionSplitsPlatformAndAccountsForScreenOrigin() {
        let platforms = WindowPlatform.visible([
            (id: 1, frame: CGRect(x: -180, y: 150, width: 60, height: 100)),
            (id: 2, frame: CGRect(x: -250, y: 100, width: 200, height: 100)),
        ], ground: CGRect(x: -300, y: 50, width: 300, height: 400),
           walkerSize: CGSize(width: 40, height: 42))
        XCTAssertEqual(platforms[1].frame.maxY, 150)
        XCTAssertEqual(platforms[1].spans, [30.0...100.0, 160.0...230.0])
    }

    func testFullyCoveredTopAndInsufficientHeadroomAreNotUsable() {
        let platforms = WindowPlatform.visible([
            (id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 300)),
            (id: 2, frame: CGRect(x: 50, y: 0, width: 100, height: 150)),
        ], ground: CGRect(x: 0, y: 0, width: 300, height: 320),
           walkerSize: CGSize(width: 40, height: 42))
        XCTAssertEqual(platforms.count, 1)
        XCTAssertTrue(platforms[0].spans.isEmpty)
    }
}
