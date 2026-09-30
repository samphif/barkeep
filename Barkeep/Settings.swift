import Foundation

enum RehideDelay: Int, CaseIterable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case never = 0

    var seconds: TimeInterval? {
        switch self {
        case .never: nil
        case .fiveSeconds, .tenSeconds, .thirtySeconds: TimeInterval(rawValue)
        }
    }

    var title: String {
        switch self {
        case .never: "Never"
        case .fiveSeconds, .tenSeconds, .thirtySeconds: "After \(rawValue) Seconds"
        }
    }
}

@MainActor
final class Settings {
    private enum Key {
        static let rehideDelay = "rehideDelay"
        static let revealOnHover = "revealOnHover"
        static let revealOnScroll = "revealOnScroll"
        static let alwaysHiddenEnabled = "alwaysHiddenEnabled"
        static let hasShownWelcome = "hasShownWelcome"
        static let hasConfiguredLaunchAtLogin = "hasConfiguredLaunchAtLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.rehideDelay: RehideDelay.tenSeconds.rawValue,
            Key.revealOnHover: false,
            Key.revealOnScroll: true,
            Key.alwaysHiddenEnabled: false,
            Key.hasShownWelcome: false,
            Key.hasConfiguredLaunchAtLogin: false,
        ])
    }

    var rehideDelay: RehideDelay {
        get { RehideDelay(rawValue: defaults.integer(forKey: Key.rehideDelay)) ?? .tenSeconds }
        set { defaults.set(newValue.rawValue, forKey: Key.rehideDelay) }
    }

    var revealOnHover: Bool {
        get { defaults.bool(forKey: Key.revealOnHover) }
        set { defaults.set(newValue, forKey: Key.revealOnHover) }
    }

    var revealOnScroll: Bool {
        get { defaults.bool(forKey: Key.revealOnScroll) }
        set { defaults.set(newValue, forKey: Key.revealOnScroll) }
    }

    var alwaysHiddenEnabled: Bool {
        get { defaults.bool(forKey: Key.alwaysHiddenEnabled) }
        set { defaults.set(newValue, forKey: Key.alwaysHiddenEnabled) }
    }

    var hasShownWelcome: Bool {
        get { defaults.bool(forKey: Key.hasShownWelcome) }
        set { defaults.set(newValue, forKey: Key.hasShownWelcome) }
    }

    var hasConfiguredLaunchAtLogin: Bool {
        get { defaults.bool(forKey: Key.hasConfiguredLaunchAtLogin) }
        set { defaults.set(newValue, forKey: Key.hasConfiguredLaunchAtLogin) }
    }
}
