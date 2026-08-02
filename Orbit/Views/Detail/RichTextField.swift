import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RichTextField
// A text field with two modes:
//   • Preview — renders markdown (headings, bullets, bold/italic/code/links)
//   • Edit    — plain TextEditor with comfortable padding
// Empty + not-focused shows a placeholder. Toggle via the eye/pencil button.
// ─────────────────────────────────────────────────────────────────────────────

struct RichTextField: View {
    @Binding var text: String
    var placeholder: String = "Add text…"
    var minHeight: CGFloat = 90
    /// When true, the empty-state editor box uses a dashed Nocturne border
    /// instead of the normal solid one — used by the Solution section, whose
    /// empty state reads as an inert placeholder box rather than an active
    /// input, per the Nocturne spec.
    var dashedWhenEmpty: Bool = false
    var onCommit: () -> Void = {}

    @State private var isEditing = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Mode toggle (only meaningful when there's content)
            HStack {
                Spacer()
                if !text.isEmpty {
                    Button {
                        isEditing.toggle()
                        if isEditing { focused = true }
                    } label: {
                        SwiftUI.Label(
                            isEditing ? "Preview" : "Edit",
                            systemImage: isEditing ? "eye" : "pencil"
                        )
                        .font(Nocturne.Font_.chip)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Nocturne.textDim)
                }
            }

            if isEditing || text.isEmpty {
                editor
            } else {
                preview
            }
        }
    }

    // MARK: - Editor

    private var isDashedEmpty: Bool { dashedWhenEmpty && text.isEmpty }

    private var emptyBoxBorderColor: Color {
        if focused { return Nocturne.accent }
        return isDashedEmpty ? Nocturne.dashed : Nocturne.border
    }

    private var editor: some View {
        TextEditor(text: $text)
            .focused($focused)
            .font(Nocturne.Font_.body)
            .foregroundStyle(Nocturne.text)
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: minHeight)
            .background(isDashedEmpty ? Color.clear : Nocturne.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        emptyBoxBorderColor,
                        style: StrokeStyle(lineWidth: focused ? 1.5 : 1, dash: isDashedEmpty ? [4, 3] : [])
                    )
            )
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Nocturne.Font_.body)
                        .foregroundStyle(Nocturne.textFaint)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: focused) { if !focused { onCommit() } }
            .animation(.easeInOut(duration: 0.12), value: focused)
    }

    // MARK: - Preview

    private var preview: some View {
        MarkdownText(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isEditing = true
                focused = true
            }
            .help("Click to edit")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MarkdownText
// Lightweight block-level markdown renderer. Parses line-by-line for headings
// and bullet/numbered lists, and uses AttributedString for inline styling
// (**bold**, *italic*, `code`, [links](url)).
// ─────────────────────────────────────────────────────────────────────────────

struct MarkdownText: View {
    let source: String

    init(_ source: String) { self.source = source }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
    }

    // MARK: - Parsing

    private enum Block {
        case heading(String, level: Int)
        case bullet(String)
        case numbered(String, n: Int)
        case paragraph(String)
        case spacer

        @ViewBuilder var view: some View {
            switch self {
            case .heading(let s, let level):
                inline(s)
                    .font(headingFont(level))
                    .foregroundStyle(Nocturne.text)
                    .padding(.top, level <= 2 ? 4 : 2)
            case .bullet(let s):
                // Nocturne bullet: 4px dot in accentDeep + 12.5pt/1.6 textMuted body.
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Nocturne.accentDeep)
                        .frame(width: 4, height: 4)
                        .padding(.top, 6.5)
                    inline(s)
                        .font(Nocturne.Font_.control)
                        .foregroundStyle(Nocturne.textMuted)
                        .lineSpacing(4)
                }
            case .numbered(let s, let n):
                HStack(alignment: .top, spacing: 8) {
                    Text("\(n).")
                        .font(Nocturne.Font_.control)
                        .foregroundStyle(Nocturne.accentDeep)
                        .monospacedDigit()
                    inline(s)
                        .font(Nocturne.Font_.control)
                        .foregroundStyle(Nocturne.textMuted)
                        .lineSpacing(4)
                }
            case .paragraph(let s):
                // Detail body: 13pt, line-height ~1.65, Nocturne.Neutral.n300.
                inline(s)
                    .font(Nocturne.Font_.body)
                    .foregroundStyle(Nocturne.Neutral.n300)
                    .lineSpacing(8.5)
            case .spacer:
                Spacer().frame(height: 4)
            }
        }

        private func headingFont(_ level: Int) -> Font {
            switch level {
            case 1: Nocturne.Font_.inter(17, .medium)
            case 2: Nocturne.Font_.inter(15, .medium)
            default: Nocturne.Font_.inter(13.5, .medium)
            }
        }

        /// Renders inline markdown (bold/italic/code/link) for one line.
        private func inline(_ s: String) -> Text {
            if let attr = try? AttributedString(
                markdown: s,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                return Text(attr)
            }
            return Text(s)
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for rawLine in source.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { result.append(.spacer); continue }

            if line.hasPrefix("### ") {
                result.append(.heading(String(line.dropFirst(4)), level: 3))
            } else if line.hasPrefix("## ") {
                result.append(.heading(String(line.dropFirst(3)), level: 2))
            } else if line.hasPrefix("# ") {
                result.append(.heading(String(line.dropFirst(2)), level: 1))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(.bullet(String(line.dropFirst(2))))
            } else if let (n, rest) = numberedPrefix(line) {
                result.append(.numbered(rest, n: n))
            } else {
                result.append(.paragraph(line))
            }
        }
        return result
    }

    /// Detects "1. text" / "12. text" → (1, "text").
    private func numberedPrefix(_ line: String) -> (Int, String)? {
        guard let dotRange = line.range(of: ". ") else { return nil }
        let numPart = line[line.startIndex..<dotRange.lowerBound]
        guard let n = Int(numPart) else { return nil }
        return (n, String(line[dotRange.upperBound...]))
    }
}
