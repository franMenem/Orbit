import SwiftUI

/// Nocturne label chip — fill = label color @12.5%, border = label color @33%,
/// text = label color. Public API (name/colorHex/onRemove) is unchanged so
/// existing call sites (IssueRow, IssueCard, LabelManagerView)
/// keep working untouched.
struct LabelChip: View {
    let name: String
    let colorHex: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        let c = Color(hex: colorHex)
        HStack(spacing: 3) {
            Text(name)
                .font(Nocturne.Font_.chip)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .opacity(0.6)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 1)
        .foregroundStyle(c)
        .background(c.opacity(0.125), in: Capsule())
        .overlay(Capsule().stroke(c.opacity(0.33), lineWidth: 1))
    }
}
