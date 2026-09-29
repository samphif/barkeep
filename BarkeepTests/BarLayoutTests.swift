import AppKit
import Foundation
import Testing
@testable import Barkeep

struct BarLayoutTests {
    @Test func collapsedPushesHiddenSectionOffScreen() {
        let lengths = BarLayout.lengths(for: .collapsed, collapsedLength: 777)
        #expect(lengths.hidden == 777)
        #expect(lengths.alwaysHidden == BarLayout.dividerLength)
    }

    @Test func expandedKeepsAlwaysHiddenSectionOffScreen() {
        let lengths = BarLayout.lengths(for: .expanded, collapsedLength: 777)
        #expect(lengths.hidden == BarLayout.dividerLength)
        #expect(lengths.alwaysHidden == 777)
    }

    @Test func collapsedLengthStaysUnderHalfOfNarrowestScreen() {
        let length = BarLayout.collapsedLength(screenWidths: [2560, 1728, 1920])
        #expect(length == 777)
        #expect(length < 1728 / 2)
    }

    @Test func collapsedLengthFallsBackWithoutScreens() {
        #expect(BarLayout.collapsedLength(screenWidths: []) == BarLayout.fallbackCollapsedLength)
        #expect(BarLayout.collapsedLength(screenWidths: [0]) == BarLayout.fallbackCollapsedLength)
    }

    @Test func expandedAllShowsEverything() {
        let lengths = BarLayout.lengths(for: .expandedAll, collapsedLength: 777)
        #expect(lengths.hidden == BarLayout.dividerLength)
        #expect(lengths.alwaysHidden == BarLayout.dividerLength)
    }

    private func item(x: CGFloat, width: CGFloat = 28) -> CGRect {
        CGRect(x: x, y: 1084, width: width, height: 33)
    }

    @Test func orderedWhenDividerIsLeftOfChevron() {
        #expect(BarLayout.isOrdered(toggle: item(x: 1200), hidden: item(x: 1000), alwaysHidden: nil))
    }

    @Test func notOrderedWhenDividerIsRightOfChevron() {
        #expect(!BarLayout.isOrdered(toggle: item(x: 1000), hidden: item(x: 1200), alwaysHidden: nil))
    }

    @Test func alwaysHiddenDividerMustBeLeftOfHiddenDivider() {
        #expect(BarLayout.isOrdered(toggle: item(x: 1200), hidden: item(x: 1000), alwaysHidden: item(x: 800)))
        #expect(!BarLayout.isOrdered(toggle: item(x: 1200), hidden: item(x: 1000), alwaysHidden: item(x: 1100)))
    }

    @Test func overlappingPlaceholderFramesDoNotBlockCollapse() {
        let toggle = CGRect(x: 1017, y: 1084, width: 38, height: 33)
        let hidden = CGRect(x: 1027, y: 1084, width: 28, height: 33)
        #expect(BarLayout.isOrdered(toggle: toggle, hidden: hidden, alwaysHidden: nil))
    }

    @Test func menuBarHitTestIncludesTopEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(BarLayout.isInMenuBar(point: CGPoint(x: 700, y: 982), screenFrame: screen, menuBarHeight: 37))
        #expect(BarLayout.isInMenuBar(point: CGPoint(x: 700, y: 950), screenFrame: screen, menuBarHeight: 37))
        #expect(!BarLayout.isInMenuBar(point: CGPoint(x: 700, y: 900), screenFrame: screen, menuBarHeight: 37))
        #expect(!BarLayout.isInMenuBar(point: CGPoint(x: 1600, y: 982), screenFrame: screen, menuBarHeight: 37))
    }

    @Test func rehidesAfterDelayWhenMouseIsAway() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(11)
        #expect(BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: 10, menuBarInUse: false))
    }

    @Test func waitsWhileMenuBarIsInUse() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(60)
        #expect(!BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: 10, menuBarInUse: true))
    }

    @Test func neverRehidesWithoutDelay() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(3600)
        #expect(!BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: nil, menuBarInUse: false))
    }

    @Test func doesNotRehideEarly() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(5)
        #expect(!BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: 10, menuBarInUse: false))
    }
}

@MainActor
struct MenuBarControllerContractTests {
    /// NSTrackingArea calls these by selector; a misnamed export throws inside AppKit.
    @Test func respondsToTrackingAreaSelectors() {
        #expect(MenuBarController.instancesRespond(to: NSSelectorFromString("mouseEntered:")))
        #expect(MenuBarController.instancesRespond(to: NSSelectorFromString("mouseExited:")))
    }
}

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
