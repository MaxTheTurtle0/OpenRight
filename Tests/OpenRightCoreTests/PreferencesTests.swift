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
        let preferences = Preferences(trigger: .rightOption, repeatBehavior: .hide, disabledKeys: "aq", launchAtLogin: true, bindings: [AppBinding(key: "z", bundleID: "mail", name: "Mail", path: "/Mail.app", behavior: .hide)])
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

    func testASCIIShortcutKeysAndInvalidCharacters() {
        for character in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let key = String(character)
            XCTAssertEqual(ShortcutKey.normalized(key), key.lowercased())
        }
        for key in ["!", "@", "[", "`", "{", "\u{0}", "\t", "\n", "\u{7f}", "ab", "1a", "\r\n"] {
            XCTAssertNil(ShortcutKey.normalized(key))
        }
    }

    func testUnicodeShortcutNormalizationRetainsFoundationFolding() {
        let locale = Locale(identifier: "en_US_POSIX")
        for key in ["é", "Ａ", "９", "ß", "İ", "œ", "각", "e\u{20DD}", "👩‍💻", "🇦🇹", "", "éx"] {
            let folded = key.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
                .lowercased(with: locale)
            let expected: String?
            if folded.utf8.count == 1, let byte = folded.utf8.first,
               (97...122).contains(byte) || (48...57).contains(byte) {
                expected = folded
            } else { expected = nil }
            XCTAssertEqual(ShortcutKey.normalized(key), expected, key)
        }
    }
}
