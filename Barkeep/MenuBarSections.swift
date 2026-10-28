import CoreGraphics
import Foundation

enum MenuBarSection: Int, Comparable, CaseIterable {
    case visible
    case hidden
    case alwaysHidden

    static func < (lhs: MenuBarSection, rhs: MenuBarSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Numeric ids `MenuBarClientCore` accepts for macOS's own status items.
/// Values match `MBSystemItemIdentifier` on macOS 27 (battery 0 … Control Center 8).
enum SystemItemID: Int, CaseIterable {
    case battery = 0
    case bluetooth = 1
    case clock = 2
    case displays = 3
    case keyboard = 4
    case volume = 5
    case wifi = 6
    case screenMirroring = 7
    case controlCenter = 8

    /// Clock and Control Center stay on the far right; never hide them via the allow-list.
    static let alwaysVisible: Set<SystemItemID> = [.clock, .controlCenter]
    /// Wide enough that identifiers added after battery…Control Center still stay visible.
    /// `0..<64` silently drops Screen Mirroring on some builds.
    static let allowListRange = 0...255

    /// Accessibility identifiers Control Center / MenuBarAgent expose for each item.
    init?(identifier: String?) {
        guard let identifier else { return nil }
        switch identifier {
        case "com.apple.menuextra.battery": self = .battery
        case "com.apple.menuextra.bluetooth": self = .bluetooth
        case "com.apple.menuextra.clock": self = .clock
        case "com.apple.menuextra.displays", "com.apple.menuextra.display": self = .displays
        case "com.apple.menuextra.TextInputMenuAgent", "com.apple.menuextra.keyboard": self = .keyboard
        case "com.apple.menuextra.volume", "com.apple.menuextra.sound": self = .volume
        case "com.apple.menuextra.wifi", "com.apple.menuextra.airport": self = .wifi
        case "com.apple.menuextra.ScreenMirroring", "com.apple.menuextra.airplay": self = .screenMirroring
        case "com.apple.menuextra.controlcenter": self = .controlCenter
        default: return nil
        }
    }
}

/// Which section each app's icons sit in, from where the user ⌘-dragged them:
///
///     [ always hidden ] ┊ [ hidden ] │ [ visible ]
///
/// Hiding works per app, so an app with several icons gets its most visible section.
/// System items are tracked separately by `SystemItemID`, so Battery left of the divider
/// can hide while Control Center stays visible.
struct MenuBarSections: Equatable {
    /// macOS agents whose icons are allow-listed by system-item id, not by bundle id.
    static let systemOwners: Set<String> = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"]

    private(set) var byOwner: [String: MenuBarSection] = [:]
    /// Section for each identifiable system item the user has positioned.
    private(set) var bySystemItem: [SystemItemID: MenuBarSection] = [:]

    func owners(in sections: Set<MenuBarSection>) -> [String] {
        byOwner.filter { sections.contains($0.value) }.map(\.key).sorted()
    }

    /// System-item ids that should stay drawn for the currently shown sections.
    /// Unknown ids stay allowed so a future macOS item isn't silently dropped.
    func allowedSystemItems(shown: Set<MenuBarSection>) -> [NSNumber] {
        let hidden = Set(
            bySystemItem.compactMap { id, section -> Int? in
                if SystemItemID.alwaysVisible.contains(id) || shown.contains(section) { return nil }
                return id.rawValue
            }
        )
        return SystemItemID.allowListRange.filter { !hidden.contains($0) }.map { NSNumber(value: $0) }
    }

    /// Nil when Barkeep's own divider can't be found, since nothing can be judged then.
    init?(snapshot: MenuBarSnapshot, screens: [CGRect], ownerToSkip: String?) {
        guard let dividers = Dividers(own: snapshot.own),
              let hiddenOffset = Self.offsetFromRightEdge(of: dividers.hidden, screens: screens) else { return nil }
        let alwaysHiddenOffset = dividers.alwaysHidden.flatMap { Self.offsetFromRightEdge(of: $0, screens: screens) }

        for item in snapshot.others {
            guard let owner = item.owner, owner != ownerToSkip else { continue }
            let section = Self.section(for: item.frame, hiddenOffset: hiddenOffset, alwaysHiddenOffset: alwaysHiddenOffset, screens: screens)

            if Self.systemOwners.contains(owner) {
                if let id = SystemItemID(identifier: item.identifier), !SystemItemID.alwaysVisible.contains(id) {
                    bySystemItem[id] = min(bySystemItem[id] ?? section, section)
                }
                continue
            }

            byOwner[owner] = min(byOwner[owner] ?? section, section)
        }
    }

    private init(byOwner: [String: MenuBarSection], bySystemItem: [SystemItemID: MenuBarSection]) {
        self.byOwner = byOwner
        self.bySystemItem = bySystemItem
    }

    /// Hidden items report stale frames, so owners the current restriction hides keep
    /// their last known section, as do apps too busy to answer this time.
    func updated(with fresh: MenuBarSections, keeping hiddenOwners: Set<String>, keepingSystemItems hiddenSystemItems: Set<SystemItemID> = []) -> MenuBarSections {
        var mergedOwners = byOwner.merging(fresh.byOwner) { _, new in new }
        for owner in hiddenOwners {
            if let section = byOwner[owner] { mergedOwners[owner] = section }
        }
        var mergedSystem = bySystemItem.merging(fresh.bySystemItem) { _, new in new }
        for id in hiddenSystemItems {
            if let section = bySystemItem[id] { mergedSystem[id] = section }
        }
        return MenuBarSections(byOwner: mergedOwners, bySystemItem: mergedSystem)
    }

    private static func section(for frame: CGRect, hiddenOffset: CGFloat, alwaysHiddenOffset: CGFloat?, screens: [CGRect]) -> MenuBarSection {
        guard let offset = offsetFromRightEdge(of: frame, screens: screens) else {
            // An item that isn't on any display is never hidden by guesswork.
            return .visible
        }
        if offset < hiddenOffset {
            return .visible
        } else if let alwaysHiddenOffset, offset > alwaysHiddenOffset {
            return .alwaysHidden
        } else {
            return .hidden
        }
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
