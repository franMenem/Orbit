import SwiftUI
import SwiftData

/// Multi-select list of the workspace's labels. Toggling adds/removes on BOTH sides.
struct LabelPickerView: View {
    @Bindable var issue: Issue
    let workspace: Workspace
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Labels")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            Divider()
            List {
                ForEach(workspace.unwrappedLabels) { (label: Orbit.Label) in
                    let attached = issue.unwrappedLabels.contains {
                        $0.persistentModelID == label.persistentModelID
                    }
                    Button {
                        toggle(label: label, attached: attached)
                    } label: {
                        HStack {
                            LabelChip(name: label.name, colorHex: label.colorHex)
                            Spacer()
                            if attached {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 260, height: 320)
    }

    private func toggle(label: Orbit.Label, attached: Bool) {
        if attached {
            issue.labels?.removeAll { $0.persistentModelID == label.persistentModelID }
            label.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
        } else {
            if issue.labels == nil { issue.labels = [] }
            issue.labels?.append(label)
            if label.issues == nil { label.issues = [] }
            label.issues?.append(issue)
        }
        try? context.save()
    }
}
