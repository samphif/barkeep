import Foundation

@MainActor
final class Settings {
    static let rehideDelayChoices: [TimeInterval] = [5, 10, 30]

    private enum Key {
        static let rehideDelay = "rehideDelay"
        static let revealOnHover = "revealOnHover"
        static let revealOnScroll = "revealOnScroll"
        static let alwaysHiddenEnabled = "alwaysHiddenEnabled"
        static let hasShownWelcome = "hasShownWelcome"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.rehideDelay: 10.0,
            Key.revealOnHover: false,
            Key.revealOnScroll: true,
            Key.alwaysHiddenEnabled: false,
            Key.hasShownWelcome: false,
        ])
    }

    /// `nil` means hidden items stay revealed until you hide them again.
    var rehideDelay: TimeInterval? {
        get {
            let value = defaults.double(forKey: Key.rehideDelay)
            return value > 0 ? value : nil
        }
        set { defaults.set(newValue ?? 0, forKey: Key.rehideDelay) }
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
}
