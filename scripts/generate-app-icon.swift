import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "GemmaDesktop.icns")
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("GemmaDesktop-\(UUID().uuidString).iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconImage {
    let name: String
    let size: CGFloat
}

let images = [
    IconImage(name: "icon_16x16.png", size: 16),
    IconImage(name: "icon_16x16@2x.png", size: 32),
    IconImage(name: "icon_32x32.png", size: 32),
    IconImage(name: "icon_32x32@2x.png", size: 64),
    IconImage(name: "icon_128x128.png", size: 128),
    IconImage(name: "icon_128x128@2x.png", size: 256),
    IconImage(name: "icon_256x256.png", size: 256),
    IconImage(name: "icon_256x256@2x.png", size: 512),
    IconImage(name: "icon_512x512.png", size: 512),
    IconImage(name: "icon_512x512@2x.png", size: 1024),
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.06
    let body = rect.insetBy(dx: inset, dy: inset)
    let corner = size * 0.22

    let shadow = NSShadow()
    shadow.shadowColor = color(0.0, 0.0, 0.0, 0.36)
    shadow.shadowBlurRadius = size * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.016)
    shadow.set()

    let bodyPath = NSBezierPath(roundedRect: body, xRadius: corner, yRadius: corner)
    color(0.055, 0.063, 0.075).setFill()
    bodyPath.fill()

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()

    let topBand = CGRect(x: body.minX, y: body.maxY - body.height * 0.24, width: body.width, height: body.height * 0.24)
    color(0.115, 0.129, 0.153).setFill()
    NSBezierPath(rect: topBand).fill()

    color(0.36, 0.62, 1.0, 0.13).setStroke()
    for step in stride(from: body.minX + body.width * 0.18, through: body.maxX, by: max(6, size * 0.12)) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: step, y: body.minY))
        path.line(to: CGPoint(x: step - body.width * 0.35, y: body.maxY))
        path.lineWidth = max(1, size * 0.006)
        path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()

    color(0.38, 0.94, 0.64, 0.85).setStroke()
    bodyPath.lineWidth = max(1.5, size * 0.018)
    bodyPath.stroke()

    let dotSize = max(2, size * 0.045)
    let dotY = body.maxY - body.height * 0.12
    let dotX = body.minX + body.width * 0.13
    for (offset, dotColor) in [
        (0.0, color(1.0, 0.34, 0.32)),
        (1.7, color(1.0, 0.78, 0.25)),
        (3.4, color(0.30, 0.84, 0.42)),
    ] {
        dotColor.setFill()
        NSBezierPath(ovalIn: CGRect(x: dotX + dotSize * offset, y: dotY, width: dotSize, height: dotSize)).fill()
    }

    let prompt = ">_"
    let promptFont = NSFont.monospacedSystemFont(ofSize: size * 0.30, weight: .bold)
    let promptAttributes: [NSAttributedString.Key: Any] = [
        .font: promptFont,
        .foregroundColor: color(0.38, 0.94, 0.64),
        .kern: -size * 0.012,
    ]
    let promptSize = prompt.size(withAttributes: promptAttributes)
    prompt.draw(
        at: CGPoint(
            x: body.minX + body.width * 0.16,
            y: body.minY + body.height * 0.34
        ),
        withAttributes: promptAttributes
    )

    let codexMark = "G"
    let markFont = NSFont.monospacedSystemFont(ofSize: size * 0.21, weight: .black)
    let markAttributes: [NSAttributedString.Key: Any] = [
        .font: markFont,
        .foregroundColor: color(0.96, 0.72, 0.31),
    ]
    let markSize = codexMark.size(withAttributes: markAttributes)
    codexMark.draw(
        at: CGPoint(
            x: body.maxX - markSize.width - body.width * 0.15,
            y: body.minY + body.height * 0.33
        ),
        withAttributes: markAttributes
    )

    if size >= 128 {
        let label = "LOCAL"
        let labelFont = NSFont.monospacedSystemFont(ofSize: size * 0.055, weight: .semibold)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: color(0.58, 0.61, 0.65),
        ]
        label.draw(
            at: CGPoint(
                x: body.minX + body.width * 0.17,
                y: body.minY + body.height * 0.17
            ),
            withAttributes: labelAttributes
        )
    }

    _ = promptSize
    return image
}

func writePNG(image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "GemmaIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url)
}

for item in images {
    try writePNG(image: drawIcon(size: item.size), to: iconsetURL.appendingPathComponent(item.name))
}

try? fileManager.removeItem(at: outputURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: iconsetURL)

guard process.terminationStatus == 0 else {
    throw NSError(domain: "GemmaIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}
