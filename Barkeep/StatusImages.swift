import AppKit

@MainActor
enum StatusImages {
    static let divider = makeDivider(dotted: false, description: "Barkeep divider")
    static let alwaysHiddenDivider = makeDivider(dotted: true, description: "Barkeep always-hidden divider")

    static let showHidden = symbol("chevron.left", description: "Show hidden menu bar items")
    static let hideItems = symbol("chevron.right", description: "Hide menu bar items")

    private static func symbol(_ name: String, description: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private static func makeDivider(dotted: Bool, description: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            if dotted {
                for y in stride(from: 1.0, to: 15.0, by: 4.0) {
                    NSBezierPath(ovalIn: NSRect(x: 1, y: y, width: 2, height: 2)).fill()
                }
            } else {
                NSBezierPath(roundedRect: NSRect(x: 1.25, y: 1, width: 1.5, height: 14), xRadius: 0.75, yRadius: 0.75).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }
}
