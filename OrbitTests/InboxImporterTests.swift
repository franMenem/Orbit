import Foundation
import SwiftData
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
}
