import SwiftUI

/// Three-column root shell. The SINGLE owner of all shared @Observable state.
/// Holds each shared object as @State and injects it once via .environment.
/// Children NEVER instantiate these objects — they read via @Environment(Type.self).
struct RootSplitView: View {
    @State private var selection = Selection()
    @State private var filterState = FilterState()
    @State private var cloudStatus = iCloudStatus()
    @Environment(AppActions.self) private var appActions  // owned by OrbitApp

    var body: some View {
        @Bindable var actions = appActions
        VStack(spacing: 0) {
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
        .sheet(isPresented: $actions.showCommandPalette) {
            CommandPaletteView()
            #if os(macOS)
                .frame(width: 600, height: 400)
            #endif
        }
    }
}

// MARK: - Offline Banner

private struct OfflineBanner: View {
    let reason: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "icloud.slash")
                .foregroundStyle(.secondary)
            Text("Working offline — \(reason)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
