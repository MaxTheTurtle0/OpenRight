import XCTest
@testable import OpenRightCore

final class ShortcutResolverTests: XCTestCase {
    private let safari = AppCandidate(id: "com.apple.Safari", name: "Safari", path: "/Applications/Safari.app")
    private let slack = AppCandidate(id: "com.tinyspeck.slackmacgap", name: "Slack", path: "/Applications/Slack.app")
    private let signal = AppCandidate(id: "org.whispersystems.signal-desktop", name: "Signal", path: "/Applications/Signal.app")
    private let mail = AppCandidate(id: "com.apple.mail", name: "Mail", path: "/System/Applications/Mail.app")

    func testMostRecentlyUsedMatchingAppWins() {
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari, slack, signal, mail], frontmostID: mail.id, recentIDs: [signal.id, slack.id, safari.id], preferences: Preferences()), .activate(signal))
    }

    func testCycleTraversesEveryMatchingAppAndWraps() {
        let apps = [safari, slack, signal]
        let order = [slack.id, signal.id, safari.id]
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: slack.id, recentIDs: order, preferences: Preferences()), .activate(signal))
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: signal.id, recentIDs: order, preferences: Preferences()), .activate(safari))
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: safari.id, recentIDs: order, preferences: Preferences()), .activate(slack))
    }

    func testCycleSingleAppKeepsItActive() {
        XCTAssertEqual(ShortcutResolver.action(for: "m", candidates: [mail], frontmostID: mail.id, recentIDs: [], preferences: Preferences()), .activate(mail))
    }

    func testHideVisibleFrontmostApp() {
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari, slack], frontmostID: safari.id, recentIDs: [slack.id], preferences: Preferences(repeatBehavior: .hide)), .hide(safari))
    }

    func testHiddenAppIsActivatedInsteadOfHiddenAgain() {
        var hidden = safari
        hidden.isHidden = true
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [hidden], frontmostID: hidden.id, recentIDs: [], preferences: Preferences(repeatBehavior: .hide)), .activate(hidden))
    }

    func testBindingOverridesDynamicMatchingApp() {
        let pin = AppBinding(key: "s", bundleID: mail.id, name: mail.name, path: mail.path)
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari, mail], frontmostID: nil, recentIDs: [safari.id], preferences: Preferences(bindings: [pin])), .activate(mail))
    }

    func testPinnedCycleIncludesNaturalMatchesAndWrapsToPin() {
        let pin = AppBinding(key: "s", bundleID: mail.id, name: mail.name, path: mail.path)
        let preferences = Preferences(bindings: [pin])
        let apps = [mail, safari, slack]
        let recency = [slack.id, safari.id]
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: "unrelated", recentIDs: recency, preferences: preferences), .activate(mail))
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: mail.id, recentIDs: recency, preferences: preferences), .activate(slack))
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: slack.id, recentIDs: recency, preferences: preferences), .activate(safari))
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: apps, frontmostID: safari.id, recentIDs: recency, preferences: preferences), .activate(mail))
    }

    func testPinnedHideActivatesPinFromAnotherMatchingApp() {
        let pin = AppBinding(key: "s", bundleID: mail.id, name: mail.name, path: mail.path, behavior: .hide)
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [mail, safari], frontmostID: safari.id, recentIDs: [], preferences: Preferences(bindings: [pin])), .activate(mail))
    }

    func testBindingLaunchesAppThatIsNotRunning() {
        let pin = AppBinding(key: "m", bundleID: mail.id, name: mail.name, path: mail.path)
        var stopped = mail
        stopped.isRunning = false
        XCTAssertEqual(ShortcutResolver.action(for: "m", candidates: [stopped], frontmostID: nil, recentIDs: [], preferences: Preferences(bindings: [pin])), .launch(pin))
    }

    func testMissingPinnedAppStillProducesLaunchAction() {
        let pin = AppBinding(key: "m", bundleID: mail.id, name: mail.name, path: mail.path)
        XCTAssertEqual(ShortcutResolver.action(for: "m", candidates: [], frontmostID: nil, recentIDs: [], preferences: Preferences(bindings: [pin])), .launch(pin))
    }

    func testPinRepeatBehaviorOverridesGlobalBehavior() {
        let hidePin = AppBinding(key: "s", bundleID: safari.id, name: safari.name, path: safari.path, behavior: .hide)
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari], frontmostID: safari.id, recentIDs: [], preferences: Preferences(repeatBehavior: .cycle, bindings: [hidePin])), .hide(safari))
        var cyclePin = hidePin
        cyclePin.behavior = .cycle
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari], frontmostID: safari.id, recentIDs: [], preferences: Preferences(repeatBehavior: .hide, bindings: [cyclePin])), .activate(safari))
    }

    func testDisabledKeyPreventsPinnedAndDynamicActions() {
        let pin = AppBinding(key: "s", bundleID: safari.id, name: safari.name, path: safari.path)
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari], frontmostID: nil, recentIDs: [], preferences: Preferences(disabledKeys: "S", bindings: [pin])), .none)
    }

    func testUnknownAndInvalidKeysPassThrough() {
        for key in ["x", "", "ss", " ", "⌘", "!"] {
            XCTAssertEqual(ShortcutResolver.action(for: key, candidates: [safari], frontmostID: nil, recentIDs: [], preferences: Preferences()), .none)
        }
    }

    func testCaseAndDiacriticsMatchLetter() {
        let editor = AppCandidate(id: "editor", name: "Éditeur", path: "/Applications/Editor.app")
        XCTAssertEqual(ShortcutResolver.action(for: "E", candidates: [editor], frontmostID: nil, recentIDs: [], preferences: Preferences()), .activate(editor))
    }

    func testStoppedAppsDoNotReceiveDynamicShortcuts() {
        var stopped = safari
        stopped.isRunning = false
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [stopped], frontmostID: nil, recentIDs: [], preferences: Preferences()), .none)
    }

    func testDuplicateCandidatesAndRecencyEntriesAreSafe() {
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [safari, safari, slack], frontmostID: safari.id, recentIDs: [safari.id, slack.id, safari.id], preferences: Preferences()), .activate(slack))
    }

    func testNoRecencyFallsBackToDeterministicNameOrder() {
        XCTAssertEqual(ShortcutResolver.action(for: "s", candidates: [slack, signal, safari], frontmostID: nil, recentIDs: [], preferences: Preferences()), .activate(safari))
    }

    func testTargetsIncludeNaturalMatchesWithTheirOwnAlternatePins() {
        let teams = AppCandidate(id: "teams", name: "Microsoft Teams", path: "/Teams.app")
        let code = AppCandidate(id: "code", name: "T3 Code", path: "/Code.app")
        let tailscale = AppCandidate(id: "tailscale", name: "Tailscale", path: "/Tailscale.app")
        let preferences = Preferences(bindings: [
            AppBinding(key: "t", bundleID: teams.id, name: teams.name, path: teams.path),
            AppBinding(key: "3", bundleID: code.id, name: code.name, path: code.path)
        ])
        XCTAssertEqual(ShortcutResolver.targets(for: "t", candidates: [code, teams, tailscale], recentIDs: [tailscale.id, code.id], preferences: preferences), [teams, tailscale, code])
        XCTAssertEqual(ShortcutResolver.targets(for: "3", candidates: [code, teams, tailscale], recentIDs: [], preferences: preferences), [code])
    }

    func testHidePinAndDisabledKeyLimitTheDisplayedTargets() {
        let binding = AppBinding(key: "s", bundleID: mail.id, name: mail.name, path: mail.path, behavior: .hide)
        var preferences = Preferences(bindings: [binding])
        XCTAssertEqual(ShortcutResolver.targets(for: "s", candidates: [mail, safari, slack], recentIDs: [], preferences: preferences), [mail])
        preferences.disabledKeys = "s"
        XCTAssertTrue(ShortcutResolver.targets(for: "s", candidates: [mail, safari, slack], recentIDs: [], preferences: preferences).isEmpty)
    }

    func testClosedPinIsTheOnlyTargetUntilItLaunches() {
        let binding = AppBinding(key: "s", bundleID: mail.id, name: "Old Mail", path: "/Old/Mail.app")
        var current = mail
        current.isRunning = false
        let preferences = Preferences(bindings: [binding])
        XCTAssertEqual(ShortcutResolver.targets(for: "s", candidates: [current, safari], recentIDs: [], preferences: preferences), [current])
        current.isRunning = true
        XCTAssertEqual(ShortcutResolver.targets(for: "s", candidates: [current, safari], recentIDs: [], preferences: preferences), [current, safari])
    }

    func testPublicResolverEntryPointsStillSanitizeDirtyInputs() {
        let oldPin = AppBinding(key: "S", bundleID: safari.id, name: safari.name, path: safari.path)
        let replacement = AppBinding(key: "ś", bundleID: mail.id, name: mail.name, path: mail.path, behavior: .hide)
        let invalid = AppBinding(key: "too long", bundleID: slack.id, name: slack.name, path: slack.path)
        let preferences = Preferences(disabledKeys: "X!x", bindings: [oldPin, invalid, replacement])
        let apps = [mail, safari, slack]
        XCTAssertEqual(ShortcutResolver.targets(for: "Ｓ", candidates: apps, recentIDs: [], preferences: preferences), [mail])
        XCTAssertEqual(ShortcutResolver.action(for: "Ś", candidates: apps, frontmostID: mail.id, recentIDs: [], preferences: preferences), .hide(mail))
        XCTAssertTrue(ShortcutResolver.targets(for: "X", candidates: apps, recentIDs: [], preferences: preferences).isEmpty)
        XCTAssertEqual(ShortcutResolver.action(for: "X", candidates: apps, frontmostID: nil, recentIDs: [], preferences: preferences), .none)
    }
}
