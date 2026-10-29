import AppKit
import XCTest
@testable import OpenRight

final class UpdateServiceTests: XCTestCase {
    private let appURL = URL(fileURLWithPath: "/Applications/OpenRight.app")
    private var validInfo: [String: Any] {
        ["SUFeedURL": "https://github.com/MaxTheTurtle0/OpenRight/releases/latest/download/appcast.xml",
         "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString()]
    }

    func testReleaseConfigurationAcceptsHTTPSAndEd25519PublicKey() {
        let config = UpdateConfiguration(bundleURL: appURL, info: validInfo)
        XCTAssertEqual(config?.feedURL.host, "github.com")
        XCTAssertEqual(config?.feedURL.scheme, "https")
    }

    func testUnsafeOrMissingFeedsAreRejected() {
        for feed in ["http://github.com/feed.xml", "file:///tmp/feed.xml", "https:///feed.xml",
                     "https://user:password@github.com/feed.xml", "https://github.com/feed.xml#fragment", ""] {
            var info = validInfo
            info["SUFeedURL"] = feed
            XCTAssertNil(UpdateConfiguration(bundleURL: appURL, info: info), feed)
        }
        var info = validInfo
        info.removeValue(forKey: "SUFeedURL")
        XCTAssertNil(UpdateConfiguration(bundleURL: appURL, info: info))
    }

    func testMissingMalformedAndWrongSizedKeysAreRejected() {
        var info = validInfo
        info.removeValue(forKey: "SUPublicEDKey")
        XCTAssertNil(UpdateConfiguration(bundleURL: appURL, info: info))
        for key in ["not-base64", Data(repeating: 1, count: 31).base64EncodedString(),
                    Data(repeating: 1, count: 33).base64EncodedString()] {
            info["SUPublicEDKey"] = key
            XCTAssertNil(UpdateConfiguration(bundleURL: appURL, info: info))
        }
    }

    @MainActor
    func testUnbundledTestsDoNotStartAnUpdaterOrChangeUserPreferences() {
        XCTAssertNil(UpdateConfiguration(bundleURL: URL(fileURLWithPath: "/tmp/OpenRightTests.xctest"), info: validInfo))
        let before = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? NSNumber
        let service = UpdateService()
        service.startIfConfigured(bundle: Bundle(for: Self.self))
        service.setAutomaticallyChecksForUpdates(true)
        service.checkForUpdates()
        XCTAssertFalse(service.isConfigured)
        XCTAssertFalse(service.canCheckForUpdates)
        XCTAssertFalse(service.automaticallyChecksForUpdates)
        XCTAssertEqual(UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? NSNumber, before)
    }
}
