import SwiftUI

/// Shell 1b "Stage": two-column root shell (sidebar + content). The detail
/// view is no longer a third NavigationSplitView column — it's an overlaid
/// panel (see `DetailPanelOverlay` below) that slides in from the trailing
/// edge whenever an issue is selected. The SINGLE owner of all shared
/// @Observable state. Holds each shared object as @State and injects it once
/// via .environment. Children NEVER instantiate these objects — they read
/// via @Environment(Type.self).
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
            ZStack(alignment: .trailing) {
                NavigationSplitView {
                    SidebarView()
                    #if os(macOS)
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                    #endif
                } detail: {
                    ContentPaneView()
                }
                #if os(macOS)
                // Suppresses the native sidebar-toggle button that
                // NavigationSplitView otherwise injects into the window's
                // toolbar. Using `.toolbar(removing: .sidebarToggle)` here
                // (rather than `.toolbar(.hidden, for: .windowToolbar)`)
                // leaves the window's native toolbar/titlebar chrome intact
                // — including the traffic-light buttons — instead of
                // collapsing it, which previously nuked the close/
                // miniaturize/zoom buttons entirely and still left a blank
                // reserved strip above our custom TitleBar.
                .toolbar(removing: .sidebarToggle)
                #endif

                DetailPanelOverlay()
            }
        }
        #if os(macOS)
        .background(WindowConfigurator())
        #endif
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

// MARK: - Detail Panel Overlay
//
// Shell 1b "Stage" (README §"Panel de detalle"): el detalle ya no es la
// tercera columna del NavigationSplitView — es un panel de 540px que entra
// desde el borde derecho sobre un backdrop semitransparente. Cerrar = click
// en el backdrop, botón "Cerrar" dentro de IssueDetailView, o Escape.
//
// Fuente de verdad del estado del panel: `selection.selectedIssue` (no hay
// `@State private var showDetailPanel` adicional). El README lo deja abierto
// ("si selectedIssue alcanza como fuente de verdad, anotalo y no dupliques
// estado") — duplicar el flag introduciría un segundo lugar para
// desincronizarse de la selección real, por ejemplo cuando `NewIssueSheet`
// hace `selection.selectedIssue = issue` al crear (ContentPaneView) o cuando
// se selecciona una fila desde List/Board/Timeline vía el binding de
// `Selection` — todos esos casos ya abren el panel gratis con este approach.
private struct DetailPanelOverlay: View {
    @Environment(Selection.self) private var selection

    var body: some View {
        // El ZStack en sí es SIEMPRE parte del árbol (no está detrás de un
        // `if` a este nivel) para que `.animation(value:)` pueda animar la
        // entrada/salida de su contenido condicional sin depender de que
        // cada call-site que toca `selectedIssue` recuerde envolver en
        // `withAnimation` (List, NewIssueSheet, etc. no lo hacen).
        ZStack(alignment: .trailing) {
            if selection.selectedIssue != nil {
                Color(hex: "#08090F")
                    .opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)

                IssueDetailView()
                    .frame(width: 540)
                    .frame(maxHeight: .infinity)
                    .shadow(color: .black.opacity(0.55), radius: 30, x: -12, y: 0)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeOut(duration: 0.2), value: selection.selectedIssue)
        .onExitCommand { close() }
    }

    private func close() {
        selection.selectedIssue = nil
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

// MARK: - Window Configurator
//
// `.windowStyle(.hiddenTitleBar)` (OrbitApp) hides the native title text and
// background, but SwiftUI still leaves the window's standard buttons and
// styleMask up to us to reason about explicitly. This grabs the underlying
// NSWindow once the view lands in the hierarchy and configures it directly:
// transparent/hidden titlebar, `.fullSizeContentView` so content (our custom
// TitleBar) extends under the traffic-light area instead of leaving a
// reserved blank strip, and explicit re-assertion that the close/miniaturize/
// zoom buttons are present and visible (they can end up hidden depending on
// how the toolbar/style-mask combo above resolves).
#if os(macOS)
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert([.closable, .miniaturizable, .resizable])
        window.isMovableByWindowBackground = false

        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
}
#endif
