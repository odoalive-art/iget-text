#!/usr/bin/env swift

import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("TextGrabber.iconset", isDirectory: true)
let outputURL = resourcesURL.appendingPathComponent("TextGrabber.icns")

try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func roundedPath(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(
        roundedRect: NSRect(x: x, y: y, width: width, height: height),
        xRadius: radius,
        yRadius: radius
    )
}

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = size * 0.06
    let bodyRect = canvas.insetBy(dx: inset, dy: inset)
    let radius = size * 0.22
    let body = roundedPath(x: bodyRect.minX, y: bodyRect.minY, width: bodyRect.width, height: bodyRect.height, radius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.31, blue: 0.18, alpha: 1.0),
        NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.24, alpha: 1.0)
    ])!
    gradient.draw(in: body, angle: 135)

    NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
    body.lineWidth = max(1, size * 0.012)
    body.stroke()

    let cardRect = NSRect(
        x: size * 0.23,
        y: size * 0.24,
        width: size * 0.48,
        height: size * 0.54
    )
    let card = roundedPath(x: cardRect.minX, y: cardRect.minY, width: cardRect.width, height: cardRect.height, radius: size * 0.045)
    NSColor(calibratedWhite: 1.0, alpha: 0.94).setFill()
    card.fill()

    NSColor(calibratedWhite: 1.0, alpha: 0.7).setFill()
    roundedPath(x: size * 0.29, y: size * 0.65, width: size * 0.21, height: size * 0.04, radius: size * 0.02).fill()

    NSColor(calibratedRed: 0.22, green: 0.20, blue: 0.18, alpha: 0.72).setFill()
    for index in 0..<4 {
        let width = size * (index == 1 ? 0.32 : 0.27)
        let y = size * (0.56 - CGFloat(index) * 0.085)
        roundedPath(x: size * 0.30, y: y, width: width, height: size * 0.026, radius: size * 0.013).fill()
    }

    let lensRect = NSRect(x: size * 0.52, y: size * 0.25, width: size * 0.24, height: size * 0.24)
    let lens = NSBezierPath(ovalIn: lensRect)
    NSColor(calibratedWhite: 1.0, alpha: 0.98).setStroke()
    lens.lineWidth = size * 0.055
    lens.stroke()

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: size * 0.70, y: size * 0.30))
    handle.line(to: NSPoint(x: size * 0.82, y: size * 0.18))
    handle.lineCapStyle = .round
    NSColor(calibratedWhite: 1.0, alpha: 0.98).setStroke()
    handle.lineWidth = size * 0.07
    handle.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconEntries: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in iconEntries {
    let rep = drawIcon(size: entry.pixels)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: iconsetURL.appendingPathComponent(entry.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "TextGrabberIconGeneration", code: Int(process.terminationStatus))
}

try? FileManager.default.removeItem(at: iconsetURL)
print("Generated \(outputURL.path)")
