import CoreGraphics

enum MenuBarSection: Int, Comparable, CaseIterable {
    case visible
    case hidden
    case alwaysHidden

    static func < (lhs: MenuBarSection, rhs: MenuBarSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Which section each app's icons sit in, from where the user ⌘-dragged them:
///
///     [ always hidden ] ┊ [ hidden ] │ [ visible ]
///
/// Hiding works per app, so an app with several icons gets its most visible section.
struct MenuBarSections: Equatable {
    /// macOS's own items can't be hidden by app, so they're kept visible separately.
    static let systemOwners: Set<String> = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"]

    private(set) var byOwner: [String: MenuBarSection] = [:]

    func owners(in sections: Set<MenuBarSection>) -> [String] {
        byOwner.filter { sections.contains($0.value) }.map(\.key).sorted()
    }

    /// Nil when Barkeep's own divider can't be found, since nothing can be judged then.
    init?(snapshot: MenuBarSnapshot, screens: [CGRect], ownerToSkip: String?) {
        guard let dividers = Dividers(own: snapshot.own),
              let hiddenOffset = Self.offsetFromRightEdge(of: dividers.hidden, screens: screens) else { return nil }
        let alwaysHiddenOffset = dividers.alwaysHidden.flatMap { Self.offsetFromRightEdge(of: $0, screens: screens) }

        for item in snapshot.others {
            guard let owner = item.owner, owner != ownerToSkip, !Self.systemOwners.contains(owner) else { continue }
            let section: MenuBarSection
            if let offset = Self.offsetFromRightEdge(of: item.frame, screens: screens) {
                section = if offset < hiddenOffset {
                    .visible
                } else if let alwaysHiddenOffset, offset > alwaysHiddenOffset {
                    .alwaysHidden
                } else {
                    .hidden
                }
            } else {
                // An item that isn't on any display is never hidden by guesswork.
                section = .visible
            }
            byOwner[owner] = min(byOwner[owner] ?? section, section)
        }
    }

    private init(byOwner: [String: MenuBarSection]) {
        self.byOwner = byOwner
    }

    /// Hidden items report stale frames, so owners the current restriction hides keep
    /// their last known section, as do apps too busy to answer this time.
    func updated(with fresh: MenuBarSections, keeping hiddenOwners: Set<String>) -> MenuBarSections {
        var merged = byOwner.merging(fresh.byOwner) { _, new in new }
        for owner in hiddenOwners {
            if let section = byOwner[owner] { merged[owner] = section }
        }
        return MenuBarSections(byOwner: merged)
    }

    /// Status items are right-aligned on every display, so the distance from the right
    /// edge of the display an item is drawn on compares across displays.
    static func offsetFromRightEdge(of frame: CGRect, screens: [CGRect]) -> CGFloat? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = screens.first(where: { $0.contains(center) }) else { return nil }
        return screen.maxX - center.x
    }
}

/// Barkeep's dividers among its own status items: by accessibility identifier, or when
/// macOS doesn't pass that through, by shape. The bow tie is the widest, and the
/// always-hidden divider sits left of the hidden one.
struct Dividers: Equatable {
    let hidden: CGRect
    let alwaysHidden: CGRect?

    init?(own: [MenuBarItemFrame]) {
        if let hidden = own.first(where: { $0.identifier == StatusItemID.hiddenDivider }) {
            self.hidden = hidden.frame
            alwaysHidden = own.first(where: { $0.identifier == StatusItemID.alwaysHiddenDivider })?.frame
            return
        }
        guard let widest = own.max(by: { $0.frame.width < $1.frame.width }) else { return nil }
        let dividers = own.filter { $0 != widest }.map(\.frame).sorted { $0.minX < $1.minX }
        guard let hidden = dividers.last else { return nil }
        self.hidden = hidden
        alwaysHidden = dividers.count > 1 ? dividers.first : nil
    }
}

enum StatusItemID {
    static let toggle = "BarkeepToggle"
    static let hiddenDivider = "BarkeepHiddenDivider"
    static let alwaysHiddenDivider = "BarkeepAlwaysHiddenDivider"
}
