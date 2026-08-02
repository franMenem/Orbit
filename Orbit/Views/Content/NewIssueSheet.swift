import SwiftUI
import SwiftData

/// Modal for creating an issue. Nothing is written to the store until the
/// user presses Create (or Enter). Cancel discards without creating anything —
/// no more empty "Untitled" rows left lying around.
struct NewIssueSheet: View {
    let project: Project
    let onCreate: (Issue) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var status: IssueStatus = .backlog
    @State private var priority: IssuePriority = .none
    @State private var selectedLabelIDs: Set<PersistentIdentifier> = []
    @FocusState private var titleFocused: Bool

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var workspaceLabels: [Orbit.Label] {
        project.workspace?.unwrappedLabels ?? []
    }

    private var breadcrumb: String {
        let workspaceName = project.workspace?.name ?? "Workspace"
        return "\(workspaceName) / \(project.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — breadcrumb only, no chrome.
            Text(breadcrumb)
                .font(Nocturne.Font_.meta)
                .foregroundStyle(Nocturne.textDim)
                .padding(.horizontal, DS.Space.xl)
                .padding(.top, DS.Space.lg)
                .padding(.bottom, DS.Space.md)

            // Body — title + description, no native chrome.
            VStack(alignment: .leading, spacing: DS.Space.md) {
                TextField("What needs to be done?", text: $title)
                    .textFieldStyle(.plain)
                    .font(Nocturne.Font_.inter(17, .medium))
                    .foregroundStyle(Nocturne.text)
                    .focused($titleFocused)
                    .onSubmit { if canCreate { create() } }

                descriptionEditor
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.bottom, DS.Space.lg)

            // Footer — pills left, actions right, border on top.
            HStack(spacing: DS.Space.sm) {
                statusPill
                priorityPill
                labelsPill
                Spacer(minLength: DS.Space.sm)
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineNeutralButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .buttonStyle(OutlineAccentButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.vertical, DS.Space.md)
            .overlay(alignment: .top) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }
        }
        .frame(width: 520)
        .background(Nocturne.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sheet))
        .nocturneElevation(.sheet)
        .onAppear { titleFocused = true }
    }

    // MARK: - Description

    private var descriptionEditor: some View {
        ZStack(alignment: .topLeading) {
            if details.isEmpty {
                Text("Add a description…")
                    .font(Nocturne.Font_.body)
                    .foregroundStyle(Nocturne.textFaint)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $details)
                .font(Nocturne.Font_.body)
                .foregroundStyle(Nocturne.textMuted)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(minHeight: 90, maxHeight: 160)
        }
    }

    // MARK: - Pills

    private var statusPill: some View {
        Menu {
            ForEach(IssueStatus.allCases, id: \.self) { s in
                Button {
                    status = s
                } label: {
                    SwiftUI.Label(s.displayName, systemImage: s.glyph)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: status.glyph)
                    .font(.system(size: 11))
                    .foregroundStyle(status.color)
                Text(status.displayName)
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textMuted)
            }
            .nocturnePill()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var priorityPill: some View {
        Menu {
            ForEach(IssuePriority.allCases, id: \.self) { p in
                Button {
                    priority = p
                } label: {
                    SwiftUI.Label(p.displayName, systemImage: p.symbolName)
                }
            }
        } label: {
            HStack(spacing: 5) {
                PriorityBars(priority: priority)
                Text(priority.displayName)
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textMuted)
            }
            .nocturnePill()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var labelsPill: some View {
        Menu {
            if workspaceLabels.isEmpty {
                Text("No labels yet")
            } else {
                ForEach(workspaceLabels) { label in
                    Button {
                        toggleLabel(label)
                    } label: {
                        if selectedLabelIDs.contains(label.persistentModelID) {
                            SwiftUI.Label(label.name, systemImage: "checkmark")
                        } else {
                            Text(label.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(Nocturne.textDim)
                Text(selectedLabelIDs.isEmpty ? "Labels" : "Labels (\(selectedLabelIDs.count))")
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textMuted)
            }
            .nocturnePill()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func toggleLabel(_ label: Orbit.Label) {
        if selectedLabelIDs.contains(label.persistentModelID) {
            selectedLabelIDs.remove(label.persistentModelID)
        } else {
            selectedLabelIDs.insert(label.persistentModelID)
        }
    }

    // MARK: - Create

    private func create() {
        let issue = Issue(title: title.trimmingCharacters(in: .whitespaces))
        issue.details  = details.trimmingCharacters(in: .whitespaces)
        issue.status   = status
        issue.priority = priority
        issue.project  = project
        issue.code     = Issue.makeCode(for: project)
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)

        for label in workspaceLabels where selectedLabelIDs.contains(label.persistentModelID) {
            if issue.labels == nil { issue.labels = [] }
            issue.labels?.append(label)
            if label.issues == nil { label.issues = [] }
            label.issues?.append(issue)
        }

        context.insert(issue)
        try? context.save()
        onCreate(issue)
        dismiss()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared sheet pieces
//
// `OutlineNeutralButtonStyle` lives here (rather than Theme.swift, which is
// foundation-owned) because it's needed by the Cancel action in every sheet
// this pass touches. Non-private so LabelManagerView.swift can reuse it —
// same module, no import needed.
// ─────────────────────────────────────────────────────────────────────────────

/// Secondary sheet action: outline neutral `#2F3240`, never filled.
struct OutlineNeutralButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Nocturne.Font_.control.weight(.medium))
            .foregroundStyle(Nocturne.Neutral.n400)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .fill(configuration.isPressed ? Color.white.opacity(0.04) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .stroke(Color(hex: "#2F3240"), lineWidth: 1)
            )
    }
}

/// Pill chrome shared by the Status / Priority / Labels selectors in this
/// sheet's footer: border `Nocturne.border`, radius 7.
extension View {
    func nocturnePill() -> some View {
        self
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Nocturne.Radius.control)
                    .stroke(Nocturne.border, lineWidth: 1)
            )
    }
}
