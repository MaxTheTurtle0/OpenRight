import XCTest
@testable import OpenRightCore

final class PreferencesTests: XCTestCase {
    func testMissingFieldsUseDefaults() throws {
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8)), Preferences())
    }

    func testMalformedIndividualFieldsDoNotDiscardValidSettings() throws {
        let json = """
        {"trigger":"bad-trigger","repeatBehavior":"hide","showHints":"oops","launchAtLogin":true,"disabledKeys":42,"bindings":null}
        """
        let result = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertEqual(result.trigger, .rightCommand)
        XCTAssertEqual(result.repeatBehavior, .hide)
        XCTAssertTrue(result.showHints)
        XCTAssertTrue(result.launchAtLogin)
        XCTAssertEqual(result.disabledKeys, "")
        XCTAssertEqual(result.bindings, [])
    }

    func testMalformedBindingDoesNotDiscardOtherBindings() throws {
        let json = """
        {"bindings":[{"key":"m","bundleID":"mail","name":"Mail","path":"/Mail.app","behavior":"hide"},null,42,{"key":"bad"},{"key":"s","bundleID":"safari","name":"Safari","path":"/Safari.app","behavior":"cycle"}]}
        """
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertEqual(preferences.bindings.map(\.key), ["m", "s"])
    }

    func testBindingWithoutRepeatBehaviorUsesCycle() throws {
        let json = """
        {"bindings":[{"key":"m","bundleID":"mail","name":"Mail","path":"/Mail.app"}]}
        """
        let result = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertEqual(result.bindings.first?.behavior, .cycle)
    }

    func testMalformedTopLevelStillThrowsForCallerToHandle() {
        XCTAssertThrowsError(try JSONDecoder().decode(Preferences.self, from: Data("[]".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(Preferences.self, from: Data("not json".utf8)))
    }

    func testRoundTripPreservesSettings() throws {
        let preferences = Preferences(trigger: .rightOption, repeatBehavior: .hide, disabledKeys: "aq", showHints: false, launchAtLogin: true, bindings: [AppBinding(key: "z", bundleID: "mail", name: "Mail", path: "/Mail.app", behavior: .hide)])
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences)), preferences)
    }

    func testLastBindingWinsAndInvalidBindingsAreRemoved() {
        let first = AppBinding(key: "S", bundleID: "safari", name: "Safari", path: "/Safari.app")
        let replacement = AppBinding(key: "s", bundleID: "slack", name: "Slack", path: "/Slack.app")
        let invalid = AppBinding(key: "too long", bundleID: "bad", name: "Bad", path: "/Bad.app")
        let missingID = AppBinding(key: "a", bundleID: "", name: "Missing", path: "/Missing.app")
        let result = Preferences(disabledKeys: "sS!2eÉ", bindings: [first, invalid, missingID, replacement]).sanitized()
        XCTAssertEqual(result.bindings, [replacement])
        XCTAssertEqual(result.disabledKeys, "2es")
    }

    func testSetBindingReplacesExistingKey() {
        var preferences = Preferences(bindings: [AppBinding(key: "m", bundleID: "mail", name: "Mail", path: "/Mail.app")])
        preferences.setBinding(AppBinding(key: "M", bundleID: "music", name: "Music", path: "/Music.app"))
        XCTAssertEqual(preferences.bindings.count, 1)
        XCTAssertEqual(preferences.bindings.first?.bundleID, "music")
        XCTAssertEqual(preferences.bindings.first?.key, "m")
    }

    func testShortcutNormalizationAcceptsOneLetterOrDigitOnly() {
        XCTAssertEqual(ShortcutKey.normalized("A"), "a")
        XCTAssertEqual(ShortcutKey.normalized("É"), "e")
        XCTAssertEqual(ShortcutKey.normalized("９"), "9")
        XCTAssertNil(ShortcutKey.normalized("ab"))
        XCTAssertNil(ShortcutKey.normalized(" "))
        XCTAssertEqual(ShortcutKey.initial(for: "1Password"), "1")
        XCTAssertEqual(ShortcutKey.initial(for: "  Éditeur"), "e")
        XCTAssertNil(ShortcutKey.initial(for: ""))
    }
}
