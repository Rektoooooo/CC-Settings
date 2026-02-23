#!/usr/bin/env swift

import AppKit
import CoreGraphics

// Generate app icon: gear on terracotta gradient with rounded square mask
func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Rounded rectangle path (22.37% corner radius)
    let cornerRadius = s * 0.2237
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Clip to rounded rectangle
    context.addPath(path)
    context.clip()

    // Background gradient: #E88B6F -> #CC785C (top-left to bottom-right)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0xE8/255.0, green: 0x8B/255.0, blue: 0x6F/255.0, alpha: 1.0),
        CGColor(red: 0xCC/255.0, green: 0x78/255.0, blue: 0x5C/255.0, alpha: 1.0)
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
        // top-left to bottom-right (in flipped coords: bottom-left to top-right in CG)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: s, y: 0),
            options: []
        )
    }

    // Draw gear icon
    let center = CGPoint(x: s / 2, y: s / 2)
    let gearSize = s * 0.32  // outer radius of gear
    let innerRadius = gearSize * 0.65
    let holeRadius = gearSize * 0.28
    let toothCount = 12
    let toothDepth = gearSize * 0.22
    let toothWidth: CGFloat = .pi / CGFloat(toothCount) * 0.6

    // Gear color: white with 95% opacity
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))

    // Build gear path
    let gearPath = CGMutablePath()
    let steps = toothCount * 2
    for i in 0..<steps {
        let angle = CGFloat(i) * .pi / CGFloat(toothCount) - .pi / 2
        let isOuter = i % 2 == 0
        let radius = isOuter ? gearSize : gearSize - toothDepth

        if isOuter {
            // Tooth top
            let a1 = angle - toothWidth / 2
            let a2 = angle + toothWidth / 2
            let p1 = CGPoint(x: center.x + cos(a1) * radius, y: center.y + sin(a1) * radius)
            let p2 = CGPoint(x: center.x + cos(a2) * radius, y: center.y + sin(a2) * radius)
            if i == 0 {
                gearPath.move(to: p1)
            } else {
                gearPath.addLine(to: p1)
            }
            gearPath.addLine(to: p2)
        } else {
            // Valley
            let a1 = angle - toothWidth / 2
            let a2 = angle + toothWidth / 2
            let p1 = CGPoint(x: center.x + cos(a1) * radius, y: center.y + sin(a1) * radius)
            let p2 = CGPoint(x: center.x + cos(a2) * radius, y: center.y + sin(a2) * radius)
            gearPath.addLine(to: p1)
            gearPath.addLine(to: p2)
        }
    }
    gearPath.closeSubpath()

    // Inner circle (subtracted via even-odd rule)
    gearPath.addEllipse(in: CGRect(
        x: center.x - holeRadius,
        y: center.y - holeRadius,
        width: holeRadius * 2,
        height: holeRadius * 2
    ))

    // Draw with shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.016, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.2))
    context.addPath(gearPath)
    context.fillPath(using: .evenOdd)
    context.restoreGState()

    // Draw inner circle gradient overlay for 3D effect
    context.saveGState()
    let innerCirclePath = CGMutablePath()
    let innerGearRadius = gearSize - toothDepth
    innerCirclePath.addEllipse(in: CGRect(
        x: center.x - innerGearRadius,
        y: center.y - innerGearRadius,
        width: innerGearRadius * 2,
        height: innerGearRadius * 2
    ))
    innerCirclePath.addEllipse(in: CGRect(
        x: center.x - holeRadius,
        y: center.y - holeRadius,
        width: holeRadius * 2,
        height: holeRadius * 2
    ))
    context.addPath(innerCirclePath)
    context.clip(using: .evenOdd)

    let faceColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.15),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    if let faceGradient = CGGradient(colorsSpace: colorSpace, colors: faceColors, locations: locations) {
        context.drawLinearGradient(
            faceGradient,
            start: CGPoint(x: center.x, y: center.y + innerGearRadius),
            end: CGPoint(x: center.x, y: center.y - innerGearRadius),
            options: []
        )
    }
    context.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Generated: \(path)")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Icon sizes: (point size, scale, pixel size)
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let outputDir = "CC Settings/Resources/Assets.xcassets/AppIcon.appiconset"

for entry in sizes {
    let image = generateIcon(size: entry.pixels)
    savePNG(image, to: "\(outputDir)/\(entry.name)")
}

print("All icons generated!")
