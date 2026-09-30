import AppKit

struct ScrollSample {
    let deltaY: CGFloat
    let phase: NSEvent.Phase
    let momentumPhase: NSEvent.Phase
}

/// System-wide scroll, display, and Accessibility-permission events, delivered on the main actor.
@MainActor
final class SystemEvents {
    /// The trust flag updates a moment after macOS announces the change.
    private static let accessibilitySettleDelay: Duration = .seconds(1)

    private var scrollMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?

    init(
        onScroll: @escaping @MainActor (ScrollSample) -> Void,
        onScreensChanged: @escaping @MainActor () -> Void,
        onAccessibilityChanged: @escaping @MainActor () -> Void
    ) {
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
            let sample = ScrollSample(deltaY: event.scrollingDeltaY, phase: event.phase, momentumPhase: event.momentumPhase)
            MainActor.assumeIsolated { onScroll(sample) }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onScreensChanged() }
        }
        accessibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                try? await Task.sleep(for: Self.accessibilitySettleDelay)
                onAccessibilityChanged()
            }
        }
    }

    isolated deinit {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let accessibilityObserver { DistributedNotificationCenter.default().removeObserver(accessibilityObserver) }
    }
}
