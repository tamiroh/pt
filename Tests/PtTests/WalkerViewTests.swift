import AppKit
import XCTest
@testable import Pt

final class WalkerViewTests: XCTestCase {
    @MainActor
    func testDraggingPreservesGrabOffsetAndEndsOnRelease() throws {
        let view = WalkerView(frame: NSRect(origin: .zero, size: WalkerView.size))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100,
                                                  width: view.bounds.width,
                                                  height: view.bounds.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        var starts = 0
        var ends = 0
        var origin: NSPoint?
        view.onDragStarted = {
            starts += 1
            origin = $0
        }
        view.onDragMoved = { origin = $0 }
        view.onDragEnded = { ends += 1 }

        func event(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                               timestamp: 0, windowNumber: window.windowNumber,
                               context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }

        view.mouseDown(with: event(.leftMouseDown, at: NSPoint(x: 12, y: 15)))
        view.mouseDragged(with: event(.leftMouseDragged, at: NSPoint(x: 42, y: 65)))
        XCTAssertEqual(origin, NSPoint(x: 130, y: 150))
        XCTAssertEqual(window.frame.origin, NSPoint(x: 100, y: 100))

        window.setFrameOrigin(try XCTUnwrap(origin))
        view.mouseDragged(with: event(.leftMouseDragged, at: NSPoint(x: 42, y: 65)))
        XCTAssertEqual(origin, NSPoint(x: 160, y: 200))
        view.mouseUp(with: event(.leftMouseUp, at: NSPoint(x: 52, y: 75)))
        XCTAssertEqual(origin, NSPoint(x: 170, y: 210))
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(ends, 1)

        view.mouseDragged(with: event(.leftMouseDragged, at: NSPoint(x: 60, y: 60)))
        XCTAssertEqual(origin, NSPoint(x: 170, y: 210))
        XCTAssertEqual(window.frame.origin, NSPoint(x: 130, y: 150))
    }
}
