import Foundation
import SwiftData
import os

/// Escribe `~/Library/Application Support/Orbit/Export/issues.json`: una foto
/// de todas las issues, para que la API local de Python responda los GET sin
/// abrir el store de SwiftData.
final class IssueSnapshotExporter {

    struct Row: Encodable {
        let code: String
        let title: String
        let project: String
        let details: String
        let solution: String
        let status: String
        let priority: Int
        let dueDate: String?
        let labels: [String]
        let createdAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case code, title, project, details, solution, status, priority, labels
            case dueDate = "due_date"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(code, forKey: .code)
            try c.encode(title, forKey: .title)
            try c.encode(project, forKey: .project)
            try c.encode(details, forKey: .details)
            try c.encode(solution, forKey: .solution)
            try c.encode(status, forKey: .status)
            try c.encode(priority, forKey: .priority)
            try c.encode(dueDate, forKey: .dueDate)   // null explícito cuando no hay fecha
            try c.encode(labels, forKey: .labels)
            try c.encode(createdAt, forKey: .createdAt)
            try c.encode(updatedAt, forKey: .updatedAt)
        }
    }

    static let logger = Logger(subsystem: "com.fran.Orbit", category: "IssueSnapshotExporter")

    static var defaultExportURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Orbit/Export/issues.json")
    }

    let exportURL: URL

    /// Último contenido escrito: si no cambió, no se vuelve a escribir el archivo.
    private var lastWritten: Data?

    init(exportURL: URL = IssueSnapshotExporter.defaultExportURL) {
        self.exportURL = exportURL
    }

    /// Exporta todas las issues del contexto. Devuelve true si escribió el archivo.
    @discardableResult
    func export(from context: ModelContext) -> Bool {
        do {
            let data = try Self.snapshotData(from: context)
            if data == lastWritten, FileManager.default.fileExists(atPath: exportURL.path) { return false }
            try write(data)
            lastWritten = data
            return true
        } catch {
            Self.logger.error("No se pudo exportar el snapshot: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Contenido

    static func snapshotData(from context: ModelContext) throws -> Data {
        let issues = try context.fetch(FetchDescriptor<Issue>())
        let rows = issues
            .sorted {
                $0.createdAt == $1.createdAt ? $0.code < $1.code : $0.createdAt < $1.createdAt
            }
            .map(row(for:))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(rows)
    }

    static func row(for issue: Issue) -> Row {
        Row(code: issue.code,
            title: issue.title,
            project: issue.project?.name ?? "",
            details: issue.details,
            solution: issue.solution,
            status: issue.status.rawValue,
            priority: issue.priority.rawValue,
            dueDate: issue.dueDate.map(localDateString),
            labels: issue.unwrappedLabels.map(\.name),
            createdAt: isoString(issue.createdAt),
            updatedAt: isoString(issue.updatedAt))
    }

    /// "YYYY-MM-DD" en el calendario local (inversa de `InboxImporter.parseLocalDate`).
    static func localDateString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// ISO-8601 UTC sin fracciones, ej. "2026-11-06T09:00:00Z".
    static func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Escritura atómica

    /// Temp en la misma carpeta + reemplazo: el lector de Python nunca ve un archivo a medias.
    private func write(_ data: Data) throws {
        let fm = FileManager.default
        let dir = exportURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let tmp = dir.appendingPathComponent(".issues-\(UUID().uuidString).tmp")
        try data.write(to: tmp)
        do {
            if fm.fileExists(atPath: exportURL.path) {
                _ = try fm.replaceItemAt(exportURL, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: exportURL)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw error
        }
    }
}
