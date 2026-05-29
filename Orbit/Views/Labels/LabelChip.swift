import SwiftUI

struct LabelChip: View {
    let name: String
    let colorHex: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.caption2)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(hex: colorHex).opacity(0.2))
        .foregroundStyle(Color(hex: colorHex))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: colorHex).opacity(0.4), lineWidth: 0.5))
    }
}
