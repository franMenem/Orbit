import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// Nocturne — design-system tokens translated to SwiftUI.
// Source: design_handoff_orbit_redesign/Theme.swift (redesign bundle).
// Rule: no loose hex values in views. Everything comes from here.
//
// Integration note: the IssueStatus and IssuePriority colors/glyphs and the
// FadingRule / PriorityBars components live in DesignTokens.swift and
// NocturneComponents.swift respectively (to avoid duplicating declarations
// with the existing design system). This file provides the
// base tokens (colors, typography, radii, elevation) and the reusable
// pieces that don't collide with those two files.
// ─────────────────────────────────────────────────────────────────────────────

enum Nocturne {

    // MARK: Grounds & surfaces

    static let bg          = Color(hex: "#161826")  // content column
    static let bgDeep      = Color(hex: "#12131F")  // sidebar, detail panel
    static let bgBar       = Color(hex: "#141623")  // filter bar
    static let surface     = Color(hex: "#1B1D2B")  // cards, sheets, row hover
    static let surfaceHi   = Color(hex: "#20222F")  // card hover
    static let titlebar    = Color(hex: "#1B1D2B")

    // MARK: Text

    static let text        = Color(hex: "#E9E9ED")
    static let textMuted   = Color(hex: "#B2B6CA")
    static let textDim     = Color(hex: "#75798C")
    static let textFaint   = Color(hex: "#4D5060")

    // MARK: Lines

    static let divider     = Color(hex: "#212433")  // between columns
    static let border      = Color(hex: "#262939")  // control border
    static let borderHover = Color(hex: "#3F424D")
    static let rowLine     = Color(hex: "#1A1C29")  // between table rows
    static let dashed      = Color(hex: "#2B2E3D")  // empty states

    // MARK: Accent

    static let accent      = Color(hex: "#9184D9")
    static let accentText  = Color(hex: "#B5ABFC")  // text on a dark background
    static let accentDeep  = Color(hex: "#5D5294")  // bullets, small marks
    static let accentTint  = Color(hex: "#9184D9").opacity(0.14)  // hover outline
    static let accentSel   = Color(hex: "#9184D9").opacity(0.13)  // selected row

    /// The only saturated color outside the accent — reserved for Urgent priority.
    static let urgent      = Color(hex: "#E8415B")

    // MARK: Ramps (Nocturne, OKLCH on a single luminosity scale)

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
        // Inter is bundled in Orbit/Fonts (400/500/600, static TTFs) and
        // registered via INFOPLIST_KEY_ATSApplicationFontsPath. The PostScript
        // names of those TTFs are Inter-Regular / Inter-Medium /
        // Inter-SemiBold; any other requested weight falls back to the closest
        // of those three.
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

    // MARK: Elevation — border + ambient darkness, never stacked shadows

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

    /// System selection mark: faint background + 2px accent bar.
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

/// System primary button: accent outline, never filled.
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

// Note: `NocturneLabelChip` was removed from here — it duplicated
// `Views/Labels/LabelChip.swift`, which already implements exactly this shape
// (12.5% background, 33% border, pill radius, 10.5pt) and is the component the
// rest of the app already integrates with (IssueRow, IssueCard, LabelManagerView,
// IssueDetailView).

/// Progress ring for the project header.
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

/// Section header in small caps.
struct SectionCaps: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Nocturne.Font_.sectionCaps)
            .tracking(1.05)
            .foregroundStyle(Nocturne.Neutral.n700)
    }
}
