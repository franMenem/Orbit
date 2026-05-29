import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0x8E, 0x8E, 0x93) // fallback gray
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return "#8E8E93" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// Linear-ish color palette (~10 colors)
extension Color {
    static let labelPalette: [(name: String, hex: String)] = [
        ("Gray",   "#6E7278"),
        ("Blue",   "#5E9EFF"),
        ("Cyan",   "#57C4E8"),
        ("Green",  "#56CF8F"),
        ("Orange", "#F5A623"),
        ("Red",    "#E8415B"),
        ("Purple", "#A865C9"),
        ("Pink",   "#FF7CA3"),
        ("Yellow", "#FFC940"),
        ("Teal",   "#4DBCB0"),
    ]
}
