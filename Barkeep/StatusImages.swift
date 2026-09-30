import AppKit

@MainActor
enum StatusImages {
    static let divider = makeDivider(dotted: false, description: "Barkeep divider")
    static let alwaysHiddenDivider = makeDivider(dotted: true, description: "Barkeep always-hidden divider")

    /// A bow tie, like Bartender's: solid while items are hidden, outlined while they show.
    static let showHidden = makeBowTie(filled: true, description: "Show hidden menu bar items")
    static let hideItems = makeBowTie(filled: false, description: "Hide menu bar items")

    private static func makeBowTie(filled: Bool, description: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 14), flipped: false) { _ in
            NSColor.black.set()
            let wings = NSBezierPath()
            for (inner, outer) in [(8.0, 2.0), (12.0, 18.0)] {
                wings.move(to: NSPoint(x: inner, y: 5.25))
                wings.line(to: NSPoint(x: outer, y: 2))
                wings.line(to: NSPoint(x: outer, y: 12))
                wings.line(to: NSPoint(x: inner, y: 8.75))
                wings.close()
            }
            wings.lineJoinStyle = .round
            wings.lineWidth = 1.5
            wings.stroke()
            let knot = NSRect(x: 7.75, y: 4.5, width: 4.5, height: 5)
            if filled {
                wings.fill()
                // A thin gap keeps the knot distinct from the solid wings.
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(roundedRect: knot.insetBy(dx: -1, dy: -1), xRadius: 2.5, yRadius: 2.5).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
            NSBezierPath(roundedRect: knot, xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
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
