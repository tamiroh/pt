import XCTest
@testable import Pt

final class SystemLoadTests: XCTestCase {
    func testUsageIsBusyShareOfTicks() {
        XCTAssertEqual(SystemLoad.usage(busy: 25, total: 100), 0.25)
        XCTAssertEqual(SystemLoad.usage(busy: 200, total: 100), 1)
        XCTAssertNil(SystemLoad.usage(busy: 0, total: 0))
    }

    func testFirstCPUSampleHasNoBaseline() {
        var load = SystemLoad()
        XCTAssertNil(load.cpu())
        let usage = load.cpu()
        if let usage { XCTAssertTrue((0...1).contains(usage)) }
    }

    func testGPUUsageIsAFraction() {
        if let usage = SystemLoad.gpu() { XCTAssertTrue((0...1).contains(usage)) }
    }
}
