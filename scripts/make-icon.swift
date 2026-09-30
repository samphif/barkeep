// Draws the layers of Barkeep/AppIcon.icon. Run from the repo root:
//   swift scripts/make-icon.swift
import AppKit

let size = 1024
let outDir = URL(fileURLWithPath: "Barkeep/AppIcon.icon/Assets", isDirectory: true)
let previewURL = URL(fileURLWithPath: "build/icon-preview.png")

func render(_ name: String, _ draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.displayP3)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Top-left origin, like the design grid.
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
    draw(context)
    let image = context.makeImage()!
    if !name.isEmpty {
        let rep = NSBitmapImageRep(cgImage: image)
        try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(name).png"))
    }
    return image
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

// A menu bar: faded icons on the hidden side, a divider, the bow tie, then crisp icons.
func drawBar(_ c: CGContext) {
    let bar = CGRect(x: 172, y: 196, width: 680, height: 92)
    c.setFillColor(color(0xFFFFFF, 0.22))
    c.addPath(CGPath(roundedRect: bar, cornerWidth: 46, cornerHeight: 46, transform: nil))
    c.fillPath()

    let midY = bar.midY
    for (i, alpha) in [0.18, 0.3, 0.45].enumerated() {
        c.setFillColor(color(0xFFFFFF, alpha))
        c.fillEllipse(in: CGRect(x: 222 + CGFloat(i) * 70, y: midY - 18, width: 36, height: 36))
    }
    c.setFillColor(color(0xFFFFFF, 0.9))
    c.fill(CGRect(x: 443, y: midY - 28, width: 8, height: 56))

    c.setFillColor(color(0xFFFFFF))
    c.setStrokeColor(color(0xFFFFFF))
    c.setLineWidth(6)
    c.setLineJoin(.round)
    for (inner, outer) in [(CGFloat(508), CGFloat(482)), (CGFloat(532), CGFloat(558))] {
        c.move(to: CGPoint(x: inner, y: midY - 8))
        c.addLine(to: CGPoint(x: outer, y: midY - 22))
        c.addLine(to: CGPoint(x: outer, y: midY + 22))
        c.addLine(to: CGPoint(x: inner, y: midY + 8))
        c.closePath()
    }
    c.drawPath(using: .fillStroke)
    c.addPath(CGPath(roundedRect: CGRect(x: 507, y: midY - 11, width: 26, height: 22), cornerWidth: 7, cornerHeight: 7, transform: nil))
    c.fillPath()

    for i in 0..<3 {
        c.fillEllipse(in: CGRect(x: 588 + CGFloat(i) * 76, y: midY - 20, width: 40, height: 40))
    }
}

let rimY: CGFloat = 360
let tipY: CGFloat = 648
let rimLeft: CGFloat = 268
let rimRight: CGFloat = 756

func drawGlass(_ c: CGContext) {
    // One path, so the translucent bowl and stem don't double up where they meet.
    c.setFillColor(color(0xFFFFFF, 0.92))
    c.move(to: CGPoint(x: rimLeft, y: rimY))
    c.addLine(to: CGPoint(x: rimRight, y: rimY))
    c.addLine(to: CGPoint(x: 512, y: tipY))
    c.closePath()
    c.addRect(CGRect(x: 496, y: tipY - 24, width: 32, height: 210))
    c.addPath(CGPath(roundedRect: CGRect(x: 382, y: 822, width: 260, height: 38), cornerWidth: 19, cornerHeight: 19, transform: nil))
    c.fillPath(using: .winding)
}

func drawDrink(_ c: CGContext) {
    // The liquid fills the bowl below this line, inset from the glass.
    let surfaceY: CGFloat = 414
    let inset: CGFloat = 26
    let t = (surfaceY - rimY) / (tipY - rimY)
    let left = rimLeft + (512 - rimLeft) * t + inset
    let right = rimRight - (rimRight - 512) * t - inset
    let gradient = CGGradient(colorsSpace: nil, colors: [color(0xFFC857), color(0xF77F00)] as CFArray, locations: [0, 1])!
    c.saveGState()
    c.move(to: CGPoint(x: left, y: surfaceY))
    c.addLine(to: CGPoint(x: right, y: surfaceY))
    c.addLine(to: CGPoint(x: 512, y: tipY - inset * 1.4))
    c.closePath()
    c.clip()
    c.drawLinearGradient(gradient, start: CGPoint(x: 512, y: surfaceY), end: CGPoint(x: 512, y: tipY), options: [])
    c.restoreGState()

    c.setStrokeColor(color(0x5B3A1A))
    c.setLineWidth(8)
    c.setLineCap(.round)
    c.move(to: CGPoint(x: 552, y: 494))
    c.addLine(to: CGPoint(x: 648, y: 322))
    c.strokePath()
    c.setFillColor(color(0x7BA23F))
    c.fillEllipse(in: CGRect(x: 530, y: 452, width: 70, height: 70))
    c.setFillColor(color(0xC8102E))
    c.fillEllipse(in: CGRect(x: 555, y: 477, width: 20, height: 20))
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let layers = [render("bar", drawBar), render("glass", drawGlass), render("drink", drawDrink)]

// A rough flat preview: the background gradient, the macOS squircle mask, and the layers.
let preview = render("") { c in
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    c.addPath(CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil))
    c.clip()
    let background = CGGradient(colorsSpace: nil, colors: [color(0x3A3F9E), color(0x151836)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(background, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    // Layers are drawn full-canvas, then scaled into the body like the system does.
    for layer in layers {
        c.saveGState()
        c.translateBy(x: 100, y: 924)
        c.scaleBy(x: 824 / 1024, y: -824 / 1024)
        c.draw(layer, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        c.restoreGState()
    }
}
try FileManager.default.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try NSBitmapImageRep(cgImage: preview).representation(using: .png, properties: [:])!.write(to: previewURL)
print("Wrote layers to \(outDir.path) and a preview to \(previewURL.path)")
