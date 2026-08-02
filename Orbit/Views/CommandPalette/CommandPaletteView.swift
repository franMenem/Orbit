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
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.textDim)
                TextField("Search commands or type to create an issue…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Nocturne.Font_.inter(14))
                    .foregroundStyle(Nocturne.text)
                    .focused($isQueryFocused)
                    .onKeyPress(.upArrow)   { moveSelection(-1); return .handled }
                    .onKeyPress(.downArrow) { moveSelection(+1); return .handled }
                    .onKeyPress(.escape)    { dismiss();         return .handled }
                    .onKeyPress(.return)    { execute();         return .handled }
                    .onChange(of: query) { selectedIndex = 0 }
                Text("esc")
                    .font(Nocturne.Font_.inter(10))
                    .foregroundStyle(Nocturne.textFaint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Nocturne.border, lineWidth: 1)
                    )
            }
            .padding(DS.Space.lg)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }

            // Results
            if commands.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(Nocturne.Neutral.n800)
                    Text("No commands")
                        .font(Nocturne.Font_.control)
                        .foregroundStyle(Nocturne.textDim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(commands) { command in
                                CommandRow(
                                    command: command,
                                    isSelected: commands.firstIndex(where: { $0.id == command.id }) == selectedIndex
                                )
                                .id(command.id)
                                .contentShape(Rectangle())
                                .onTapGesture { execute(command) }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: selectedIndex) {
                        if selectedIndex < commands.count {
                            proxy.scrollTo(commands[selectedIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
        // Explicit height: now that RootSplitView no longer wraps this sheet in
        // an outer .frame, the ScrollView inside has no intrinsic height to
        // report, so macOS would otherwise collapse the sheet to a sliver.
        .frame(width: 420, height: 440)
        .background(Nocturne.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sheet))
        .nocturneElevation(.sheet)
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

    // CommandRegistry reuses `subtitle` to carry the keyboard shortcut for the
    // view-mode switch commands ("⌘1" / "⌘2") since it has no separate
    // shortcut field. We can't change CommandRegistry's API here, so this
    // view derives the display split from the data it already exposes: a
    // subtitle starting with "⌘" renders in the trailing shortcut slot
    // instead of the subtitle line. Every other command's subtitle (project
    // name, workspace name, "Saved View") renders normally underneath the
    // title.
    private var isShortcut: Bool { command.subtitle.hasPrefix("⌘") }
    private var subtitleText: String? {
        isShortcut ? nil : (command.subtitle.isEmpty ? nil : command.subtitle)
    }
    private var shortcutText: String? {
        isShortcut ? command.subtitle : nil
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: command.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Nocturne.accent : Nocturne.textDim)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(Nocturne.Font_.inter(13))
                    .foregroundStyle(Nocturne.Neutral.n300)
                if let subtitleText {
                    Text(subtitleText)
                        .font(Nocturne.Font_.inter(10.5))
                        .foregroundStyle(Nocturne.Neutral.n700)
                }
            }
            Spacer()
            if let shortcutText {
                Text(shortcutText)
                    .font(Nocturne.Font_.inter(10.5))
                    .foregroundStyle(Nocturne.textFaint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Nocturne.Radius.control)
                .fill(isSelected ? Nocturne.accentSel : Color.clear)
        )
    }
}
