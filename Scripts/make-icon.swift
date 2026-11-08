// Renders the app icon to a 1024×1024 PNG.
// Usage: swift Scripts/make-icon.swift <output.png>
//
// Design by @jubinverse: a white rounded square with a black "island" pill across the
// middle, and a purple-to-blue gradient dot on its left, like a live activity indicator.
// Proportions come from the original Figma frame, mapped onto Apple's macOS icon grid
// (an 824-pt body centred in a 1024 canvas).
import AppKit

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Body: white rounded square with the standard macOS drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24,
              color: NSColor.black.withAlphaComponent(0.28).cgColor)
color(0xFFFFFF).setFill()
bodyPath.fill()
ctx.restoreGState()

// A barely-there vertical shade keeps the white from looking flat in the Dock.
ctx.saveGState()
bodyPath.addClip()
NSGradient(colors: [color(0xFFFFFF), color(0xF1F1F4)])!.draw(in: body, angle: -90)
ctx.restoreGState()

// Island pill: 75% of the body's width, 24% of its height, centred.
let pillWidth = body.width * 0.754
let pillHeight = body.width * 0.244
let pill = CGRect(x: body.midX - pillWidth / 2, y: body.midY - pillHeight / 2,
                  width: pillWidth, height: pillHeight)
color(0x000000).setFill()
NSBezierPath(roundedRect: pill, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()

// Gradient dot inset evenly from the pill's left end.
let inset = pillHeight * 0.095
let dotSize = pillHeight - inset * 2
let dot = CGRect(x: pill.minX + inset, y: pill.midY - dotSize / 2, width: dotSize, height: dotSize)
let dotPath = NSBezierPath(ovalIn: dot)
ctx.saveGState()
dotPath.addClip()
NSGradient(colors: [color(0xC58BFF), color(0x5B7BFA)])!.draw(in: dot, angle: -90)
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
