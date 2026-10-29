import AppKit
import Foundation

// Original app artwork. The same drawing is rendered at every macOS icon size.
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func render(size: Int, name: String) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                       isPlanar: false, colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "OpenRightIcon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let transform = AffineTransform(scale: CGFloat(size) / 1024)
    (transform as NSAffineTransform).concat()

    let bounds = NSRect(x: 64, y: 64, width: 896, height: 896)
    let tile = NSBezierPath(roundedRect: bounds, xRadius: 202, yRadius: 202)
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.09, green: 0.19, blue: 0.22, alpha: 1),
                              ending: NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.10, alpha: 1))!
    gradient.draw(in: tile, angle: 90)
    NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
    tile.lineWidth = 4
    tile.stroke()

    let command = "⌘" as NSString
    command.draw(in: NSRect(x: 194, y: 220, width: 640, height: 640), withAttributes: [
        .font: NSFont.systemFont(ofSize: 540, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1)
    ])

    let badge = NSBezierPath(roundedRect: NSRect(x: 592, y: 108, width: 268, height: 200),
                             xRadius: 76, yRadius: 76)
    NSColor(calibratedRed: 0.28, green: 0.88, blue: 0.73, alpha: 1).setFill()
    badge.fill()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 656, y: 208))
    arrow.line(to: NSPoint(x: 796, y: 208))
    arrow.move(to: NSPoint(x: 748, y: 254))
    arrow.line(to: NSPoint(x: 796, y: 208))
    arrow.line(to: NSPoint(x: 748, y: 162))
    arrow.lineWidth = 22
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(calibratedRed: 0.03, green: 0.18, blue: 0.17, alpha: 1).setStroke()
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "OpenRightIcon", code: 2)
    }
    try data.write(to: outputDirectory.appendingPathComponent(name))
}

for baseSize in [16, 32, 128, 256, 512] {
    try render(size: baseSize, name: "icon_\(baseSize)x\(baseSize).png")
    try render(size: baseSize * 2, name: "icon_\(baseSize)x\(baseSize)@2x.png")
}
