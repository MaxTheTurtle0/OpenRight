import Combine
import Foundation
import XCTest
import OpenRightCore
@testable import OpenRight

final class CatalogPerformanceTests: XCTestCase {
    @MainActor
    func testUnchangedWorkspaceSnapshotDoesNotRepublishCatalog() {
        let model = isolatedModel()
        let app = AppCandidate(id: "app.one", name: "One", path: "/One.app")
        model.updateRunningApps([app], conflictingAppRunning: false)
        var runningEvents = 0
        var installedEvents = 0
        var conflictEvents = 0
        var subscriptions = Set<AnyCancellable>()
        model.$runningApps.dropFirst().sink { _ in runningEvents += 1 }.store(in: &subscriptions)
        model.$installedApps.dropFirst().sink { _ in installedEvents += 1 }.store(in: &subscriptions)
        model.$conflictingAppRunning.dropFirst().sink { _ in conflictEvents += 1 }.store(in: &subscriptions)
        defer { subscriptions.forEach { $0.cancel() } }

        model.updateRunningApps([app], conflictingAppRunning: false)
        XCTAssertEqual(runningEvents, 0)
        XCTAssertEqual(installedEvents, 0)
        XCTAssertEqual(conflictEvents, 0)

        model.updateRunningApps([app], conflictingAppRunning: true)
        XCTAssertEqual(runningEvents, 0)
        XCTAssertEqual(installedEvents, 0)
        XCTAssertEqual(conflictEvents, 1)

        var hidden = app
        hidden.isHidden = true
        model.updateRunningApps([hidden], conflictingAppRunning: true)
        XCTAssertEqual(runningEvents, 1)
        XCTAssertEqual(installedEvents, 1)
        XCTAssertEqual(conflictEvents, 1)
        XCTAssertEqual(model.installedApps.first { $0.id == app.id }, hidden)
    }

    @MainActor
    func testActivationPublishesMRUOnceAndSkipsAnUnchangedOrder() {
        let model = isolatedModel()
        model.recentIDs = ["one", "two", "one"]
        var changes: [[String]] = []
        let subscription = model.$recentIDs.dropFirst().sink { changes.append($0) }
        defer { subscription.cancel() }

        model.recordActivation("one")
        model.recordActivation("one")
        model.recordActivation("two")
        XCTAssertEqual(changes, [["one", "two"], ["two", "one"]])
        XCTAssertEqual(model.recentIDs, ["two", "one"])
    }

    @MainActor
    func testReplacingScanCancelsItsWorkerAndPublishesOnlyTheNewCatalog() async {
        let probe = ScanProbe()
        let model = isolatedModel(applicationScanner: { probe.scan() })
        await eventually { probe.state.started }

        model.refreshApplications()
        await eventually {
            probe.state.cancelled && model.installedApps.contains { $0.id == "scan.current" }
        }
        XCTAssertFalse(model.installedApps.contains { $0.id == "scan.obsolete" })
    }

    @MainActor
    func testModelDeinitializationCancelsItsScanWorker() async {
        let probe = ScanProbe()
        var model: AppModel? = isolatedModel(applicationScanner: { probe.scan() })
        await eventually { probe.state.started }
        XCTAssertNotNil(model)
        model = nil
        await eventually { probe.state.cancelled }
    }

    @MainActor
    func testUnchangedPreferencesSkipPhysicalWriteAndRepublishing() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("preferences.json")
        let model = AppModel(preferencesURL: url, applicationScanner: { [] })
        model.preferences = Preferences(disabledKeys: "q")
        model.savePreferences()

        let marker = Date(timeIntervalSince1970: 946_684_800)
        try FileManager.default.setAttributes([.modificationDate: marker], ofItemAtPath: url.path)
        var published = 0
        let subscription = model.$preferences.dropFirst().sink { _ in published += 1 }
        defer { subscription.cancel() }

        model.savePreferences()
        XCTAssertEqual(published, 0)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual(attributes[.modificationDate] as? Date, marker)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url)), model.preferences)
    }

    @MainActor
    func testUnchangedPreferencesRecreateADeletedFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("preferences.json")
        let model = AppModel(preferencesURL: url, applicationScanner: { [] })
        model.preferences = Preferences(disabledKeys: "q")
        model.savePreferences()
        try FileManager.default.removeItem(at: url)

        model.savePreferences()
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url)), model.preferences)
        XCTAssertTrue(model.statusMessage.isEmpty)
    }

    @MainActor
    func testFailedPreferenceWriteCanRetryTheSameValuesWithoutSettings() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blockedParent = directory.appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blockedParent)
        let url = blockedParent.appendingPathComponent("preferences.json")
        let model = AppModel(preferencesURL: url, applicationScanner: { [] })
        model.preferences = Preferences(disabledKeys: "q")
        var callbacks = 0
        model.preferencesDidChange = { callbacks += 1 }
        model.savePreferences()
        XCTAssertTrue(model.statusMessage.hasPrefix("Could not save preferences:"))

        try FileManager.default.removeItem(at: blockedParent)
        model.savePreferences()
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url)), model.preferences)
        XCTAssertTrue(model.statusMessage.isEmpty)
        XCTAssertEqual(callbacks, 2)
    }

    @MainActor
    private func isolatedModel(applicationScanner: @escaping @Sendable () -> [AppCandidate] = { [] }) -> AppModel {
        AppModel(preferencesURL: temporaryDirectory().appendingPathComponent("preferences.json"), applicationScanner: applicationScanner)
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("OpenRightCatalogTests-" + UUID().uuidString)
    }

    @MainActor
    private func eventually(_ condition: @escaping @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = Date().addingTimeInterval(3)
        while !condition() && Date() < deadline && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }
}

/// A cooperative stand-in for filesystem I/O. It records no real app data.
private final class ScanProbe: @unchecked Sendable {
    struct State {
        let started: Bool
        let cancelled: Bool
    }

    private let lock = NSLock()
    private var calls = 0
    private var started = false
    private var cancelled = false

    var state: State {
        lock.lock()
        defer { lock.unlock() }
        return State(started: started, cancelled: cancelled)
    }

    func scan() -> [AppCandidate] {
        lock.lock()
        calls += 1
        let first = calls == 1
        if first { started = true }
        lock.unlock()
        guard first else {
            return [AppCandidate(id: "scan.current", name: "Current", path: "/Current.app", isRunning: false)]
        }

        let deadline = Date().addingTimeInterval(2)
        while !Task.isCancelled && Date() < deadline { Thread.sleep(forTimeInterval: 0.001) }
        lock.lock()
        cancelled = Task.isCancelled
        lock.unlock()
        return [AppCandidate(id: "scan.obsolete", name: "Obsolete", path: "/Obsolete.app", isRunning: false)]
    }
}
