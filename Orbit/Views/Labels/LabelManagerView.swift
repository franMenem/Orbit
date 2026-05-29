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
            HStack {
                Text("Manage Labels")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            Divider()

            // Existing labels
            List {
                ForEach(workspace.unwrappedLabels) { label in
                    LabelRow(label: label, onDelete: { labelToDelete = label })
                }
            }
            .frame(minHeight: 200)

            Divider()

            // Add new label
            HStack(spacing: 8) {
                ColorPaletteButton(selectedHex: $newLabelColorHex)
                TextField("New label name", text: $newLabelName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addLabel() }
                    .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 440)
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
    @State private var isEditingColor = false

    var body: some View {
        HStack(spacing: 8) {
            ColorPaletteButton(selectedHex: Binding(
                get: { label.colorHex },
                set: { label.colorHex = $0; try? context.save() }
            ))
            TextField("Label name", text: $label.name)
                .onSubmit { try? context.save() }
            Spacer()
            LabelChip(name: label.name, colorHex: label.colorHex)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }
}

struct ColorPaletteButton: View {
    @Binding var selectedHex: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Circle()
                .fill(Color(hex: selectedHex))
                .frame(width: 18, height: 18)
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
                        .overlay(Circle().stroke(Color.primary, lineWidth: selectedHex == item.hex ? 2 : 0))
                        .onTapGesture {
                            selectedHex = item.hex
                            isPresented = false
                        }
                }
            }
            Divider()
            HStack {
                Text("Custom").font(.caption)
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
    }
}
