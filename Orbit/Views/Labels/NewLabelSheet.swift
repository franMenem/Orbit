import SwiftUI
import SwiftData

/// Small sheet for creating a new label inline from a label-assignment menu
/// (NewIssueSheet's `labelsPill`, IssueDetailView's `IssueLabelsValue`).
/// Mirrors the name field + `ColorPaletteButton` + create logic already in
/// LabelManagerView.swift, scoped down to "create one label and hand it back
/// to the caller" so each call site can attach/select it immediately.
struct NewLabelSheet: View {
    let workspace: Workspace
    let onCreate: (Orbit.Label) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = Color.labelPalette[0].hex
    @FocusState private var nameFocused: Bool

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.accent)
                Text("New Label")
                    .font(Nocturne.Font_.inter(15, .semibold))
                    .foregroundStyle(Nocturne.text)
                Spacer()
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }

            // Color + name
            HStack(spacing: 8) {
                ColorPaletteButton(selectedHex: $colorHex)
                TextField("Label name", text: $name)
                    .textFieldStyle(.plain)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(Nocturne.text)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Nocturne.bg)
                    .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: Nocturne.Radius.control)
                            .stroke(Nocturne.border, lineWidth: 1)
                    )
                    .focused($nameFocused)
                    .onSubmit { if canCreate { create() } }
            }
            .padding(DS.Space.lg)

            // Footer
            HStack(spacing: DS.Space.sm) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineNeutralButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .buttonStyle(OutlineAccentButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.md)
            .overlay(alignment: .top) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }
        }
        .frame(width: 320)
        .background(Nocturne.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sheet))
        .nocturneElevation(.sheet)
        .onAppear { nameFocused = true }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let label = Orbit.Label(name: trimmed, colorHex: colorHex)
        label.workspace = workspace
        if workspace.labels == nil { workspace.labels = [] }
        workspace.labels?.append(label)
        context.insert(label)
        try? context.save()
        onCreate(label)
        dismiss()
    }
}
