import AppKit
import ApplicationServices
import Combine
import SwiftUI
import OpenRightCore

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let model = AppModel()
    let keyboard = KeyboardMonitor()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var hintsPanel: NSPanel?
    private var launcherPanel: LauncherPanel?
    private var permissionTimer: Timer?
    private var hintsWork: DispatchWorkItem?
    private var sessionRecentIDs: [String] = []
    private var logicalFrontmostID: String?
    private var sessionHiddenStates: [String: Bool] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "OpenRight")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        model.openSettings = { [weak self] in self?.showSettings() }
        model.showLauncher = { [weak self] in self?.showLauncher() }
        model.didActivate = { [weak self] in self?.dismissLauncher() }
        model.preferencesDidChange = { [weak self] in self?.updateKeyboard() }
        keyboard.onTriggerChanged = { [weak self] held in self?.triggerChanged(held) }
        keyboard.onKey = { [weak self] key, assigning in self?.handleKey(key, assigning: assigning) ?? false }
        keyboard.onLauncher = { [weak self] in DispatchQueue.main.async { self?.showLauncher() } }
        keyboard.onCancel = { [weak self] in self?.hideHints() }
        model.$isPaused.dropFirst().sink { [weak self] _ in DispatchQueue.main.async { self?.updateKeyboard() } }.store(in: &subscriptions)
        model.$conflictingAppRunning.dropFirst().sink { [weak self] _ in DispatchQueue.main.async { self?.updateKeyboard() } }.store(in: &subscriptions)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkPermissions() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                                        object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.async {
                self?.keyboard.stop()
                self?.checkPermissions()
            }
        }
        checkPermissions()
        if !model.accessibilityGranted || CommandLine.arguments.contains("--settings") { showSettings() }
    }

    private func installMainMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "OpenRight")
        addItem("Settings…", action: #selector(settingsFromMenu), to: appMenu, key: ",")
        appMenu.addItem(.separator())
        addItem("Quit OpenRight", action: #selector(quit), to: appMenu, key: "q")
        appItem.submenu = appMenu
        bar.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", #selector(NSText.cut(_:)), "x"),
                                       ("Copy", #selector(NSText.copy(_:)), "c"),
                                       ("Paste", #selector(NSText.paste(_:)), "v"),
                                       ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        editItem.submenu = editMenu
        bar.addItem(editItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        bar.addItem(windowItem)
        NSApp.mainMenu = bar
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboard.stop()
        permissionTimer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if keyboard.launcherVisible, launcherPanel?.isVisible == true {
            launcherPanel?.makeKeyAndOrderFront(nil)
        } else { showSettings() }
        return true
    }

    private func checkPermissions() {
        let granted = AXIsProcessTrusted()
        if granted != model.accessibilityGranted { model.accessibilityGranted = granted }
        if granted {
            let active = keyboard.start()
            if active != model.listenerActive { model.listenerActive = active }
        } else {
            if model.listenerActive { keyboard.stop() }
            if model.listenerActive { model.listenerActive = false }
        }
        updateKeyboard()
    }

    private func updateKeyboard() {
        if keyboard.trigger != model.preferences.trigger {
            keyboard.resetSession()
            keyboard.trigger = model.preferences.trigger
        }
        let enabled = model.accessibilityGranted && model.listenerActive && model.shortcutsAllowed
        if enabled != keyboard.enabled { keyboard.enabled = enabled }
        if statusItem?.button?.appearsDisabled != !enabled { statusItem?.button?.appearsDisabled = !enabled }
        if statusItem?.button?.toolTip != statusText { statusItem?.button?.toolTip = statusText }
        if !keyboard.enabled { hideHints() }
    }

    private var statusText: String {
        if model.isPaused { return "OpenRight is paused" }
        if !model.accessibilityGranted { return "Accessibility permission needed" }
        if !model.listenerActive { return "Keyboard listener unavailable. Check Input Monitoring, then relaunch." }
        if model.conflictingAppRunning && model.preferences.trigger == .rightCommand { return "Quit rcmd or choose another trigger" }
        return "OpenRight is ready"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        addItem("Search apps…", action: #selector(searchFromMenu), to: menu)
        addItem("Settings…", action: #selector(settingsFromMenu), to: menu, key: ",")
        addItem(model.isPaused ? "Resume shortcuts" : "Pause shortcuts", action: #selector(togglePause), to: menu)
        menu.addItem(.separator())
        addItem("Quit OpenRight", action: #selector(quit), to: menu, key: "q")
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func searchFromMenu() { showLauncher() }
    @objc private func settingsFromMenu() { showSettings() }
    @objc private func togglePause() { model.isPaused.toggle(); updateKeyboard() }
    @objc private func quit() { NSApp.terminate(nil) }

    func showSettings() {
        dismissLauncher()
        hideHints()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 650),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OpenRight"
            window.minSize = NSSize(width: 780, height: 600)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func triggerChanged(_ held: Bool) {
        hideHints()
        if held {
            sessionRecentIDs = model.recentIDs
            logicalFrontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            sessionHiddenStates = [:]
            guard model.preferences.showHints, !keyboard.launcherVisible else { return }
            let work = DispatchWorkItem { [weak self] in self?.showHints() }
            hintsWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
        } else {
            sessionRecentIDs = []
            logicalFrontmostID = nil
            sessionHiddenStates = [:]
        }
    }

    func handleKey(_ key: String, assigning: Bool) -> Bool {
        guard !model.preferences.disabledKeys.contains(key) else { return false }
        if assigning {
            guard let focused = NSWorkspace.shared.frontmostApplication,
                  let id = focused.bundleIdentifier,
                  let app = model.runningApps.first(where: { $0.id == id }) else { return false }
            let behavior = model.preferences.repeatBehavior
            DispatchQueue.main.async { [weak self] in self?.model.pin(key: key, app: app, behavior: behavior) }
            return true
        }
        let candidates = model.runningApps.map { app -> AppCandidate in
            var app = app
            if let hidden = sessionHiddenStates[app.id] { app.isHidden = hidden }
            return app
        }
        let action = ShortcutResolver.action(for: key, candidates: candidates,
                                              frontmostID: logicalFrontmostID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                                              recentIDs: sessionRecentIDs, preferences: model.preferences)
        guard action != .none else { return false }
        switch action {
        case .activate(let app):
            logicalFrontmostID = app.id
            sessionHiddenStates[app.id] = false
        case .launch(let binding): logicalFrontmostID = binding.bundleID
        case .hide(let app):
            logicalFrontmostID = ""
            sessionHiddenStates[app.id] = true
        case .none: break
        }
        // Keep expensive activation and disk writes out of the event tap callback.
        DispatchQueue.main.async { [weak self] in self?.model.perform(action) }
        return true
    }

    private func showHints() {
        guard keyboard.enabled, keyboard.isTriggerHeld, !keyboard.launcherVisible else { return }
        if hintsPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 390),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: HintsView(model: model))
            hintsPanel = panel
        }
        if let view = hintsPanel?.contentView { hintsPanel?.setContentSize(view.fittingSize) }
        hintsPanel?.center()
        hintsPanel?.orderFrontRegardless()
    }

    private func hideHints() {
        hintsWork?.cancel()
        hintsWork = nil
        hintsPanel?.orderOut(nil)
    }

    func showLauncher() {
        hideHints()
        keyboard.launcherVisible = true
        model.searchQuery = ""
        model.selectedSearchIndex = 0
        if launcherPanel == nil {
            let panel = LauncherPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 510),
                                      styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            panel.title = "Search apps"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.delegate = self
            launcherPanel = panel
        }
        // A fresh field gets first responder on every invocation, including
        // after dismissing with a button or activating a previous result.
        let content = NSHostingView(rootView: LauncherView(model: model, onDismiss: { [weak self] in self?.dismissLauncher() }))
        launcherPanel?.contentView = content
        launcherPanel?.setContentSize(content.fittingSize)
        launcherPanel?.center()
        NSApp.activate(ignoringOtherApps: true)
        launcherPanel?.makeKeyAndOrderFront(nil)
    }

    func dismissLauncher() {
        launcherPanel?.orderOut(nil)
        keyboard.launcherVisible = false
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === launcherPanel { dismissLauncher() }
    }
}
