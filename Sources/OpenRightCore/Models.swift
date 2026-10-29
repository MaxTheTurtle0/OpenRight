import Foundation

public struct AppCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var path: String
    public var isRunning: Bool
    public var isHidden: Bool

    public init(id: String, name: String, path: String, isRunning: Bool = true, isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.isRunning = isRunning
        self.isHidden = isHidden
    }
}

public enum RepeatBehavior: String, Codable, CaseIterable, Sendable {
    case cycle, hide
}

public enum Trigger: String, Codable, CaseIterable, Sendable {
    case rightCommand, rightOption, controlOption
}

public struct AppBinding: Codable, Equatable, Identifiable, Sendable {
    public var key: String
    public var id: String { key }
    public var bundleID: String
    public var name: String
    public var path: String
    public var behavior: RepeatBehavior

    public init(key: String, bundleID: String, name: String, path: String, behavior: RepeatBehavior = .cycle) {
        self.key = key
        self.bundleID = bundleID
        self.name = name
        self.path = path
        self.behavior = behavior
    }

    private enum CodingKeys: String, CodingKey {
        case key, bundleID, name, path, behavior
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            key: try values.decode(String.self, forKey: .key),
            bundleID: try values.decode(String.self, forKey: .bundleID),
            name: try values.decode(String.self, forKey: .name),
            path: try values.decode(String.self, forKey: .path),
            behavior: (try? values.decode(RepeatBehavior.self, forKey: .behavior)) ?? .cycle
        )
    }
}

/// Preferences tolerate missing or invalid individual fields so that one hand-edited
/// value does not discard the rest of a user's configuration.
public struct Preferences: Codable, Equatable, Sendable {
    public var trigger: Trigger
    public var repeatBehavior: RepeatBehavior
    public var disabledKeys: String
    public var showHints: Bool
    public var launchAtLogin: Bool
    public var bindings: [AppBinding]

    public init(
        trigger: Trigger = .rightCommand,
        repeatBehavior: RepeatBehavior = .cycle,
        disabledKeys: String = "",
        showHints: Bool = true,
        launchAtLogin: Bool = false,
        bindings: [AppBinding] = []
    ) {
        self.trigger = trigger
        self.repeatBehavior = repeatBehavior
        self.disabledKeys = disabledKeys
        self.showHints = showHints
        self.launchAtLogin = launchAtLogin
        self.bindings = bindings
    }

    private enum CodingKeys: String, CodingKey {
        case trigger, repeatBehavior, disabledKeys, showHints, launchAtLogin, bindings
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            trigger: (try? values.decode(Trigger.self, forKey: .trigger)) ?? .rightCommand,
            repeatBehavior: (try? values.decode(RepeatBehavior.self, forKey: .repeatBehavior)) ?? .cycle,
            disabledKeys: (try? values.decode(String.self, forKey: .disabledKeys)) ?? "",
            showHints: (try? values.decode(Bool.self, forKey: .showHints)) ?? true,
            launchAtLogin: (try? values.decode(Bool.self, forKey: .launchAtLogin)) ?? false,
            bindings: (try? values.decode([LossyBinding].self, forKey: .bindings))?.compactMap(\.value) ?? []
        )
        self = sanitized()
    }

    /// Returns normalized keys and one pin per key. Later pins replace earlier pins.
    public func sanitized() -> Preferences {
        var result = self
        result.disabledKeys = String(Set(disabledKeys.compactMap { ShortcutKey.normalized(String($0)) }.joined()).sorted())
        var pins: [String: AppBinding] = [:]
        for var binding in bindings {
            guard let key = ShortcutKey.normalized(binding.key), !binding.bundleID.isEmpty else { continue }
            binding.key = key
            pins[key] = binding
        }
        result.bindings = pins.values.sorted { $0.key < $1.key }
        return result
    }

    public mutating func setBinding(_ binding: AppBinding) {
        bindings.append(binding)
        self = sanitized()
    }
}

private struct LossyBinding: Decodable {
    let value: AppBinding?

    init(from decoder: Decoder) throws {
        value = try? AppBinding(from: decoder)
    }
}

public enum ShortcutAction: Equatable, Sendable {
    case activate(AppCandidate)
    case launch(AppBinding)
    case hide(AppCandidate)
    case none
}

public enum ShortcutKey {
    /// Shortcut keys use a single ASCII letter or digit. Uppercase and accented
    /// letters normalize to the corresponding lowercase key where possible.
    public static func normalized(_ key: String) -> String? {
        let folded = folded(key)
        guard folded.utf8.count == 1, let byte = folded.utf8.first,
              (97...122).contains(byte) || (48...57).contains(byte) else { return nil }
        return folded
    }

    public static func initial(for name: String) -> String? {
        for character in folded(name) {
            if let key = normalized(String(character)) { return key }
        }
        return nil
    }

    static func folded(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}
