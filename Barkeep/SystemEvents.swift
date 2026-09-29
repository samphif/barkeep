import AppKit

struct ScrollSample {
    let deltaY: CGFloat
    let phase: NSEvent.Phase
    let momentumPhase: NSEvent.Phase
}

/// System-wide scroll and display-change events, delivered on the main actor.
@MainActor
final class SystemEvents {
    private var scrollMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    init(
        onScroll: @escaping @MainActor (ScrollSample) -> Void,
        onScreensChanged: @escaping @MainActor () -> Void
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
    }

    isolated deinit {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
}
