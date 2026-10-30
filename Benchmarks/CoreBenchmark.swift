import Foundation
import Dispatch

// Compile alongside Sources/OpenRightCore/*.swift with -O and
// -whole-module-optimization. All data is synthetic; no events are posted.
@main
struct CoreBenchmark {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let filter: String? = arguments.firstIndex(of: "--filter").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        func selected(_ name: String) -> Bool { filter.map { name.contains($0) } ?? true }
        func record(_ name: String, iterations: Int, _ operation: (Int) -> Int) throws {
            guard selected(name) else { return }
            var checksum = 0
            for index in 0..<8 { checksum = checksum &+ operation(index) }
            var samples: [Double] = []
            for _ in 0..<7 {
                let start = DispatchTime.now().uptimeNanoseconds
                for index in 0..<iterations { checksum = checksum &+ operation(index) }
                let elapsed = DispatchTime.now().uptimeNanoseconds - start
                samples.append(Double(elapsed) / Double(iterations))
            }
            let result: [String: Any] = [
                "benchmark": name,
                "iterationsPerSample": iterations,
                "samplesNsPerOperation": samples,
                "medianNsPerOperation": samples.sorted()[samples.count / 2],
                "checksum": checksum
            ]
            let encoded = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            print(String(decoding: encoded, as: UTF8.self))
        }
        let ascii = ["a", "P", "0", "9", "z"]
        try record("normalize-ascii", iterations: 50_000) { index in
            ShortcutKey.normalized(ascii[index % ascii.count])?.utf8.count ?? 0
        }
        let unicode = ["É", "９", "À", "ß", "e\u{20DD}"]
        try record("normalize-unicode", iterations: 10_000) { index in
            ShortcutKey.normalized(unicode[index % unicode.count])?.utf8.count ?? 0
        }
        let names = ["1Password", "Finder", "Grok Bot", "Microsoft Teams", "Passwords", "Preview", "T3 Code (Nightly)", "Tailscale", "UniFi Endpoint", "WhatsApp", "Zen"]
        let normalApps = names.enumerated().map { index, name in
            AppCandidate(id: "synthetic.\(index)", name: name, path: "/Synthetic/\(name).app")
        }
        let assignments: [(String, Int)] = [("1",0),("3",6),("o",2),("p",4),("t",3),("w",9),("z",10)]
        let normalPreferences = Preferences(bindings: assignments.map { key, index in
            let app = normalApps[index]
            return AppBinding(key: key, bundleID: app.id, name: app.name, path: app.path)
        })
        try record("initial-ascii-names", iterations: 20_000) { index in
            ShortcutKey.initial(for: names[index % names.count])?.utf8.count ?? 0
        }
        func actionChecksum(_ action: ShortcutAction) -> Int {
            switch action {
            case .activate(let app): return app.id.utf8.count + 17
            case .hide(let app): return app.id.utf8.count + 29
            case .launch(let binding): return binding.bundleID.utf8.count + 31
            case .none: return 0
            }
        }
        let keys = assignments.map(\.0) + ["f", "u", "x"]
        let normalRecency = normalApps.reversed().map(\.id)
        try record("resolve-11-apps-7-pins", iterations: 5_000) { index in
            actionChecksum(ShortcutResolver.action(for: keys[index % keys.count], candidates: normalApps,
                frontmostID: normalApps[index % normalApps.count].id, recentIDs: normalRecency, preferences: normalPreferences))
        }
        let letters = Array("abcdefghijklmnopqrstuvwxyz0123456789").map(String.init)
        let busyApps = (0..<100).map { index in
            AppCandidate(id: "synthetic.busy.\(index)", name: "\(letters[index % 26].uppercased()) Tool \(String(format: "%03d",index))",
                path: "/Synthetic/Busy\(index).app", isHidden: index % 11 == 0)
        }
        let busyPreferences = Preferences(bindings: letters.enumerated().map { index, key in
            let app = busyApps[index]
            return AppBinding(key: key, bundleID: app.id, name: app.name, path: app.path)
        })
        let busyRecency = busyApps.reversed().map(\.id)
        try record("resolve-100-apps-36-pins", iterations: 1_000) { index in
            actionChecksum(ShortcutResolver.action(for: letters[index % letters.count], candidates: busyApps,
                frontmostID: busyApps[index % busyApps.count].id, recentIDs: busyRecency, preferences: busyPreferences))
        }
        let baseNames = ["Xcode", "Safari", "Slack", "Zen", "Calendar", "Visual Studio Code", "Password Helper", "Microsoft Teams", "Terminal", "Calculator", "Éditeur", "Mail", "Signal", "Home", "Settings", "Preview"]
        for count in [100, 500, 2_000] {
            let catalog = (0..<count).map { index in
                AppCandidate(id: "synthetic.catalog.\(index)", name: "\(baseNames[index % baseNames.count]) \(String(format: "%04d",index))",
                    path: "/Synthetic/Catalog\(index).app", isRunning: index < 15)
            }
            let recent = catalog.prefix(15).reversed().map(\.id)
            for (label, query) in [("empty", ""), ("prefix", "cal"), ("fuzzy", "vsc"), ("miss", "zzzzzz")] {
                try record("search-\(count)-\(label)", iterations: count == 2_000 ? 20 : 50) { _ in
                    SearchMatcher.search(query, in: catalog, recentIDs: recent).reduce(0) { sum, app in
                        app.id.utf8.reduce(sum &* 31) { ($0 &* 33) &+ Int($1) }
                    }
                }
            }
        }
    }
}
