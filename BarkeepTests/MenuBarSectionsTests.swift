import CoreGraphics
import Testing
@testable import Barkeep

struct MenuBarSectionsTests {
    /// The built-in display with two external displays stacked above it.
    static let builtIn = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    static let wide = CGRect(x: -1414, y: 1117, width: 2560, height: 1080)
    static let side = CGRect(x: 1146, y: 1117, width: 1920, height: 1080)
    static let screens = [builtIn, wide, side]

    /// An item `offset` points left of `screen`'s right edge, in its menu bar.
    static func item(_ owner: String?, _ offset: CGFloat, on screen: CGRect = builtIn, id: String? = nil, width: CGFloat = 20) -> MenuBarItemFrame {
        MenuBarItemFrame(owner: owner, identifier: id, frame: CGRect(x: screen.maxX - offset - width / 2, y: screen.maxY - 24, width: width, height: 24))
    }

    static func sections(_ others: [MenuBarItemFrame], own: [MenuBarItemFrame]) -> MenuBarSections? {
        MenuBarSections(snapshot: MenuBarSnapshot(others: others, own: own), screens: screens, ownerToSkip: "com.samuelphifer.Barkeep")
    }

    static let ownItems = [
        item(nil, 300, id: StatusItemID.alwaysHiddenDivider, width: 12),
        item(nil, 200, id: StatusItemID.hiddenDivider, width: 12),
        item(nil, 180, id: StatusItemID.toggle, width: 24),
    ]

    @Test func splitsAppsByDivider() throws {
        let sections = try #require(Self.sections([
            Self.item("visible.app", 100),
            Self.item("hidden.app", 250),
            Self.item("always.app", 400),
        ], own: Self.ownItems))
        #expect(sections.owners(in: [.visible]) == ["visible.app"])
        #expect(sections.owners(in: [.hidden]) == ["hidden.app"])
        #expect(sections.owners(in: [.alwaysHidden]) == ["always.app"])
    }

    @Test func comparesItemsReportedOnDifferentDisplays() throws {
        let sections = try #require(Self.sections([
            Self.item("visible.app", 100, on: Self.wide),
            Self.item("hidden.app", 250, on: Self.side),
        ], own: Self.ownItems))
        #expect(sections.owners(in: [.visible]) == ["visible.app"])
        #expect(sections.owners(in: [.hidden]) == ["hidden.app"])
    }

    @Test func appWithAnyVisibleIconStaysVisible() throws {
        let sections = try #require(Self.sections([
            Self.item("split.app", 100),
            Self.item("split.app", 250),
        ], own: Self.ownItems))
        #expect(sections.owners(in: [.visible]) == ["split.app"])
    }

    @Test func offScreenItemsAndSystemItemsAreNeverHidden() throws {
        let offScreen = MenuBarItemFrame(owner: "lost.app", identifier: nil, frame: CGRect(x: 9000, y: 9000, width: 20, height: 24))
        let sections = try #require(Self.sections([
            offScreen,
            Self.item("com.apple.controlcenter", 250),
            Self.item("com.samuelphifer.Barkeep", 250),
        ], own: Self.ownItems))
        #expect(sections.owners(in: [.visible]) == ["lost.app"])
        #expect(sections.owners(in: [.hidden, .alwaysHidden]).isEmpty)
    }

    @Test func noDividerMeansNoSections() {
        #expect(Self.sections([Self.item("hidden.app", 250)], own: []) == nil)
    }

    @Test func hiddenAppsKeepTheirLastSection() throws {
        let before = try #require(Self.sections([
            Self.item("hidden.app", 250),
            Self.item("busy.app", 250),
            Self.item("moved.app", 250),
        ], own: Self.ownItems))
        // While hidden, hidden.app reports a stale frame; busy.app didn't answer; moved.app was dragged right.
        let fresh = try #require(Self.sections([
            Self.item("hidden.app", 100),
            Self.item("moved.app", 100),
        ], own: Self.ownItems))
        let merged = before.updated(with: fresh, keeping: ["hidden.app"])
        #expect(merged.owners(in: [.hidden]) == ["busy.app", "hidden.app"])
        #expect(merged.owners(in: [.visible]) == ["moved.app"])
    }
}

struct DividersTests {
    @Test func prefersAccessibilityIdentifiers() throws {
        let dividers = try #require(Dividers(own: MenuBarSectionsTests.ownItems))
        #expect(dividers.hidden == MenuBarSectionsTests.ownItems[1].frame)
        #expect(dividers.alwaysHidden == MenuBarSectionsTests.ownItems[0].frame)
    }

    @Test func fallsBackToShapeWithoutIdentifiers() throws {
        let own = [
            MenuBarSectionsTests.item(nil, 180, width: 24),
            MenuBarSectionsTests.item(nil, 200, width: 12),
            MenuBarSectionsTests.item(nil, 300, width: 12),
        ]
        let dividers = try #require(Dividers(own: own))
        #expect(dividers.hidden == own[1].frame)
        #expect(dividers.alwaysHidden == own[2].frame)
    }

    @Test func singleDividerHasNoAlwaysHiddenSection() throws {
        let own = [MenuBarSectionsTests.item(nil, 180, width: 24), MenuBarSectionsTests.item(nil, 200, width: 12)]
        let dividers = try #require(Dividers(own: own))
        #expect(dividers.hidden == own[1].frame)
        #expect(dividers.alwaysHidden == nil)
    }
}
