import AppKit
import XCTest
@testable import Pt

final class WalkerWindowTests: XCTestCase {
    @MainActor
    private func event(_ type: NSEvent.EventType, in window: NSWindow, at point: NSPoint,
                       modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: modifiers,
            timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    @MainActor
    func testDraggingPreservesGrabOffsetAndReportsFinalPositionBeforeRendering() throws {
        let window = WalkerWindow()
        let view = try XCTUnwrap(window.contentView as? WalkerView)
        let ground = NSRect(x: 0, y: 0, width: 1_000, height: 800)
        var walker = Walker(x: 100)
        walker.drop(from: 100)
        window.render(walker, on: ground, walking: true)
        var drops: [NSPoint] = []
        window.onDragEnded = { origin in
            drops.append(origin)
            walker.x = origin.x
            walker.drop(from: origin.y)
        }

        view.mouseDown(with: try event(.leftMouseDown, in: window, at: NSPoint(x: 12, y: 15)))
        XCTAssertTrue(window.isDragging)
        view.mouseDragged(with: try event(.leftMouseDragged, in: window, at: NSPoint(x: 42, y: 65)))
        XCTAssertEqual(window.frame.origin, NSPoint(x: 100, y: 100))
        window.advance(seconds: 0.02)
        window.render(walker, on: ground, walking: false)
        XCTAssertEqual(window.frame.origin, NSPoint(x: 130, y: 150))
        XCTAssertFalse(view.standing)
        XCTAssertNotEqual(view.swing, 0)

        view.mouseDragged(with: try event(.leftMouseDragged, in: window, at: NSPoint(x: 42, y: 65)))
        view.mouseUp(with: try event(.leftMouseUp, in: window, at: NSPoint(x: 52, y: 75)))
        XCTAssertFalse(window.isDragging)
        XCTAssertEqual(drops, [NSPoint(x: 170, y: 210)])
        XCTAssertEqual(window.frame.origin, NSPoint(x: 130, y: 150))
        window.render(walker, on: ground, walking: true)
        XCTAssertEqual(window.frame.origin, NSPoint(x: 170, y: 210))

        view.mouseDragged(with: try event(.leftMouseDragged, in: window, at: NSPoint(x: 60, y: 60)))
        view.mouseUp(with: try event(.leftMouseUp, in: window, at: .zero))
        XCTAssertFalse(window.isDragging)
        XCTAssertEqual(drops.count, 1)
    }

    @MainActor
    func testRightClickAndControlClickRequestMenuWithoutDragging() throws {
        let window = WalkerWindow()
        let view = try XCTUnwrap(window.contentView)
        var menus = 0
        var drops = 0
        window.onMenuRequested = { menus += 1 }
        window.onDragEnded = { _ in drops += 1 }

        view.rightMouseDown(with: try event(.rightMouseDown, in: window, at: .zero))
        view.mouseDown(with: try event(.leftMouseDown, in: window, at: .zero, modifiers: .control))
        view.mouseUp(with: try event(.leftMouseUp, in: window, at: .zero))
        XCTAssertEqual(menus, 2)
        XCTAssertEqual(drops, 0)
        XCTAssertFalse(window.isDragging)
    }

    @MainActor
    func testRendersWalkingPausedAndOffstageStates() throws {
        let window = WalkerWindow()
        let view = try XCTUnwrap(window.contentView as? WalkerView)
        let ground = NSRect(x: -300, y: 50, width: 300, height: 400)
        var walker = Walker(x: 50, direction: 1)
        walker.advance(seconds: 0.2, width: 260)
        window.render(walker, on: ground, walking: true)
        XCTAssertEqual(window.frame.minX, ground.minX + walker.x, accuracy: 1)
        XCTAssertEqual(window.frame.minY, ground.minY)
        XCTAssertEqual(view.swing, walker.swing)
        XCTAssertEqual(view.direction, 1)
        XCTAssertFalse(view.standing)
        window.render(walker, on: ground, walking: false)
        XCTAssertTrue(view.standing)
        XCTAssertEqual(window.menuAnchor.minY, window.frame.minY)
        XCTAssertEqual(window.bubbleAnchor.y, window.menuAnchor.maxY)

        walker = Walker(x: 1, direction: -1, randomNumberGenerator: FixedRandom(value: 0))
        walker.advance(seconds: 3, width: 260)
        window.render(walker, on: ground, walking: true)
        XCTAssertEqual(window.alphaValue, 0)
        XCTAssertTrue(window.ignoresMouseEvents)
        walker.drop(from: 0)
        window.render(walker, on: ground, walking: true)
        XCTAssertEqual(window.alphaValue, 1)
        XCTAssertFalse(window.ignoresMouseEvents)
    }

    @MainActor
    func testFloatingPoseAndPositionYieldToDragging() throws {
        let window = WalkerWindow()
        let view = try XCTUnwrap(window.contentView as? WalkerView)
        let ground = NSRect(x: 0, y: 0, width: 1_000, height: 1_200)
        var walker = Walker(x: 100)
        walker.drop(from: 1_000)
        walker.advance(seconds: 2, width: 960, walking: false)
        window.render(walker, on: ground, walking: true)
        XCTAssertTrue(view.floating)
        XCTAssertEqual(view.sway, walker.sway)
        let angle = walker.sway * .pi / 180
        XCTAssertEqual(window.frame.minX, walker.x + BalloonWindow.stringLength * sin(angle), accuracy: 1)
        XCTAssertEqual(window.frame.minY,
                       walker.height + BalloonWindow.stringLength * (1 - cos(angle)), accuracy: 1)

        let origin = window.frame.origin
        view.mouseDown(with: try event(.leftMouseDown, in: window, at: NSPoint(x: 12, y: 15)))
        window.render(walker, on: ground, walking: true)
        XCTAssertFalse(view.floating)
        XCTAssertEqual(view.sway, 0)
        XCTAssertEqual(window.frame.origin, origin)
    }
}
