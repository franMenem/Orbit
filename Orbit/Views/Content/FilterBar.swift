import SwiftUI
import SwiftData

struct FilterBar: View {
    @Environment(FilterState.self) private var filterState
    @Environment(Selection.self) private var selection
    @Environment(AppActions.self) private var appActions
    @Environment(\.modelContext) private var context
    @State private var showSaveSheet = false
    @FocusState private var isSearchFocused: Bool

    /// Uniform height for every control in the bar — fixes the mismatched heights.
    private let controlHeight: CGFloat = 26

    var activeWorkspace: Workspace? {
        selection.selectedProject?.workspace ?? selection.selectedSavedView?.workspace
    }

    var body: some View {
        @Bindable var fs = filterState
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                statusMenu
                priorityMenu
                if let workspace = activeWorkspace, !workspace.unwrappedLabels.isEmpty {
                    labelMenu(workspace)
                }

                Divider().frame(height: 16)

                openToggle
                sortMenu

                Spacer(minLength: 12)

                searchField

                if filterState.isActive {
                    clearButton
                    saveButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            Divider()
        }
        .onChange(of: appActions.focusSearchSignal) {
            if appActions.focusSearchSignal {
                isSearchFocused = true
                appActions.focusSearchSignal = false
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveViewSheet(isPresented: $showSaveSheet, onSave: { name in saveView(name: name) })
        }
    }

    // MARK: - Controls

    private var statusMenu: some View {
        Menu {
            ForEach(IssueStatus.allCases, id: \.self) { status in
                Toggle(status.displayName, isOn: Binding(
                    get: { filterState.statuses.contains(status) },
                    set: { on in
                        if on { filterState.statuses.insert(status) }
                        else  { filterState.statuses.remove(status) }
                    }
                ))
            }
        } label: {
            FilterPill(title: "Status", count: filterState.statuses.count,
                       icon: "circle.dashed", height: controlHeight)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(IssuePriority.allCases, id: \.self) { priority in
                Toggle(isOn: Binding(
                    get: { filterState.priorities.contains(priority) },
                    set: { on in
                        if on { filterState.priorities.insert(priority) }
                        else  { filterState.priorities.remove(priority) }
                    }
                )) {
                    SwiftUI.Label(priority.displayName, systemImage: priority.symbolName)
                }
            }
        } label: {
            FilterPill(title: "Priority", count: filterState.priorities.count,
                       icon: "flag", height: controlHeight)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func labelMenu(_ workspace: Workspace) -> some View {
        Menu {
            ForEach(workspace.unwrappedLabels) { (label: Orbit.Label) in
                Toggle(label.name, isOn: Binding(
                    get: { filterState.labelIDs.contains(label.id) },
                    set: { on in
                        if on { filterState.labelIDs.insert(label.id) }
                        else  { filterState.labelIDs.remove(label.id) }
                    }
                ))
            }
        } label: {
            FilterPill(title: "Labels", count: filterState.labelIDs.count,
                       icon: "tag", height: controlHeight)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var openToggle: some View {
        Button {
            filterState.hideCompleted.toggle()
        } label: {
            FilterPill(
                title: "Open",
                count: 0,
                icon: filterState.hideCompleted ? "circle.lefthalf.filled" : "circle",
                height: controlHeight,
                active: filterState.hideCompleted
            )
        }
        .buttonStyle(.plain)
        .help("Show only open issues (hide Done & Cancelled)")
    }

    private var sortMenu: some View {
        Menu {
            ForEach(IssueSort.allCases, id: \.self) { sort in
                Button {
                    filterState.sort = sort
                } label: {
                    if filterState.sort == sort {
                        SwiftUI.Label(sort.displayName, systemImage: "checkmark")
                    } else {
                        Text(sort.displayName)
                    }
                }
            }
        } label: {
            FilterPill(title: "Sort", count: 0, icon: "arrow.up.arrow.down", height: controlHeight)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var searchField: some View {
        @Bindable var fs = filterState
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Search", text: $fs.searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(width: 160)
                .focused($isSearchFocused)
            if !filterState.searchText.isEmpty {
                Button { filterState.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: controlHeight)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
    }

    private var clearButton: some View {
        Button { filterState.reset() } label: {
            Image(systemName: "xmark.circle.fill")
                .frame(height: controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Clear all filters")
    }

    private var saveButton: some View {
        Button { showSaveSheet = true } label: {
            Text("Save View")
                .font(.callout)
                .padding(.horizontal, 10)
                .frame(height: controlHeight)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func saveView(name: String) {
        guard let workspace = activeWorkspace else { return }
        let view = SavedView(name: name)
        view.workspace = workspace
        filterState.encode(into: view)
        if workspace.savedViews == nil { workspace.savedViews = [] }
        workspace.savedViews?.append(view)
        context.insert(view)
        try? context.save()
    }
}

// MARK: - FilterPill
// Uniform-height control used by every filter menu/button so the bar
// reads as one clean row instead of mismatched heights.

private struct FilterPill: View {
    let title: String
    var count: Int = 0
    let icon: String
    let height: CGFloat
    var active: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.callout)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(active ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(active ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .foregroundStyle(active || count > 0 ? Color.accentColor : Color.primary)
        .contentShape(Rectangle())
    }
}

// MARK: - SaveViewSheet

private struct SaveViewSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save View").font(.headline)
            Text("Saves the current filters and sort as a reusable view in this workspace.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("View name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") { onSave(name); isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
