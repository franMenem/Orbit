#!/usr/bin/env swift
// Generates Orbit.app icon at exact pixel sizes using CGBitmapContext.
// Run with: swift scripts/generate_icon.swift
import AppKit
import CoreGraphics

let outputDir = "Orbit/Assets.xcassets/AppIcon.appiconset"

// ── Core drawing into a CGContext ─────────────────────────────────────────────

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

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

    // ── 1. Background: deep space radial gradient ─────────────────────────────
    let bgColors = [cgColor(12, 8, 35), cgColor(22, 14, 58), cgColor(10, 6, 28)] as CFArray
    let bgLocs: [CGFloat] = [0, 0.45, 1]
    let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: bgLocs)!
    ctx.drawRadialGradient(bgGrad,
        startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy * 0.65), endRadius: s * 0.78,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // ── 2. Deterministic star field ───────────────────────────────────────────
    var seed: UInt64 = 0xdeadbeef1234abcd
    func nextRand() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 33) / CGFloat(1 << 31)
    }
    let starCount = pixelSize > 128 ? 80 : (pixelSize > 32 ? 30 : 8)
    for _ in 0..<starCount {
        let sx  = nextRand() * s
        let sy  = nextRand() * s
        let sr  = nextRand() * (s * 0.0025) + (s * 0.0008)
        let al  = nextRand() * 0.5 + 0.2
        ctx.setFillColor(cgColor(200, 215, 255, al))
        ctx.fillEllipse(in: CGRect(x: sx-sr, y: sy-sr, width: sr*2, height: sr*2))
    }

    // ── 3. Helper: draw orbit ellipse with glow ───────────────────────────────
    func drawOrbit(rx: CGFloat, ry: CGFloat, angle: CGFloat,
                   color: CGColor, lineWidth: CGFloat, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: angle)
        let rect = CGRect(x: -rx, y: -ry, width: rx*2, height: ry*2)

        // Glow
        ctx.setStrokeColor(color.copy(alpha: alpha * 0.22)!)
        ctx.setLineWidth(lineWidth * 4)
        ctx.addEllipse(in: rect); ctx.strokePath()
        // Mid glow
        ctx.setStrokeColor(color.copy(alpha: alpha * 0.40)!)
        ctx.setLineWidth(lineWidth * 2)
        ctx.addEllipse(in: rect); ctx.strokePath()
        // Core line
        ctx.setStrokeColor(color.copy(alpha: alpha)!)
        ctx.setLineWidth(lineWidth)
        ctx.addEllipse(in: rect); ctx.strokePath()

        ctx.restoreGState()
    }

    let u = s / 1024  // unit scale
    let rw = max(1.5, 5.5 * u)

    // Outer orbit — electric blue
    drawOrbit(rx: 370*u, ry: 150*u, angle: -.pi / 9,
              color: cgColor(70, 155, 255), lineWidth: rw * 1.5, alpha: 0.78)
    // Inner orbit — violet
    drawOrbit(rx: 205*u, ry: 88*u, angle: .pi / 7.5,
              color: cgColor(150, 95, 255), lineWidth: rw * 1.1, alpha: 0.68)

    // ── 4. Satellite on outer orbit ───────────────────────────────────────────
    let orbitT: CGFloat  = -.pi * 0.21
    let tiltOut: CGFloat = -.pi / 9
    let rawX = cos(orbitT) * 370 * u
    let rawY = sin(orbitT) * 150 * u
    let satX = cx + rawX * cos(tiltOut) - rawY * sin(tiltOut)
    let satY = cy + rawX * sin(tiltOut) + rawY * cos(tiltOut)
    let satR = 22 * u

    // Satellite halo
    ctx.setFillColor(cgColor(255, 110, 80, 0.20))
    ctx.fillEllipse(in: CGRect(x: satX-satR*2.5, y: satY-satR*2.5, width: satR*5, height: satR*5))
    // Satellite body
    let satC = [cgColor(255, 185, 145), cgColor(255, 80, 55)] as CFArray
    let satG  = CGGradient(colorsSpace: cs, colors: satC, locations: nil)!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: satX-satR, y: satY-satR, width: satR*2, height: satR*2))
    ctx.clip()
    ctx.drawLinearGradient(satG,
        start: CGPoint(x: satX-satR, y: satY+satR),
        end:   CGPoint(x: satX+satR, y: satY-satR), options: [])
    ctx.restoreGState()

    // ── 5. Central planet ─────────────────────────────────────────────────────
    let pr = 88 * u

    // Outer aura
    let auraColors = [cgColor(50, 130, 255, 0.0), cgColor(50, 130, 255, 0.15), cgColor(50, 130, 255, 0.0)] as CFArray
    let auraLocs: [CGFloat] = [0, 0.5, 1]
    let auraGrad = CGGradient(colorsSpace: cs, colors: auraColors, locations: auraLocs)!
    ctx.drawRadialGradient(auraGrad,
        startCenter: CGPoint(x: cx, y: cy), startRadius: pr * 0.8,
        endCenter:   CGPoint(x: cx, y: cy), endRadius: pr * 2.8,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Planet body with radial gradient
    let pColors = [cgColor(155, 210, 255), cgColor(55, 118, 245), cgColor(18, 55, 175)] as CFArray
    let pLocs: [CGFloat] = [0, 0.5, 1]
    let pGrad  = CGGradient(colorsSpace: cs, colors: pColors, locations: pLocs)!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx-pr, y: cy-pr, width: pr*2, height: pr*2))
    ctx.clip()
    ctx.drawRadialGradient(pGrad,
        startCenter: CGPoint(x: cx - pr*0.22, y: cy + pr*0.22), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy), endRadius: pr,
        options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // Specular highlight
    let specC = [cgColor(255, 255, 255, 0.60), cgColor(255, 255, 255, 0.0)] as CFArray
    let specG  = CGGradient(colorsSpace: cs, colors: specC, locations: nil)!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx-pr, y: cy-pr, width: pr*2, height: pr*2))
    ctx.clip()
    ctx.drawRadialGradient(specG,
        startCenter: CGPoint(x: cx - pr*0.28, y: cy + pr*0.32), startRadius: 0,
        endCenter:   CGPoint(x: cx - pr*0.28, y: cy + pr*0.32), endRadius: pr * 0.60,
        options: [.drawsAfterEndLocation])
    ctx.restoreGState()

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
