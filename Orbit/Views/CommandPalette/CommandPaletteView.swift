import SwiftUI
import SwiftData

struct CommandPaletteView: View {
    @Environment(Selection.self) private var selection
    @Environment(AppActions.self) private var appActions
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isQueryFocused: Bool

    private var commands: [PaletteCommand] {
        CommandRegistry.build(
            query: query,
            selection: selection,
            appActions: appActions,
            workspaces: workspaces
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search commands or type to create an issue…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isQueryFocused)
                    .onKeyPress(.upArrow)   { moveSelection(-1); return .handled }
                    .onKeyPress(.downArrow) { moveSelection(+1); return .handled }
                    .onKeyPress(.escape)    { dismiss();         return .handled }
                    .onKeyPress(.return)    { execute();         return .handled }
                    .onChange(of: query) { selectedIndex = 0 }
            }
            .padding(16)

            Divider()

            // Results
            if commands.isEmpty {
                ContentUnavailableView("No commands", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(commands) { command in
                        CommandRow(command: command, isSelected: commands.firstIndex(where: { $0.id == command.id }) == selectedIndex)
                            .id(command.id)
                            .contentShape(Rectangle())
                            .onTapGesture { execute(command) }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) {
                        if selectedIndex < commands.count {
                            proxy.scrollTo(commands[selectedIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .onAppear { isQueryFocused = true }
    }

    private func moveSelection(_ delta: Int) {
        guard !commands.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + commands.count) % commands.count
    }

    private func execute(_ command: PaletteCommand? = nil) {
        let cmd = command ?? (selectedIndex < commands.count ? commands[selectedIndex] : nil)
        guard let cmd else { return }
        dismiss()
        // Small delay so dismiss completes before action fires
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            cmd.action()
        }
    }
}

private struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: command.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.body)
                if !command.subtitle.isEmpty {
                    Text(command.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
