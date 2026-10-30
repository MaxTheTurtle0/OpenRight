import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI
import OpenRightCore

struct AppShortcutGroup: Identifiable {
    let key: String
    var apps: [AppCandidate]
    var id: String { key }
}

struct AppShortcutSnapshot {
    let groups: [AppShortcutGroup]
    let unassigned: [AppCandidate]
}

@MainActor
final class AppModel: ObservableObject {
    let updates = UpdateService()
    @Published var preferences = Preferences()
    @Published var runningApps: [AppCandidate] = []
    @Published var installedApps: [AppCandidate] = []
    @Published var recentIDs: [String] = []
    @Published var isPaused = false
    @Published var accessibilityGranted = false
    @Published var listenerActive = false
    @Published var conflictingAppRunning = false
    @Published var statusMessage = ""
    @Published var searchQuery = ""
    @Published var selectedSearchIndex = 0
    var openSettings: (() -> Void)?
    var showLauncher: (() -> Void)?
    var preferencesDidChange: (() -> Void)?
    var didActivate: (() -> Void)?

    private let preferencesURL: URL
    private let applicationScanner: @Sendable () -> [AppCandidate]
    private var savedPreferences: Preferences?
    private var installedCatalog: [AppCandidate] = []
    private var observers: [NSObjectProtocol] = []
    private var scanTask: Task<Void, Never>?

    init(preferencesURL: URL? = nil,
         applicationScanner: @escaping @Sendable () -> [AppCandidate] = { AppModel.scanInstalledApplications() }) {
        self.preferencesURL = preferencesURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenRight/preferences.json")
        self.applicationScanner = applicationScanner
        loadPreferences()
        let loginStatus = SMAppService.mainApp.status
        preferences.launchAtLogin = loginStatus == .enabled || loginStatus == .requiresApproval
        refreshApplications()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let activatedID = note.name == NSWorkspace.didActivateApplicationNotification
                    ? (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier : nil
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let id = activatedID { self.recordActivation(id) }
                    self.refreshRunningApps()
                }
            })
        }
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier { recentIDs = [id] }
    }

    deinit {
        scanTask?.cancel()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    var searchResults: [AppCandidate] {
        SearchMatcher.search(searchQuery, in: installedApps, recentIDs: recentIDs)
    }

    var shortcutApps: [AppCandidate] {
        var apps = Dictionary(runningApps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for binding in preferences.bindings where apps[binding.bundleID] == nil {
            apps[binding.bundleID] = installedApps.first { $0.id == binding.bundleID }
                ?? AppCandidate(id: binding.bundleID, name: binding.name, path: binding.path, isRunning: false)
        }
        return apps.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var shortcutSnapshot: AppShortcutSnapshot {
        let preferences = preferences.sanitized()
        let pinnedIDs = Set(preferences.bindings.filter { !preferences.disabledKeys.contains($0.key) }.map(\.bundleID))
        let automaticKeys = runningApps.filter { !pinnedIDs.contains($0.id) }.compactMap { ShortcutKey.initial(for: $0.name) }
        let keys = Set(preferences.bindings.map(\.key) + automaticKeys)
        let apps = shortcutApps
        let groups = keys.sorted().compactMap { key -> AppShortcutGroup? in
            let targets = ShortcutResolver.targets(for: key, candidates: apps, recentIDs: recentIDs, preferences: preferences)
            return targets.isEmpty ? nil : AppShortcutGroup(key: key, apps: targets)
        }
        let groupedIDs = Set(groups.flatMap(\.apps).map(\.id))
        return AppShortcutSnapshot(groups: groups, unassigned: apps.filter { !groupedIDs.contains($0.id) })
    }

    var shortcutGroups: [AppShortcutGroup] {
        shortcutSnapshot.groups
    }

    var appsWithoutShortcut: [AppCandidate] {
        shortcutSnapshot.unassigned
    }

    var shortcutsAllowed: Bool {
        !isPaused && !(conflictingAppRunning && preferences.trigger == .rightCommand)
    }

    func loadPreferences() {
        savedPreferences = nil
        guard FileManager.default.fileExists(atPath: preferencesURL.path) else { return }
        do {
            let loaded = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: preferencesURL)).sanitized()
            if preferences != loaded { preferences = loaded }
            savedPreferences = loaded
        } catch {
            statusMessage = "Could not read preferences. Your file was kept; defaults are active."
        }
    }

    func savePreferences() {
        let sanitized = preferences.sanitized()
        if preferences != sanitized { preferences = sanitized }
        do {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: preferencesURL.path, isDirectory: &isDirectory)
            if savedPreferences != sanitized || !exists || isDirectory.boolValue {
                try FileManager.default.createDirectory(at: preferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(sanitized).write(to: preferencesURL, options: .atomic)
                savedPreferences = sanitized
            }
            if !statusMessage.isEmpty { statusMessage = "" }
        } catch {
            let message = "Could not save preferences: \(error.localizedDescription)"
            if statusMessage != message { statusMessage = message }
        }
        preferencesDidChange?()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        if !accessibilityGranted { openAccessibilitySettings() }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshRunningApps() {
        let applications = NSWorkspace.shared.runningApplications
        let apps = applications.compactMap { app -> AppCandidate? in
            guard app.activationPolicy == .regular, !app.isTerminated,
                  let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier,
                  let url = app.bundleURL else { return nil }
            return AppCandidate(id: id, name: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
                                path: url.path, isRunning: true, isHidden: app.isHidden)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let conflict = applications.contains { $0.bundleIdentifier == "com.lowtechguys.rcmd" && !$0.isTerminated }
        updateRunningApps(apps, conflictingAppRunning: conflict)
    }

    func updateRunningApps(_ apps: [AppCandidate], conflictingAppRunning conflict: Bool) {
        if conflictingAppRunning != conflict { conflictingAppRunning = conflict }
        guard runningApps != apps else { return }
        runningApps = apps
        mergeCatalog()
    }

    func recordActivation(_ id: String) {
        guard id != Bundle.main.bundleIdentifier else { return }
        var updated = recentIDs.filter { $0 != id }
        updated.insert(id, at: 0)
        if updated != recentIDs { recentIDs = updated }
    }

    func refreshApplications() {
        refreshRunningApps()
        scanTask?.cancel()
        let scanner = applicationScanner
        scanTask = Task.detached(priority: .utility) { [weak self] in
            guard !Task.isCancelled else { return }
            let catalog = scanner()
            guard !Task.isCancelled else { return }
            await self?.acceptInstalledCatalog(catalog)
        }
    }

    private func acceptInstalledCatalog(_ catalog: [AppCandidate]) {
        guard !Task.isCancelled, installedCatalog != catalog else { return }
        installedCatalog = catalog
        mergeCatalog()
    }

    nonisolated static func scanInstalledApplications() -> [AppCandidate] {
        let roots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
                     URL(fileURLWithPath: "/System/Applications"), URL(fileURLWithPath: "/System/Library/CoreServices/Applications")]
        var result: [String: AppCandidate] = [:]
        for root in roots {
            guard !Task.isCancelled else { return [] }
            guard let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                                                options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in iterator {
                guard !Task.isCancelled else { return [] }
                guard url.pathExtension.lowercased() == "app" else { continue }
                iterator.skipDescendants()
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, id != "org.openright.app", result[id] == nil,
                      !(bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool ?? false),
                      !(bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool ?? false) else { continue }
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                result[id] = AppCandidate(id: id, name: name, path: url.path, isRunning: false)
            }
        }
        guard !Task.isCancelled else { return [] }
        return result.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func mergeCatalog() {
        var apps = Dictionary(installedCatalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for app in runningApps { apps[app.id] = app }
        let merged = apps.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if merged != installedApps { installedApps = merged }
    }

    func activate(_ app: AppCandidate) {
        // A normal open also sends a reopen request to an existing process,
        // letting apps restore a minimized window or create one after the last closes.
        launch(path: app.path, name: app.name, bundleID: app.id)
        didActivate?()
    }

    func launch(path: String, name: String, bundleID: String) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first(where: { !$0.isTerminated })
        let url = running?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) ?? URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path), Bundle(url: url)?.bundleIdentifier == bundleID else {
            statusMessage = "\(name) is no longer at its saved location. Assign it again in Apps."
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async { self?.statusMessage = "Could not open \(name): \(error.localizedDescription)" }
        }
    }

    func perform(_ action: ShortcutAction) {
        switch action {
        case .activate(let app): activate(app)
        case .launch(let binding): launch(path: binding.path, name: binding.name, bundleID: binding.bundleID)
        case .hide(let app): NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first?.hide()
        case .none: break
        }
    }

    func pin(key: String, app: AppCandidate, behavior: RepeatBehavior) {
        guard let key = ShortcutKey.normalized(key) else { statusMessage = "Choose one letter or digit for a pin."; return }
        preferences.setBinding(AppBinding(key: key, bundleID: app.id, name: app.name, path: app.path, behavior: behavior))
        savePreferences()
        statusMessage = "\(key.uppercased()) assigned to \(app.name)"
    }

    func removeBinding(_ key: String) {
        preferences.bindings.removeAll { $0.key == key }
        savePreferences()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            preferences.launchAtLogin = enabled
            savePreferences()
            if SMAppService.mainApp.status == .requiresApproval { statusMessage = "Allow OpenRight in System Settings > General > Login Items." }
        } catch {
            preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
            statusMessage = "Could not change login startup: \(error.localizedDescription)"
        }
    }

    func restoreDefaults() {
        if preferences.launchAtLogin { setLaunchAtLogin(false) }
        let loginState = SMAppService.mainApp.status == .enabled
        preferences = Preferences()
        preferences.launchAtLogin = loginState
        savePreferences()
    }
}
