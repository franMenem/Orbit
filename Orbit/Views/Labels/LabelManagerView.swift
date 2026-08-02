import SwiftUI
import SwiftData

struct LabelManagerView: View {
    let workspace: Workspace
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var newLabelName = ""
    @State private var newLabelColorHex = Color.labelPalette[0].hex
    @State private var labelToDelete: Orbit.Label?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.accent)
                Text("Manage Labels")
                    .font(Nocturne.Font_.inter(15, .semibold))
                    .foregroundStyle(Nocturne.text)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(OutlineNeutralButtonStyle())
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }

            // Existing labels
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(workspace.unwrappedLabels) { label in
                        LabelRow(label: label, onDelete: { labelToDelete = label })
                        if label.id != workspace.unwrappedLabels.last?.id {
                            Rectangle().fill(Nocturne.rowLine).frame(height: 1)
                        }
                    }
                }
            }
            .frame(minHeight: 220)
            .background(Nocturne.surface)

            // Add new label
            HStack(spacing: 8) {
                ColorPaletteButton(selectedHex: $newLabelColorHex)
                TextField("New label name", text: $newLabelName)
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
                    .onSubmit { addLabel() }
                Button("Add") { addLabel() }
                    .buttonStyle(OutlineAccentButtonStyle())
                    .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DS.Space.lg)
            .overlay(alignment: .top) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }
        }
        .frame(width: 460, height: 480)
        .background(Nocturne.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sheet))
        .nocturneElevation(.sheet)
        .confirmationDialog(
            "Delete \"\(labelToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { labelToDelete != nil }, set: { if !$0 { labelToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let label = labelToDelete { deleteLabel(label) }
            }
        }
    }

    private func addLabel() {
        let name = newLabelName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let label = Orbit.Label(name: name, colorHex: newLabelColorHex)
        label.workspace = workspace
        if workspace.labels == nil { workspace.labels = [] }
        workspace.labels?.append(label)
        context.insert(label)
        try? context.save()
        newLabelName = ""
    }

    private func deleteLabel(_ label: Orbit.Label) {
        // Detach from all issues before deleting
        label.issues?.forEach { issue in
            issue.labels?.removeAll { $0.persistentModelID == label.persistentModelID }
        }
        context.delete(label)
        try? context.save()
        labelToDelete = nil
    }
}

private struct LabelRow: View {
    @Bindable var label: Orbit.Label
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context
    @FocusState private var nameFocused: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            ColorPaletteButton(selectedHex: Binding(
                get: { label.colorHex },
                set: { label.colorHex = $0; try? context.save() }
            ))
            TextField("Label name", text: $label.name)
                .textFieldStyle(.plain)
                .font(Nocturne.Font_.inter(13))
                .foregroundStyle(Nocturne.text)
                .focused($nameFocused)
                .onSubmit { try? context.save() }
            Spacer()
            Text("\(label.issues?.count ?? 0)")
                .font(Nocturne.Font_.meta)
                .foregroundStyle(Nocturne.textFaint)
            Button { nameFocused = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.Neutral.n700)
            }
            .buttonStyle(.plain)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.Neutral.n700)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isHovering ? Nocturne.surfaceHi : Color.clear)
        .onHover { isHovering = $0 }
    }
}

struct ColorPaletteButton: View {
    @Binding var selectedHex: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: selectedHex))
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            ColorPalettePopover(selectedHex: $selectedHex, isPresented: $showPopover)
        }
    }
}

private struct ColorPalettePopover: View {
    @Binding var selectedHex: String
    @Binding var isPresented: Bool
    @State private var customColor = Color.gray

    var body: some View {
        VStack(spacing: 12) {
            let columns = Array(repeating: GridItem(.fixed(28), spacing: 6), count: 5)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Color.labelPalette, id: \.hex) { item in
                    Circle()
                        .fill(Color(hex: item.hex))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Nocturne.accent, lineWidth: selectedHex == item.hex ? 2 : 0))
                        .onTapGesture {
                            selectedHex = item.hex
                            isPresented = false
                        }
                }
            }
            Rectangle().fill(Nocturne.border).frame(height: 1)
            HStack {
                Text("Custom").font(.caption).foregroundStyle(Nocturne.textDim)
                Spacer()
                ColorPicker("", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: customColor) {
                        selectedHex = customColor.toHex()
                        isPresented = false
                    }
            }
        }
        .padding(12)
        .frame(width: 180)
        .background(Nocturne.surface)
    }
}
