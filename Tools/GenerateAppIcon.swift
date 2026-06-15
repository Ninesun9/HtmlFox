import AppKit
import CoreGraphics

struct RGB {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ hex: UInt32, alpha: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xff) / 255
        g = CGFloat((hex >> 8) & 0xff) / 255
        b = CGFloat(hex & 0xff) / 255
        a = alpha
    }

    var cg: CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
}

let outputDir = URL(fileURLWithPath: "HtmlFoxIOS/Assets.xcassets/AppIcon.appiconset")
let sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]

func point(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> CGPoint {
    CGPoint(x: x * scale, y: y * scale)
}

func drawIcon(size: Int) -> NSImage {
    let scale = CGFloat(size) / 1024
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high

    context.setFillColor(RGB(0x111319).cg)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            RGB(0x1B1E27).cg,
            RGB(0x111319).cg,
            RGB(0x08090D).cg
        ] as CFArray,
        locations: [0, 0.62, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 180, y: 1024),
        end: CGPoint(x: 900, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: RGB(0x000000, alpha: 0.28).cg)
    context.setLineWidth(76)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let ivory = RGB(0xF3EFE5).cg
    context.setStrokeColor(ivory)

    let topArc = CGMutablePath()
    topArc.move(to: CGPoint(x: 346, y: 690))
    topArc.addCurve(to: CGPoint(x: 512, y: 770), control1: CGPoint(x: 390, y: 740), control2: CGPoint(x: 454, y: 770))
    topArc.addCurve(to: CGPoint(x: 678, y: 690), control1: CGPoint(x: 570, y: 770), control2: CGPoint(x: 634, y: 740))
    context.addPath(topArc)
    context.strokePath()

    let bottomArc = CGMutablePath()
    bottomArc.move(to: CGPoint(x: 346, y: 334))
    bottomArc.addCurve(to: CGPoint(x: 512, y: 254), control1: CGPoint(x: 390, y: 284), control2: CGPoint(x: 454, y: 254))
    bottomArc.addCurve(to: CGPoint(x: 678, y: 334), control1: CGPoint(x: 570, y: 254), control2: CGPoint(x: 634, y: 284))
    context.addPath(bottomArc)
    context.strokePath()

    let leftChevron = CGMutablePath()
    leftChevron.move(to: CGPoint(x: 400, y: 650))
    leftChevron.addLine(to: CGPoint(x: 286, y: 512))
    leftChevron.addLine(to: CGPoint(x: 400, y: 374))
    context.addPath(leftChevron)
    context.strokePath()

    let rightChevron = CGMutablePath()
    rightChevron.move(to: CGPoint(x: 624, y: 650))
    rightChevron.addLine(to: CGPoint(x: 738, y: 512))
    rightChevron.addLine(to: CGPoint(x: 624, y: 374))
    context.addPath(rightChevron)
    context.strokePath()

    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: RGB(0x4DE8D3, alpha: 0.2).cg)
    context.setStrokeColor(RGB(0x76F2DC).cg)
    context.setLineWidth(56)

    let slash = CGMutablePath()
    slash.move(to: CGPoint(x: 570, y: 662))
    slash.addLine(to: CGPoint(x: 454, y: 362))
    context.addPath(slash)
    context.strokePath()

    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setFillColor(RGB(0x76F2DC, alpha: 0.18).cg)
    context.fillEllipse(in: CGRect(x: 456, y: 456, width: 112, height: 112))

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "Icon", code: 1)
    }

    try png.write(to: url)
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

for size in sizes {
    let image = drawIcon(size: size)
    try writePNG(image, to: outputDir.appendingPathComponent("AppIcon-\(size).png"))
}
