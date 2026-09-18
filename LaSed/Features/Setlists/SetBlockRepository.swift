import Foundation
import GRDB

final class SetBlockRepository {
    private let db: AppDatabase
    init(_ db: AppDatabase = .shared) { self.db = db }

    func create(_ block: SetBlock) throws {
        var b = block
        b.rev = 1
        b.createdAt = Date()
        b.updatedAt = Date()
        try db.dbWriter.write { d in
            try b.insert(d)
            try logOutbox(d, table: SetBlock.databaseTableName, recordId: b.id, op: .insert)
        }
    }

    func update(_ block: SetBlock) throws {
        var b = block
        b.updatedAt = Date()
        b.rev += 1
        try db.dbWriter.write { d in
            try b.update(d)
            try logOutbox(d, table: SetBlock.databaseTableName, recordId: b.id, op: .update)
        }
    }

    func softDelete(id: String, by editor: String) throws {
        try db.dbWriter.write { d in
            guard var b = try SetBlock.fetchOne(d, key: id) else { return }
            b.deletedAt = Date()
            b.updatedAt = Date()
            b.rev += 1
            b.lastEditedBy = editor
            try b.update(d)
            try logOutbox(d, table: SetBlock.databaseTableName, recordId: id, op: .delete)

            // Cascada manual: el ON DELETE CASCADE del esquema nunca dispara
            // porque la app solo hace soft delete.
            let items = try SetlistItem
                .filter(Column("blockId") == id)
                .filter(Column("deletedAt") == nil)
                .fetchAll(d)
            for var item in items {
                item.deletedAt = Date()
                item.updatedAt = Date()
                item.rev += 1
                item.lastEditedBy = editor
                try item.update(d)
                try logOutbox(d, table: SetlistItem.databaseTableName, recordId: item.id, op: .delete)
            }
        }
    }

    func fetchById(_ id: String) throws -> SetBlock? {
        try db.dbWriter.read { d in try SetBlock.fetchOne(d, key: id) }
    }

    /// Bloques activos de un setlist, en orden A/B/C/SUP según `position`.
    func fetchActiveBySetlist(_ setlistId: String) throws -> [SetBlock] {
        try db.dbWriter.read { d in
            try SetBlock
                .filter(Column("setlistId") == setlistId)
                .filter(Column("deletedAt") == nil)
                .order(Column("position"))
                .fetchAll(d)
        }
    }

    /// Nombres más usados en cualquier setlist (activo), más frecuentes primero.
    func nombresMasUsados(limite: Int = 6) throws -> [String] {
        try db.dbWriter.read { d in
            let nombres = try SetBlock
                .filter(Column("deletedAt") == nil)
                .fetchAll(d)
                .map(\.name)
            var conteo: [String: Int] = [:]
            for nombre in nombres { conteo[nombre, default: 0] += 1 }
            return conteo
                .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                .prefix(limite)
                .map(\.key)
        }
    }
}
