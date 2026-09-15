import Foundation
import GRDB

final class SetlistItemRepository {
    private let db: AppDatabase
    init(_ db: AppDatabase = .shared) { self.db = db }

    func create(_ item: SetlistItem) throws {
        var i = item
        i.rev = 1
        i.createdAt = Date()
        i.updatedAt = Date()
        try db.dbWriter.write { d in
            try i.insert(d)
            try logOutbox(d, table: SetlistItem.databaseTableName, recordId: i.id, op: .insert)
        }
    }

    func update(_ item: SetlistItem) throws {
        var i = item
        i.updatedAt = Date()
        i.rev += 1
        try db.dbWriter.write { d in
            try i.update(d)
            try logOutbox(d, table: SetlistItem.databaseTableName, recordId: i.id, op: .update)
        }
    }

    func softDelete(id: String, by editor: String) throws {
        try db.dbWriter.write { d in
            guard var i = try SetlistItem.fetchOne(d, key: id) else { return }
            i.deletedAt = Date()
            i.updatedAt = Date()
            i.rev += 1
            i.lastEditedBy = editor
            try i.update(d)
            try logOutbox(d, table: SetlistItem.databaseTableName, recordId: id, op: .delete)
        }
    }

    func fetchById(_ id: String) throws -> SetlistItem? {
        try db.dbWriter.read { d in try SetlistItem.fetchOne(d, key: id) }
    }

    /// Canciones activas de un bloque, en orden de interpretación (=Orden del CSV).
    func fetchActiveByBlock(_ blockId: String) throws -> [SetlistItem] {
        try db.dbWriter.read { d in
            try SetlistItem
                .filter(Column("blockId") == blockId)
                .filter(Column("deletedAt") == nil)
                .order(Column("position"))
                .fetchAll(d)
        }
    }
}
