import XCTest
@testable import OpenRightCore

final class SearchMatcherTests: XCTestCase {
    private func app(_ name: String, running: Bool = true, id: String? = nil) -> AppCandidate {
        AppCandidate(id: id ?? name, name: name, path: "/\(name).app", isRunning: running)
    }

    func testSearchRanksExactThenPrefixThenWordThenSubstringThenSubsequence() {
        let names = ["Scaffolding", "My Safari", "Safari Tools", "Fari", "Saf ari", "Fari Kit"]
        let result = SearchMatcher.search("fari", in: names.map { app($0) }).map(\.name)
        XCTAssertEqual(result, ["Fari", "Fari Kit", "My Safari", "Safari Tools", "Saf ari"])
    }

    func testLongPrefixStillOutranksShortSubstring() {
        let prefix = app("Mail " + String(repeating: "x", count: 500))
        let substring = app("Email")
        XCTAssertEqual(SearchMatcher.search("mail", in: [substring, prefix]), [prefix, substring])
    }

    func testFuzzySubsequenceMatchesAcrossWords() {
        let apps = [app("Visual Studio Code"), app("Calendar"), app("Safari")]
        XCTAssertEqual(SearchMatcher.search("vsc", in: apps).map(\.name), ["Visual Studio Code"])
        XCTAssertEqual(SearchMatcher.search("clndr", in: apps).map(\.name), ["Calendar"])
    }

    func testSearchIgnoresCaseAndDiacriticsAndOuterWhitespace() {
        XCTAssertEqual(SearchMatcher.search("  EDITEUR \n", in: [app("Éditeur")]).map(\.name), ["Éditeur"])
    }

    func testEmptySearchPutsRunningAppsThenMostRecentThenName() {
        let apps = [app("Calendar", running: false), app("Safari"), app("Mail"), app("Slack")]
        XCTAssertEqual(SearchMatcher.search("", in: apps, recentIDs: ["Slack", "Safari"]).map(\.name), ["Slack", "Safari", "Mail", "Calendar"])
    }

    func testRunningStateDoesNotOverrideBetterMatch() {
        let apps = [app("Mail", running: false), app("Mail Helper")]
        XCTAssertEqual(SearchMatcher.search("mail", in: apps).map(\.name), ["Mail", "Mail Helper"])
    }

    func testNoMatchReturnsEmptyArray() {
        XCTAssertEqual(SearchMatcher.search("xyz", in: [app("Mail"), app("Safari")]), [])
        XCTAssertEqual(SearchMatcher.search("mail", in: []), [])
    }

    func testDuplicateCandidatesReturnOneResultPerID() {
        let mail = app("Mail")
        XCTAssertEqual(SearchMatcher.search("", in: [mail, mail]), [mail])
    }

    func testDuplicateMRUEntriesDoNotCrashOrChangeFirstRank() {
        let apps = [app("Mail"), app("Safari")]
        XCTAssertEqual(SearchMatcher.search("", in: apps, recentIDs: ["Safari", "Mail", "Safari"]).map(\.name), ["Safari", "Mail"])
    }

    func testFoldedNameTiesUseRecencyThenIdentifier() {
        let accented = app("Éditeur", running: false, id: "z")
        let ascii = app("Editeur", running: false, id: "a")
        XCTAssertEqual(SearchMatcher.search("ED", in: [accented, ascii]), [ascii, accented])
        XCTAssertEqual(SearchMatcher.search("ED", in: [ascii, accented], recentIDs: [accented.id, ascii.id]), [accented, ascii])
        XCTAssertEqual(SearchMatcher.search("", in: [accented, ascii]), [ascii, accented])
    }
}
