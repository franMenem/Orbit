import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// Nocturne — componentes compartidos chicos, consumidos por IssueRow,
// IssueCard, IssueDetailView y los headers de la lista agrupada.
// ─────────────────────────────────────────────────────────────────────────────

/// Marca de señal de 3 barras — reemplaza las flechas de colores de prioridad.
/// Ancho 2.5, alturas 4/6.5/9, gap 1.5, radio 1, alineadas abajo. Las barras
/// activas (`priority.barCount`) toman `priority.color`; las inactivas quedan
/// en `Nocturne.dashed`.
struct PriorityBars: View {
    let priority: IssuePriority
    private let heights: [CGFloat] = [4, 6.5, 9]

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < priority.barCount ? priority.color : Nocturne.dashed)
                    .frame(width: 2.5, height: height)
            }
        }
        .frame(height: 9)
        .accessibilityLabel("Prioridad \(priority.displayName)")
    }
}

/// Línea horizontal de 1pt que se desvanece en los extremos — firma visual de
/// Nocturne. Se usa en el header de grupo de la lista y entre secciones del
/// detalle.
struct FadingRule: View {
    var color: Color = Nocturne.divider
    var inset: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let stop = min(inset / max(geo.size.width, 1), 0.45)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: color, location: stop),
                    .init(color: color, location: 1 - stop),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }
        .frame(height: 1)
    }
}
