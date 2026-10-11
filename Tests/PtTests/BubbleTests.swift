import AppKit
import XCTest
@testable import Pt

final class BubbleTests: XCTestCase {
    func testFadesInAndOutAroundItsLife() {
        let bubble = Bubble(text: "Whoa", born: 10, life: 3)

        XCTAssertEqual(bubble.opacity(at: 10), 0)
        XCTAssertEqual(bubble.opacity(at: 10.1), 0.5, accuracy: 0.000_001)
        XCTAssertEqual(bubble.opacity(at: 11), 1)
        XCTAssertEqual(bubble.opacity(at: 12.9), 0.5, accuracy: 0.000_001)
        XCTAssertFalse(bubble.isOver(at: 12.9))
        XCTAssertTrue(bubble.isOver(at: 13))
        XCTAssertEqual(bubble.opacity(at: 14), 0)
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
