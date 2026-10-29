import XCTest
import CoreGraphics
import OpenRightCore
@testable import OpenRight

final class KeyboardMonitorTests: XCTestCase {
    private let rightCommand = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x10)
    private let leftCommand = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
    private let rightOption = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x40)

    // These events stay inside the test process. Nothing is posted to the desktop.
    private func event(_ code: CGKeyCode, flags: CGEventFlags, text: String = "") -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
        event.flags = flags
        let utf16 = Array(text.utf16)
        if !utf16.isEmpty { event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16) }
        return event
    }

    @MainActor
    func testLeftCommandNeverActivatesTrigger() {
        XCTAssertFalse(KeyboardMonitor.triggerHeld(.rightCommand, flags: leftCommand))
        XCTAssertTrue(KeyboardMonitor.triggerHeld(.rightCommand, flags: rightCommand))
        XCTAssertFalse(KeyboardMonitor.triggerHeld(.rightCommand, flags: rightCommand.union(leftCommand)))
        XCTAssertFalse(KeyboardMonitor.triggerHeld(.rightCommand, flags: rightCommand.union(.maskControl)))
    }

    @MainActor
    func testAlternateTriggersAndPinModifiers() {
        XCTAssertTrue(KeyboardMonitor.triggerHeld(.rightOption, flags: rightOption))
        XCTAssertFalse(KeyboardMonitor.triggerHeld(.rightOption, flags: CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x20)))
        XCTAssertTrue(KeyboardMonitor.triggerHeld(.rightCommand, flags: rightCommand.union(.maskAlternate)))
        XCTAssertTrue(KeyboardMonitor.triggerHeld(.controlOption, flags: [.maskControl, .maskAlternate]))
        XCTAssertFalse(KeyboardMonitor.triggerHeld(.controlOption, flags: [.maskControl]))
    }

    @MainActor
    func testDisabledKeyCannotAssignPin() {
        let delegate = AppDelegate()
        delegate.model.preferences.disabledKeys = "c"
        XCTAssertFalse(delegate.handleKey("c", assigning: true))
        XCTAssertFalse(delegate.handleKey("c", assigning: false))
    }

    @MainActor
    func testSpaceConsumesMatchingKeyUpEvenAfterModifierRelease() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        var launched = 0
        monitor.onLauncher = { launched += 1 }
        XCTAssertFalse(monitor.handle(type: .flagsChanged, event: event(54, flags: rightCommand)))
        XCTAssertTrue(monitor.isTriggerHeld)
        XCTAssertTrue(monitor.handle(type: .keyDown, event: event(49, flags: rightCommand, text: " ")))
        XCTAssertEqual(launched, 1)
        XCTAssertFalse(monitor.handle(type: .flagsChanged, event: event(54, flags: [])))
        XCTAssertFalse(monitor.isTriggerHeld)
        XCTAssertTrue(monitor.handle(type: .keyUp, event: event(49, flags: [])))
        XCTAssertFalse(monitor.handle(type: .keyUp, event: event(49, flags: [])))
    }

    @MainActor
    func testUnmappedKeysAndLeftCommandPassThrough() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        var called = false
        monitor.onKey = { _, _ in called = true; return false }
        XCTAssertFalse(monitor.handle(type: .keyDown, event: event(8, flags: leftCommand, text: "c")))
        XCTAssertFalse(called)
        XCTAssertFalse(monitor.handle(type: .keyDown, event: event(8, flags: rightCommand, text: "c")))
        XCTAssertTrue(called)
        XCTAssertFalse(monitor.handle(type: .keyUp, event: event(8, flags: [])))
    }

    @MainActor
    func testConsumedLettersDoNotRepeatAndPairKeyUp() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        var calls = 0
        monitor.onKey = { key, _ in XCTAssertEqual(key, "c"); calls += 1; return true }
        XCTAssertTrue(monitor.handle(type: .keyDown, event: event(8, flags: rightCommand, text: "c")))
        let repeated = event(8, flags: rightCommand, text: "c")
        repeated.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertTrue(monitor.handle(type: .keyDown, event: repeated))
        XCTAssertEqual(calls, 1)
        monitor.enabled = false
        XCTAssertTrue(monitor.handle(type: .keyDown, event: repeated))
        XCTAssertTrue(monitor.handle(type: .keyUp, event: event(8, flags: [])))
    }

    @MainActor
    func testHeldLetterCannotLeakAfterReleasingTrigger() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        monitor.onKey = { _, _ in true }
        XCTAssertTrue(monitor.handle(type: .keyDown, event: event(8, flags: rightCommand, text: "c")))
        let repeated = event(8, flags: [], text: "c")
        repeated.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertTrue(monitor.handle(type: .keyDown, event: repeated))
        XCTAssertTrue(monitor.handle(type: .keyUp, event: event(8, flags: [])))
        XCTAssertFalse(monitor.handle(type: .keyDown, event: repeated))
    }

    @MainActor
    func testHeldSpaceCannotLeakIntoLauncher() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        monitor.onLauncher = { monitor.launcherVisible = true }
        XCTAssertTrue(monitor.handle(type: .keyDown, event: event(49, flags: rightCommand, text: " ")))
        let repeated = event(49, flags: [], text: " ")
        repeated.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertTrue(monitor.handle(type: .keyDown, event: repeated))
        XCTAssertTrue(monitor.handle(type: .keyUp, event: event(49, flags: [])))
    }

    @MainActor
    func testLauncherAndShiftPassThrough() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        monitor.onKey = { _, _ in XCTFail("Should pass through"); return true }
        XCTAssertFalse(monitor.handle(type: .keyDown, event: event(8, flags: rightCommand.union(.maskShift), text: "C")))
        monitor.launcherVisible = true
        XCTAssertFalse(monitor.handle(type: .keyDown, event: event(8, flags: rightCommand, text: "c")))
    }

    @MainActor
    func testEscapeCancelsUntilTriggerRelease() {
        let monitor = KeyboardMonitor()
        monitor.enabled = true
        _ = monitor.handle(type: .flagsChanged, event: event(54, flags: rightCommand))
        XCTAssertTrue(monitor.handle(type: .keyDown, event: event(53, flags: rightCommand)))
        XCTAssertFalse(monitor.handle(type: .keyDown, event: event(49, flags: rightCommand)))
        _ = monitor.handle(type: .flagsChanged, event: event(54, flags: []))
        _ = monitor.handle(type: .flagsChanged, event: event(54, flags: rightCommand))
        XCTAssertTrue(monitor.handle(type: .keyDown, event: event(49, flags: rightCommand)))
    }
}
