import CoreGraphics

enum RevealState: Equatable {
    case collapsed
    case expanded
    case expandedAll

    func toggled(showAll: Bool) -> RevealState {
        switch self {
        case .collapsed: showAll ? .expandedAll : .expanded
        case .expanded: showAll ? .expandedAll : .collapsed
        case .expandedAll: .collapsed
        }
    }

    /// Without the always-hidden section there is nothing extra to show.
    func normalized(alwaysHiddenEnabled: Bool) -> RevealState {
        self == .expandedAll && !alwaysHiddenEnabled ? .expanded : self
    }

    func dividerLengths(collapsed: CGFloat) -> DividerLengths {
        let narrow = BarLayout.dividerLength
        return switch self {
        case .collapsed: DividerLengths(hidden: collapsed, alwaysHidden: narrow)
        case .expanded: DividerLengths(hidden: narrow, alwaysHidden: collapsed)
        case .expandedAll: DividerLengths(hidden: narrow, alwaysHidden: narrow)
        }
    }
}

struct DividerLengths: Equatable {
    let hidden: CGFloat
    let alwaysHidden: CGFloat
}
