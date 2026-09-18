//
//  Models.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 09/09/2026
//
import Foundation
import GRDB

struct Song: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "song"

    var id: String
    var spotifyId: String?
    var titleDisplay: String
    var titleSpotify: String?
    var artist: String
    var matchKey: String
    var isLive: Bool
    var originalKey: String?
    var durationSec: Int?
    var country: String?
    var language: String?
    var level: Int?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var rev: Int
    var lastEditedBy: String
    var youtubeUrl: String?
    var physicalNotes: String?
    var contentASTJson: String?

    // StyleSheet por canción (Fase 3, migración v4). nil = hereda el ajuste
    // global de DisplaySettingsView. Declarados con valor por defecto para
    // que el init memberwise sintetizado NO obligue a tocar los Song(...)
    // existentes en NotesImportPreviewView/AddSongView/etc.
    var styleFontFamily: String? = nil
    var styleFontSize: Double? = nil
    var styleLineSpacing: Double? = nil
    var styleLineGap: Double? = nil
    var styleSectionGap: Double? = nil

    // BPM manual (Fase 3, migración v5). nil = sin especificar. Base para el
    // metrónomo y, a futuro, scroll automático sincronizado al tempo
    // (pendiente, no implementado todavía).
    var bpm: Int? = nil
}

extension Song {
    /// Resolución "efectiva" de cada ajuste de estilo: valor propio de la
    /// canción si existe, si no el global de la app. Usado por
    /// ChordChartView, SongContentEditorView y EditSongView en vez de leer
    /// @AppStorage directo, para que una canción con override no dependa
    /// del ajuste global.
    func effectiveFontFamily(globalRaw: String) -> ChordFontFamily {
        ChordFontFamily(rawValue: styleFontFamily ?? globalRaw) ?? .sistema
    }
    func effectiveFontSize(global: Double) -> Double { styleFontSize ?? global }
    func effectiveLineSpacing(global: Double) -> Double { styleLineSpacing ?? global }
    func effectiveLineGap(global: Double) -> Double { styleLineGap ?? global }
    func effectiveSectionGap(global: Double) -> Double { styleSectionGap ?? global }
}

struct Setlist: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "setlist"

    var id: String
    var name: String
    var venue: String?
    var date: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var rev: Int
    var lastEditedBy: String
    var folder: String? = nil
}

struct SetBlock: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "setBlock"

    var id: String
    var setlistId: String
    var name: String
    var position: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var rev: Int
    var lastEditedBy: String
}

struct SetlistItem: Codable, FetchableRecord, MutablePersistableRecord, Identifiable {
    static let databaseTableName = "setlistItem"

    var id: String
    var blockId: String
    var songId: String
    var position: Int
    var keyOverride: String?
    var capoOverride: Int?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var rev: Int
    var lastEditedBy: String
}

struct SyncOutboxEntry: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "syncOutbox"

    var id: String
    var tableName: String
    var recordId: String
    var operation: String   // "insert" | "update" | "delete"
    var createdAt: Date
    var syncedAt: Date?
}

struct SongAlias: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "songAlias"

    var id: String
    var songId: String
    var aliasText: String
    var normalizedAlias: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var rev: Int
    var lastEditedBy: String
}

extension SongAlias: SyncedRecord {}
