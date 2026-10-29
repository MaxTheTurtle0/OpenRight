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
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    switch section {
                    case .general: general
                    case .bindings: BindingsEditor(model: model)
                    case .apps: runningApps
                    case .about: about
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 760, idealWidth: 800, minHeight: 570, idealHeight: 640)
        .tint(.teal)
        .onChange(of: model.preferences) { _ in model.savePreferences() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenRight").font(.headline)
                    Text("Your apps, one key away")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)
            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { item in
                    Button { section = item } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.system(size: 13, weight: section == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(section == item ? Color.teal.opacity(0.14) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-\(item.id)")
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(model.isPaused ? "Shortcuts paused" : !model.shortcutsAllowed ? "Trigger unavailable" : model.listenerActive ? "Shortcuts active" : "Setup needed")
                        .font(.system(size: 11, weight: .medium))
                }
                Text("Open source. On your Mac.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).padding(.bottom, 14)
        }
        .padding(.horizontal, 14)
        .frame(width: 190)
        .background(.thinMaterial)
    }

    private var statusColor: Color {
        model.isPaused || !model.shortcutsAllowed ? .orange : model.listenerActive ? .teal : .secondary
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.rawValue).font(.system(size: 27, weight: .bold, design: .rounded))
            Text(section.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            setupCard
            SettingsCard {
                VStack(alignment: .leading, spacing: 18) {
                    settingRow("Trigger", detail: "Hold this modifier and press an app's first letter.") {
                        Picker("Trigger", selection: $model.preferences.trigger) {
                            ForEach(Trigger.allCases, id: \.self) { trigger in
                                Text(triggerTitle(trigger)).tag(trigger)
                            }
                        }
                        .labelsHidden().frame(width: 172)
                        .accessibilityIdentifier("trigger-picker")
                    }
                    Divider()
                    settingRow("Press the same key again", detail: "Choose what happens when the matching app is already active.") {
                        Picker("Repeat behavior", selection: $model.preferences.repeatBehavior) {
                            Text("Cycle matching apps").tag(RepeatBehavior.cycle)
                            Text("Hide the active app").tag(RepeatBehavior.hide)
                        }
                        .labelsHidden().frame(width: 172)
                        .accessibilityIdentifier("repeat-picker")
                    }
                    Divider()
                    Toggle(isOn: $model.preferences.showHints) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Show key hints").font(.system(size: 13, weight: .medium))
                            Text("Hold the trigger for 1 second to see the app list.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("hints-toggle")
                    Divider()
                    settingRow("Disabled keys", detail: "These letters and numbers keep their usual shortcuts.") {
                        TextField("For example, qw", text: $model.preferences.disabledKeys)
                            .textFieldStyle(.roundedBorder).frame(width: 172)
                            .accessibilityIdentifier("disabled-keys")
                    }
                }
            }
            SettingsCard {
                Toggle(isOn: Binding(get: { model.preferences.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Start at login").font(.system(size: 13, weight: .medium))
                        Text("Keep OpenRight available after you restart your Mac.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("login-toggle")
            }
            HStack(spacing: 9) {
                Image(systemName: "space").font(.system(size: 16)).foregroundStyle(.teal)
                Text("\(triggerTitle(model.preferences.trigger)) + Space opens app search.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Try search") { model.showLauncher?() }
            }
        }
    }

    private var setupCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: model.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                        .font(.system(size: 24)).foregroundStyle(model.accessibilityGranted ? Color.teal : Color.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.accessibilityGranted ? "Accessibility is enabled" : "Allow global shortcuts")
                            .font(.system(size: 14, weight: .semibold))
                        Text(model.accessibilityGranted ? model.statusMessage : "macOS needs Accessibility access to recognize and handle shortcuts in other apps.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if !model.accessibilityGranted {
                    HStack {
                        Button("Enable Accessibility", action: model.requestAccessibility)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("enable-accessibility")
                        Button("Open System Settings", action: model.openAccessibilitySettings)
                    }
                }
                if model.conflictingAppRunning && model.preferences.trigger == .rightCommand {
                    Label("rcmd is running. OpenRight's Right Command trigger is suspended. Quit rcmd or choose another trigger here.", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("conflicting-app-warning")
                }
                if model.accessibilityGranted {
                    if !model.listenerActive {
                        Label("The keyboard listener could not start. Check Input Monitoring in System Settings, then relaunch OpenRight.", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Toggle("Pause shortcuts", isOn: $model.isPaused)
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("pause-toggle")
                }
            }
        }
    }

    private var runningApps: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(model.runningApps.count) running apps").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh", action: model.refreshApplications)
                    .accessibilityIdentifier("refresh-apps")
            }
            SettingsCard {
                if model.runningApps.isEmpty {
                    Text("No running apps found. Try Refresh.").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.runningApps.enumerated()), id: \.element.id) { index, app in
                            HStack(spacing: 10) {
                                AppIcon(path: app.path, size: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name).font(.system(size: 13, weight: .medium))
                                    if app.isHidden { Text("Hidden").font(.system(size: 10)).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                KeyCap(key: firstKey(app.name).uppercased())
                                Button("Open") { model.activate(app) }.buttonStyle(.borderless)
                            }
                            .padding(.vertical, 10)
                            if index < model.runningApps.count - 1 { Divider() }
                        }
                    }
                }
            }
            Text("Apps with the same first letter share a key. With cycling enabled, press it again to move between them. Pinned keys take priority.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "command.square.fill").font(.system(size: 54)).foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("OpenRight").font(.system(size: 23, weight: .bold, design: .rounded))
                            Text("An open-source app switcher for macOS.")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    shortcutLine("Letter", "Focus a running app by its first letter.")
                    shortcutLine("Space", "Search installed apps and launch a result.")
                    Text("Hold your selected trigger for these shortcuts. Add \(pinModifier(model.preferences.trigger)) while pressing a letter to pin the frontmost app to that key.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your activity stays on this Mac", systemImage: "lock.shield")
                        .font(.system(size: 13, weight: .semibold))
                    Text("OpenRight does not record typed text, collect analytics, or send app usage to a server. Settings and pinned keys are stored locally.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Independent implementation. MIT licensed.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("Restore default settings", action: model.restoreDefaults)
                .accessibilityIdentifier("restore-defaults")
        }
    }

    private func settingRow<Content: View>(_ title: String, detail: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            control()
        }
    }

    private func shortcutLine(_ key: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            KeyCap(key: key).frame(width: 58)
            Text(detail).font(.system(size: 12))
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", bindings = "Pinned keys", apps = "Running apps", about = "About"
    var id: String { rawValue.lowercased().replacingOccurrences(of: " ", with: "-") }
    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .bindings: return "pin"
        case .apps: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }
    var subtitle: String {
        switch self {
        case .general: return "Choose your shortcut and make it yours."
        case .bindings: return "Give favorite apps a permanent key, even when they aren't running."
        case .apps: return "The apps available through first-letter switching."
        case .about: return "A small app with a simple job."
        }
    }
}

@MainActor
private struct BindingsEditor: View {
    @ObservedObject var model: AppModel
    @State private var appQuery = ""
    @State private var selectedAppID = ""
    @State private var key = ""
    @State private var behavior = RepeatBehavior.cycle

    private var filteredApps: [AppCandidate] {
        Array(model.installedApps.filter { appQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(appQuery) }.prefix(100))
    }
    private var selectedApp: AppCandidate? { model.installedApps.first { $0.id == selectedAppID } }
    private var normalizedKey: String { ShortcutKey.normalized(key.trimmingCharacters(in: .whitespacesAndNewlines)) ?? "" }
    private var validKey: Bool { !normalizedKey.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 13) {
                    Text("Add a pinned key").font(.system(size: 14, weight: .semibold))
                    TextField("Filter installed apps", text: $appQuery)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("pin-app-filter")
                    Picker("App", selection: $selectedAppID) {
                        Text("Choose an app").tag("")
                        ForEach(filteredApps) { app in Text(app.name).tag(app.id) }
                    }
                    .accessibilityIdentifier("pin-app-picker")
                    HStack(alignment: .center, spacing: 12) {
                        TextField("Key", text: $key)
                            .textFieldStyle(.roundedBorder).frame(width: 56)
                            .accessibilityLabel("Pinned letter or number")
                            .accessibilityIdentifier("pin-key")
                        Picker("Repeat", selection: $behavior) {
                            Text("Cycle").tag(RepeatBehavior.cycle)
                            Text("Hide").tag(RepeatBehavior.hide)
                        }
                        Spacer(minLength: 0)
                        Button(model.preferences.bindings.contains { $0.key == normalizedKey } ? "Replace pin" : "Add pin") {
                            if let app = selectedApp, validKey {
                                model.pin(key: normalizedKey, app: app, behavior: behavior)
                                key = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!validKey || selectedApp == nil)
                        .accessibilityIdentifier("add-pin")
                    }
                    Text("Use one letter or number. You can also hold the trigger, add \(pinModifier(model.preferences.trigger)), and press a key to pin the frontmost app.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if model.preferences.bindings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "pin.slash").font(.system(size: 26)).foregroundStyle(.secondary)
                    Text("No pinned keys yet").font(.system(size: 14, weight: .medium))
                    Text("First-letter switching works without any setup.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                SettingsCard {
                    VStack(spacing: 0) {
                        ForEach(Array(model.preferences.bindings.sorted { $0.key < $1.key }.enumerated()), id: \.element.id) { index, binding in
                            HStack(spacing: 10) {
                                KeyCap(key: binding.key.uppercased())
                                AppIcon(path: binding.path, size: 26)
                                Text(binding.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 4)
                                Picker("Repeat for \(binding.name)", selection: Binding(
                                    get: { model.preferences.bindings.first { $0.key == binding.key }?.behavior ?? .cycle },
                                    set: { value in
                                        guard let index = model.preferences.bindings.firstIndex(where: { $0.key == binding.key }) else { return }
                                        model.preferences.bindings[index].behavior = value
                                    }
                                )) {
                                    Text("Cycle").tag(RepeatBehavior.cycle)
                                    Text("Hide").tag(RepeatBehavior.hide)
                                }
                                .labelsHidden().frame(width: 88)
                                Button { model.removeBinding(binding.key) } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(binding.key.uppercased()) pin for \(binding.name)")
                            }
                            .padding(.vertical, 11)
                            if index < model.preferences.bindings.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
        .onChange(of: appQuery) { _ in
            if !filteredApps.contains(where: { $0.id == selectedAppID }) { selectedAppID = "" }
        }
    }
}

@MainActor
struct HintsView: View {
    @ObservedObject var model: AppModel

    private var hints: [HintEntry] {
        let disabled = Set(model.preferences.disabledKeys.lowercased().map(String.init))
        let pinned = Dictionary(model.preferences.bindings.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var groups: [String: [AppCandidate]] = [:]
        for app in model.runningApps { groups[firstKey(app.name), default: []].append(app) }
        let keys = Set(groups.keys).union(pinned.keys).filter { !$0.isEmpty && !disabled.contains($0) }.sorted()
        return keys.compactMap { key in
            if let binding = pinned[key] {
                return HintEntry(key: key, name: binding.name, path: binding.path, detail: "Pinned", pinned: true)
            }
            guard let apps = groups[key], let first = apps.sorted(by: {
                let leftRank = rank($0.id), rightRank = rank($1.id)
                return leftRank == rightRank ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : leftRank < rightRank
            }).first else { return nil }
            return HintEntry(key: key, name: first.name, path: first.path, detail: apps.count > 1 ? "\(apps.count) apps share this key" : "", pinned: false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "command.square.fill").foregroundStyle(.teal)
                Text("OpenRight").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(triggerTitle(model.preferences.trigger)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if hints.isEmpty {
                Text("No app keys available").font(.system(size: 13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                        ForEach(hints) { hint in
                            HStack(spacing: 8) {
                                KeyCap(key: hint.key.uppercased())
                                AppIcon(path: hint.path, size: 25)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(hint.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                    if !hint.detail.isEmpty { Text(hint.detail).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1) }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 7).padding(.horizontal, 6)
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("\(hint.key.uppercased()), \(hint.name), \(hint.detail)")
                        }
                    }
                }
                .frame(height: min(CGFloat((hints.count + 2) / 3) * 57, 300))
            }
            Divider()
            HStack(spacing: 7) {
                KeyCap(key: "Space")
                Text("Search all apps").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("Add \(pinModifier(model.preferences.trigger)) + key to pin").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 650)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
        .tint(.teal)
    }

    private func rank(_ id: String) -> Int { model.recentIDs.firstIndex(of: id) ?? Int.max }
}

private struct HintEntry: Identifiable {
    var key: String
    var name: String
    var path: String
    var detail: String
    var pinned: Bool
    var id: String { key }
}

@MainActor
struct LauncherView: View {
    @ObservedObject var model: AppModel
    var onDismiss: () -> Void

    private var results: [AppCandidate] { Array(model.searchResults.prefix(100)) }

    var body: some View {
        VStack(spacing: 0) {
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
                                .id(index)
                                .accessibilityLabel("\(app.name), \(app.isRunning ? "running" : "launch app")")
                                .accessibilityAddTraits(index == model.selectedSearchIndex ? .isSelected : [])
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 342)
                .onChange(of: model.selectedSearchIndex) { value in
                    proxy.scrollTo(value, anchor: .center)
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
        .onAppear { model.selectedSearchIndex = 0 }
        .onChange(of: model.searchQuery) { _ in model.selectedSearchIndex = 0 }
        .onExitCommand(perform: onDismiss)
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { model.selectedSearchIndex = 0; return }
        model.selectedSearchIndex = min(max(model.selectedSearchIndex + delta, 0), results.count - 1)
    }

    private func activateSelection() {
        guard results.indices.contains(model.selectedSearchIndex) else { return }
        activateResult(results[model.selectedSearchIndex])
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
                guard let self, let window else { return }
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
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
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

private func pinModifier(_ trigger: Trigger) -> String {
    trigger == .rightCommand ? "Option" : "Command"
}
