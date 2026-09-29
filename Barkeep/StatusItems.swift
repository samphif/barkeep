import AppKit

enum StatusClick {
    case toggle
    case showAll
    case menu(NSStatusBarButton)
}

/// Barkeep's three menu bar items. Items created first sit furthest right, so this order
/// yields: [always-hidden ┊] [hidden │] [chevron].
@MainActor
final class StatusItems: NSObject {
    var onClick: (StatusClick) -> Void = { _ in }
    var onHover: () -> Void = {}

    private let toggleItem: NSStatusItem
    private let hiddenDivider: NSStatusItem
    private let alwaysHiddenDivider: NSStatusItem

    override init() {
        let statusBar = NSStatusBar.system
        toggleItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        hiddenDivider = statusBar.statusItem(withLength: BarLayout.dividerLength)
        alwaysHiddenDivider = statusBar.statusItem(withLength: BarLayout.dividerLength)
        super.init()

        toggleItem.autosaveName = "BarkeepToggle"
        hiddenDivider.autosaveName = "BarkeepHiddenDivider"
        alwaysHiddenDivider.autosaveName = "BarkeepAlwaysHiddenDivider"
        hiddenDivider.button?.image = StatusImages.divider
        alwaysHiddenDivider.button?.image = StatusImages.alwaysHiddenDivider

        for item in [toggleItem, hiddenDivider, alwaysHiddenDivider] {
            item.button?.target = self
            item.button?.action = #selector(buttonClicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        toggleItem.button?.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    var alwaysHiddenVisible: Bool {
        get { alwaysHiddenDivider.isVisible }
        set { alwaysHiddenDivider.isVisible = newValue }
    }

    func show(_ state: RevealState) {
        let collapsedLength = BarLayout.collapsedLength(screenWidths: NSScreen.screens.map(\.frame.width))
        let lengths = state.dividerLengths(collapsed: collapsedLength)
        hiddenDivider.length = lengths.hidden
        alwaysHiddenDivider.length = lengths.alwaysHidden
        toggleItem.button?.image = state == .collapsed ? StatusImages.showHidden : StatusImages.hideItems
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            onClick(.menu(sender))
        } else if event.modifierFlags.contains(.option) {
            onClick(.showAll)
        } else {
            onClick(.toggle)
        }
    }

    // NSTrackingArea sends `mouseEntered:` / `mouseExited:` to its owner; a missing or
    // misnamed selector throws inside AppKit and tears down any open modal alert.
    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        onHover()
    }

    @objc(mouseExited:) func mouseExited(with event: NSEvent) {}
}
