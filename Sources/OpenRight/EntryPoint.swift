import AppKit
import ApplicationServices

@main
struct OpenRightEntryPoint {
@MainActor
static func main() throws {
if CommandLine.arguments.contains("--diagnostics") {
    let catalog = AppModel.scanInstalledApplications()
    let diagnostics: [String: Any] = [
        "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
        "accessibilityGranted": AXIsProcessTrusted(),
        "installedAppCount": catalog.count,
        "runningAppCount": NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.count,
        "rcmdRunning": !NSRunningApplication.runningApplications(withBundleIdentifier: "com.lowtechguys.rcmd").isEmpty,
        "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unbundled"
    ]
    let data = try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
}
}
