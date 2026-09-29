import AppKit
import Testing
@testable import Barkeep

struct ScrollGestureTests {
    private struct Event {
        var deltaY: CGFloat
        var phase: NSEvent.Phase = []
        var momentum: NSEvent.Phase = []
        var at: TimeInterval = 0
    }

    private func toggles(_ events: [Event]) -> [Bool] {
        var gesture = ScrollGesture()
        let start = Date(timeIntervalSince1970: 0)
        return events.map {
            gesture.shouldToggle(deltaY: $0.deltaY, phase: $0.phase, momentumPhase: $0.momentum, now: start.addingTimeInterval($0.at))
        }
    }

    @Test func trackpadGestureTogglesOnce() {
        let results = toggles([
            Event(deltaY: 2, phase: .began),
            Event(deltaY: 7, phase: .changed),
            Event(deltaY: 20, phase: .changed),
            Event(deltaY: 0, phase: .ended),
        ])
        #expect(results == [false, true, false, false])
    }

    @Test func ignoresMomentum() {
        let results = toggles([
            Event(deltaY: 40, momentum: .began),
            Event(deltaY: 40, momentum: .changed),
        ])
        #expect(results == [false, false])
    }

    @Test func smallTrackpadNudgeDoesNothing() {
        let results = toggles([
            Event(deltaY: 3, phase: .began),
            Event(deltaY: 3, phase: .changed),
        ])
        #expect(results == [false, false])
    }

    @Test func nextGestureCanToggleAgain() {
        let results = toggles([
            Event(deltaY: 10, phase: .began),
            Event(deltaY: 0, phase: .ended),
            Event(deltaY: -10, phase: .began),
        ])
        #expect(results == [true, false, true])
    }

    @Test func mouseWheelRespectsCooldown() {
        let results = toggles([
            Event(deltaY: 1),
            Event(deltaY: 1, at: 0.3),
            Event(deltaY: 1, at: 0.7),
        ])
        #expect(results == [true, false, true])
    }
}
