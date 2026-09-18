//
//  AppDatabase.swift
//  LaSed
//
//  Versión: 0.2.0
//  Actualizado: 09/09/2026
//
import Foundation
import GRDB

final class AppDatabase {
    static let shared = makeShared()
    let dbWriter: DatabaseWriter

    init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_esquema_inicial") { db in

            try db.create(table: "song") { t in
                t.primaryKey("id", .text)
                t.column("spotifyId", .text)
                t.column("titleDisplay", .text).notNull()
                t.column("titleSpotify", .text)
                t.column("artist", .text).notNull()
                t.column("matchKey", .text).notNull().indexed()
                t.column("isLive", .boolean).notNull().defaults(to: false)
                t.column("originalKey", .text)
                t.column("durationSec", .integer)
                t.column("country", .text)
                t.column("language", .text)
                t.column("level", .integer)
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
                t.column("rev", .integer).notNull().defaults(to: 1)
                t.column("lastEditedBy", .text).notNull().defaults(to: "unknown")
            }

            try db.create(table: "setlist") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("venue", .text)
                t.column("date", .datetime)
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
                t.column("rev", .integer).notNull().defaults(to: 1)
                t.column("lastEditedBy", .text).notNull().defaults(to: "unknown")
            }

            try db.create(table: "setBlock") { t in
                t.primaryKey("id", .text)
                t.column("setlistId", .text).notNull()
                    .references("setlist", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
                t.column("rev", .integer).notNull().defaults(to: 1)
                t.column("lastEditedBy", .text).notNull().defaults(to: "unknown")
            }

            try db.create(table: "setlistItem") { t in
                t.primaryKey("id", .text)
                t.column("blockId", .text).notNull()
                    .references("setBlock", onDelete: .cascade)
                t.column("songId", .text).notNull().references("song")
                t.column("position", .integer).notNull()
                t.column("keyOverride", .text)
                t.column("capoOverride", .integer)
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
                t.column("rev", .integer).notNull().defaults(to: 1)
                t.column("lastEditedBy", .text).notNull().defaults(to: "unknown")
            }

            try db.create(table: "syncOutbox") { t in
                t.primaryKey("id", .text)
                t.column("tableName", .text).notNull()
                t.column("recordId", .text).notNull()
                t.column("operation", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("syncedAt", .datetime)
            }
        }

        migrator.registerMigration("v2_alias_y_fuentes") { db in

            // 1. Song: dónde escuchar la canción (campos simples, sin tabla nueva)
            try db.alter(table: "song") { t in
                t.add(column: "youtubeUrl", .text)
                t.add(column: "physicalNotes", .text)
            }

            // 2. SongAlias — mismo patrón de sync que las demás tablas
            try db.create(table: "songAlias") { t in
                t.primaryKey("id", .text)
                t.column("songId", .text).notNull().references("song")
                t.column("aliasText", .text).notNull()
                t.column("normalizedAlias", .text).notNull().indexed()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
                t.column("rev", .integer).notNull().defaults(to: 1)
                t.column("lastEditedBy", .text).notNull().defaults(to: "unknown")
            }

            // 3. Índice de búsqueda: título/artista de Song + alias, en una sola tabla
            try db.create(virtualTable: "songSearchIndex", using: FTS5()) { t in
                t.column("songId").notIndexed()
                t.column("sourceId").notIndexed()
                t.column("searchText")
            }

            // 4. Triggers: mantienen el índice sincronizado solo
            try db.execute(sql: """
                CREATE TRIGGER song_ai AFTER INSERT ON song WHEN new.deletedAt IS NULL BEGIN
                    INSERT INTO songSearchIndex(songId, sourceId, searchText)
                    VALUES (new.id, new.id, new.titleDisplay || ' ' || IFNULL(new.titleSpotify,'') || ' ' || new.artist);
                END;
                """)
            try db.execute(sql: """
                CREATE TRIGGER song_au AFTER UPDATE ON song BEGIN
                    DELETE FROM songSearchIndex WHERE sourceId = old.id;
                    INSERT INTO songSearchIndex(songId, sourceId, searchText)
                    SELECT new.id, new.id, new.titleDisplay || ' ' || IFNULL(new.titleSpotify,'') || ' ' || new.artist
                    WHERE new.deletedAt IS NULL;
                END;
                """)
            try db.execute(sql: """
                CREATE TRIGGER song_ad AFTER DELETE ON song BEGIN
                    DELETE FROM songSearchIndex WHERE sourceId = old.id;
                END;
                """)
            try db.execute(sql: """
                CREATE TRIGGER alias_ai AFTER INSERT ON songAlias WHEN new.deletedAt IS NULL BEGIN
                    INSERT INTO songSearchIndex(songId, sourceId, searchText)
                    VALUES (new.songId, new.id, new.aliasText);
                END;
                """)
            try db.execute(sql: """
                CREATE TRIGGER alias_au AFTER UPDATE ON songAlias BEGIN
                    DELETE FROM songSearchIndex WHERE sourceId = old.id;
                    INSERT INTO songSearchIndex(songId, sourceId, searchText)
                    SELECT new.songId, new.id, new.aliasText
                    WHERE new.deletedAt IS NULL;
                END;
                """)
            try db.execute(sql: """
                CREATE TRIGGER alias_ad AFTER DELETE ON songAlias BEGIN
                    DELETE FROM songSearchIndex WHERE sourceId = old.id;
                END;
                """)

            // 5. Backfill: indexa las canciones que ya existen antes de esta migración
            try db.execute(sql: """
                INSERT INTO songSearchIndex(songId, sourceId, searchText)
                SELECT id, id, titleDisplay || ' ' || IFNULL(titleSpotify,'') || ' ' || artist
                FROM song WHERE deletedAt IS NULL;
                """)
        }
        
        migrator.registerMigration("v3_contenido_importado") { db in
            // Guarda el contentAST (secciones/líneas/acordes) como JSON.
            // Nullable: las canciones creadas a mano en Fase 2 no lo tienen.
            try db.alter(table: "song") { t in
                t.add(column: "contentASTJson", .text)
            }
        }

        migrator.registerMigration("v4_stylesheet_por_cancion") { db in
            // StyleSheet por canción (Fase 3, decisión de este chat): fuente,
            // tamaño y los 3 espacios pueden sobrescribirse por canción.
            // Mayúsculas/minúsculas se quedó FUERA a propósito — casi no
            // varía por canción individual, y así se reduce la superficie
            // tocada. Todas nullable: NULL = hereda el ajuste global de
            // DisplaySettingsView (@AppStorage). Ninguna canción existente
            // se rompe con esta migración.
            try db.alter(table: "song") { t in
                t.add(column: "styleFontFamily", .text)
                t.add(column: "styleFontSize", .double)
                t.add(column: "styleLineSpacing", .double)
                t.add(column: "styleLineGap", .double)
                t.add(column: "styleSectionGap", .double)
            }
        }

        migrator.registerMigration("v5_bpm") { db in
            // BPM manual por canción — Spotify deprecó el endpoint
            // audio-features (tempo) el 27/nov/2024 para apps nuevas, no hay
            // reemplazo oficial. Nullable: entrada manual, nunca obligatoria.
            // Pendiente futuro (pedido este chat): usar este campo para un
            // scroll automático sincronizado al tempo — no implementado aún,
            // solo el dato base.
            try db.alter(table: "song") { t in
                t.add(column: "bpm", .integer)
            }
        }

        migrator.registerMigration("v6_carpetas_setlist") { db in
            // Carpetas para agrupar setlists en el sidebar (ej: "La Sed",
            // "Acústicon"), igual que Apple Notes. Nullable: sin carpeta
            // asignada, el setlist aparece en "Sin carpeta".
            try db.alter(table: "setlist") { t in
                t.add(column: "folder", .text)
            }
        }
        return migrator
    }

    private static func makeShared() -> AppDatabase {
        do {
            let folder = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
            let dbURL = folder.appendingPathComponent("lased.sqlite")
            print("📁 Base de datos en: \(dbURL.path)")
            let pool = try DatabasePool(path: dbURL.path)
            return try AppDatabase(pool)
        } catch {
            fatalError("No se pudo crear la base de datos: \(error)")
        }
    }
}
