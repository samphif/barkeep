import AppKit

/// Turns a stream of scroll events into at most one toggle per gesture.
/// Trackpads send a began/changed/ended gesture followed by momentum events that can
/// last over a second; mouse wheels send discrete events with no phase at all.
struct ScrollGesture {
    static let trackpadThreshold: CGFloat = 8
    static let wheelCooldown: TimeInterval = 0.6

    private var accumulated: CGFloat = 0
    private var firedThisGesture = false
    private var lastWheelToggle = Date.distantPast

    mutating func shouldToggle(
        deltaY: CGFloat,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        now: Date
    ) -> Bool {
        guard momentumPhase.isEmpty else { return false }

        if phase.isEmpty {
            guard deltaY != 0, now.timeIntervalSince(lastWheelToggle) >= Self.wheelCooldown else { return false }
            lastWheelToggle = now
            return true
        }

        if phase.contains(.began) || phase.contains(.mayBegin) {
            accumulated = 0
            firedThisGesture = false
        }
        if phase.contains(.ended) || phase.contains(.cancelled) {
            accumulated = 0
            firedThisGesture = false
            return false
        }

        accumulated += deltaY
        guard !firedThisGesture, abs(accumulated) >= Self.trackpadThreshold else { return false }
        firedThisGesture = true
        return true
    }
}
