import CoreGraphics

enum BarLayout {
    static let dividerLength: CGFloat = 12
    /// macOS 27 discards a status item at half the display width instead of clamping it,
    /// so a wide divider must stay below that on the narrowest display. Icons it displaces
    /// fall into the system overflow chevron.
    static let collapsedScreenFraction: CGFloat = 0.45
    static let fallbackCollapsedLength: CGFloat = 600

    static func collapsedLength(screenWidths: [CGFloat]) -> CGFloat {
        guard let narrowest = screenWidths.filter({ $0 > 0 }).min() else { return fallbackCollapsedLength }
        return (narrowest * collapsedScreenFraction).rounded(.down)
    }

    static func isInMenuBar(point: CGPoint, screenFrame: CGRect, menuBarHeight: CGFloat) -> Bool {
        point.x >= screenFrame.minX
            && point.x <= screenFrame.maxX
            && point.y <= screenFrame.maxY
            && point.y >= screenFrame.maxY - menuBarHeight
    }
}
