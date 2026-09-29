import CoreGraphics
import Foundation

enum RevealState: Equatable {
    case collapsed
    case expanded
    case expandedAll
}

struct DividerLengths: Equatable {
    let hidden: CGFloat
    let alwaysHidden: CGFloat
}

enum BarLayout {
    static let dividerLength: CGFloat = 12
    /// Wide enough to push everything left of a divider past the left edge of any display.
    static let collapsedLength: CGFloat = 10_000

    static func lengths(for state: RevealState) -> DividerLengths {
        switch state {
        case .collapsed:
            DividerLengths(hidden: collapsedLength, alwaysHidden: dividerLength)
        case .expanded:
            DividerLengths(hidden: dividerLength, alwaysHidden: collapsedLength)
        case .expandedAll:
            DividerLengths(hidden: dividerLength, alwaysHidden: dividerLength)
        }
    }

    /// Collapsing is only safe when each divider sits to the left of the item it guards;
    /// otherwise the chevron itself would be pushed off screen.
    /// On macOS 27 the menu bar is drawn by MenuBarAgent and status item windows report
    /// overlapping placeholder frames, so ordering can only be judged when frames are disjoint.
    static func isOrdered(toggle: CGRect, hidden: CGRect, alwaysHidden: CGRect?) -> Bool {
        guard isLeft(hidden, of: toggle) else { return false }
        guard let alwaysHidden else { return true }
        return isLeft(alwaysHidden, of: hidden)
    }

    private static func isLeft(_ item: CGRect, of other: CGRect) -> Bool {
        if item.intersects(other) { return true }
        return item.maxX <= other.minX
    }

    static func isInMenuBar(point: CGPoint, screenFrame: CGRect, menuBarHeight: CGFloat) -> Bool {
        point.x >= screenFrame.minX
            && point.x <= screenFrame.maxX
            && point.y <= screenFrame.maxY
            && point.y >= screenFrame.maxY - menuBarHeight
    }

    static func shouldRehide(now: Date, revealedAt: Date, delay: TimeInterval?, mouseInMenuBar: Bool) -> Bool {
        guard let delay, !mouseInMenuBar else { return false }
        return now.timeIntervalSince(revealedAt) >= delay
    }
}
