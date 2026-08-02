import SwiftUI

/// Sidebar wordmark logo: an orbit ellipse (stroked, rotated -28°) with a
/// filled core "planet" and a satellite dot riding the ellipse's rim.
/// ViewBox is 24×24 to match the spec. Mirrors the same motif drawn by
/// `scripts/generate_icon.swift` for the AppIcon, simplified for small size.
struct OrbitLogo: View {
    var size: CGFloat = 24

    /// Position of the satellite along the (unrotated) orbit ellipse, in
    /// radians. Chosen so it sits clear of the core circle, upper-right.
    private let satelliteAngle: CGFloat = -.pi / 5

    var body: some View {
        let scale = size / 24
        let rx: CGFloat = 10.5 * scale
        let ry: CGFloat = 5 * scale
        let rotation = Angle.degrees(-28)

        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            // Orbit ellipse, rotated -28° about the center.
            var orbitPath = Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry,
                                                     width: rx * 2, height: ry * 2))
            orbitPath = orbitPath.applying(
                CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: CGFloat(rotation.radians))
                    .translatedBy(x: -center.x, y: -center.y)
            )
            context.stroke(orbitPath, with: .color(Nocturne.accent), lineWidth: 1.4 * scale)

            // Central core.
            let coreR: CGFloat = 3.4 * scale
            let corePath = Path(ellipseIn: CGRect(x: center.x - coreR, y: center.y - coreR,
                                                    width: coreR * 2, height: coreR * 2))
            context.fill(corePath, with: .color(Nocturne.accent))

            // Satellite: a point on the unrotated ellipse rim, then rotated
            // -28° to land on the drawn orbit's rim.
            let rawX = cos(satelliteAngle) * rx
            let rawY = sin(satelliteAngle) * ry
            let rad = CGFloat(rotation.radians)
            let satX = center.x + rawX * cos(rad) - rawY * sin(rad)
            let satY = center.y + rawX * sin(rad) + rawY * cos(rad)
            let satR: CGFloat = 1.9 * scale
            let satPath = Path(ellipseIn: CGRect(x: satX - satR, y: satY - satR,
                                                  width: satR * 2, height: satR * 2))
            context.fill(satPath, with: .color(Nocturne.Accent.a300))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    OrbitLogo()
        .padding(20)
        .background(Nocturne.bgDeep)
}
