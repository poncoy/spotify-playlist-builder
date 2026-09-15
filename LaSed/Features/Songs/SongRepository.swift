import Foundation
import GRDB

final class SongRepository {
    private let db: AppDatabase
    init(_ db: AppDatabase = .shared) { self.db = db }

    func create(_ song: Song) throws {
        var s = song
        s.rev = 1
        s.createdAt = Date()
        s.updatedAt = Date()
        s.matchKey = normalizeForMatching("\(s.titleDisplay) \(s.artist)")
        try db.dbWriter.write { d in
            try s.insert(d)
            try logOutbox(d, table: Song.databaseTableName, recordId: s.id, op: .insert)
        }
    }

    func update(_ song: Song) throws {
        var s = song
        s.updatedAt = Date()
        s.rev += 1
        s.matchKey = normalizeForMatching("\(s.titleDisplay) \(s.artist)")
        try db.dbWriter.write { d in
            try s.update(d)
            try logOutbox(d, table: Song.databaseTableName, recordId: s.id, op: .update)
        }
    }

    func softDelete(id: String, by editor: String) throws {
        try db.dbWriter.write { d in
            guard var s = try Song.fetchOne(d, key: id) else { return }
            s.deletedAt = Date()
            s.updatedAt = Date()
            s.rev += 1
            s.lastEditedBy = editor
            try s.update(d)
            try logOutbox(d, table: Song.databaseTableName, recordId: id, op: .delete)
        }
    }

    func fetchById(_ id: String) throws -> Song? {
        try db.dbWriter.read { d in try Song.fetchOne(d, key: id) }
    }

    func fetchAllActive() throws -> [Song] {
        try db.dbWriter.read { d in
            try Song.filter(Column("deletedAt") == nil).fetchAll(d)
        }
    }

    /// Incluye canciones borradas — usado solo para no reutilizar un song_code viejo.
    func fetchAllIncludingDeleted() throws -> [Song] {
        try db.dbWriter.read { d in try Song.fetchAll(d) }
    }

    func fetchByCode(_ code: String) throws -> Song? {
        try fetchById(code)
    }

    func fetchBySpotifyId(_ spotifyId: String) throws -> Song? {
        try db.dbWriter.read { d in
            try Song.filter(Column("spotifyId") == spotifyId).fetchOne(d)
        }
    }

    /// Fix real (10/09/2026): esta función NO filtraba deletedAt, así que
    /// una canción borrada (soft delete) seguía "existiendo" para efectos de
    /// detección de duplicados en el importador. Síntoma observado: borrar
    /// toda la biblioteca y reimportar mostraba "Ya estaban en tu biblioteca
    /// (119)" — 0 canciones nuevas — porque el matchKey de las borradas
    /// seguía matcheando. Ahora solo cuenta como "ya existe" una canción
    /// ACTIVA; una borrada se trata como si no existiera, y el importador
    /// puede volver a crearla con normalidad.
    func fetchByMatchKey(_ key: String) throws -> Song? {
        try db.dbWriter.read { d in
            try Song.filter(Column("matchKey") == key && Column("deletedAt") == nil).fetchOne(d)
        }
    }

    func search(_ query: String) throws -> [Song] {
        let terms = query
            .split(separator: " ")
            .map { "\"\($0)\"*" }
            .joined(separator: " ")
        guard !terms.isEmpty else { return try fetchAllActive() }
        return try db.dbWriter.read { d in
            try Song.fetchAll(d, sql: """
                SELECT DISTINCT song.*
                FROM song
                JOIN songSearchIndex ON songSearchIndex.songId = song.id
                WHERE songSearchIndex MATCH ?
                AND song.deletedAt IS NULL
                """, arguments: [terms])
        }
    }

    /// Sugiere el siguiente song_code libre (MAX+1 de LS-XXXX), incluyendo
    /// borrados para nunca reutilizar un número. Es solo una sugerencia
    /// editable: el usuario decide el código final en el formulario.
    func suggestNextCode() throws -> String {
        let all = try fetchAllIncludingDeleted()
        let maxNumber = all.compactMap { song -> Int? in
            guard song.id.hasPrefix("LS-") else { return nil }
            return Int(song.id.dropFirst(3))
        }.max() ?? 0
        return String(format: "LS-%04d", maxNumber + 1)
    }
}

