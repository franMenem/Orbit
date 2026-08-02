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
            HStack(spacing: 7) {
                statusMenu
                priorityMenu
                if let workspace = activeWorkspace, !workspace.unwrappedLabels.isEmpty {
                    labelMenu(workspace)
                }

                Rectangle()
                    .fill(Nocturne.border)
                    .frame(width: 1, height: 15)

                openToggle
                sortMenu

                Spacer(minLength: 12)

                searchField

                if filterState.isActive {
                    clearButton
                    saveButton
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Nocturne.bgBar)
            Rectangle()
                .fill(Nocturne.divider)
                .frame(height: 1)
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

    /// `#191B28` no es uno de los tokens de superficie en Theme.swift (no es
    /// `bg`/`bgDeep`/`bgBar`/`surface`); es el hex literal que el README §4 pide
    /// puntualmente para el fondo del campo de búsqueda (mismo valor que usa
    /// el buscador de la sidebar en §2). Local y anotado, según la regla del
    /// contexto común.
    private var searchFieldBackground: Color { Color(hex: "#191B28") }

    private var searchField: some View {
        @Bindable var fs = filterState
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Nocturne.textDim)
            TextField("Search", text: $fs.searchText)
                .textFieldStyle(.plain)
                .font(Nocturne.Font_.control)
                .foregroundStyle(Nocturne.text)
                .frame(width: 170)
                .focused($isSearchFocused)
            if !filterState.searchText.isEmpty {
                Button { filterState.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Nocturne.textFaint)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: controlHeight)
        .background(searchFieldBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Nocturne.border, lineWidth: 1))
    }

    private var clearButton: some View {
        Button { filterState.reset() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .frame(height: controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Nocturne.textDim)
        .help("Clear all filters")
    }

    /// "Save View" pasa a outline acento cuando `filterState.isActive`
    /// (README §4) — en la práctica siempre que esté visible, ya que solo se
    /// renderiza dentro del `if filterState.isActive` de arriba.
    private var saveButton: some View {
        Button { showSaveSheet = true } label: {
            Text("Save View")
        }
        .buttonStyle(OutlineAccentButtonStyle())
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
    @State private var hovering = false

    /// Un filtro con selección (count > 0) se ve "activo" igual que un toggle
    /// explícito como "Solo abiertos" — mismo tratamiento visual en ambos casos.
    private var isActive: Bool { active || count > 0 }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#161826"))
                    .frame(minWidth: 15, minHeight: 15)
                    .background(Nocturne.accent, in: Circle())
            }
        }
        .padding(.horizontal, 9)
        .frame(height: height)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Nocturne.accentSel : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? Nocturne.Accent.a800 : (hovering ? Nocturne.borderHover : Nocturne.border), lineWidth: 1)
        )
        .foregroundStyle(isActive ? Nocturne.accentText : Nocturne.textMuted)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - SaveViewSheet

private struct SaveViewSheet: View {
    @Binding var isPresented: Bool
    let onSave: (String) -> Void
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Save View")
                .font(Nocturne.Font_.inter(15, .semibold))
                .foregroundStyle(Nocturne.text)
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.md)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Nocturne.border).frame(height: 1)
                }

            // Body
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("Saves the current filters and sort as a reusable view in this workspace.")
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textDim)
                TextField("View name", text: $name)
                    .textFieldStyle(.plain)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(Nocturne.text)
                    .focused($nameFocused)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Nocturne.bg)
                    .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: Nocturne.Radius.control)
                            .stroke(Nocturne.border, lineWidth: 1)
                    )
                    .onSubmit { if canSave { save() } }
            }
            .padding(DS.Space.lg)

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(OutlineNeutralButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .buttonStyle(OutlineAccentButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
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

    private func save() {
        onSave(name)
        isPresented = false
    }
}
