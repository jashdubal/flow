// Renders the Flow app icon to PNG. Run: swift scripts/makeicon.swift <out.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let S: CGFloat = 1024

let img = NSImage(size: NSSize(width: S, height: S), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // macOS icon grid: content inset inside the 1024 canvas, superellipse-ish corner.
    let inset: CGFloat = 92
    let body = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    shape.addClip()

    // Near-black vertical gradient ground.
    let ground = NSGradient(colors: [NSColor(srgbRed: 0.09, green: 0.10, blue: 0.12, alpha: 1),
                                     NSColor(srgbRed: 0.03, green: 0.03, blue: 0.04, alpha: 1)])!
    ground.draw(in: body, angle: -90)

    // Faint terminal scanlines.
    NSColor.white.withAlphaComponent(0.022).setFill()
    var y = body.minY
    while y < body.maxY {
        NSRect(x: body.minX, y: y, width: body.width, height: 2).fill()
        y += 7
    }

    // Three ascending bars, razer green, centred on the body.
    let barW: CGFloat = 86
    let gap: CGFloat = 54
    let heights: [CGFloat] = [150, 250, 350]
    let totalW = barW * 3 + gap * 2
    let x0 = body.midX - totalW / 2
    let baseY = body.midY - 150

    let top = NSColor(srgbRed: 0.55, green: 1.0, blue: 0.38, alpha: 1)
    let bottom = NSColor(srgbRed: 0.16, green: 0.72, blue: 0.10, alpha: 1)

    // CGContext shadows are unreliable inside an NSImage draw block, so the bloom is
    // painted by hand: concentric translucent rects fading outward from each bar.
    for (i, h) in heights.enumerated() {
        let r = NSRect(x: x0 + CGFloat(i) * (barW + gap), y: baseY, width: barW, height: h)
        for step in stride(from: 46, through: 4, by: -6) {
            let g = CGFloat(step)
            NSColor(srgbRed: 0.27, green: 0.9, blue: 0.17, alpha: 0.035).setFill()
            r.insetBy(dx: -g, dy: -g).fill()
        }
    }

    for (i, h) in heights.enumerated() {
        let r = NSRect(x: x0 + CGFloat(i) * (barW + gap), y: baseY, width: barW, height: h)
        NSGradient(colors: [top, bottom])!.draw(in: r, angle: -90)
        // Hot cap on each bar.
        NSColor(srgbRed: 0.85, green: 1.0, blue: 0.75, alpha: 1).setFill()
        NSRect(x: r.minX, y: r.maxY - 9, width: barW, height: 9).fill()
    }

    // Baseline rule under the bars.
    NSColor(srgbRed: 0.35, green: 0.95, blue: 0.22, alpha: 0.55).setFill()
    NSRect(x: x0 - 34, y: baseY - 30, width: totalW + 68, height: 6).fill()

    // Corner ticks: a reticle framing the mark.
    NSColor(srgbRed: 0.35, green: 0.95, blue: 0.22, alpha: 0.28).setFill()
    let tick: CGFloat = 46, t: CGFloat = 5, pad: CGFloat = 78
    for (cx, cy, sx, sy) in [(body.minX + pad, body.minY + pad, 1.0, 1.0),
                             (body.maxX - pad, body.minY + pad, -1.0, 1.0),
                             (body.minX + pad, body.maxY - pad, 1.0, -1.0),
                             (body.maxX - pad, body.maxY - pad, -1.0, -1.0)] {
        let dx = CGFloat(sx), dy = CGFloat(sy)
        NSRect(x: min(cx, cx + dx * tick), y: cy, width: tick, height: t).fill()
        NSRect(x: cx, y: min(cy, cy + dy * tick), width: t, height: tick).fill()
    }

    ctx.restoreGState()

    // Inner hairline edge for that machined look.
    NSColor.white.withAlphaComponent(0.09).setStroke()
    shape.lineWidth = 3
    shape.stroke()
    return true
}

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("icon render failed\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
