import Foundation

public enum SearchMatcher {
    /// Searches app names by exact name, prefix, word prefix, substring, then
    /// subsequence. Recency breaks ties without changing match quality.
    public static func search(_ query: String, in candidates: [AppCandidate], recentIDs: [String] = []) -> [AppCandidate] {
        let query = ShortcutKey.folded(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let recency = Dictionary(recentIDs.enumerated().reversed().map { ($0.element, $0.offset) }, uniquingKeysWith: { _, latest in latest })
        return uniqueCandidates(candidates).compactMap { candidate -> (app: AppCandidate, score: (Int, Int), name: String, rank: Int)? in
            let name = ShortcutKey.folded(candidate.name)
            guard let score = score(query, name: name) else { return nil }
            return (candidate, score, name, recency[candidate.id] ?? Int.max)
        }.sorted { left, right in
            if left.score != right.score { return left.score < right.score }
            if left.app.isRunning != right.app.isRunning { return left.app.isRunning }
            if left.rank != right.rank { return left.rank < right.rank }
            if left.name != right.name { return left.name < right.name }
            return left.app.id < right.app.id
        }.map(\.app)
    }

    private static func score(_ query: String, name: String) -> (Int, Int)? {
        if query.isEmpty { return (0, 0) }
        if query == name { return (0, 0) }
        if name.hasPrefix(query) { return (1, name.count - query.count) }
        let words = name.split { !$0.isLetter && !$0.isNumber }
        if words.contains(where: { $0.hasPrefix(query) }) { return (2, name.count - query.count) }
        if let range = name.range(of: query) {
            return (3, name.distance(from: name.startIndex, to: range.lowerBound) + name.count - query.count)
        }
        let letters = Array(name)
        var searchStart = 0
        var positions: [Int] = []
        for character in query {
            guard searchStart < letters.count,
                  let position = letters[searchStart...].firstIndex(of: character) else { return nil }
            positions.append(position)
            searchStart = position + 1
        }
        guard let first = positions.first, let last = positions.last else { return nil }
        let gaps = last - first + 1 - positions.count
        return (4, gaps * 4 + first + name.count - query.count)
    }
}
