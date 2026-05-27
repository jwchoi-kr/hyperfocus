#!/usr/bin/env swift
import AppKit

// Cyberpunk hourglass icon.
// Gradient flows cyan → violet → magenta top-to-bottom through the sand.
// Clean geometry: no excessive glow, just the shape and color.

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func linearGradient(colors: [CGColor], locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: colors as CFArray,
               locations: locations)!
}

// Hourglass glass wall: bezier curves so the sides flow smoothly
// out of the flat top/bottom edges (vertical tangent at corners).
func glassPath(cx: CGFloat, cy: CGFloat,
               gw: CGFloat, nw: CGFloat,
               topY: CGFloat, botY: CGFloat) -> CGPath {
    let h = topY - cy   // half-height of one chamber
    let p = CGMutablePath()

    p.move(to: CGPoint(x: cx - gw, y: topY))
    p.addLine(to: CGPoint(x: cx + gw, y: topY))          // top edge

    // Right: top-corner → neck  (vertical departure → sweep inward)
    p.addCurve(to:      CGPoint(x: cx + nw, y: cy),
               control1: CGPoint(x: cx + gw, y: topY - h * 0.55),
               control2: CGPoint(x: cx + nw * 2.8, y: cy + h * 0.22))

    // Right: neck → bottom-corner  (sweep outward → vertical arrival)
    p.addCurve(to:      CGPoint(x: cx + gw, y: botY),
               control1: CGPoint(x: cx + nw * 2.8, y: cy - h * 0.22),
               control2: CGPoint(x: cx + gw, y: botY + h * 0.55))

    p.addLine(to: CGPoint(x: cx - gw, y: botY))          // bottom edge

    // Left: bottom-corner → neck
    p.addCurve(to:      CGPoint(x: cx - nw, y: cy),
               control1: CGPoint(x: cx - gw, y: botY + h * 0.55),
               control2: CGPoint(x: cx - nw * 2.8, y: cy - h * 0.22))

    // Left: neck → top-corner
    p.addCurve(to:      CGPoint(x: cx - gw, y: topY),
               control1: CGPoint(x: cx - nw * 2.8, y: cy + h * 0.22),
               control2: CGPoint(x: cx - gw, y: topY - h * 0.55))

    p.closeSubpath()
    return p
}

// Simple rect spanning the full glass width — the glass clip handles the shape.
func sandRect(cx: CGFloat, gw: CGFloat, fromY: CGFloat, toY: CGFloat) -> CGRect {
    let minY = min(fromY, toY)
    let maxY = max(fromY, toY)
    return CGRect(x: cx - gw, y: minY, width: gw * 2, height: maxY - minY)
}

func drawIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus(); return img
    }

    // ── Background ──────────────────────────────────────────────────
    let bgRect  = CGRect(x: 0, y: 0, width: size, height: size)
    let bgCorner = size * 0.22
    let bgPath  = CGPath(roundedRect: bgRect, cornerWidth: bgCorner,
                         cornerHeight: bgCorner, transform: nil)
    ctx.setFillColor(rgb(0.024, 0.031, 0.071))   // #060814
    ctx.addPath(bgPath); ctx.fillPath()

    // Subtle radial vignette (lighter center)
    let vgColors = [rgb(0.12, 0.14, 0.26, 0.55),
                    rgb(0.00, 0.00, 0.00, 0.00)] as CFArray
    if let vg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: vgColors, locations: [0, 1]) {
        ctx.saveGState()
        ctx.addPath(bgPath); ctx.clip()
        ctx.drawRadialGradient(vg,
            startCenter: CGPoint(x: size/2, y: size/2), startRadius: 0,
            endCenter:   CGPoint(x: size/2, y: size/2), endRadius: size * 0.7,
            options: [])
        ctx.restoreGState()
    }

    // ── Geometry ─────────────────────────────────────────────────────
    let cx  = size / 2
    let cy  = size / 2
    let pad = size * 0.150               // breathing room from icon edge
    let gw  = size * 0.238               // 10% narrower
    let nw  = size * 0.028               // neck
    let topY = size - pad
    let botY = pad

    // Sand levels: upper ~62% full (from neck up), lower ~58% full (from bottom up)
    let upperSandY = cy + (topY - cy) * 0.62
    let lowerSandY = botY + (cy - botY) * 0.58

    let glass = glassPath(cx: cx, cy: cy, gw: gw, nw: nw, topY: topY, botY: botY)

    // ── Caps ──────────────────────────────────────────────────────────
    let capH = size * 0.062
    let capW = gw * 1.08
    let capR = capH * 0.38
    let capLineW = size * 0.011

    func drawCap(rect: CGRect, fill: CGColor, stroke: CGColor) {
        let p = CGPath(roundedRect: rect, cornerWidth: capR, cornerHeight: capR, transform: nil)
        ctx.setFillColor(fill)
        ctx.addPath(p); ctx.fillPath()
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(capLineW)
        ctx.addPath(p); ctx.strokePath()
    }

    // Top cap: cyan accent
    drawCap(rect: CGRect(x: cx - capW, y: topY, width: capW * 2, height: capH),
            fill:   rgb(0.00, 0.70, 0.90, 0.18),
            stroke: rgb(0.00, 0.88, 1.00, 0.90))

    // Bottom cap: magenta accent
    drawCap(rect: CGRect(x: cx - capW, y: botY - capH, width: capW * 2, height: capH),
            fill:   rgb(0.80, 0.10, 0.50, 0.18),
            stroke: rgb(1.00, 0.15, 0.65, 0.90))

    // ── Glass interior (dark fill) ─────────────────────────────────
    ctx.setFillColor(rgb(0.05, 0.07, 0.16, 0.55))
    ctx.addPath(glass); ctx.fillPath()

    // ── Upper sand (neck → upperSandY, clipped to glass) ─────────
    let upGrad = linearGradient(
        colors: [rgb(0.00, 0.90, 1.00, 0.92),
                 rgb(0.48, 0.18, 1.00, 0.88)],
        locations: [0, 1])
    ctx.saveGState()
    ctx.addPath(glass); ctx.clip()
    ctx.clip(to: sandRect(cx: cx, gw: gw, fromY: cy, toY: upperSandY))
    ctx.drawLinearGradient(upGrad,
        start: CGPoint(x: cx, y: upperSandY),
        end:   CGPoint(x: cx, y: cy),
        options: [])
    ctx.restoreGState()

    // ── Lower sand (botY → lowerSandY, clipped to glass) ─────────
    let loGrad = linearGradient(
        colors: [rgb(0.48, 0.18, 1.00, 0.88),
                 rgb(1.00, 0.14, 0.62, 0.92)],
        locations: [0, 1])
    ctx.saveGState()
    ctx.addPath(glass); ctx.clip()
    ctx.clip(to: sandRect(cx: cx, gw: gw, fromY: botY, toY: lowerSandY))
    ctx.drawLinearGradient(loGrad,
        start: CGPoint(x: cx, y: lowerSandY),
        end:   CGPoint(x: cx, y: botY),
        options: [])
    ctx.restoreGState()

    // ── Glass outline: soft glow then crisp line ──────────────────
    ctx.setLineJoin(.miter)

    // Glow layer (wider, low alpha)
    ctx.setStrokeColor(rgb(0.00, 0.88, 1.00, 0.18))
    ctx.setLineWidth(size * 0.045)
    ctx.addPath(glass); ctx.strokePath()

    // Crisp outline
    ctx.setStrokeColor(rgb(0.00, 0.88, 1.00, 0.82))
    ctx.setLineWidth(size * 0.013)
    ctx.addPath(glass); ctx.strokePath()

    img.unlockFocus()
    return img
}

// ── Output ────────────────────────────────────────────────────────────

func savePNG(_ img: NSImage, to path: String) {
    guard let tiff = img.tiffRepresentation,
          let bmp  = NSBitmapImageRep(data: tiff),
          let png  = bmp.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
    print("Saved \(path)")
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

if CommandLine.arguments.count > 2, CommandLine.arguments[2] == "--all" {
    let sizes: [(String, CGFloat)] = [
        ("icon_16x16.png", 16),       ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),       ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),    ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),    ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),    ("icon_512x512@2x.png", 1024),
    ]
    for (name, px) in sizes {
        savePNG(drawIcon(size: px), to: "\(outDir)/\(name)")
    }
} else {
    savePNG(drawIcon(size: 512), to: "\(outDir)/preview.png")
}

print("Done.")
