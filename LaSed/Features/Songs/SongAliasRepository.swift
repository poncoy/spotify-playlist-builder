//
//  SongAliasRepository.swift
//  LaSed
//
//  Versión: 0.2.0
//  Actualizado: 09/09/2026
//
import Foundation
import GRDB

enum SongAliasError: Error {
    case conflict(existingSongId: String, existingSongTitle: String)
}

final class SongAliasRepository {
    private let db: AppDatabase
    init(_ db: AppDatabase = .shared) { self.db = db }

    private func normalize(_ text: String) -> String {
        normalizeForMatching(text)
    }

    func create(songId: String, aliasText: String, by editor: String) throws {
        let key = normalize(aliasText)
        var alias = SongAlias(
            id: UUID().uuidString,
            songId: songId,
            aliasText: aliasText,
            normalizedAlias: key,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            rev: 1,
            lastEditedBy: editor)
        try db.dbWriter.write { d in
            if let existingAlias = try SongAlias
                .filter(Column("normalizedAlias") == key)
                .filter(Column("deletedAt") == nil)
                .fetchOne(d), existingAlias.songId != songId {
                let existingSong = try Song.fetchOne(d, key: existingAlias.songId)
                throw SongAliasError.conflict(
                    existingSongId: existingAlias.songId,
                    existingSongTitle: existingSong?.titleDisplay ?? "una canción existente")
            }
            try alias.insert(d)
            try logOutbox(d, table: SongAlias.databaseTableName, recordId: alias.id, op: .insert)
        }
    }

    func update(_ alias: SongAlias, by editor: String) throws {
        var a = alias
        a.normalizedAlias = normalize(a.aliasText)
        a.updatedAt = Date()
        a.rev += 1
        a.lastEditedBy = editor
        try db.dbWriter.write { d in
            try a.update(d)
            try logOutbox(d, table: SongAlias.databaseTableName, recordId: a.id, op: .update)
        }
    }

    func softDelete(id: String, by editor: String) throws {
        try db.dbWriter.write { d in
            guard var a = try SongAlias.fetchOne(d, key: id) else { return }
            a.deletedAt = Date()
            a.updatedAt = Date()
            a.rev += 1
            a.lastEditedBy = editor
            try a.update(d)
            try logOutbox(d, table: SongAlias.databaseTableName, recordId: id, op: .delete)
        }
    }

    /// Deshace un softDelete: el alias vuelve a estar activo.
    func restore(id: String, by editor: String) throws {
        try db.dbWriter.write { d in
            guard var a = try SongAlias.fetchOne(d, key: id) else { return }
            a.deletedAt = nil
            a.updatedAt = Date()
            a.rev += 1
            a.lastEditedBy = editor
            try a.update(d)
            try logOutbox(d, table: SongAlias.databaseTableName, recordId: id, op: .update)
        }
    }

    func fetchBySong(_ songId: String) throws -> [SongAlias] {
        try db.dbWriter.read { d in
            try SongAlias
                .filter(Column("songId") == songId)
                .filter(Column("deletedAt") == nil)
                .fetchAll(d)
        }
    }

    func findByNormalized(_ text: String) throws -> SongAlias? {
        let key = normalize(text)
        return try db.dbWriter.read { d in
            try SongAlias
                .filter(Column("normalizedAlias") == key)
                .filter(Column("deletedAt") == nil)
                .fetchOne(d)
        }
    }
}
