import SwiftUI
import SwiftData

struct FilterBar: View {
    @Environment(FilterState.self) private var filterState
    @Environment(Selection.self) private var selection
    @Environment(AppActions.self) private var appActions
    @Environment(\.modelContext) private var context
    @State private var showSaveSheet = false
    @State private var savedViewName = ""
    @FocusState private var isSearchFocused: Bool

    var activeWorkspace: Workspace? {
        selection.selectedProject?.workspace ?? selection.selectedSavedView?.workspace
    }

    var body: some View {
        @Bindable var fs = filterState
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Status filter
                Menu {
                    ForEach(IssueStatus.allCases, id: \.self) { status in
                        Button {
                            if filterState.statuses.contains(status) {
                                filterState.statuses.remove(status)
                            } else {
                                filterState.statuses.insert(status)
                            }
                        } label: {
                            HStack {
                                Text(status.displayName)
                                if filterState.statuses.contains(status) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(title: "Status", count: filterState.statuses.count)
                }

                // Priority filter
                Menu {
                    ForEach(IssuePriority.allCases, id: \.self) { priority in
                        Button {
                            if filterState.priorities.contains(priority) {
                                filterState.priorities.remove(priority)
                            } else {
                                filterState.priorities.insert(priority)
                            }
                        } label: {
                            HStack {
                                SwiftUI.Label(priority.displayName, systemImage: priority.symbolName)
                                if filterState.priorities.contains(priority) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(title: "Priority", count: filterState.priorities.count)
                }

                // Label filter
                if let workspace = activeWorkspace, !workspace.unwrappedLabels.isEmpty {
                    Menu {
                        ForEach(workspace.unwrappedLabels) { (label: Orbit.Label) in
                            Button {
                                if filterState.labelIDs.contains(label.id) {
                                    filterState.labelIDs.remove(label.id)
                                } else {
                                    filterState.labelIDs.insert(label.id)
                                }
                            } label: {
                                HStack {
                                    Text(label.name)
                                    if filterState.labelIDs.contains(label.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        FilterChipLabel(title: "Labels", count: filterState.labelIDs.count)
                    }
                }

                // Quick "Open" toggle — hides Done + Cancelled
                Button {
                    filterState.hideCompleted.toggle()
                } label: {
                    SwiftUI.Label("Open", systemImage: filterState.hideCompleted ? "circle.lefthalf.filled" : "circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(filterState.hideCompleted ? .accentColor : nil)
                .help("Show only open issues (hide Done & Cancelled)")

                // Sort menu
                Menu {
                    ForEach(IssueSort.allCases, id: \.self) { sort in
                        Button {
                            filterState.sort = sort
                        } label: {
                            HStack {
                                Text(sort.displayName)
                                if filterState.sort == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    SwiftUI.Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search", text: $fs.searchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(width: 140)
                        .focused($isSearchFocused)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Clear + Save
                if filterState.isActive {
                    Button(action: { filterState.reset() }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear filters")

                    Button("Save View") { showSaveSheet = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
            SaveViewSheet(isPresented: $showSaveSheet, onSave: { name in
                saveView(name: name)
            })
        }
    }

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

private struct FilterChipLabel: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .font(.caption)
    }
}

private struct SaveViewSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Save View").font(.headline)
            TextField("View name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Button("Cancel") { isPresented = false }
                Button("Save") { onSave(name); isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}
