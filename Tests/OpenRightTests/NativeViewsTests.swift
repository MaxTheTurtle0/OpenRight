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
        model.preferences.bindings = [
            AppBinding(key: "c", bundleID: "com.apple.calculator", name: "Calculator", path: "/System/Applications/Calculator.app"),
            AppBinding(key: "x", bundleID: "com.apple.calculator", name: "Calculator", path: "/System/Applications/Calculator.app", behavior: .hide),
            AppBinding(key: "z", bundleID: "app.zen-browser.zen", name: "Zen", path: "/Applications/Zen.app")
        ]
        model.conflictingAppRunning = true
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/verification")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try render(SettingsView(model: model), size: NSSize(width: 820, height: 650), to: folder.appendingPathComponent("settings.png"))
        try render(AppsSettingsView(model: model).padding(28).tint(.teal), size: NSSize(width: 600, height: 620), to: folder.appendingPathComponent("apps.png"))
        try render(AppKeysEditor(model: model, app: model.runningApps[0]).tint(.teal), size: NSSize(width: 400, height: 340), to: folder.appendingPathComponent("app-keys.png"))
        try render(LauncherView(model: model, onDismiss: {}), size: NSSize(width: 590, height: 490), to: folder.appendingPathComponent("launcher.png"))
    }

    @MainActor
    func testShortcutAppsKeepsClosedPinsAndUsesCurrentAppMetadata() {
        let model = AppModel(preferencesURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        let running = AppCandidate(id: "zen", name: "Zen", path: "/Current/Zen.app", isHidden: true)
        let installed = AppCandidate(id: "terminal", name: "Terminal", path: "/Current/Terminal.app", isRunning: false)
        model.runningApps = [running]
        model.installedApps = [running, installed, AppCandidate(id: "unassigned", name: "Unassigned", path: "/Unassigned.app", isRunning: false)]
        model.preferences.bindings = [
            AppBinding(key: "z", bundleID: "zen", name: "Old Zen", path: "/Old/Zen.app"),
            AppBinding(key: "x", bundleID: "zen", name: "Old Zen", path: "/Old/Zen.app"),
            AppBinding(key: "t", bundleID: "terminal", name: "Old Terminal", path: "/Old/Terminal.app"),
            AppBinding(key: "m", bundleID: "missing", name: "Missing", path: "/Missing.app")
        ]
        let apps = model.shortcutApps
        XCTAssertEqual(apps.map(\.id), ["missing", "terminal", "zen"])
        XCTAssertEqual(apps.first { $0.id == "zen" }, running)
        XCTAssertEqual(apps.first { $0.id == "terminal" }, installed)
        XCTAssertEqual(apps.first { $0.id == "missing" }, AppCandidate(id: "missing", name: "Missing", path: "/Missing.app", isRunning: false))
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
