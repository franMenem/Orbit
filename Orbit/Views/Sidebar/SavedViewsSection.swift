import SwiftUI
import SwiftData

struct SavedViewsSection: View {
    let workspace: Workspace
    @Environment(Selection.self) private var selection
    @Environment(FilterState.self) private var filterState
    @Environment(\.modelContext) private var context

    var body: some View {
        if !workspace.unwrappedSavedViews.isEmpty {
            SectionCaps(text: "Views in \(workspace.name)")
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
                .padding(.top, 10)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(workspace.unwrappedSavedViews) { view in
                SavedViewRow(
                    view: view,
                    isSelected: selection.selectedSavedView?.persistentModelID == view.persistentModelID,
                    onSelect: { selectView(view) },
                    onDelete: { deleteView(view) }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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

// MARK: - SavedViewRow

private struct SavedViewRow: View {
    let view: SavedView
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "bookmark")
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Nocturne.accent : Nocturne.textDim)
            Text(view.name)
                .font(Nocturne.Font_.inter(12.5))
                .foregroundStyle(isSelected ? Nocturne.text : Nocturne.textMuted)
                .lineLimit(1)
            Spacer(minLength: 4)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(alignment: .leading) {
            if isSelected {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Nocturne.accentSel)
                    Rectangle().fill(Nocturne.accent).frame(width: 2)
                }
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6).fill(Nocturne.surface)
            }
        }
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
