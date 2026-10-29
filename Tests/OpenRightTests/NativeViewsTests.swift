import AppKit
import SwiftUI
import XCTest
import OpenRightCore
@testable import OpenRight

final class NativeViewsTests: XCTestCase {
    @MainActor
    func testNativeViewsRenderAtUsableSizes() throws {
        _ = NSApplication.shared
        let model = AppModel(preferencesURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        model.runningApps = [
            AppCandidate(id: "com.apple.calculator", name: "Calculator", path: "/System/Applications/Calculator.app"),
            AppCandidate(id: "com.apple.Calendar", name: "Calendar", path: "/System/Applications/Calendar.app"),
            AppCandidate(id: "com.apple.Safari", name: "Safari", path: "/Applications/Safari.app")
        ]
        model.installedApps = model.runningApps
        model.conflictingAppRunning = true
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/verification")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try render(SettingsView(model: model), size: NSSize(width: 820, height: 650), to: folder.appendingPathComponent("settings.png"))
        try render(HintsView(model: model), size: NSSize(width: 650, height: 300), to: folder.appendingPathComponent("hints.png"))
        try render(LauncherView(model: model, onDismiss: {}), size: NSSize(width: 590, height: 490), to: folder.appendingPathComponent("launcher.png"))
    }

    @MainActor
    func testPreferencesSaveAndReloadInIsolatedDirectory() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("OpenRightTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("preferences.json")
        let model = AppModel(preferencesURL: url)
        model.preferences.trigger = .rightOption
        model.preferences.disabledKeys = "CCq!"
        model.pin(key: "s", app: AppCandidate(id: "com.apple.Safari", name: "Safari", path: "/Applications/Safari.app"), behavior: .hide)
        let restored = AppModel(preferencesURL: url)
        XCTAssertEqual(restored.preferences.trigger, .rightOption)
        XCTAssertEqual(restored.preferences.disabledKeys, "cq")
        XCTAssertEqual(restored.preferences.bindings.first?.bundleID, "com.apple.Safari")
        XCTAssertEqual(restored.preferences.bindings.first?.behavior, .hide)
        restored.removeBinding("s")
        XCTAssertTrue(AppModel(preferencesURL: url).preferences.bindings.isEmpty)
    }

    @MainActor
    func testConflictOnlyBlocksDefaultTrigger() {
        let model = AppModel(preferencesURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        model.conflictingAppRunning = true
        XCTAssertFalse(model.shortcutsAllowed)
        model.preferences.trigger = .rightOption
        XCTAssertTrue(model.shortcutsAllowed)
        model.isPaused = true
        XCTAssertFalse(model.shortcutsAllowed)
    }

    @MainActor
    private func render<Content: View>(_ content: Content, size: NSSize, to url: URL) throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        let view = NSHostingView(rootView: content)
        window.contentView = view
        view.setFrameSize(size)
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return XCTFail("No bitmap for native view") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 5_000, "View should render content")
        try png.write(to: url)
        window.contentView = nil
    }
}
