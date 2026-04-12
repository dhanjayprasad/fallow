#!/usr/bin/env swift
// generate-icon.swift
// Generates all macOS app icon sizes for Fallow using CoreGraphics.
// Run: swift scripts/generate-icon.swift
// Part of Fallow. MIT licence.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outputDir = "Fallow/Fallow/Resources/Assets.xcassets/AppIcon.appiconset"

// All required macOS icon sizes: (point size, scale, pixel size)
let iconSizes: [(label: String, pixels: Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

func drawIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Background: rounded squircle with green gradient
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22 // macOS icon corner radius ratio
    let path = CGPath(roundedRect: rect.insetBy(dx: s * 0.02, dy: s * 0.02),
                      cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                      transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Gradient: warm earth green to darker green
    let gradientColors = [
        CGColor(red: 0.42, green: 0.65, blue: 0.32, alpha: 1.0),
        CGColor(red: 0.22, green: 0.40, blue: 0.18, alpha: 1.0),
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: s, y: 0),
                               options: [])
    }

    // Draw a simple leaf/sprout shape in white
    let leafPath = CGMutablePath()
    let cx = s * 0.5
    let cy = s * 0.45

    // Stem
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.setLineWidth(s * 0.03)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: cx, y: s * 0.25))
    ctx.addLine(to: CGPoint(x: cx, y: s * 0.7))
    ctx.strokePath()

    // Left leaf
    leafPath.move(to: CGPoint(x: cx, y: cy))
    leafPath.addQuadCurve(to: CGPoint(x: cx - s * 0.22, y: cy - s * 0.18),
                          control: CGPoint(x: cx - s * 0.25, y: cy + s * 0.05))
    leafPath.addQuadCurve(to: CGPoint(x: cx, y: cy),
                          control: CGPoint(x: cx - s * 0.08, y: cy - s * 0.25))

    // Right leaf
    leafPath.move(to: CGPoint(x: cx, y: cy - s * 0.08))
    leafPath.addQuadCurve(to: CGPoint(x: cx + s * 0.22, y: cy - s * 0.26),
                          control: CGPoint(x: cx + s * 0.25, y: cy - s * 0.03))
    leafPath.addQuadCurve(to: CGPoint(x: cx, y: cy - s * 0.08),
                          control: CGPoint(x: cx + s * 0.08, y: cy - s * 0.33))

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.addPath(leafPath)
    ctx.fillPath()

    return ctx.makeImage()
}

func saveImage(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// Generate all sizes
var generated = 0
for entry in iconSizes {
    guard let image = drawIcon(size: entry.pixels) else {
        print("ERROR: Failed to draw \(entry.label) (\(entry.pixels)px)")
        continue
    }
    let path = "\(outputDir)/\(entry.label).png"
    if saveImage(image, to: path) {
        print("  Generated \(entry.label).png (\(entry.pixels)x\(entry.pixels))")
        generated += 1
    } else {
        print("ERROR: Failed to save \(path)")
    }
}

print("\nGenerated \(generated)/\(iconSizes.count) icon files")

// Update Contents.json
let contentsPath = "\(outputDir)/Contents.json"
let sizes: [(size: String, scale: String, filename: String)] = [
    ("16x16",   "1x", "icon_16x16.png"),
    ("16x16",   "2x", "icon_16x16@2x.png"),
    ("32x32",   "1x", "icon_32x32.png"),
    ("32x32",   "2x", "icon_32x32@2x.png"),
    ("128x128", "1x", "icon_128x128.png"),
    ("128x128", "2x", "icon_128x128@2x.png"),
    ("256x256", "1x", "icon_256x256.png"),
    ("256x256", "2x", "icon_256x256@2x.png"),
    ("512x512", "1x", "icon_512x512.png"),
    ("512x512", "2x", "icon_512x512@2x.png"),
]

var imagesJSON = "[\n"
for (i, entry) in sizes.enumerated() {
    imagesJSON += """
        {
          "filename" : "\(entry.filename)",
          "idiom" : "mac",
          "scale" : "\(entry.scale)",
          "size" : "\(entry.size)"
        }
    """
    if i < sizes.count - 1 { imagesJSON += "," }
    imagesJSON += "\n"
}
imagesJSON += "  ]"

let contentsJSON = """
{
  "images" : \(imagesJSON),
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try! contentsJSON.write(toFile: contentsPath, atomically: true, encoding: .utf8)
print("Updated \(contentsPath)")
