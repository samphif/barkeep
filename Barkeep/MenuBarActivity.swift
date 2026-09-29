import AppKit

/// Whether the user is working in the menu bar right now. None of these checks need
/// Screen Recording or Accessibility permission.
@MainActor
enum MenuBarActivity {
    static var isInUse: Bool {
        NSApp.modalWindow != nil || isPointerInMenuBar || isAnyMenuOpen
    }

    static var isPointerInMenuBar: Bool {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            return BarLayout.isInMenuBar(point: pointer, screenFrame: screen.frame, menuBarHeight: menuBarHeight)
        }
    }

    /// Open menus from any app sit at the pop-up menu window level.
    private static var isAnyMenuOpen: Bool {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }
}
