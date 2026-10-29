import AppKit
import Combine
import Sparkle

/// Sparkle owns update preferences and archive verification. This adapter only
/// publishes the state needed by the menu and settings window.
@MainActor
final class UpdateService: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isConfigured = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var statusDescription = "Updates are unavailable in this development build."

    private var controller: SPUStandardUpdaterController?
    private var subscriptions = Set<AnyCancellable>()

    func startIfConfigured(bundle: Bundle = .main) {
        guard controller == nil else { return }
        guard UpdateConfiguration(bundleURL: bundle.bundleURL, info: bundle.infoDictionary ?? [:]) != nil else {
            statusDescription = "Updates are unavailable in this development build."
            return
        }

        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        isConfigured = true
        statusDescription = "Check GitHub for signed updates to OpenRight."

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] available in
                self?.canCheckForUpdates = available
                self?.statusDescription = available
                    ? "Check GitHub for signed updates to OpenRight."
                    : "An update check is in progress."
            }
            .store(in: &subscriptions)

        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$automaticallyChecksForUpdates)

        // Sparkle keeps its first-launch consent and previously saved choices.
        // No preference setters run here.
        controller.startUpdater()
    }

    func checkForUpdates() {
        guard canCheckForUpdates, let controller else { return }
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard let controller else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }
}

struct UpdateConfiguration {
    let feedURL: URL

    init?(bundleURL: URL, info: [String: Any]) {
        guard bundleURL.pathExtension.lowercased() == "app",
              let feed = info["SUFeedURL"] as? String,
              let components = URLComponents(string: feed),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.fragment == nil,
              let url = components.url,
              let publicKey = info["SUPublicEDKey"] as? String,
              let key = Data(base64Encoded: publicKey), key.count == 32 else { return nil }
        feedURL = url
    }
}
