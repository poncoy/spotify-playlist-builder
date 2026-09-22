import Foundation
import GRDB

final class SetlistRepository {
    private let db: AppDatabase
    init(_ db: AppDatabase = .shared) { self.db = db }

    func create(_ setlist: Setlist) throws {
        var s = setlist
        s.rev = 1
        s.createdAt = Date()
        s.updatedAt = Date()
        try db.dbWriter.write { d in
            try s.insert(d)
            try logOutbox(d, table: Setlist.databaseTableName, recordId: s.id, op: .insert)
        }
    }

    func update(_ setlist: Setlist) throws {
        var s = setlist
        s.updatedAt = Date()
        s.rev += 1
        try db.dbWriter.write { d in
            try s.update(d)
            try logOutbox(d, table: Setlist.databaseTableName, recordId: s.id, op: .update)
        }
    }

    func softDelete(id: String, by editor: String) throws {
        try db.dbWriter.write { d in
            guard var s = try Setlist.fetchOne(d, key: id) else { return }
            s.deletedAt = Date()
            s.updatedAt = Date()
            s.rev += 1
            s.lastEditedBy = editor
            try s.update(d)
            try logOutbox(d, table: Setlist.databaseTableName, recordId: id, op: .delete)

            let blocks = try SetBlock
                .filter(Column("setlistId") == id)
                .filter(Column("deletedAt") == nil)
                .fetchAll(d)
            for var block in blocks {
                block.deletedAt = Date()
                block.updatedAt = Date()
                block.rev += 1
                block.lastEditedBy = editor
                try block.update(d)
                try logOutbox(d, table: SetBlock.databaseTableName, recordId: block.id, op: .delete)

                let items = try SetlistItem
                    .filter(Column("blockId") == block.id)
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
    }

    func fetchById(_ id: String) throws -> Setlist? {
        try db.dbWriter.read { d in try Setlist.fetchOne(d, key: id) }
    }

    func fetchAllActive() throws -> [Setlist] {
        try db.dbWriter.read { d in
            try Setlist.filter(Column("deletedAt") == nil).fetchAll(d)
        }
    }

    /// Nombres reales: "18/09 Diagonal 🎸", "12/09 Diagonal"... Se le saca
    /// la fecha de adelante y cualquier emoji/símbolo de atrás para sacar el
    /// "lugar" repetido, y se ordena por qué tan seguido aparece.
    func lugaresFrecuentes(limite: Int = 5) throws -> [String] {
        let nombres = try fetchAllActive().map(\.name)
        var conteo: [String: Int] = [:]
        for nombre in nombres {
            guard let lugar = extraerLugar(nombre) else { continue }
            conteo[lugar, default: 0] += 1
        }
        return conteo
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limite)
            .map(\.key)
    }

    private func extraerLugar(_ nombre: String) -> String? {
        var resto = nombre
        if let rango = resto.range(of: #"^\d{1,2}[/\-]\d{1,2}\s*"#, options: .regularExpression) {
            resto.removeSubrange(rango)
        }
        resto = resto.trimmingCharacters(in: .whitespaces)
        while let ultimo = resto.last, !(ultimo.isLetter || ultimo.isNumber) {
            resto.removeLast()
            resto = resto.trimmingCharacters(in: .whitespaces)
        }
        return resto.isEmpty ? nil : resto
    }
}
