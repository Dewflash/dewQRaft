#!/usr/bin/env swift
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "/tmp/DewQRaft.iconset"
let outputURL = URL(fileURLWithPath: output)
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceURL = rootURL.appendingPathComponent("assets/app-icon-source.png")

try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard
    let sourceImage = NSImage(contentsOf: sourceURL),
    let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    fputs("Could not load app icon source at \(sourceURL.path)\n", stderr)
    exit(1)
}

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

func centeredCropRect(for image: CGImage) -> CGRect {
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let cropSize = min(height * 0.60, width * 0.328)
    return CGRect(
        x: (width - cropSize) / 2,
        y: (height - cropSize) / 2,
        width: cropSize,
        height: cropSize
    ).integral
}

func iconImage(size: CGFloat, crop: CGImage) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    ).addClip()
    NSImage(cgImage: crop, size: NSSize(width: crop.width, height: crop.height)).draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(x: 0, y: 0, width: crop.width, height: crop.height),
        operation: .copy,
        fraction: 1
    )
    image.unlockFocus()
    return image
}

let cropRect = centeredCropRect(for: sourceCGImage)
guard let croppedImage = sourceCGImage.cropping(to: cropRect) else {
    fputs("Could not crop app icon source\n", stderr)
    exit(1)
}

for (name, pointSize) in sizes {
    let image = iconImage(size: pointSize, crop: croppedImage)
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else { continue }
    try png.write(to: outputURL.appendingPathComponent(name))
}
