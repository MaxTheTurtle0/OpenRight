import AppKit
import SwiftUI
import OpenRightCore

@MainActor
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var section: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch section {
                case .general:
                    ScrollView { general.padding(18).frame(maxWidth: .infinity, alignment: .leading) }
                case .apps:
                    AppsSettingsView(model: model).padding(18)
                case .about:
                    ScrollView { about.padding(18).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 660, idealWidth: 720, minHeight: 440, idealHeight: 560)
        .tint(.teal)
        .onChange(of: model.preferences) { _ in model.savePreferences() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { item in
                    Button { section = item } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.system(size: 13, weight: section == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(section == item ? Color.teal.opacity(0.14) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-\(item.id)")
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }
            .padding(.top, 12)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(model.isPaused ? "Shortcuts paused" : !model.shortcutsAllowed ? "Trigger unavailable" : model.listenerActive ? "Shortcuts active" : "Setup needed")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 4).padding(.bottom, 14)
        }
        .padding(.horizontal, 10)
        .frame(width: 148)
        .background(.thinMaterial)
    }

    private var statusColor: Color {
        model.isPaused || !model.shortcutsAllowed ? .orange : model.listenerActive ? .teal : .secondary
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.accessibilityGranted || !model.listenerActive || (model.conflictingAppRunning && model.preferences.trigger == .rightCommand) {
                setupCard
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    settingRow("Trigger", detail: "Hold this modifier and press an app's key.") {
                        Picker("Trigger", selection: $model.preferences.trigger) {
                            ForEach(Trigger.allCases, id: \.self) { trigger in Text(triggerTitle(trigger)).tag(trigger) }
                        }
                        .labelsHidden().frame(width: 172)
                        .accessibilityIdentifier("trigger-picker")
                    }
                    Divider()
                    settingRow("Repeat key", detail: "Choose what happens when the matching app is already active.") {
                        Picker("Repeat behavior", selection: $model.preferences.repeatBehavior) {
                            Text("Cycle matching apps").tag(RepeatBehavior.cycle)
                            Text("Hide the active app").tag(RepeatBehavior.hide)
                        }
                        .labelsHidden().frame(width: 172)
                        .accessibilityIdentifier("repeat-picker")
                    }
                    Divider()
                    settingRow("Disabled keys", detail: "These letters and numbers keep their usual shortcuts.") {
                        TextField("For example, qw", text: $model.preferences.disabledKeys)
                            .textFieldStyle(.roundedBorder).frame(width: 172)
                            .accessibilityIdentifier("disabled-keys")
                    }
                    if model.accessibilityGranted {
                        Divider()
                        Toggle("Pause shortcuts", isOn: $model.isPaused)
                            .toggleStyle(.switch).accessibilityIdentifier("pause-toggle")
                    }
                }
            }
            SettingsCard {
                Toggle("Start at login", isOn: Binding(get: { model.preferences.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch).accessibilityIdentifier("login-toggle")
            }
            UpdatesSettingsView(service: model.updates)
            HStack {
                Button("Search apps…") { model.showLauncher?() }
                Spacer()
                Text("\(triggerTitle(model.preferences.trigger)) + Space")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if !model.statusMessage.isEmpty {
                Text(model.statusMessage).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 13))
    }

    private var setupCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                if !model.accessibilityGranted {
                    Text("Enable Accessibility to use global shortcuts.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack {
                        Button("Enable Accessibility", action: model.requestAccessibility)
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("enable-accessibility")
                        Button("Open System Settings", action: model.openAccessibilitySettings)
                    }
                }
                if model.conflictingAppRunning && model.preferences.trigger == .rightCommand {
                    Label("rcmd is running. Quit it or choose another trigger to use OpenRight.", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("conflicting-app-warning")
                }
                if model.accessibilityGranted && !model.listenerActive {
                    Label("The keyboard listener could not start. Check Input Monitoring in System Settings, then relaunch OpenRight.", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "command.square.fill").font(.system(size: 32)).foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("OpenRight").font(.headline)
                            Text(appVersionDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Text("Independent implementation. MIT licensed.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Link("Source code", destination: URL(string: "https://github.com/MaxTheTurtle0/OpenRight")!)
                        Link("Release notes", destination: URL(string: "https://github.com/MaxTheTurtle0/OpenRight/releases")!)
                    }
                    .font(.system(size: 12))
                }
            }
            SettingsCard {
                Text("OpenRight does not record typed text or collect analytics. Settings and pins stay on this Mac. Update checks and downloads contact GitHub.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Restore default settings", action: model.restoreDefaults)
                .accessibilityIdentifier("restore-defaults")
        }
    }

    private func settingRow<Content: View>(_ title: String, detail: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 13, weight: .medium)).help(detail)
            Spacer(minLength: 6)
            control()
        }
    }
}

@MainActor
private struct UpdatesSettingsView: View {
    @ObservedObject var service: UpdateService

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Updates").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(appVersionDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { service.automaticallyChecksForUpdates },
                    set: { service.setAutomaticallyChecksForUpdates($0) }
                ))
                .font(.system(size: 13)).toggleStyle(.switch)
                .disabled(!service.isConfigured).accessibilityIdentifier("automatic-update-checks")
                HStack {
                    Button("Check for Updates…", action: service.checkForUpdates)
                        .disabled(!service.canCheckForUpdates).accessibilityIdentifier("check-for-updates")
                    if service.isConfigured && !service.canCheckForUpdates {
                        Text("Checking…").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if !service.isConfigured {
                    Text(service.statusDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private var appVersionDescription: String {
    guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
        return "Development build"
    }
    return "Version \(version)"
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", apps = "Apps", about = "About"
    var id: String { rawValue.lowercased().replacingOccurrences(of: " ", with: "-") }
    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .apps: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }

}

@MainActor
struct AppsSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var addingPin = false

    var body: some View {
        let snapshot = model.shortcutSnapshot
        let filter = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredKey = ShortcutKey.normalized(filter).flatMap { key in
            snapshot.groups.contains(where: { $0.key == key }) ? key : nil
        }
        let groups = snapshot.groups.compactMap { group -> AppShortcutGroup? in
            if let filteredKey { return group.key == filteredKey ? group : nil }
            if filter.isEmpty || group.key.localizedCaseInsensitiveContains(filter) { return group }
            let apps = group.apps.filter { $0.name.localizedCaseInsensitiveContains(filter) }
            return apps.isEmpty ? nil : AppShortcutGroup(key: group.key, apps: apps)
        }
        let unassigned = filteredKey == nil
            ? snapshot.unassigned.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
            : []
        let lastGroupID = groups.last?.id
        let hasUnassigned = !unassigned.isEmpty

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Filter apps or keys", text: $query)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("apps-filter")
                Button("Add pin…") { addingPin = true }
                    .accessibilityIdentifier("add-app-pin")
                    .popover(isPresented: $addingPin) { AppKeysEditor(model: model) }
                Button(action: model.refreshApplications) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Refresh apps")
                    .accessibilityLabel("Refresh apps").accessibilityIdentifier("refresh-apps")
            }
            .controlSize(.small)
            ScrollView {
                if groups.isEmpty && !hasUnassigned {
                    Text(filter.isEmpty ? "No apps yet. Add a pin or refresh." : "No apps match your search.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    SettingsCard(padding: 12) {
                        VStack(spacing: 0) {
                            ForEach(groups) { group in
                                HStack(alignment: .top, spacing: 12) {
                                    KeyCap(key: group.key.uppercased()).frame(width: 32).padding(.top, 4)
                                        .accessibilityLabel("Shortcut \(group.key.uppercased())")
                                        .accessibilityIdentifier("shortcut-group-\(group.key)")
                                    VStack(spacing: 0) {
                                        ForEach(group.apps) { app in AppSettingsRow(model: model, app: app) }
                                    }
                                }
                                .padding(.vertical, 4)
                                if group.id != lastGroupID || hasUnassigned { Divider() }
                            }
                            if hasUnassigned {
                                HStack(alignment: .top, spacing: 12) {
                                    Text("No key").font(.system(size: 10)).foregroundStyle(.secondary)
                                        .frame(width: 32).padding(.top, 9)
                                        .accessibilityIdentifier("apps-without-key")
                                    VStack(spacing: 0) {
                                        ForEach(unassigned) { app in AppSettingsRow(model: model, app: app) }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }
}

@MainActor
private struct AppSettingsRow: View {
    @ObservedObject var model: AppModel
    var app: AppCandidate
    @State private var editingKeys = false

    private var bindings: [AppBinding] {
        model.preferences.bindings.filter { $0.bundleID == app.id }.sorted { $0.key < $1.key }
    }

    var body: some View {
        let bindings = self.bindings
        return HStack(spacing: 8) {
            Button { model.activate(app) } label: {
                HStack(spacing: 9) {
                    AppIcon(path: app.path, size: 22)
                    Text(app.name).font(.system(size: 13)).lineLimit(1)
                    if !app.isRunning {
                        Text("Closed").font(.system(size: 10)).foregroundStyle(.secondary)
                    } else if app.isHidden {
                        Text("Hidden").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Open \(app.name)")
            .accessibilityLabel("Open \(app.name)")
            .accessibilityValue(!app.isRunning ? "Closed" : app.isHidden ? "Hidden" : "Running")
            .accessibilityIdentifier("app-open-\(app.id)")
            Button { editingKeys = true } label: {
                Image(systemName: bindings.isEmpty ? "pin" : "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(bindings.isEmpty ? Color.secondary : Color.teal)
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Manage keys for \(app.name)")
            .accessibilityLabel("Manage keys for \(app.name)")
            .accessibilityValue(bindings.isEmpty ? "No pinned keys" : "Pinned keys \(bindings.map { $0.key.uppercased() }.joined(separator: ", "))")
            .accessibilityIdentifier("app-keys-\(app.id)")
            .popover(isPresented: $editingKeys) { AppKeysEditor(model: model, app: app) }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
struct AppKeysEditor: View {
    @ObservedObject var model: AppModel
    var app: AppCandidate? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var appQuery = ""
    @State private var selectedAppID = ""
    @State private var key = ""
    @State private var behavior = RepeatBehavior.cycle

    private var filteredApps: [AppCandidate] {
        let query = appQuery
        return Array(model.installedApps.lazy.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }.prefix(100))
    }
    private var selectedApp: AppCandidate? { app ?? model.installedApps.first { $0.id == selectedAppID } }

    var body: some View {
        let selectedApp = self.selectedApp
        let normalizedKey = ShortcutKey.normalized(key.trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        let existingPin = model.preferences.bindings.first { $0.key == normalizedKey }
        let bindings = selectedApp.map { selected in
            model.preferences.bindings.filter { $0.bundleID == selected.id }.sorted { $0.key < $1.key }
        } ?? []

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let app {
                    AppIcon(path: app.path, size: 24)
                    Text(app.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                } else {
                    Text("Add a pinned key").font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if app == nil {
                if let selectedApp {
                    HStack(spacing: 10) {
                        AppIcon(path: selectedApp.path, size: 24)
                        Text(selectedApp.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Spacer()
                        Button("Change app") { selectedAppID = "" }
                    }
                } else {
                    let filteredApps = self.filteredApps
                    TextField("Find an installed app", text: $appQuery)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("pin-app-filter")
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if filteredApps.isEmpty {
                                Text("No installed apps match your search.")
                                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(8)
                            }
                            ForEach(filteredApps) { candidate in
                                Button { selectedAppID = candidate.id } label: {
                                    HStack(spacing: 9) {
                                        AppIcon(path: candidate.path, size: 22)
                                        Text(candidate.name).font(.system(size: 13)).lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(7).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Select \(candidate.name)")
                                .accessibilityIdentifier("pin-select-\(candidate.id)")
                            }
                        }
                    }
                    .frame(height: min(CGFloat(max(filteredApps.count, 1)) * 38, 190))
                }
            }
            if !bindings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pinned keys").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(bindings) { binding in
                                HStack(spacing: 10) {
                                    KeyCap(key: binding.key.uppercased())
                                    Spacer()
                                    Picker("Repeat for \(binding.key.uppercased()) in \(binding.name)", selection: Binding(
                                        get: { model.preferences.bindings.first { $0.key == binding.key }?.behavior ?? .cycle },
                                        set: { value in
                                            guard let index = model.preferences.bindings.firstIndex(where: { $0.key == binding.key }) else { return }
                                            model.preferences.bindings[index].behavior = value
                                        }
                                    )) {
                                        Text("Cycle").tag(RepeatBehavior.cycle)
                                        Text("Hide").tag(RepeatBehavior.hide)
                                    }
                                    .labelsHidden().frame(width: 100)
                                    Button { model.removeBinding(binding.key) } label: { Image(systemName: "minus.circle") }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel("Remove \(binding.key.uppercased()) pin for \(binding.name)")
                                }
                                .frame(height: 38)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(bindings.count) * 38, 190))
                }
                Divider()
            }
            HStack(spacing: 10) {
                TextField("Key", text: $key)
                    .textFieldStyle(.roundedBorder).frame(width: 50)
                    .accessibilityLabel("Pinned letter or number")
                    .accessibilityIdentifier("pin-key")
                Picker("Repeat", selection: $behavior) {
                    Text("Cycle").tag(RepeatBehavior.cycle)
                    Text("Hide").tag(RepeatBehavior.hide)
                }
                .frame(width: 150)
                Spacer(minLength: 0)
                Button(existingPin == nil ? "Add pin" : "Replace pin") {
                    guard let app = selectedApp, !normalizedKey.isEmpty else { return }
                    model.pin(key: normalizedKey, app: app, behavior: behavior)
                    key = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(normalizedKey.isEmpty || selectedApp == nil)
                .accessibilityIdentifier("add-pin")
            }
            if let existingPin, existingPin.bundleID != selectedApp?.id {
                Text("\(normalizedKey.uppercased()) is pinned to \(existingPin.name). Replacing it moves that key to the selected app.")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Use one letter or number. A pinned key works even when the app is closed.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 400)
        .onChange(of: appQuery) { _ in
            if !selectedAppID.isEmpty && !filteredApps.contains(where: { $0.id == selectedAppID }) { selectedAppID = "" }
        }
    }
}

@MainActor
struct LauncherView: View {
    @ObservedObject var model: AppModel
    var onDismiss: () -> Void

    private var results: [AppCandidate] { Array(model.searchResults.prefix(100)) }

    var body: some View {
        let results = self.results
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 21)).foregroundStyle(.teal)
                LauncherSearchField(text: $model.searchQuery, onMove: moveSelection, onSubmit: activateSelection, onDismiss: onDismiss)
                    .frame(height: 32)
                    .accessibilityIdentifier("launcher-search")
                Button(action: onDismiss) {
                    KeyCap(key: "esc")
                }
                .buttonStyle(.plain).accessibilityLabel("Close app search")
            }
            .padding(22)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if results.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass").font(.system(size: 25))
                                Text("No matching apps").font(.system(size: 14, weight: .medium))
                                Text("Try a shorter name or another spelling.").font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, app in
                                Button { activateResult(app) } label: {
                                    HStack(spacing: 12) {
                                        AppIcon(path: app.path, size: 36)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(app.name).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                                            Text(app.isRunning ? "Running" : "Launch app")
                                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if index == model.selectedSearchIndex {
                                            Image(systemName: "return").font(.system(size: 13)).foregroundStyle(.teal)
                                        }
                                    }
                                    .padding(.horizontal, 13).padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(index == model.selectedSearchIndex ? Color.teal.opacity(0.13) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(app.id)
                                .accessibilityLabel("\(app.name), \(app.isRunning ? "running" : "launch app")")
                                .accessibilityAddTraits(index == model.selectedSearchIndex ? .isSelected : [])
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 342)
                .onChange(of: model.selectedSearchIndex) { value in
                    guard results.indices.contains(value) else { return }
                    proxy.scrollTo(results[value].id, anchor: .center)
                }
            }
            Divider()
            HStack(spacing: 7) {
                Text("↑ ↓").font(.system(size: 11, weight: .medium, design: .monospaced))
                Text("select").font(.system(size: 11)).foregroundStyle(.secondary)
                KeyCap(key: "return")
                Text("open").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("\(results.count) app\(results.count == 1 ? "" : "s")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .frame(width: 590)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
        .tint(.teal)
        .onAppear(perform: resetSelection)
        .onChange(of: model.searchQuery) { _ in resetSelection() }
        .onExitCommand(perform: onDismiss)
    }

    private func moveSelection(_ delta: Int) {
        let results = self.results
        guard !results.isEmpty else { resetSelection(); return }
        let index = min(max(model.selectedSearchIndex + delta, 0), results.count - 1)
        if index != model.selectedSearchIndex { model.selectedSearchIndex = index }
    }

    private func activateSelection() {
        let results = self.results
        guard results.indices.contains(model.selectedSearchIndex) else { return }
        activateResult(results[model.selectedSearchIndex])
    }

    private func resetSelection() {
        if model.selectedSearchIndex != 0 { model.selectedSearchIndex = 0 }
    }

    private func activateResult(_ app: AppCandidate) {
        onDismiss()
        model.activate(app)
    }
}

/// NSTextField's editing delegate handles the vertical arrows before the field
/// editor consumes them, while ordinary text editing keeps its native behavior.
@MainActor
private struct LauncherSearchField: NSViewRepresentable {
    @Binding var text: String
    var onMove: (Int) -> Void
    var onSubmit: () -> Void
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SearchField {
        let field = SearchField()
        field.delegate = context.coordinator
        field.placeholderString = "Search apps"
        field.font = .systemFont(ofSize: 23, weight: .medium)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.setAccessibilityLabel("Search apps")
        field.setAccessibilityIdentifier("launcher-search")
        return field
    }

    func updateNSView(_ field: SearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    final class SearchField: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.window === window else { return }
                window.makeFirstResponder(self)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LauncherSearchField
        init(_ parent: LauncherSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch NSStringFromSelector(selector) {
            case "moveDown:": parent.onMove(1)
            case "moveUp:": parent.onMove(-1)
            case "insertNewline:": parent.onSubmit()
            case "cancelOperation:": parent.onDismiss()
            default: return false
            }
            return true
        }
    }
}

private struct SettingsCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))
    }
}

private struct KeyCap: View {
    var key: String
    var body: some View {
        Text(key)
            .font(.system(size: key.count > 1 ? 10 : 13, weight: .semibold, design: .monospaced))
            .padding(.horizontal, key.count > 1 ? 7 : 0)
            .frame(minWidth: 25, minHeight: 25)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.08)))
    }
}

private struct AppIcon: View {
    var path: String
    var size: CGFloat
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private func triggerTitle(_ trigger: Trigger) -> String {
    switch trigger {
    case .rightCommand: return "Right Command ⌘"
    case .rightOption: return "Right Option ⌥"
    case .controlOption: return "Control + Option ⌃⌥"
    }
}

private func firstKey(_ name: String) -> String {
    ShortcutKey.initial(for: name) ?? ""
}
