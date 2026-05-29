import SwiftUI
import SwiftData

struct SavedViewsSection: View {
    let workspace: Workspace
    @Environment(Selection.self) private var selection
    @Environment(FilterState.self) private var filterState
    @Environment(\.modelContext) private var context

    var body: some View {
        if !workspace.unwrappedSavedViews.isEmpty {
            Section {
                ForEach(workspace.unwrappedSavedViews) { view in
                    SwiftUI.Label(view.name, systemImage: "bookmark")
                        .tag(view.id)   // use id as tag to avoid model Hashable quirks in List
                        .onTapGesture { selectView(view) }
                        .background(
                            selection.selectedSavedView?.persistentModelID == view.persistentModelID
                                ? Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .contextMenu {
                            Button("Delete", role: .destructive) { deleteView(view) }
                        }
                }
            } header: {
                Text("Views in \(workspace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectView(_ view: SavedView) {
        filterState.load(from: view)
        selection.selectedSavedView = view
    }

    private func deleteView(_ view: SavedView) {
        if selection.selectedSavedView?.persistentModelID == view.persistentModelID {
            selection.selectedSavedView = nil
            filterState.reset()
        }
        context.delete(view)
        try? context.save()
    }
}
