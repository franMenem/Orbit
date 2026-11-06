import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Orbit

/// Todos los tests usan un ModelContainer en memoria (sin CloudKit) y un
/// directorio temporal propio: nunca tocan el Inbox real.
@MainActor
struct InboxImporterTests {

    // MARK: - Helpers

    private struct Env {
        let container: ModelContainer
        let context: ModelContext
        let inbox: URL
        let importer: InboxImporter
        let workspace: Workspace
    }

    private func makeEnv(createInboxDir: Bool = true, withWorkspace: Bool = true) throws -> Env {
        let config = ModelConfiguration(
            schema: ContainerFactory.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: ContainerFactory.schema, configurations: [config])
        let context = container.mainContext

        let workspace = Workspace(name: "WS")
        if withWorkspace { context.insert(workspace) }
        try context.save()

        let inbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbitInboxTests-\(UUID().uuidString)", isDirectory: true)
        if createInboxDir {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        }
        return Env(container: container, context: context, inbox: inbox,
                   importer: InboxImporter(inboxURL: inbox), workspace: workspace)
    }

    @discardableResult
    private func write(_ json: String, named name: String = "\(UUID().uuidString).json", in inbox: URL) throws -> URL {
        let url = inbox.appendingPathComponent(name)
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func files(in dir: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    private func issues(_ ctx: ModelContext) throws -> [Orbit.Issue] {
        try ctx.fetch(FetchDescriptor<Orbit.Issue>())
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Tests

    @Test func decodesAndMapsFullFile() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = Project(name: "Orbit")
        project.workspace = env.workspace
        env.context.insert(project)
        try env.context.save()

        let id = "c0360e2a-a62c-49fe-a4bf-a2d47dea8232"
        let file = try write("""
        {"title": "Revisar la configuración", "project": "Orbit", "details": "Detalle ñandú", "status": "inProgress", "priority": 3, "due_date": "2026-11-10", "id": "\(id)"}
        """, named: "\(id).json", in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.imported == 1)
        #expect(summary.failed == 0)
        let all = try issues(env.context)
        #expect(all.count == 1)
        let issue = try #require(all.first)
        #expect(issue.title == "Revisar la configuración")
        #expect(issue.details == "Detalle ñandú")
        #expect(issue.status == .inProgress)
        #expect(issue.priority == .high)
        #expect(issue.dueDate == day(2026, 11, 10))
        #expect(issue.id == UUID(uuidString: id))
        #expect(issue.code == "ORB-1")
        #expect(issue.project?.persistentModelID == project.persistentModelID)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func nullDueDateAndEmptyDetails() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        try write("""
        {"title": "Sin fecha", "project": "General", "details": "", "status": "backlog", "priority": 0, "due_date": null, "id": "\(UUID().uuidString)"}
        """, in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.imported == 1)
        let issue = try #require(try issues(env.context).first)
        #expect(issue.dueDate == nil)
        #expect(issue.details == "")
        #expect(issue.status == .backlog)
        #expect(issue.priority == IssuePriority.none)
    }

    @Test func unknownProjectIsCreatedInFirstWorkspace() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        try write(#"{"title": "A", "project": "Proyecto Nuevo", "status": "todo", "priority": 1}"#, in: env.inbox)
        try write(#"{"title": "B", "project": "  proyecto nuevo ", "status": "todo", "priority": 1}"#, in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.imported == 2)
        let projects = try env.context.fetch(FetchDescriptor<Project>())
        #expect(projects.count == 1)   // el segundo matchea case-insensitive + trim
        let project = try #require(projects.first)
        #expect(project.name == "Proyecto Nuevo")
        #expect(project.workspace?.persistentModelID == env.workspace.persistentModelID)
        #expect(project.unwrappedIssues.count == 2)
        #expect(Set(project.unwrappedIssues.map(\.code)) == ["PRO-1", "PRO-2"])
    }

    @Test func existingProjectMatchesCaseInsensitiveAndTrimmed() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = Project(name: "Orbit")
        project.workspace = env.workspace
        env.context.insert(project)
        try env.context.save()
        try write(#"{"title": "A", "project": "  ORBIT  "}"#, in: env.inbox)

        env.importer.importPending(into: env.context)

        #expect(try env.context.fetchCount(FetchDescriptor<Project>()) == 1)
        #expect(project.unwrappedIssues.count == 1)
    }

    @Test func invalidFilesGoToFailedAndOthersStillImport() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        try write("esto no es json", named: "malo1.json", in: env.inbox)
        try write(#"{"title": "X", "project": "P", "status": "nope", "priority": 1}"#, named: "malo2.json", in: env.inbox)
        try write(#"{"title": "X", "project": "P", "due_date": "2026-13-45"}"#, named: "malo3.json", in: env.inbox)
        try write(#"{"title": "   ", "project": "P"}"#, named: "malo4.json", in: env.inbox)
        try write(#"{"title": "Bueno", "project": "P"}"#, named: "bueno.json", in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.failed == 4)
        #expect(summary.imported == 1)
        #expect(try issues(env.context).map(\.title) == ["Bueno"])
        #expect(files(in: env.inbox) == ["Failed"])
        #expect(files(in: env.importer.failedURL) == ["malo1.json", "malo2.json", "malo3.json", "malo4.json"])
    }

    @Test func missingFolderIsNoOp() throws {
        let env = try makeEnv(createInboxDir: false)
        let summary = env.importer.importPending(into: env.context)
        #expect(summary == InboxImporter.Summary())
        #expect(!FileManager.default.fileExists(atPath: env.inbox.path))
        #expect(try issues(env.context).isEmpty)
    }

    @Test func noWorkspaceKeepsFileInInbox() throws {
        let env = try makeEnv(withWorkspace: false)
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let file = try write(#"{"title": "A", "project": "P"}"#, in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.deferred == 1)
        #expect(summary.failed == 0)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(try issues(env.context).isEmpty)
    }

    @Test func alreadyImportedIdIsNotDuplicated() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let json = #"{"title": "A", "project": "P", "id": "\#(UUID().uuidString)"}"#
        let f1 = try write(json, named: "a.json", in: env.inbox)
        env.importer.importPending(into: env.context)
        // Simula crash entre save y borrado: el archivo reaparece.
        try json.write(to: f1, atomically: true, encoding: .utf8)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.duplicates == 1)
        #expect(try issues(env.context).count == 1)
        #expect(files(in: env.inbox).isEmpty)
    }

    @Test func ignoresNonJsonFilesAndFailedFolder() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        try write("hola", named: "notas.txt", in: env.inbox)
        try FileManager.default.createDirectory(at: env.importer.failedURL, withIntermediateDirectories: true)
        try write("roto", named: "viejo.json", in: env.importer.failedURL)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary == InboxImporter.Summary())
        #expect(files(in: env.inbox) == ["Failed", "notas.txt"])
        #expect(files(in: env.importer.failedURL) == ["viejo.json"])
    }

    // MARK: - Helpers (acciones, labels, snapshot)

    /// Escribe un archivo con fecha de creación explícita, para que el orden
    /// "más viejo primero" sea determinista en los tests.
    @discardableResult
    private func writeAt(_ seconds: TimeInterval, _ json: String, in inbox: URL) throws -> URL {
        let url = try write(json, in: inbox)
        try FileManager.default.setAttributes(
            [.creationDate: Date(timeIntervalSince1970: 1_700_000_000 + seconds)], ofItemAtPath: url.path)
        return url
    }

    private func seedProject(_ env: Env, name: String = "Orbit") throws -> Project {
        let project = Project(name: name)
        project.workspace = env.workspace
        env.context.insert(project)
        try env.context.save()
        return project
    }

    private func issue(code: String, _ ctx: ModelContext) throws -> Orbit.Issue? {
        try ctx.fetch(FetchDescriptor<Orbit.Issue>()).first { $0.code == code }
    }

    private func labelNames(_ i: Orbit.Issue) -> [String] { i.unwrappedLabels.map(\.name) }

    private func addIssue(_ env: Env, _ project: Project, title: String = "T") throws -> Orbit.Issue {
        let i = Orbit.Issue(title: title)
        i.project = project
        i.code = Orbit.Issue.makeCode(for: project)
        project.issues?.append(i)
        env.context.insert(i)
        try env.context.save()
        return i
    }

    // MARK: - create: solution + labels

    @Test func createWithLabelsAndSolution() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        _ = try seedProject(env)
        let existing = Orbit.Label(name: "Bug", colorHex: "#123456")
        existing.workspace = env.workspace
        env.workspace.labels?.append(existing)
        env.context.insert(existing)
        try env.context.save()

        try write("""
        {"action": "create", "title": "A", "project": "Orbit", "solution": "Reiniciar", "labels": ["  bug ", "api", "API", "   ", ""]}
        """, in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.imported == 1)
        let i = try #require(try issues(env.context).first)
        #expect(i.solution == "Reiniciar")
        #expect(labelNames(i) == ["Bug", "api"])   // "bug" matcheó el existente; "api"/"API" colapsan
        let all = try env.context.fetch(FetchDescriptor<Orbit.Label>())
        #expect(all.count == 2)
        let api = try #require(all.first { $0.name == "api" })
        #expect(api.workspace?.persistentModelID == env.workspace.persistentModelID)
        #expect(api.colorHex == SwiftUI.Color.labelPalette[0].hex)
        #expect(existing.issues?.count == 1)   // ambos lados de la relación
    }

    @Test func absentActionIsCreateAndInvalidActionFails() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        try write(#"{"title": "Sin action", "project": "P"}"#, named: "ok.json", in: env.inbox)
        try write(#"{"action": "explode", "title": "X", "project": "P"}"#, named: "bad.json", in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.imported == 1)
        #expect(summary.failed == 1)
        #expect(try issues(env.context).map(\.title) == ["Sin action"])
        #expect(files(in: env.importer.failedURL) == ["bad.json"])
    }

    // MARK: - update

    @Test func updateChangesOnlyPresentKeys() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = try seedProject(env)
        let i = try addIssue(env, project, title: "Original")
        i.details = "d"; i.priority = .low; i.dueDate = day(2026, 11, 10)
        i.updatedAt = Date(timeIntervalSince1970: 0)
        try env.context.save()

        let file = try write(#"{"action": "update", "id": "\#(UUID().uuidString)", "code": "ORB-1", "status": "done", "solution": "Listo"}"#, in: env.inbox)
        let summary = env.importer.importPending(into: env.context)

        #expect(summary.updated == 1)
        #expect(i.status == .done)
        #expect(i.solution == "Listo")
        #expect(i.title == "Original")
        #expect(i.details == "d")
        #expect(i.priority == .low)
        #expect(i.dueDate == day(2026, 11, 10))
        #expect(i.updatedAt > Date(timeIntervalSince1970: 1))
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func updateAllScalarFieldsAndDueDateNullClears() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = try seedProject(env)
        let i = try addIssue(env, project)
        i.dueDate = day(2026, 11, 10)
        try env.context.save()

        try writeAt(0, #"{"action": "update", "code": "orb-1", "title": " Nuevo ", "details": "dd", "priority": 4, "due_date": "2026-12-01"}"#, in: env.inbox)
        env.importer.importPending(into: env.context)
        #expect(i.title == "Nuevo")
        #expect(i.details == "dd")
        #expect(i.priority == .urgent)
        #expect(i.dueDate == day(2026, 12, 1))

        try writeAt(1, #"{"action": "update", "code": "ORB-1", "due_date": null}"#, in: env.inbox)
        env.importer.importPending(into: env.context)
        #expect(i.dueDate == nil)
    }

    @Test func updateLabelsReplacesWholeSet() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = try seedProject(env)
        let i = try addIssue(env, project)
        try write(#"{"action": "update", "code": "ORB-1", "labels": ["a", "b"]}"#, in: env.inbox)
        env.importer.importPending(into: env.context)
        #expect(labelNames(i) == ["a", "b"])

        try write(#"{"action": "update", "code": "ORB-1", "labels": ["B", "c"]}"#, in: env.inbox)
        env.importer.importPending(into: env.context)
        #expect(labelNames(i) == ["b", "c"])
        let a = try #require(try env.context.fetch(FetchDescriptor<Orbit.Label>()).first { $0.name == "a" })
        #expect((a.issues ?? []).isEmpty)

        try write(#"{"action": "update", "code": "ORB-1", "labels": []}"#, in: env.inbox)
        env.importer.importPending(into: env.context)
        #expect(labelNames(i).isEmpty)
    }

    @Test func updateMovesProjectKeepingCode() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let orbit = try seedProject(env)
        let i = try addIssue(env, orbit)

        try write(#"{"action": "update", "code": "ORB-1", "project": "Otro Proyecto"}"#, in: env.inbox)
        env.importer.importPending(into: env.context)

        #expect(i.project?.name == "Otro Proyecto")
        #expect(i.code == "ORB-1")
        #expect(orbit.unwrappedIssues.isEmpty)
        #expect(i.project?.unwrappedIssues.count == 1)
    }

    @Test func updateOrDeleteUnknownCodeGoesToFailed() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = try seedProject(env)
        _ = try addIssue(env, project)
        try write(#"{"action": "update", "code": "ORB-99", "status": "done"}"#, named: "u.json", in: env.inbox)
        try write(#"{"action": "delete", "code": "ZZZ-1"}"#, named: "d.json", in: env.inbox)
        try write(#"{"action": "update", "code": "ORB-1", "status": "nope"}"#, named: "bad-status.json", in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        #expect(summary.failed == 3)
        #expect(files(in: env.importer.failedURL) == ["bad-status.json", "d.json", "u.json"])
        #expect(try issues(env.context).count == 1)
    }

    // MARK: - delete

    @Test func deleteRemovesIssueWithCascadeAndKeepsLabels() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let project = try seedProject(env)
        let i = try addIssue(env, project)
        let label = Orbit.Label(name: "x")
        label.workspace = env.workspace
        env.context.insert(label)
        i.labels = [label]; label.issues = [i]
        let comment = Orbit.Comment(text: "hola"); comment.issue = i; env.context.insert(comment)
        let att = Orbit.Attachment(filename: "f", contentType: "text/plain", data: Data([1])); att.issue = i; env.context.insert(att)
        try env.context.save()

        var notified = 0
        env.importer.willDeleteIssue = { _ in notified += 1 }
        try write(#"{"action": "delete", "id": "\#(UUID().uuidString)", "code": "ORB-1"}"#, in: env.inbox)
        let summary = env.importer.importPending(into: env.context)

        #expect(summary.deleted == 1)
        #expect(notified == 1)
        #expect(try issues(env.context).isEmpty)
        #expect(try env.context.fetchCount(FetchDescriptor<Orbit.Comment>()) == 0)
        #expect(try env.context.fetchCount(FetchDescriptor<Orbit.Attachment>()) == 0)
        #expect(try env.context.fetchCount(FetchDescriptor<Orbit.Label>()) == 1)
        #expect((label.issues ?? []).isEmpty)
        #expect(project.unwrappedIssues.isEmpty)
    }

    @Test func createThenUpdateThenDeleteApplyInOrder() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        // Nombres que ordenarían al revés alfabéticamente: manda la fecha de creación.
        try writeAt(2, #"{"action": "update", "code": "ORB-1", "status": "done", "labels": ["l"]}"#, in: env.inbox)
        try writeAt(1, #"{"action": "create", "title": "Nueva", "project": "Orbit"}"#, in: env.inbox)

        let summary = env.importer.importPending(into: env.context)

        // Orden de procesamiento: create (t=1) y luego update (t=2).
        #expect(summary.imported == 1)
        #expect(summary.updated == 1)
        #expect(summary.failed == 0)
        let i = try #require(try issue(code: "ORB-1", env.context))
        #expect(i.status == .done)
        #expect(labelNames(i) == ["l"])

        try writeAt(3, #"{"action": "delete", "code": "ORB-1"}"#, in: env.inbox)
        #expect(env.importer.importPending(into: env.context).deleted == 1)
        #expect(try issues(env.context).isEmpty)
    }

    // MARK: - Snapshot

    @Test func snapshotContentAndFormat() throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let exportURL = env.inbox.deletingLastPathComponent()
            .appendingPathComponent("OrbitExportTests-\(UUID().uuidString)/Export/issues.json")
        defer { try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent().deletingLastPathComponent()) }
        let exporter = IssueSnapshotExporter(exportURL: exportURL)

        try writeAt(0, #"{"action": "create", "title": "Primera", "project": "Orbit", "details": "d", "solution": "s", "status": "inProgress", "priority": 3, "due_date": "2026-11-10", "labels": ["bug", "api"]}"#, in: env.inbox)
        try writeAt(1, #"{"action": "create", "title": "Segunda", "project": "Orbit"}"#, in: env.inbox)
        try writeAt(2, #"{"action": "create", "title": "Tercera", "project": "Orbit"}"#, in: env.inbox)
        try writeAt(3, #"{"action": "delete", "code": "ORB-3"}"#, in: env.inbox)
        env.importer.importPending(into: env.context)
        // Fechas de creación distintas y conocidas para verificar el orden.
        for (n, i) in try issues(env.context).sorted(by: { $0.code < $1.code }).enumerated() {
            i.createdAt = Date(timeIntervalSince1970: 1_700_000_000 - Double(n) * 100)   // ORB-1 el más nuevo
            i.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        }
        try env.context.save()

        #expect(exporter.export(from: env.context))
        #expect(!exporter.export(from: env.context))   // sin cambios: no reescribe

        let data = try Data(contentsOf: exportURL)
        let rows = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(rows.map { $0["code"] as? String } == ["ORB-2", "ORB-1"])   // sin la borrada, por created_at
        let first = rows[1]
        #expect(first["title"] as? String == "Primera")
        #expect(first["project"] as? String == "Orbit")
        #expect(first["details"] as? String == "d")
        #expect(first["solution"] as? String == "s")
        #expect(first["status"] as? String == "inProgress")
        #expect(first["priority"] as? Int == 3)
        #expect(first["due_date"] as? String == "2026-11-10")
        #expect(first["labels"] as? [String] == ["api", "bug"])
        #expect(first["created_at"] as? String == "2023-11-14T22:13:20Z")
        #expect(first["updated_at"] as? String == "2023-11-14T22:13:20Z")
        #expect(Set(first.keys) == ["code", "title", "project", "details", "solution", "status", "priority", "due_date", "labels", "created_at", "updated_at"])
        // due_date ausente → null explícito
        #expect(rows[0]["due_date"] is NSNull)
        // sin archivos temporales colgados
        #expect(files(in: exportURL.deletingLastPathComponent()) == ["issues.json"])
    }

    @Test func syncExportsAtStartAfterImportAndAfterUISave() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let exportURL = env.inbox.deletingLastPathComponent()
            .appendingPathComponent("OrbitExportTests-\(UUID().uuidString)/Export/issues.json")
        defer { try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent().deletingLastPathComponent()) }
        let project = try seedProject(env)
        let i = try addIssue(env, project, title: "Antes")

        let sync = InboxSync(importer: env.importer,
                             exporter: IssueSnapshotExporter(exportURL: exportURL),
                             exportDebounce: .milliseconds(150), watchDebounce: 0.1)
        sync.start(context: env.context)
        defer { sync.stop() }

        func titles() -> [String] {
            guard let d = try? Data(contentsOf: exportURL),
                  let rows = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
            return rows.compactMap { $0["title"] as? String }
        }
        #expect(titles() == ["Antes"])   // export al arrancar

        // Cambio "de la UI": edit + save → didSave → export con debounce.
        i.title = "Después"
        try env.context.save()
        #expect(await eventually { titles() == ["Después"] })
    }

    // MARK: - Watcher / live import

    private func eventually(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func watcherPicksUpNewFileAndCreatesMissingFolder() async throws {
        let env = try makeEnv(createInboxDir: false)   // la carpeta no existe: el watcher la crea
        defer { try? FileManager.default.removeItem(at: env.inbox) }
        let exportURL = env.inbox.deletingLastPathComponent()
            .appendingPathComponent("OrbitExportTests-\(UUID().uuidString)/Export/issues.json")
        defer { try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent().deletingLastPathComponent()) }

        let sync = InboxSync(importer: env.importer,
                             exporter: IssueSnapshotExporter(exportURL: exportURL),
                             exportDebounce: .milliseconds(150), watchDebounce: 0.1)
        sync.start(context: env.context)
        defer { sync.stop() }
        #expect(FileManager.default.fileExists(atPath: env.inbox.path))

        let file = try write(#"{"title": "En vivo", "project": "Live"}"#, in: env.inbox)

        #expect(await eventually { (try? self.issues(env.context).count) == 1 })
        #expect(await eventually { !FileManager.default.fileExists(atPath: file.path) })
        #expect(await eventually { (try? String(contentsOf: exportURL, encoding: .utf8))?.contains("En vivo") == true })
    }
}
