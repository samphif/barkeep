import Foundation

/// Fires once the menu bar has gone unused for `delay` seconds.
struct RehideClock {
    let delay: TimeInterval
    private(set) var lastActivity: Date

    mutating func tick(now: Date, inUse: Bool) -> Bool {
        if inUse {
            lastActivity = now
            return false
        }
        return now.timeIntervalSince(lastActivity) >= delay
    }
}

/// Counts down from the last moment the menu bar was in use, so a revealed item's
/// menu never collapses out from under the pointer.
@MainActor
final class RehideTimer {
    private let onExpire: @MainActor () -> Void
    private var task: Task<Void, Never>?

    init(onExpire: @escaping @MainActor () -> Void) {
        self.onExpire = onExpire
    }

    func restart(after delay: RehideDelay) {
        cancel()
        guard let seconds = delay.seconds else { return }
        task = Task { [weak self] in
            var clock = RehideClock(delay: seconds, lastActivity: .now)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                if clock.tick(now: .now, inUse: MenuBarActivity.isInUse) {
                    self.onExpire()
                    return
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
