import AppKit
import XCTest
@testable import Pt

final class ContextMenuPanelTests: XCTestCase {
    @MainActor
    private var anchor: NSRect {
        let bounds = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSRect(x: bounds.midX, y: bounds.midY, width: 40, height: 35)
    }

    @MainActor
    func testReopeningReplacesItemsAndClosingClearsContent() throws {
        let panel = ContextMenuPanel()
        defer { panel.close() }
        XCTAssertFalse(panel.isOpen)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertEqual(panel.level, .popUpMenu)

        panel.open([.init(title: "Pause", action: {})], from: anchor)
        let originalView = try XCTUnwrap(panel.contentView)
        let originalHeight = panel.frame.height
        XCTAssertTrue(panel.isOpen)
        XCTAssertTrue(panel.isVisible)

        panel.open([.init(title: "Resume", action: {}), .init(title: "Quit", action: {})], from: anchor)
        XCTAssertFalse(panel.contentView === originalView)
        XCTAssertGreaterThan(panel.frame.height, originalHeight)
        XCTAssertTrue(panel.isOpen)

        panel.close()
        panel.close()
        XCTAssertFalse(panel.isOpen)
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(panel.contentView)

        panel.open([.init(title: "Pause", action: {})], from: anchor)
        XCTAssertTrue(panel.isOpen)
        XCTAssertTrue(panel.isVisible)
    }

    @MainActor
    func testChoosingItemClosesPanelBeforeInvokingAction() throws {
        let panel = ContextMenuPanel()
        defer { panel.close() }
        var chosen = false
        var openWhenChosen = true
        panel.open([
            .init(title: "Pause") { [weak panel] in
                chosen = true
                openWhenChosen = panel?.isOpen ?? false
            },
        ], from: anchor)
        let view = try XCTUnwrap(panel.contentView)
        let point = view.convert(NSPoint(x: 20, y: 16), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        view.mouseUp(with: event)
        XCTAssertTrue(chosen)
        XCTAssertFalse(openWhenChosen)
        XCTAssertFalse(panel.isVisible)
    }

    @MainActor
    func testEscapeClosesWithoutChoosingItem() throws {
        let panel = ContextMenuPanel()
        defer { panel.close() }
        var chosen = false
        panel.open([.init(title: "Pause") { chosen = true }], from: anchor)
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        panel.contentView?.keyDown(with: event)
        XCTAssertFalse(chosen)
        XCTAssertFalse(panel.isOpen)
        XCTAssertFalse(panel.isVisible)
    }
}
