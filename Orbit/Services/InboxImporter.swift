import Foundation
import SwiftData
import os

/// Importa a SwiftData las issues que la API local de Orbit (orbit_api) deja
/// como archivos JSON en `~/Library/Application Support/Orbit/Inbox/`.
///
/// Contrato por archivo:
///  - Se decodifica, se crea la `Issue` (igual que `NewIssueSheet.create()`),
///    se hace `save()` y SOLO después de un save exitoso se borra el archivo.
///  - Si el archivo es inválido o el import falla, se mueve a `Inbox/Failed/`
///    y se loguea el error. Un archivo malo no frena a los demás.
///  - Si todavía no existe ningún workspace (primer arranque, antes del seed)
///    el archivo se deja intacto en el Inbox y se reintenta en la próxima
///    activación; no es un error del archivo.
final class InboxImporter {

    // MARK: - Types

    struct Summary: Equatable {
        var imported = 0
        var failed = 0
        /// Dejados en el Inbox para reintentar más tarde (ej. no hay workspace todavía).
        var deferred = 0
        /// Ya estaban importados (mismo id): solo se borró el archivo.
        var duplicates = 0
    }

    enum ImportError: LocalizedError {
        case emptyTitle
        case emptyProjectName
        case invalidDueDate(String)
        case noWorkspace

        var errorDescription: String? {
            switch self {
            case .emptyTitle:               "title vacío"
            case .emptyProjectName:         "project vacío"
            case .invalidDueDate(let s):    "due_date inválida: \(s)"
            case .noWorkspace:              "no hay ningún workspace donde crear el proyecto"
            }
        }
    }

    /// Forma del JSON que escribe la API. `status`/`priority` desconocidos
    /// hacen fallar el decode (el archivo va a Failed/).
    struct Payload: Decodable {
        let id: UUID?
        let title: String
        let project: String
        let details: String
        let status: IssueStatus
        let priority: IssuePriority
        let dueDate: String?

        enum CodingKeys: String, CodingKey {
            case id, title, project, details, status, priority
            case dueDate = "due_date"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(UUID.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            project = try c.decode(String.self, forKey: .project)
            details = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
            status = try c.decodeIfPresent(IssueStatus.self, forKey: .status) ?? .backlog
            priority = try c.decodeIfPresent(IssuePriority.self, forKey: .priority) ?? .none
            dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        }
    }

    // MARK: - Properties

    static let logger = Logger(subsystem: "com.fran.Orbit", category: "InboxImporter")

    /// Instancia compartida de la app (apunta al Inbox real).
    static let shared = InboxImporter()

    /// `~/Library/Application Support/Orbit/Inbox` — la app NO está sandboxed,
    /// así que `homeDirectoryForCurrentUser` es el home real (el mismo que usa la API).
    static var defaultInboxURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Orbit/Inbox", isDirectory: true)
    }

    /// El target OrbitTests usa la app como test host: al arrancar, la UI NO
    /// debe importar del Inbox real ni tocar el store real durante los tests.
    static var isRunningUnderTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let inboxURL: URL
    var failedURL: URL { inboxURL.appendingPathComponent("Failed", isDirectory: true) }

    /// Guard anti doble import (launch + scenePhase .active casi juntos).
    /// Todo corre en el main actor y el import es síncrono, así que alcanza con un Bool.
    private var isImporting = false

    init(inboxURL: URL = InboxImporter.defaultInboxURL) {
        self.inboxURL = inboxURL
    }

    // MARK: - Import

    /// Punto de entrada para la UI (launch / scenePhase): no hace nada bajo XCTest.
    func importPendingFromUI(into context: ModelContext) {
        guard !Self.isRunningUnderTests else { return }
        importPending(into: context)
    }

    @discardableResult
    func importPending(into context: ModelContext) -> Summary {
        var summary = Summary()
        guard !isImporting else { return summary }
        isImporting = true
        defer { isImporting = false }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: inboxURL.path, isDirectory: &isDir), isDir.boolValue else {
            return summary   // sin carpeta = nada que hacer
        }

        let files: [URL]
        do {
            files = try pendingFiles()
        } catch {
            Self.logger.error("No se pudo listar el Inbox: \(error.localizedDescription, privacy: .public)")
            return summary
        }

        for file in files {
            do {
                let outcome = try importFile(file, into: context)
                try fm.removeItem(at: file)   // recién después del save exitoso
                switch outcome {
                case .imported:  summary.imported += 1
                case .duplicate: summary.duplicates += 1
                }
            } catch ImportError.noWorkspace {
                summary.deferred += 1
                Self.logger.notice("Import diferido (sin workspace): \(file.lastPathComponent, privacy: .public)")
            } catch {
                summary.failed += 1
                Self.logger.error("Falló \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                moveToFailed(file)
            }
        }
        return summary
    }

    // MARK: - Private

    private enum Outcome { case imported, duplicate }

    /// `*.json` regulares del Inbox (sin subcarpetas como Failed/), los más viejos primero.
    private func pendingFiles() throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: inboxURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a == b ? $0.lastPathComponent < $1.lastPathComponent : a < b
            }
    }

    private func importFile(_ file: URL, into context: ModelContext) throws -> Outcome {
        let data = try Data(contentsOf: file)
        let payload = try JSONDecoder().decode(Payload.self, from: data)

        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = payload.project.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw ImportError.emptyTitle }
        guard !projectName.isEmpty else { throw ImportError.emptyProjectName }
        let dueDate = try payload.dueDate.map(Self.parseLocalDate)

        // Idempotencia: si ya se importó (ej. crash entre save y borrado), no duplicar.
        if let id = payload.id {
            let existing = try context.fetchCount(FetchDescriptor<Issue>(predicate: #Predicate { $0.id == id }))
            if existing > 0 { return .duplicate }
        }

        let (project, createdProject) = try resolveProject(named: projectName, in: context)

        // Mismo camino que NewIssueSheet.create().
        let issue = Issue(title: title)
        if let id = payload.id { issue.id = id }
        issue.details  = payload.details.trimmingCharacters(in: .whitespaces)
        issue.status   = payload.status
        issue.priority = payload.priority
        issue.dueDate  = dueDate
        issue.project  = project
        issue.code     = Issue.makeCode(for: project)
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)

        do {
            try context.save()
        } catch {
            // Deshacer solo lo nuestro (sin rollback global: no pisar cambios del usuario).
            context.delete(issue)
            if createdProject { context.delete(project) }
            throw error
        }
        return .imported
    }

    /// Busca un proyecto por nombre (trim + case-insensitive, en todos los
    /// workspaces; gana el más viejo). Si no existe, lo crea igual que
    /// `SidebarView.addProject(to:)`, en el primer workspace (por createdAt).
    private func resolveProject(named name: String, in context: ModelContext) throws -> (Project, created: Bool) {
        let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt)]))
        let wanted = Self.normalize(name)
        if let match = projects.first(where: { Self.normalize($0.name) == wanted }) {
            return (match, false)
        }

        let workspaces = try context.fetch(FetchDescriptor<Workspace>(sortBy: [SortDescriptor(\.createdAt)]))
        guard let workspace = workspaces.first else { throw ImportError.noWorkspace }

        let project = Project(name: name)
        project.workspace = workspace
        if workspace.projects == nil { workspace.projects = [] }
        workspace.projects?.append(project)
        context.insert(project)
        return (project, true)
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// "YYYY-MM-DD" → inicio de ese día en el calendario local.
    static func parseLocalDate(_ string: String) throws -> Date {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { throw ImportError.invalidDueDate(string) }

        let cal = Calendar.current
        guard let date = cal.date(from: DateComponents(year: y, month: m, day: d)),
              cal.dateComponents([.year, .month, .day], from: date) == DateComponents(year: y, month: m, day: d)
        else { throw ImportError.invalidDueDate(string) }
        return date
    }

    private func moveToFailed(_ file: URL) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: failedURL, withIntermediateDirectories: true)
            var dest = failedURL.appendingPathComponent(file.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                let stamp = Int(Date().timeIntervalSince1970)
                dest = failedURL.appendingPathComponent("\(stamp)-\(file.lastPathComponent)")
            }
            try fm.moveItem(at: file, to: dest)
        } catch {
            // El archivo queda en el Inbox (no se borra); se va a reintentar.
            Self.logger.error("No se pudo mover a Failed/: \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
