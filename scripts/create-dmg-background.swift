import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 960
let height = 560
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let colors = [
    CGColor(red: 0.035, green: 0.055, blue: 0.13, alpha: 1),
    CGColor(red: 0.075, green: 0.12, blue: 0.27, alpha: 1),
]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: width, y: height), options: [])

func drawOrb(center: CGPoint, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

drawOrb(center: CGPoint(x: 130, y: 480), radius: 180, color: CGColor(red: 0.16, green: 0.45, blue: 1, alpha: 0.16))
drawOrb(center: CGPoint(x: 850, y: 110), radius: 220, color: CGColor(red: 0.25, green: 0.85, blue: 0.95, alpha: 0.12))

func drawText(_ string: String, at point: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [
        .font: font,
        .foregroundColor: color,
    ]))
    context.textPosition = point
    CTLineDraw(line, context)
}

drawText("Convert", at: CGPoint(x: 90, y: 355), size: 48, color: .white, weight: .semibold)
drawText("Drag to Applications to install", at: CGPoint(x: 92, y: 315), size: 19, color: NSColor.white.withAlphaComponent(0.72))

context.setStrokeColor(NSColor.white.withAlphaComponent(0.72).cgColor)
context.setLineWidth(4)
context.setLineCap(.round)
context.move(to: CGPoint(x: 440, y: 280))
context.addLine(to: CGPoint(x: 520, y: 280))
context.addLine(to: CGPoint(x: 500, y: 300))
context.move(to: CGPoint(x: 520, y: 280))
context.addLine(to: CGPoint(x: 500, y: 260))
context.strokePath()

guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
