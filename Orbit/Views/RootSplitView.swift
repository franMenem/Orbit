import SwiftUI

/// Three-column root shell. The SINGLE owner of all shared @Observable state.
/// Holds each shared object as @State and injects it once via .environment.
/// Children NEVER instantiate these objects — they read via @Environment(Type.self).
struct RootSplitView: View {
    @State private var selection = Selection()
    @State private var filterState = FilterState()
    @State private var cloudStatus = iCloudStatus()
    @Environment(AppActions.self) private var appActions  // owned by OrbitApp

    /// Workspace that owns the current selection — drives the centered
    /// titlebar label. Falls back across project/saved-view selection since
    /// the two are mutually exclusive (see `Selection`).
    private var selectedWorkspaceName: String? {
        selection.selectedProject?.workspace?.name
            ?? selection.selectedSavedView?.workspace?.name
    }

    var body: some View {
        @Bindable var actions = appActions
        VStack(spacing: 0) {
            TitleBar(
                workspaceName: selectedWorkspaceName,
                onCommandPalette: { appActions.showCommandPalette = true }
            )
            if cloudStatus.showOfflineBanner, case let .unavailable(reason) = cloudStatus.status {
                OfflineBanner(reason: reason)
            }
            NavigationSplitView {
                SidebarView()
                #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                #endif
            } content: {
                ContentPaneView()
            } detail: {
                IssueDetailView()
            }
        }
        .environment(selection)
        .environment(filterState)
        .environment(cloudStatus)
        .sheet(isPresented: $actions.showCommandPalette) {
            // Width is owned by CommandPaletteView itself (420px per the
            // Nocturne sheet spec) — no outer frame override here.
            CommandPaletteView()
        }
    }
}

// MARK: - Title Bar
//
// Own 40px titlebar over the NavigationSplitView (paired with
// .windowStyle(.hiddenTitleBar) in OrbitApp). We do NOT draw a custom traffic
// light mock — the native traffic lights still render over the hidden title
// bar area, so this bar reserves ~70px on the leading edge to avoid
// overlapping them and leaves the system chrome untouched.

private struct TitleBar: View {
    let workspaceName: String?
    let onCommandPalette: () -> Void

    var body: some View {
        ZStack {
            // Centered workspace name — independent of the leading/trailing
            // content so it stays visually centered in the window, not in
            // the remaining space after the traffic-light gutter.
            if let workspaceName {
                Text(workspaceName)
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textDim)
                    .lineLimit(1)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: 70) // gutter for native traffic lights
                Spacer()
                Button(action: onCommandPalette) {
                    Text("⌘K")
                        .font(Nocturne.Font_.chip)
                        .foregroundStyle(Nocturne.textDim)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "#2F3240"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 12)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(Nocturne.titlebar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Nocturne.border).frame(height: 1)
        }
    }
}

// MARK: - Offline Banner

private struct OfflineBanner: View {
    let reason: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 11))
                .foregroundStyle(Nocturne.textDim)
            Text("Working offline — \(reason)")
                .font(Nocturne.Font_.meta)
                .foregroundStyle(Nocturne.textDim)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Nocturne.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
