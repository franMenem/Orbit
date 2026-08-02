#!/usr/bin/env swift
// Generates Orbit.app icon at exact pixel sizes using CGBitmapContext.
// Draws the Nocturne sidebar mark (orbit ellipse + core + satellite) over a
// deep-space background, matching Orbit/Views/Sidebar/OrbitLogo.swift.
// Run with: swift scripts/generate_icon.swift
import AppKit
import CoreGraphics

let outputDir = "Orbit/Assets.xcassets/AppIcon.appiconset"

// ── Core drawing into a CGContext ─────────────────────────────────────────────

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// Nocturne palette used by the mark: accent #9184D9, accent-300 #D2CEFD,
// background #12131F (Nocturne.bgDeep).
let accentRGB: (CGFloat, CGFloat, CGFloat) = (145, 132, 217)   // #9184D9
let satelliteRGB: (CGFloat, CGFloat, CGFloat) = (210, 206, 253) // #D2CEFD
let bgRGB: (CGFloat, CGFloat, CGFloat) = (18, 19, 31)           // #12131F

/// Returns a CGImage drawn at exactly `pixelSize` x `pixelSize` pixels.
func makeIcon(pixelSize: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize, height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: pixelSize * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let s = CGFloat(pixelSize)
    let cx = s / 2
    let cy = s / 2
    let u = s / 1024 // unit scale, so proportions match across all sizes

    // ── 1. Background: flat Nocturne.bgDeep with a very subtle vignette ──────
    ctx.setFillColor(cgColor(bgRGB.0, bgRGB.1, bgRGB.2))
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    let vignetteColors = [
        cgColor(accentRGB.0, accentRGB.1, accentRGB.2, 0.10),
        cgColor(bgRGB.0, bgRGB.1, bgRGB.2, 0.0)
    ] as CFArray
    if let vignette = CGGradient(colorsSpace: cs, colors: vignetteColors, locations: [0, 1]) {
        ctx.drawRadialGradient(vignette,
            startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
            endCenter: CGPoint(x: cx, y: cy), endRadius: s * 0.62,
            options: [.drawsAfterEndLocation])
    }

    // ── 2. Orbit ellipse — rx 10.5 / ry 5 on a 24×24 viewBox, rotated -28° ────
    // Scaled up to the icon's own coordinate space (viewBox unit = s/24).
    let vb = s / 24
    let rx = 10.5 * vb
    let ry = 5.0 * vb
    let rotation = -28 * CGFloat.pi / 180
    let orbitLineWidth = max(1.4 * vb, 3 * u)

    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.rotate(by: rotation)
    let orbitRect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
    ctx.setStrokeColor(cgColor(accentRGB.0, accentRGB.1, accentRGB.2))
    ctx.setLineWidth(orbitLineWidth)
    ctx.addEllipse(in: orbitRect)
    ctx.strokePath()
    ctx.restoreGState()

    // ── 3. Central core — r 3.4 (viewBox units), filled accent ───────────────
    let coreR = 3.4 * vb
    ctx.setFillColor(cgColor(accentRGB.0, accentRGB.1, accentRGB.2))
    ctx.fillEllipse(in: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2))

    // ── 4. Satellite — r 1.9, riding the orbit rim, accent-300 fill ──────────
    let satelliteAngle: CGFloat = -.pi / 5
    let rawX = cos(satelliteAngle) * rx
    let rawY = sin(satelliteAngle) * ry
    let satX = cx + rawX * cos(rotation) - rawY * sin(rotation)
    let satY = cy + rawX * sin(rotation) + rawY * cos(rotation)
    let satR = 1.9 * vb
    ctx.setFillColor(cgColor(satelliteRGB.0, satelliteRGB.1, satelliteRGB.2))
    ctx.fillEllipse(in: CGRect(x: satX - satR, y: satY - satR, width: satR * 2, height: satR * 2))

    return ctx.makeImage()
}

// ── Save CGImage as PNG ───────────────────────────────────────────────────────

func savePNG(_ cgImage: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("❌ encode failed: \(path)"); return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("✅ \(path) (\(cgImage.width)×\(cgImage.height)px)")
    } catch {
        print("❌ \(path): \(error)")
    }
}

// ── Downscale a CGImage to a target pixel size ────────────────────────────────

func scaled(_ src: CGImage, to targetPx: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: targetPx, height: targetPx,
        bitsPerComponent: 8, bytesPerRow: targetPx * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: targetPx, height: targetPx))
    return ctx.makeImage()
}

// ── Generate ──────────────────────────────────────────────────────────────────

guard let master = makeIcon(pixelSize: 1024) else {
    print("❌ Failed to render master icon"); exit(1)
}

// (name, pixel size)
let targets: [(String, Int)] = [
    ("AppIcon-16.png",    16),
    ("AppIcon-32.png",    32),
    ("AppIcon-64.png",    64),
    ("AppIcon-128.png",   128),
    ("AppIcon-256.png",   256),
    ("AppIcon-512.png",   512),
    ("AppIcon-1024.png",  1024),
]

for (name, px) in targets {
    let img = px == 1024 ? master : (scaled(master, to: px) ?? master)
    savePNG(img, to: "\(outputDir)/\(name)")
}

print("\nDone! Icon files written to \(outputDir)/")
