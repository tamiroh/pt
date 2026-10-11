import XCTest
@testable import Pt

final class SpeechTests: XCTestCase {
    func testTidyDropsBlankRepeatedAndLongLines() {
        XCTAssertEqual(
            Speech.tidy([" Whoa \n", "", "Whoa", "Oops",
                         String(repeating: "a", count: Speech.longest + 1)]),
            ["Whoa", "Oops"])
    }

    @MainActor
    func testHandsOutEachPreparedLineOnce() async throws {
        let speech = Speech { ["Whoa", "Oops"] }
        XCTAssertNil(speech.take())

        var taken: [String] = []
        for _ in 0..<200 where taken.count < 2 {
            if let line = speech.take() { taken.append(line) }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertEqual(taken.sorted(), ["Oops", "Whoa"])
    }

    @MainActor
    func testStaysSilentWhenNothingIsGenerated() async throws {
        let speech = Speech { [] }
        speech.prepare()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(speech.take())
    }
}
