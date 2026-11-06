import Foundation
import SwiftData
import SwiftUI
import os

/// Aplica a SwiftData los comandos que la API local de Orbit (orbit_api) deja
/// como archivos JSON en `~/Library/Application Support/Orbit/Inbox/`.
///
/// Cada archivo tiene una `"action"` opcional: `create` (default si falta),
/// `update` o `delete`. Los archivos se procesan del más viejo al más nuevo,
/// así un create seguido de un update sobre la misma issue se aplica en orden.
///
/// Contrato por archivo:
///  - Se decodifica, se aplica el comando (create = igual que
///    `NewIssueSheet.create()`; update = campos presentes; delete = igual que
///    `IssueListView.deleteSelected()`), se hace `save()` y SOLO después de un
///    save exitoso se borra el archivo.
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
        var updated = 0
        var deleted = 0
    }

    enum ImportError: LocalizedError {
        case emptyTitle
        case emptyProjectName
        case invalidDueDate(String)
        case noWorkspace
        case invalidAction(String)
        case emptyCode
        case unknownCode(String)
        case ambiguousCode(String)
        case projectWithoutWorkspace

        var errorDescription: String? {
            switch self {
            case .emptyTitle:               "title vacío"
            case .emptyProjectName:         "project vacío"
            case .invalidDueDate(let s):    "due_date inválida: \(s)"
            case .noWorkspace:              "no hay ningún workspace donde crear el proyecto"
            case .invalidAction(let a):     "action inválida: \(a)"
            case .emptyCode:                "code vacío"
            case .unknownCode(let c):       "no existe ninguna issue con code \(c)"
            case .ambiguousCode(let c):     "hay más de una issue con code \(c)"
            case .projectWithoutWorkspace:  "el proyecto no tiene workspace (no se pueden resolver labels)"
            }
        }
    }

    enum Action: String {
        case create, update, delete
    }

    /// Forma del JSON de un `create`. `status`/`priority` desconocidos hacen
    /// fallar el decode (el archivo va a Failed/).
    struct Payload: Decodable {
        let id: UUID?
        let title: String
        let project: String
        let details: String
        let solution: String
        let status: IssueStatus
        let priority: IssuePriority
        let dueDate: String?
        let labels: [String]

        enum CodingKeys: String, CodingKey {
            case id, title, project, details, solution, status, priority, labels
            case dueDate = "due_date"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(UUID.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            project = try c.decode(String.self, forKey: .project)
            details = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
            solution = try c.decodeIfPresent(String.self, forKey: .solution) ?? ""
            status = try c.decodeIfPresent(IssueStatus.self, forKey: .status) ?? .backlog
            priority = try c.decodeIfPresent(IssuePriority.self, forKey: .priority) ?? .none
            dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
            labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        }
    }

    /// Forma del JSON de un `update`: solo se cambian las claves presentes
    /// (una clave con `null` cuenta como ausente, salvo `due_date`, donde
    /// `null` borra la fecha).
    struct UpdatePayload: Decodable {
        enum DueDate: Equatable { case unchanged, clear, set(String) }

        let code: String
        let title: String?
        let details: String?
        let solution: String?
        let status: IssueStatus?
        let priority: IssuePriority?
        let dueDate: DueDate
        let labels: [String]?
        let project: String?

        enum CodingKeys: String, CodingKey {
            case code, title, details, solution, status, priority, labels, project
            case dueDate = "due_date"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = try c.decode(String.self, forKey: .code)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            details = try c.decodeIfPresent(String.self, forKey: .details)
            solution = try c.decodeIfPresent(String.self, forKey: .solution)
            status = try c.decodeIfPresent(IssueStatus.self, forKey: .status)
            priority = try c.decodeIfPresent(IssuePriority.self, forKey: .priority)
            labels = try c.decodeIfPresent([String].self, forKey: .labels)
            project = try c.decodeIfPresent(String.self, forKey: .project)
            if c.contains(.dueDate) {
                dueDate = try c.decodeNil(forKey: .dueDate) ? .clear : .set(try c.decode(String.self, forKey: .dueDate))
            } else {
                dueDate = .unchanged
            }
        }
    }

    struct DeletePayload: Decodable {
        let code: String
    }

    private struct ActionProbe: Decodable {
        let action: String?
    }

    // MARK: - Properties

    static let logger = Logger(subsystem: "com.fran.Orbit", category: "InboxImporter")

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

    /// Se llama justo antes de borrar una issue por un comando `delete`, para
    /// que la UI suelte referencias (ej. `selection.selectedIssue`).
    var willDeleteIssue: ((Issue) -> Void)?

    init(inboxURL: URL = InboxImporter.defaultInboxURL) {
        self.inboxURL = inboxURL
    }

    // MARK: - Import

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
                case .updated:   summary.updated += 1
                case .deleted:   summary.deleted += 1
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

    private enum Outcome { case imported, duplicate, updated, deleted }

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
        let decoder = JSONDecoder()
        let rawAction = try decoder.decode(ActionProbe.self, from: data).action
        let action: Action
        if let rawAction {
            guard let parsed = Action(rawValue: rawAction) else { throw ImportError.invalidAction(rawAction) }
            action = parsed
        } else {
            action = .create
        }
        switch action {
        case .create:
            return try create(try decoder.decode(Payload.self, from: data), into: context)
        case .update:
            return try update(try decoder.decode(UpdatePayload.self, from: data), in: context)
        case .delete:
            return try delete(try decoder.decode(DeletePayload.self, from: data), in: context)
        }
    }

    // MARK: - create

    private func create(_ payload: Payload, into context: ModelContext) throws -> Outcome {

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
        issue.solution = payload.solution.trimmingCharacters(in: .whitespaces)
        issue.status   = payload.status
        issue.priority = payload.priority
        issue.dueDate  = dueDate
        issue.project  = project
        issue.code     = Issue.makeCode(for: project)
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)

        var createdLabels: [Orbit.Label] = []
        do {
            if !payload.labels.isEmpty {
                guard let workspace = project.workspace else { throw ImportError.projectWithoutWorkspace }
                let (labels, created) = resolveLabels(named: payload.labels, in: workspace, context: context)
                createdLabels = created
                link(labels, to: issue)
            }
            try context.save()
        } catch {
            // Deshacer solo lo nuestro (sin rollback global: no pisar cambios del usuario).
            unlinkAllLabels(of: issue)
            context.delete(issue)
            createdLabels.forEach { context.delete($0) }
            if createdProject { context.delete(project) }
            throw error
        }
        return .imported
    }

    // MARK: - update

    private func update(_ p: UpdatePayload, in context: ModelContext) throws -> Outcome {
        let issue = try findIssue(code: p.code, in: context)

        // Validar todo ANTES de mutar nada.
        let title = try p.title.map { raw -> String in
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { throw ImportError.emptyTitle }
            return t
        }
        let projectName = try p.project.map { raw -> String in
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { throw ImportError.emptyProjectName }
            return t
        }
        var newDueDate: Date??   // nil = sin cambios; .some(nil) = borrar
        switch p.dueDate {
        case .unchanged:      newDueDate = nil
        case .clear:          newDueDate = .some(nil)
        case .set(let s):     newDueDate = .some(try Self.parseLocalDate(s))
        }

        // Estado previo, para deshacer solo lo nuestro si falla el save.
        let old = (title: issue.title, details: issue.details, solution: issue.solution,
                   status: issue.status, priority: issue.priority, dueDate: issue.dueDate,
                   updatedAt: issue.updatedAt, project: issue.project, labels: issue.labels ?? [])
        var createdProject: Project?
        var createdLabels: [Orbit.Label] = []

        do {
            var targetProject = issue.project
            if let projectName {
                let (project, created) = try resolveProject(named: projectName, in: context)
                if created { createdProject = project }
                targetProject = project
            }
            let movedProject = targetProject.map { $0.persistentModelID } != issue.project.map { $0.persistentModelID }
            let workspaceChanged = movedProject
                && targetProject?.workspace?.persistentModelID != issue.project?.workspace?.persistentModelID

            if let title { issue.title = title }
            if let d = p.details { issue.details = d.trimmingCharacters(in: .whitespaces) }
            if let s = p.solution { issue.solution = s.trimmingCharacters(in: .whitespaces) }
            if let s = p.status { issue.status = s }
            if let pr = p.priority { issue.priority = pr }
            if let dd = newDueDate { issue.dueDate = dd }

            // Mover de proyecto conserva el `code` (ver informe: los códigos
            // no se renumeran, igual que al renombrar un proyecto en la UI).
            if movedProject, let target = targetProject {
                issue.project = target
                if target.issues == nil { target.issues = [] }
                target.issues?.append(issue)
                old.project?.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
            }

            // Labels: `labels` reemplaza el set completo. Si cambió el
            // workspace y no vino `labels`, se re-resuelven por nombre en el
            // workspace nuevo (los labels son por workspace).
            let labelNames: [String]?
            if let names = p.labels {
                labelNames = names
            } else if workspaceChanged {
                labelNames = old.labels.map(\.name)
            } else {
                labelNames = nil
            }
            if let names = labelNames {
                guard let workspace = targetProject?.workspace else { throw ImportError.projectWithoutWorkspace }
                let (labels, created) = resolveLabels(named: names, in: workspace, context: context)
                createdLabels = created
                unlinkAllLabels(of: issue)
                link(labels, to: issue)
            }

            issue.updatedAt = .now   // igual que IssueDetailView.save()
            try context.save()
        } catch {
            issue.title = old.title; issue.details = old.details; issue.solution = old.solution
            issue.status = old.status; issue.priority = old.priority; issue.dueDate = old.dueDate
            issue.updatedAt = old.updatedAt
            if issue.project?.persistentModelID != old.project?.persistentModelID {
                issue.project?.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
                issue.project = old.project
                if let op = old.project, !(op.issues ?? []).contains(where: { $0.persistentModelID == issue.persistentModelID }) {
                    op.issues?.append(issue)
                }
            }
            unlinkAllLabels(of: issue)
            link(old.labels, to: issue)
            createdLabels.forEach { context.delete($0) }
            if let createdProject { context.delete(createdProject) }
            throw error
        }
        return .updated
    }

    // MARK: - delete

    /// Mismo camino que `IssueListView.deleteSelected()`: se sueltan las
    /// referencias de los labels (deleteRule .nullify) y se borra la issue;
    /// attachments y comments se borran por cascade.
    private func delete(_ p: DeletePayload, in context: ModelContext) throws -> Outcome {
        let issue = try findIssue(code: p.code, in: context)
        willDeleteIssue?(issue)
        unlinkAllLabels(of: issue)
        context.delete(issue)
        try context.save()
        return .deleted
    }

    // MARK: - Helpers de issues y labels

    /// Busca por `Issue.code` (trim, case-insensitive). Si hay más de una
    /// (dos proyectos con el mismo prefijo de 3 letras) es ambiguo y falla.
    private func findIssue(code: String, in context: ModelContext) throws -> Issue {
        let wanted = Self.normalize(code)
        guard !wanted.isEmpty else { throw ImportError.emptyCode }
        let matches = try context.fetch(FetchDescriptor<Issue>()).filter { Self.normalize($0.code) == wanted }
        guard let first = matches.first else { throw ImportError.unknownCode(code) }
        guard matches.count == 1 else { throw ImportError.ambiguousCode(code) }
        return first
    }

    /// Los labels son POR WORKSPACE (`Workspace.labels`; la UI solo ofrece los
    /// del workspace del proyecto). Se matchea por nombre (trim, case-insensitive,
    /// gana el más viejo); los que faltan se crean como `NewLabelSheet.create()`
    /// (primer color de la paleta). Nombres vacíos se ignoran, duplicados se colapsan.
    private func resolveLabels(named names: [String], in workspace: Workspace, context: ModelContext)
        -> (all: [Orbit.Label], created: [Orbit.Label]) {
        var all: [Orbit.Label] = []
        var created: [Orbit.Label] = []
        var seen = Set<String>()
        let existing = (workspace.labels ?? []).sorted { $0.createdAt < $1.createdAt }
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = Self.normalize(name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            if let match = (existing + created).first(where: { Self.normalize($0.name) == key }) {
                all.append(match)
            } else {
                let label = Orbit.Label(name: name, colorHex: Color.labelPalette[0].hex)
                label.workspace = workspace
                if workspace.labels == nil { workspace.labels = [] }
                workspace.labels?.append(label)
                context.insert(label)
                created.append(label)
                all.append(label)
            }
        }
        return (all, created)
    }

    /// Ambos lados de la relación, como `IssueLabelsValue.toggle`.
    private func link(_ labels: [Orbit.Label], to issue: Issue) {
        for label in labels {
            if issue.labels == nil { issue.labels = [] }
            issue.labels?.append(label)
            if label.issues == nil { label.issues = [] }
            label.issues?.append(issue)
        }
    }

    private func unlinkAllLabels(of issue: Issue) {
        for label in issue.labels ?? [] {
            label.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
        }
        issue.labels = []
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
