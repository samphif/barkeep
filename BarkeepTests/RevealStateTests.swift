import AppKit
import Testing
@testable import Barkeep

struct RevealStateTests {
    @Test func plainToggleAlternatesCollapsedAndExpanded() {
        #expect(RevealState.collapsed.toggled(showAll: false) == .expanded)
        #expect(RevealState.expanded.toggled(showAll: false) == .collapsed)
        #expect(RevealState.expandedAll.toggled(showAll: false) == .collapsed)
    }

    @Test func showAllToggleRevealsEverythingThenCollapses() {
        #expect(RevealState.collapsed.toggled(showAll: true) == .expandedAll)
        #expect(RevealState.expanded.toggled(showAll: true) == .expandedAll)
        #expect(RevealState.expandedAll.toggled(showAll: true) == .collapsed)
    }

    @Test func expandedAllNeedsTheAlwaysHiddenSection() {
        #expect(RevealState.expandedAll.normalized(alwaysHiddenEnabled: false) == .expanded)
        #expect(RevealState.expandedAll.normalized(alwaysHiddenEnabled: true) == .expandedAll)
        #expect(RevealState.collapsed.normalized(alwaysHiddenEnabled: false) == .collapsed)
    }

    @Test func dividerLengthsPerState() {
        let narrow = BarLayout.dividerLength
        #expect(RevealState.collapsed.dividerLengths(collapsed: 777) == DividerLengths(hidden: 777, alwaysHidden: narrow))
        #expect(RevealState.expanded.dividerLengths(collapsed: 777) == DividerLengths(hidden: narrow, alwaysHidden: 777))
        #expect(RevealState.expandedAll.dividerLengths(collapsed: 777) == DividerLengths(hidden: narrow, alwaysHidden: narrow))
    }
}

struct BarLayoutTests {
    @Test func collapsedLengthStaysUnderHalfOfNarrowestScreen() {
        let length = BarLayout.collapsedLength(screenWidths: [2560, 1728, 1920])
        #expect(length == 777)
        #expect(length < 1728 / 2)
    }

    @Test func collapsedLengthFallsBackWithoutScreens() {
        #expect(BarLayout.collapsedLength(screenWidths: []) == BarLayout.fallbackCollapsedLength)
        #expect(BarLayout.collapsedLength(screenWidths: [0]) == BarLayout.fallbackCollapsedLength)
    }

    @Test func menuBarHitTestIncludesTopEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(BarLayout.isInMenuBar(point: CGPoint(x: 700, y: 982), screenFrame: screen, menuBarHeight: 37))
        #expect(BarLayout.isInMenuBar(point: CGPoint(x: 700, y: 950), screenFrame: screen, menuBarHeight: 37))
        #expect(!BarLayout.isInMenuBar(point: CGPoint(x: 700, y: 900), screenFrame: screen, menuBarHeight: 37))
        #expect(!BarLayout.isInMenuBar(point: CGPoint(x: 1600, y: 982), screenFrame: screen, menuBarHeight: 37))
    }
}

@MainActor
struct StatusItemsContractTests {
    /// NSTrackingArea calls these by selector; a misnamed export throws inside AppKit.
    @Test func respondsToTrackingAreaSelectors() {
        #expect(StatusItems.instancesRespond(to: NSSelectorFromString("mouseEntered:")))
        #expect(StatusItems.instancesRespond(to: NSSelectorFromString("mouseExited:")))
    }
}
