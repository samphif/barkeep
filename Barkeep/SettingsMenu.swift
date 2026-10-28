import AppKit

@MainActor
struct SettingsMenu {
    struct Actions {
        let toggle: @MainActor () -> Void
        let showAll: @MainActor () -> Void
        let showHelp: @MainActor () -> Void
        let settingsChanged: @MainActor () -> Void
    }

    private static let toggles: [(title: String, keyPath: ReferenceWritableKeyPath<Settings, Bool>)] = [
        ("Show on Hover Over Bow Tie", \.revealOnHover),
        ("Show on Scroll in Menu Bar", \.revealOnScroll),
        ("Always-Hidden Section", \.alwaysHiddenEnabled),
        ("Divider Mode", \.preferDividerMode),
    ]

    let state: RevealState
    let settings: Settings
    let hotKey: HotKeyCombo
    let hotKeyAvailable: Bool
    let needsAccessibility: Bool
    let actions: Actions

    func popUp(from button: NSStatusBarButton) {
        makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(state == .collapsed ? "Show Hidden Items" : "Hide Items", action: actions.toggle))
        if settings.alwaysHiddenEnabled {
            menu.addItem(ClosureMenuItem("Show All Items", action: actions.showAll))
        }
        menu.addItem(.separator())

        if needsAccessibility {
            menu.addItem(ClosureMenuItem("Allow Accessibility Access to Hide on Any Display…") {
                MenuBarInventory.openAccessibilitySettings()
            })
            menu.addItem(.separator())
        }

        let rehideItem = NSMenuItem(title: "Auto-Hide", action: nil, keyEquivalent: "")
        rehideItem.submenu = NSMenu()
        for delay in RehideDelay.allCases {
            rehideItem.submenu?.addItem(ClosureMenuItem(delay.title, checked: settings.rehideDelay == delay) {
                settings.rehideDelay = delay
                actions.settingsChanged()
            })
        }
        menu.addItem(rehideItem)

        for (title, keyPath) in Self.toggles {
            menu.addItem(ClosureMenuItem(title, checked: settings[keyPath: keyPath]) {
                settings[keyPath: keyPath].toggle()
                actions.settingsChanged()
            })
        }
        menu.addItem(ClosureMenuItem("Launch at Login", checked: LaunchAtLogin.isEnabled) {
            do {
                try LaunchAtLogin.toggle()
            } catch {
                Alerts.showError("Couldn’t change Launch at Login", error)
            }
        })
        menu.addItem(.separator())

        let hotKeyTitle = hotKeyAvailable ? "Toggle Hotkey: \(hotKey.label)" : "Hotkey \(hotKey.label) unavailable (in use)"
        menu.addItem(NSMenuItem(title: hotKeyTitle, action: nil, keyEquivalent: ""))
        menu.addItem(ClosureMenuItem("How to Use Barkeep…", action: actions.showHelp))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Barkeep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
}

/// A menu item that runs a closure, so menus don't need a selector per action.
@MainActor
private final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, checked: Bool = false, action handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fire() {
        handler()
    }
}
