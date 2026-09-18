import Foundation
import SwiftData

/// A single command in the palette.
struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
}

/// Builds the list of available commands from current app state.
/// Pure build function — no side effects; actions are closures.
enum CommandRegistry {
    static func build(
        query: String,
        selection: Selection,
        appActions: AppActions,
        workspaces: [Workspace]
    ) -> [PaletteCommand] {
        var commands: [PaletteCommand] = []

        // Quick-create: always show if query is non-empty
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let title = trimmed.hasPrefix("new issue:") || trimmed.hasPrefix("New issue:")
                ? String(trimmed.dropFirst("new issue:".count)).trimmingCharacters(in: .whitespaces)
                : trimmed
            commands.append(PaletteCommand(
                title: "Create \"\(title.isEmpty ? "New Issue" : title)\"",
                subtitle: selection.selectedProject.map { "in \($0.name)" } ?? "in default project",
                icon: "plus.circle",
                action: {
                    appActions.createIssueSignal = true
                }
            ))
        }

        // Jump to project
        let allProjects = workspaces.flatMap(\.unwrappedProjects)
        for project in allProjects {
            guard query.isEmpty || project.name.localizedCaseInsensitiveContains(query) else { continue }
            commands.append(PaletteCommand(
                title: project.name,
                subtitle: project.workspace?.name ?? "",
                icon: "folder",
                action: { selection.selectedProject = project }
            ))
        }

        // Jump to saved view
        let allViews = workspaces.flatMap(\.unwrappedSavedViews)
        for view in allViews {
            guard query.isEmpty || view.name.localizedCaseInsensitiveContains(query) else { continue }
            commands.append(PaletteCommand(
                title: view.name,
                subtitle: "Saved View",
                icon: "bookmark",
                action: { selection.selectedSavedView = view }
            ))
        }

        // Switch view mode
        if query.isEmpty || "list".localizedCaseInsensitiveContains(query) {
            commands.append(PaletteCommand(
                title: "Switch to List",
                subtitle: "⌘1",
                icon: "list.bullet",
                action: { appActions.pendingMode = .list }
            ))
        }
        if query.isEmpty || "board".localizedCaseInsensitiveContains(query) {
            commands.append(PaletteCommand(
                title: "Switch to Board",
                subtitle: "⌘2",
                icon: "square.grid.2x2",
                action: { appActions.pendingMode = .board }
            ))
        }
        if query.isEmpty || "timeline".localizedCaseInsensitiveContains(query) {
            commands.append(PaletteCommand(
                title: "Switch to Timeline",
                subtitle: "⌘3",
                icon: "calendar",
                action: { appActions.pendingMode = .timeline }
            ))
        }

        return commands
    }
}
