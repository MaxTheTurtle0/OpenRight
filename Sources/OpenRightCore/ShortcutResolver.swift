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
        guard let key = ShortcutKey.normalized(key), !preferences.disabledKeys.contains(key) else { return .none }
        let running = uniqueCandidates(candidates.filter(\.isRunning))

        if let binding = preferences.bindings.first(where: { $0.key == key }) {
            guard let candidate = running.first(where: { $0.id == binding.bundleID }) else { return .launch(binding) }
            if binding.behavior == .hide {
                if candidate.id == frontmostID, !candidate.isHidden { return .hide(candidate) }
                return .activate(candidate)
            }
            // A pin leads its key's group even if its name starts with another
            // letter. Repeated presses then traverse natural matches and wrap.
            let others = orderedByRecency(
                running.filter { $0.id != candidate.id && ShortcutKey.initial(for: $0.name) == key },
                recentIDs: recentIDs
            )
            let group = [candidate] + others
            if let activeIndex = group.firstIndex(where: { $0.id == frontmostID && !$0.isHidden }) {
                return .activate(group[(activeIndex + 1) % group.count])
            }
            return .activate(candidate)
        }

        let matches = orderedByRecency(
            running.filter { ShortcutKey.initial(for: $0.name) == key },
            recentIDs: recentIDs
        )
        guard let first = matches.first else { return .none }
        guard let activeIndex = matches.firstIndex(where: { $0.id == frontmostID && !$0.isHidden }) else {
            return .activate(first)
        }
        if preferences.repeatBehavior == .hide {
            return .hide(matches[activeIndex])
        }
        return .activate(matches[(activeIndex + 1) % matches.count])
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
