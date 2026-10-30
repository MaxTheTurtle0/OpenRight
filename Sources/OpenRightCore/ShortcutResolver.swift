import Foundation

public enum ShortcutResolver {
    public static func action(
        for key: String,
        candidates: [AppCandidate],
        frontmostID: String?,
        recentIDs: [String],
        preferences: Preferences
    ) -> ShortcutAction {
        let preferences = preferences.sanitized()
        guard let key = ShortcutKey.normalized(key) else { return .none }
        let group = targets(forNormalizedKey: key, candidates: candidates, recentIDs: recentIDs, preferences: preferences)
        guard let first = group.first else { return .none }
        let binding = preferences.bindings.first { $0.key == key }
        if let binding, !first.isRunning { return .launch(binding) }
        guard let activeIndex = group.firstIndex(where: { $0.id == frontmostID && !$0.isHidden }) else {
            return .activate(first)
        }
        if (binding?.behavior ?? preferences.repeatBehavior) == .hide {
            return .hide(group[activeIndex])
        }
        return .activate(group[(activeIndex + 1) % group.count])
    }

    /// The same ordered targets drive shortcut actions and the settings groups.
    public static func targets(
        for key: String,
        candidates: [AppCandidate],
        recentIDs: [String],
        preferences: Preferences
    ) -> [AppCandidate] {
        let preferences = preferences.sanitized()
        guard let key = ShortcutKey.normalized(key) else { return [] }
        return targets(forNormalizedKey: key, candidates: candidates, recentIDs: recentIDs, preferences: preferences)
    }

    // Both public entry points validate their inputs before using this helper.
    private static func targets(
        forNormalizedKey key: String,
        candidates: [AppCandidate],
        recentIDs: [String],
        preferences: Preferences
    ) -> [AppCandidate] {
        guard !preferences.disabledKeys.contains(key) else { return [] }
        let running = uniqueCandidates(candidates.filter(\.isRunning))
        if let binding = preferences.bindings.first(where: { $0.key == key }) {
            guard let pinned = running.first(where: { $0.id == binding.bundleID }) else {
                let closed = candidates.first { $0.id == binding.bundleID }
                    ?? AppCandidate(id: binding.bundleID, name: binding.name, path: binding.path, isRunning: false)
                return [closed]
            }
            if binding.behavior == .hide { return [pinned] }
            let others = orderedByRecency(
                running.filter { $0.id != pinned.id && ShortcutKey.initial(for: $0.name) == key },
                recentIDs: recentIDs
            )
            return [pinned] + others
        }
        return orderedByRecency(running.filter { ShortcutKey.initial(for: $0.name) == key }, recentIDs: recentIDs)
    }
}

func uniqueCandidates(_ candidates: [AppCandidate]) -> [AppCandidate] {
    var seen: Set<String> = []
    return candidates.filter { seen.insert($0.id).inserted }
}

func orderedByRecency(_ candidates: [AppCandidate], recentIDs: [String]) -> [AppCandidate] {
    let recency = Dictionary(recentIDs.enumerated().reversed().map { ($0.element, $0.offset) }, uniquingKeysWith: { _, latest in latest })
    return candidates.sorted {
        let leftRank = recency[$0.id] ?? Int.max
        let rightRank = recency[$1.id] ?? Int.max
        if leftRank != rightRank { return leftRank < rightRank }
        let leftName = ShortcutKey.folded($0.name)
        let rightName = ShortcutKey.folded($1.name)
        if leftName != rightName { return leftName < rightName }
        return $0.id < $1.id
    }
}
