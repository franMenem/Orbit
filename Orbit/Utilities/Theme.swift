import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// Nocturne — tokens del sistema de diseño traducidos a SwiftUI.
// Fuente: design_handoff_orbit_redesign/Theme.swift (bundle de rediseño).
// Regla: ningún hex suelto en las vistas. Todo sale de acá.
//
// Nota de integración: los colores/glifos de IssueStatus e IssuePriority y los
// componentes FadingRule / PriorityBars viven en DesignTokens.swift y
// NocturneComponents.swift respectivamente (para no duplicar declaraciones
// con el resto del sistema de diseño existente). Este archivo aporta los
// tokens base (colores, tipografía, radios, elevación) y las piezas
// reutilizables que no colisionan con esos dos archivos.
// ─────────────────────────────────────────────────────────────────────────────

enum Nocturne {

    // MARK: Grounds & surfaces

    static let bg          = Color(hex: "#161826")  // columna de contenido
    static let bgDeep      = Color(hex: "#12131F")  // sidebar, panel de detalle
    static let bgBar       = Color(hex: "#141623")  // barra de filtros
    static let surface     = Color(hex: "#1B1D2B")  // tarjetas, sheets, hover de fila
    static let surfaceHi   = Color(hex: "#20222F")  // hover de tarjeta
    static let titlebar    = Color(hex: "#1B1D2B")

    // MARK: Text

    static let text        = Color(hex: "#E9E9ED")
    static let textMuted   = Color(hex: "#B2B6CA")
    static let textDim     = Color(hex: "#75798C")
    static let textFaint   = Color(hex: "#4D5060")

    // MARK: Lines

    static let divider     = Color(hex: "#212433")  // entre columnas
    static let border      = Color(hex: "#262939")  // borde de control
    static let borderHover = Color(hex: "#3F424D")
    static let rowLine     = Color(hex: "#1A1C29")  // entre filas de tabla
    static let dashed      = Color(hex: "#2B2E3D")  // vacíos

    // MARK: Accent

    static let accent      = Color(hex: "#9184D9")
    static let accentText  = Color(hex: "#B5ABFC")  // texto sobre fondo oscuro
    static let accentDeep  = Color(hex: "#5D5294")  // viñetas, marcas pequeñas
    static let accentTint  = Color(hex: "#9184D9").opacity(0.14)  // hover outline
    static let accentSel   = Color(hex: "#9184D9").opacity(0.13)  // fila seleccionada

    /// Único saturado fuera del acento — reservado a prioridad Urgent.
    static let urgent      = Color(hex: "#E8415B")

    // MARK: Rampas (Nocturne, OKLCH sobre una misma escala de luminosidad)

    enum Neutral {
        static let n100 = Color(hex: "#F3F5FE"), n200 = Color(hex: "#E4E7F5")
        static let n300 = Color(hex: "#CFD3E5"), n400 = Color(hex: "#B2B6CA")
        static let n500 = Color(hex: "#9397AB"), n600 = Color(hex: "#75798C")
        static let n700 = Color(hex: "#595D6C"), n800 = Color(hex: "#3F424D")
        static let n900 = Color(hex: "#292B31")
    }

    enum Accent {
        static let a100 = Color(hex: "#F5F4FF"), a200 = Color(hex: "#E7E5FE")
        static let a300 = Color(hex: "#D2CEFD"), a400 = Color(hex: "#B5ABFC")
        static let a500 = Color(hex: "#968AE0"), a600 = Color(hex: "#796CBF")
        static let a700 = Color(hex: "#5D5294"), a800 = Color(hex: "#423A6A")
        static let a900 = Color(hex: "#2B2741")
    }

    // MARK: Type

    enum Font_ {
        // Inter está empaquetada en Orbit/Fonts (400/500/600, TTF estáticos) y
        // registrada vía INFOPLIST_KEY_ATSApplicationFontsPath. Los nombres
        // PostScript de esos TTF son Inter-Regular / Inter-Medium /
        // Inter-SemiBold; cualquier otro peso solicitado cae al más cercano
        // de esos tres.
        static func inter(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom(postScriptName(for: weight), size: size)
        }

        private static func postScriptName(for weight: SwiftUI.Font.Weight) -> String {
            switch weight {
            case .black, .heavy, .bold, .semibold:
                return "Inter-SemiBold"
            case .medium:
                return "Inter-Medium"
            default:
                return "Inter-Regular"
            }
        }
        static let projectTitle = inter(21, .medium)
        static let issueTitle   = inter(19, .medium)
        static let rowTitle     = inter(13.5, .medium)
        static let body         = inter(13)
        static let control      = inter(12.5)
        static let meta         = inter(11)
        static let chip         = inter(10.5)
        static let sectionCaps  = inter(10.5, .medium)   // + tracking(0.1em) + uppercase
    }

    // MARK: Radii — extiende DS.Radius

    enum Radius {
        static let chip: CGFloat    = 4
        static let control: CGFloat = 7
        static let row: CGFloat     = 8
        static let column: CGFloat  = 10
        static let window: CGFloat  = 12
        static let sheet: CGFloat   = 14
    }

    // MARK: Elevación — borde + oscuridad ambiente, nunca sombras apiladas

    struct Elevation: ViewModifier {
        enum Level { case card, sheet, window }
        let level: Level
        func body(content: Content) -> some View {
            switch level {
            case .card:
                content.overlay(RoundedRectangle(cornerRadius: Radius.column)
                    .stroke(Color(hex: "#1E2130"), lineWidth: 1))
            case .sheet:
                content
                    .overlay(RoundedRectangle(cornerRadius: Radius.sheet)
                        .stroke(Neutral.n800, lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 25, y: 20)
            case .window:
                content
                    .overlay(RoundedRectangle(cornerRadius: Radius.window)
                        .stroke(Color(hex: "#2F3240"), lineWidth: 1))
                    .shadow(color: .black.opacity(0.6), radius: 35, y: 30)
            }
        }
    }
}

extension View {
    func nocturneElevation(_ level: Nocturne.Elevation.Level) -> some View {
        modifier(Nocturne.Elevation(level: level))
    }

    /// Marca de selección del sistema: fondo tenue + barra de acento de 2px.
    func nocturneSelected(_ on: Bool, radius: CGFloat = Nocturne.Radius.row) -> some View {
        self.background(alignment: .leading) {
            if on {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: radius).fill(Nocturne.accentSel)
                    Rectangle().fill(Nocturne.accent).frame(width: 2)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Piezas reutilizables
// ─────────────────────────────────────────────────────────────────────────────

/// Botón primario del sistema: outline de acento, nunca relleno.
struct OutlineAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Nocturne.Font_.control.weight(.medium))
            .foregroundStyle(Nocturne.accentText)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .fill(configuration.isPressed ? Nocturne.accentTint : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .stroke(Nocturne.accent, lineWidth: 1)
            )
    }
}

// Nota: `NocturneLabelChip` se eliminó de acá — quedaba duplicado con
// `Views/Labels/LabelChip.swift`, que ya implementa exactamente esta forma
// (fondo 12.5%, borde 33%, radio pill, 10.5pt) y es el componente con el que
// el resto de la app ya integra (IssueRow, IssueCard, LabelManagerView,
// IssueDetailView).

/// Anillo de progreso del header de proyecto.
struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            Circle().stroke(Nocturne.Neutral.n900, lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(Nocturne.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

/// Header de sección en versalitas.
struct SectionCaps: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Nocturne.Font_.sectionCaps)
            .tracking(1.05)
            .foregroundStyle(Nocturne.Neutral.n700)
    }
}
