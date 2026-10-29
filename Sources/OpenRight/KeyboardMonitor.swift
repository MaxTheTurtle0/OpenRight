import AppKit
import ApplicationServices
import OpenRightCore

/// Installed on the main run loop. It never stores typed text or observes mouse events.
@MainActor
final class KeyboardMonitor {
    var onTriggerChanged: ((Bool) -> Void)?
    var onKey: ((String, Bool) -> Bool)?
    var onLauncher: (() -> Void)?
    var trigger: Trigger = .rightCommand
    var enabled = false { didSet { if !enabled { resetSession() } } }
    var launcherVisible = false
    private(set) var isTriggerHeld = false
    private var suppressed = Set<Int64>()
    private var cancelled = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return CGEvent.tapIsEnabled(tap: tap)
        }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            return monitor.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        suppressed.removeAll()
        resetSession()
    }

    func resetSession() {
        if isTriggerHeld { onTriggerChanged?(false) }
        isTriggerHeld = false
        cancelled = false
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resetSession()
            suppressed.removeAll()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp { return suppressed.remove(code) != nil }
        // A consumed press owns its repeats until key-up, even after the
        // modifier is released, the launcher opens, or shortcuts are paused.
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return suppressed.contains(code)
        }
        guard enabled else { return false }
        let held = Self.triggerHeld(trigger, flags: event.flags)
        if type == .flagsChanged {
            if held != isTriggerHeld {
                isTriggerHeld = held
                cancelled = false
                onTriggerChanged?(held)
            }
            return false
        }
        guard type == .keyDown, held, !launcherVisible, !cancelled else { return false }
        if code == 53 {
            cancelled = true
            suppressed.insert(code)
            return true
        }
        guard !event.flags.contains(.maskShift) else { return false }
        let assigning = trigger == .rightCommand ? event.flags.contains(.maskAlternate) : event.flags.contains(.maskCommand)
        if code == 49, !assigning {
            suppressed.insert(code)
            onLauncher?()
            return true
        }
        guard let chars = NSEvent(cgEvent: event)?.charactersIgnoringModifiers,
              let key = ShortcutKey.normalized(chars), onKey?(key, assigning) == true else { return false }
        suppressed.insert(code)
        return true
    }

    static func triggerHeld(_ trigger: Trigger, flags: CGEventFlags) -> Bool {
        let raw = flags.rawValue
        // IOHID/NX device-dependent modifier masks distinguish the two sides.
        switch trigger {
        case .rightCommand:
            return flags.contains(.maskCommand) && raw & 0x10 != 0 && raw & 0x08 == 0 && !flags.contains(.maskControl)
        case .rightOption:
            return flags.contains(.maskAlternate) && raw & 0x40 != 0 && raw & 0x20 == 0 && !flags.contains(.maskControl)
        case .controlOption:
            return flags.contains([.maskControl, .maskAlternate])
        }
    }
}
