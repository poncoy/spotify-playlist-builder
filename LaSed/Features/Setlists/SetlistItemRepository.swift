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

    /// Proyección: songIds que más aparecieron en bloques con este mismo
    /// nombre en OTROS setlists (ej: si "A" siempre trae las mismas 3
    /// canciones de entrada, se sugieren primero). Excluye los ya en `excluir`.
    func songIdsFrecuentesPorNombreDeBloque(
        _ nombreBloque: String,
        excluir: Set<String>,
        limite: Int = 8
    ) throws -> [String] {
        try db.dbWriter.read { d in
            let filas = try Row.fetchAll(d, sql: """
                SELECT setlistItem.songId AS songId, COUNT(*) AS frecuencia
                FROM setlistItem
                JOIN setBlock ON setBlock.id = setlistItem.blockId
                WHERE setBlock.name = ? COLLATE NOCASE
                  AND setlistItem.deletedAt IS NULL
                  AND setBlock.deletedAt IS NULL
                GROUP BY setlistItem.songId
                ORDER BY frecuencia DESC
                """, arguments: [nombreBloque])
            return filas
                .compactMap { $0["songId"] as String? }
                .filter { !excluir.contains($0) }
                .prefix(limite)
                .map { $0 }
        }
    }
}
