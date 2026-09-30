import AppKit
import ApplicationServices

/// One status item, in AppKit global coordinates. On macOS 27 Accessibility exposes no
/// title for other apps' items, so the owner and the frame are all there is.
struct MenuBarItemFrame: Equatable, Sendable {
    let owner: String?
    let identifier: String?
    let frame: CGRect
}

struct MenuBarSnapshot: Sendable {
    let others: [MenuBarItemFrame]
    let own: [MenuBarItemFrame]
}

/// Reads every app's status items through Accessibility (each app's `AXExtrasMenuBar`).
/// Barkeep's own window frames are placeholders on macOS 27, so its dividers are read
/// the same way.
enum MenuBarInventory {
    /// The default is several seconds per app, and one hung app would stall a collapse.
    private static let messagingTimeout: Float = 0.1

    @MainActor static var isTrusted: Bool { AXIsProcessTrusted() }

    @MainActor static func requestTrust() {
        // The value of kAXTrustedCheckOptionPrompt, a mutable global Swift 6 won't read.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @MainActor static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Takes about a second, so it runs off the main thread. Asking Barkeep's own process
    /// is served by the main run loop, which stays free while this awaits.
    @MainActor static func snapshot() async -> MenuBarSnapshot {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        // Only app bundles own status items; skipping helpers avoids dozens of timeouts.
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.bundleURL?.pathExtension == "app" }
            .map { App(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier) }
        let own = App(pid: ownPID, bundleID: Bundle.main.bundleIdentifier)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return await Task.detached(priority: .userInitiated) {
            MenuBarSnapshot(
                others: apps.flatMap { items(of: $0, primaryHeight: primaryHeight) },
                own: items(of: own, primaryHeight: primaryHeight)
            )
        }.value
    }

    private struct App: Sendable {
        let pid: pid_t
        let bundleID: String?
    }

    private static func items(of app: App, primaryHeight: CGFloat) -> [MenuBarItemFrame] {
        let element = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        guard let bar: AXUIElement = attribute(element, "AXExtrasMenuBar"),
              let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute) else { return [] }
        return children.compactMap { child in
            guard let position: AXValue = attribute(child, kAXPositionAttribute),
                  let size: AXValue = attribute(child, kAXSizeAttribute) else { return nil }
            var origin = CGPoint.zero
            var extent = CGSize.zero
            AXValueGetValue(position, .cgPoint, &origin)
            AXValueGetValue(size, .cgSize, &extent)
            // Accessibility measures y down from the top of the primary display.
            let frame = CGRect(x: origin.x, y: primaryHeight - origin.y - extent.height, width: extent.width, height: extent.height)
            return MenuBarItemFrame(owner: app.bundleID, identifier: attribute(child, kAXIdentifierAttribute), frame: frame)
        }
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
