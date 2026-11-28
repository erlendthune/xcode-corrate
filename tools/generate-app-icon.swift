#!/usr/bin/env swift
import AppKit

// Build: swiftc tools/generate-app-icon.swift -o /tmp/generate-app-icon
// Run: /tmp/generate-app-icon /absolute/path/to/CoachIcon.png
// Full-bleed, opaque artwork: iOS applies its own icon corner mask.
guard CommandLine.arguments.count == 2 else {
    fatalError("Provide the output PNG path.")
}
let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create icon canvas.")
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
let navy = color(0.035, 0.075, 0.14)
NSGradient(starting: color(0.075, 0.17, 0.27), ending: navy)!
    .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -65)

// A custom heart silhouette with generous margins for the system mask.
let heart = NSBezierPath()
heart.move(to: NSPoint(x: 456, y: 256))
heart.curve(to: NSPoint(x: 196, y: 584),
            controlPoint1: NSPoint(x: 396, y: 316), controlPoint2: NSPoint(x: 196, y: 456))
heart.curve(to: NSPoint(x: 456, y: 686),
            controlPoint1: NSPoint(x: 196, y: 774), controlPoint2: NSPoint(x: 372, y: 822))
heart.curve(to: NSPoint(x: 716, y: 584),
            controlPoint1: NSPoint(x: 540, y: 822), controlPoint2: NSPoint(x: 716, y: 774))
heart.curve(to: NSPoint(x: 456, y: 256),
            controlPoint1: NSPoint(x: 716, y: 456), controlPoint2: NSPoint(x: 516, y: 316))
heart.close()
NSGradient(starting: color(0.40, 0.98, 0.77), ending: color(0.12, 0.78, 0.65))!
    .draw(in: heart, angle: -90)

// Thick, rounded pulse strokes remain legible at small home-screen sizes.
let pulse = NSBezierPath()
let points: [NSPoint] = [
    NSPoint(x: 276, y: 542), NSPoint(x: 356, y: 542),
    NSPoint(x: 400, y: 610), NSPoint(x: 466, y: 432),
    NSPoint(x: 518, y: 542), NSPoint(x: 636, y: 542)
]
pulse.move(to: points[0])
for point in points.dropFirst() { pulse.line(to: point) }
pulse.lineWidth = 38
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
navy.setStroke()
pulse.stroke()

// Two audio waves distinguish coaching from a generic heart-rate app.
color(0.92, 0.98, 1).setStroke()
for (x, halfHeight, bulge) in [(CGFloat(756), CGFloat(66), CGFloat(40)),
                              (CGFloat(819), CGFloat(112), CGFloat(66))] {
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: x, y: 542 - halfHeight))
    wave.curve(to: NSPoint(x: x, y: 542 + halfHeight),
               controlPoint1: NSPoint(x: x + bulge, y: 542 - halfHeight * 0.45),
               controlPoint2: NSPoint(x: x + bulge, y: 542 + halfHeight * 0.45))
    wave.lineWidth = 30
    wave.lineCapStyle = .round
    wave.stroke()
}

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon.")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
print("Generated opaque 1024×1024 app icon.")
