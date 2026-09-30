import AppKit

@MainActor
enum Alerts {
    static func showWelcome(hotKeyLabel: String) {
        present(
            title: "Welcome to Barkeep",
            message: """
            Barkeep added a bow tie and a thin divider (│) to your menu bar.

            Hold ⌘ and drag menu bar icons:
            • Right of the divider: always visible (Wi-Fi, Control Center, Cursor…)
            • Left of the divider: hidden until you click the bow tie

            Show hidden items by clicking the bow tie, scrolling in the menu bar, or pressing \(hotKeyLabel). They hide again automatically.

            Turn on the Always-Hidden Section to get a second, dotted divider. Icons left of it only appear when you ⌥-click the bow tie.

            Right-click the bow tie for settings.
            """
        )
    }

    static func showError(_ title: String, _ error: Error) {
        present(title: title, message: error.localizedDescription)
    }

    private static func present(title: String, message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.window.level = .floating
        alert.runModal()
    }
}
