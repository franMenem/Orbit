import SwiftUI
import SwiftData

enum ContentViewMode: String {
    case list, board, timeline
}

struct ContentPaneView: View {
    @Environment(Selection.self) private var selection
    @Environment(FilterState.self) private var filterState
    @Environment(AppActions.self) private var appActions
    @Environment(\.modelContext) private var context
    @AppStorage("contentMode") private var mode: ContentViewMode = .list
    @State private var newIssueProject: Project?

    var body: some View {
        Group {
            if let project = selection.selectedProject {
                ProjectContentView(project: project, mode: $mode,
                                   onNewIssue: { newIssueProject = project })
            } else if let savedView = selection.selectedSavedView {
                savedViewContent(savedView: savedView)
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Choose a project from the sidebar or create one with the + button.")
                )
            }
        }
        // "fondo de la columna Nocturne.bg" (README §3) — se aplica acá arriba
        // de todo para cubrir las tres ramas (proyecto, saved view, vacío).
        .background(Nocturne.bg)
        .onChange(of: appActions.createIssueSignal) { handleCreateIssue() }
        .onChange(of: appActions.pendingMode)       { handlePendingMode() }
        .sheet(item: $newIssueProject) { project in
            NewIssueSheet(project: project) { issue in
                selection.selectedIssue = issue
            }
        }
    }

    // MARK: - Saved View mode

    @ViewBuilder
    private func savedViewContent(savedView: SavedView) -> some View {
        let allIssues = savedView.workspace?.unwrappedProjects.flatMap(\.unwrappedIssues) ?? []
        let filtered  = IssueFiltering.apply(allIssues, filterState)
        VStack(spacing: 0) {
            FilterBar()
            IssueListView(issues: filtered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Signal handlers

    private func handleCreateIssue() {
        guard appActions.createIssueSignal else { return }
        appActions.createIssueSignal = false
        // Open the New Issue sheet for the active (or first) project.
        newIssueProject = selection.selectedProject ?? SeedData.ensureSeed(context)
    }

    private func handlePendingMode() {
        if let m = appActions.pendingMode { mode = m; appActions.pendingMode = nil }
    }
}
// MARK: - ProjectHeader
// Editable project name shown at the top of the content pane. Click the name
// to edit it inline — no need to find it in the sidebar.

private struct ProjectHeader: View {
    @Bindable var project: Project
    let onSave: () -> Void
    let onNewIssue: () -> Void
    @FocusState private var nameFocused: Bool

    private var issues: [Issue] { project.unwrappedIssues }
    private var total: Int { issues.count }
    private var inProgressCount: Int { issues.filter { $0.status == .inProgress }.count }

    /// "Cerrados" en el resumen agrupa Done + Cancelled (README §3: "1 cerrados").
    private var closedCount: Int {
        issues.filter { $0.status == .done || $0.status == .cancelled }.count
    }

    /// Criterio del anillo de progreso: numerador = solo `.done`. Cancelled
    /// cuenta como "cerrado" en el resumen de texto de arriba, pero no como
    /// avance real, así que no infla el arco (a diferencia de `closedCount`).
    private var doneFraction: Double {
        guard total > 0 else { return 0 }
        return Double(issues.filter { $0.status == .done }.count) / Double(total)
    }

    private var summaryText: String {
        "\(total) issues · \(inProgressCount) en progreso · \(closedCount) cerrados"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(project.workspace?.name ?? "Workspace") / \(project.name)")
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textDim)
                    .lineLimit(1)

                TextField("Project name", text: $project.name)
                    .textFieldStyle(.plain)
                    .font(Nocturne.Font_.projectTitle)
                    .foregroundStyle(Nocturne.text)
                    .focused($nameFocused)
                    .onChange(of: project.name) { onSave() }
                    .onSubmit { nameFocused = false }

                Text(summaryText)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(Nocturne.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Space.sm) {
                progressBadge
                newIssueButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Nocturne.divider).frame(height: 1)
        }
    }

    private var progressBadge: some View {
        let pct = Int((doneFraction * 100).rounded())
        return HStack(spacing: 8) {
            ProgressRing(fraction: doneFraction, size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Nocturne.text)
                Text("completado")
                    .font(Nocturne.Font_.chip)
                    .foregroundStyle(Nocturne.textDim)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Nocturne.border, lineWidth: 1)
        )
    }

    private var newIssueButton: some View {
        // OutlineAccentButtonStyle ya aplica radio 8, padding 7/12 y
        // texto 12.5pt/500 — coincide exacto con el spec, sin overrides.
        Button(action: onNewIssue) {
            SwiftUI.Label("Nuevo issue", systemImage: "plus")
        }
        .buttonStyle(OutlineAccentButtonStyle())
    }
}

// MARK: - ProjectContentView
// Separate struct so we can use @Bindable for inline title editing.
// .navigationTitle($project.name) makes the title editable on double-click.

private struct ProjectContentView: View {
    @Bindable var project: Project
    @Binding var mode: ContentViewMode
    let onNewIssue: () -> Void
    @Environment(FilterState.self) private var filterState
    @Environment(\.modelContext) private var context

    var body: some View {
        let filtered = IssueFiltering.apply(project.unwrappedIssues, filterState)
        VStack(spacing: 0) {
            ProjectHeader(project: project, onSave: { try? context.save() }, onNewIssue: onNewIssue)
            ContentModeTabs(mode: $mode)
            FilterBar()
            switch mode {
            case .list:     IssueListView(issues: filtered)
            case .board:    IssueBoardView(issues: filtered)
            case .timeline: TimelineView(issues: filtered)
            }
        }
        // Anchored to the top and greedy on both axes: the column must
        // always fill the pane, regardless of whether the active mode's
        // content (e.g. an empty List/Timeline) would otherwise hug its own
        // size — without this, a non-greedy child lets the Group in
        // ContentPaneView.body center everything, leaving a huge empty gap
        // above the ProjectHeader.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: project.name) { try? context.save() }
    }
}

// MARK: - ContentModeTabs
// Shell 1b "Stage": reemplaza el Picker segmentado del toolbar por tabs
// propias List / Board / Timeline dentro del área de contenido (README §
// "Interactions & Behavior" — "Cambio de vista"). Subrayado de 2px animado
// con matchedGeometryEffect (~200ms). ⌘1/⌘2/⌘3 siguen andando vía
// `appActions.pendingMode`, consumido por `handlePendingMode()` arriba —
// esta vista solo refleja/edita el mismo `@Binding mode`.

private struct ContentModeTabs: View {
    @Binding var mode: ContentViewMode
    @Namespace private var underline
    @State private var hovered: ContentViewMode?

    private struct Tab {
        let mode: ContentViewMode
        let title: String
        let icon: String
    }

    private let tabs: [Tab] = [
        Tab(mode: .list,     title: "List",     icon: "list.bullet"),
        Tab(mode: .board,    title: "Board",    icon: "square.grid.2x2"),
        Tab(mode: .timeline, title: "Timeline", icon: "calendar"),
    ]

    var body: some View {
        HStack(spacing: DS.Space.lg) {
            ForEach(tabs, id: \.mode) { tab in
                tabButton(tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .background(Nocturne.bg)
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab) -> some View {
        let isActive = mode == tab.mode
        Button {
            withAnimation(.easeOut(duration: 0.2)) { mode = tab.mode }
        } label: {
            // No outer VStack/ZStack around the underline: an unconstrained
            // Shape (Color.clear/RoundedRectangle with only a `.frame(height:)`)
            // takes as much width as it's offered, which made every tab
            // greedy and stretched the whole HStack to fill the pane with a
            // mile-long underline. Instead the underline is an `.overlay`
            // pinned to the label's OWN measured width, so the button stays
            // compact and left-aligned.
            SwiftUI.Label(tab.title, systemImage: tab.icon)
                .font(Nocturne.Font_.control)
                .foregroundStyle(color(for: tab, isActive: isActive))
                .fixedSize()
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Nocturne.accent)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hovered = isHovering ? tab.mode : (hovered == tab.mode ? nil : hovered)
        }
    }

    private func color(for tab: Tab, isActive: Bool) -> Color {
        if isActive { return Nocturne.text }
        if hovered == tab.mode { return Nocturne.textMuted }
        return Nocturne.textDim
    }
}
