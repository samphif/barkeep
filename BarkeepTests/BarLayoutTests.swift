import Foundation
import Testing
@testable import Barkeep

struct BarLayoutTests {
    @Test func collapsedPushesHiddenSectionOffScreen() {
        let lengths = BarLayout.lengths(for: .collapsed)
        #expect(lengths.hidden == BarLayout.collapsedLength)
        #expect(lengths.alwaysHidden == BarLayout.dividerLength)
    }

    @Test func expandedKeepsAlwaysHiddenSectionOffScreen() {
        let lengths = BarLayout.lengths(for: .expanded)
        #expect(lengths.hidden == BarLayout.dividerLength)
        #expect(lengths.alwaysHidden == BarLayout.collapsedLength)
    }

    @Test func expandedAllShowsEverything() {
        let lengths = BarLayout.lengths(for: .expandedAll)
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
        #expect(BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: 10, mouseInMenuBar: false))
    }

    @Test func waitsWhileMouseIsInMenuBar() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(60)
        #expect(!BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: 10, mouseInMenuBar: true))
    }

    @Test func neverRehidesWithoutDelay() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(3600)
        #expect(!BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: nil, mouseInMenuBar: false))
    }

    @Test func doesNotRehideEarly() {
        let revealedAt = Date(timeIntervalSince1970: 0)
        let later = revealedAt.addingTimeInterval(5)
        #expect(!BarLayout.shouldRehide(now: later, revealedAt: revealedAt, delay: 10, mouseInMenuBar: false))
    }
}
