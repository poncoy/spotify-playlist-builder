//
//  Repository.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 09/09/2026
//
import Foundation
import GRDB

protocol SyncedRecord {
    var id: String { get }
    var updatedAt: Date { get set }
    var rev: Int { get set }
    var lastEditedBy: String { get set }
    var deletedAt: Date? { get set }
}

extension Song: SyncedRecord {}
extension Setlist: SyncedRecord {}
extension SetBlock: SyncedRecord {}
extension SetlistItem: SyncedRecord {}

enum OutboxOperation: String {
    case insert, update, delete
}

/// Normalización compartida: minúsculas, sin tildes, sin signos, espacios simples.
/// Usada por matchKey (Song) y normalizedAlias (SongAlias) — deben coincidir siempre.
func normalizeForMatching(_ text: String) -> String {
    text
        .folding(options: .diacriticInsensitive, locale: .current)
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}

/// Escribe la fila de outbox. Se llama SIEMPRE dentro de la misma
/// transacción que la mutación real (mismo `db`), nunca por separado.
func logOutbox(_ db: Database, table: String, recordId: String, op: OutboxOperation) throws {
    var entry = SyncOutboxEntry(
        id: UUID().uuidString,
        tableName: table,
        recordId: recordId,
        operation: op.rawValue,
        createdAt: Date(),
        syncedAt: nil)
    try entry.insert(db)
}

/// Catálogo compartido de países para el Picker de AddSongView/EditSongView
/// (10/09/2026). Misma decisión que Idioma: selección fija, no texto libre
/// — evita que "Perú"/"PERU"/"peru" convivan como valores distintos en la
/// base.
///
/// IMPORTANTE: el valor guardado en Song.country sigue siendo el EMOJI de
/// bandera (id: String = flag), no el nombre del país. El importador de
/// notas (NotesImportPreviewView.swift) ya guarda banderaPaisDetectada tal
/// cual en country — usar el emoji como valor del Picker hace que los 116+
/// registros ya importados sigan matcheando sin ninguna migración de datos.
///
/// Lista basada en las banderas reales detectadas en el triage de Fase 2b
/// (mismo origen que idiomaPorBandera en NotesImportPreviewView.swift). Un
/// país que ya exista en una canción vieja y no esté en esta lista no se
/// pierde: EditSongView agrega el valor actual como opción extra (mismo
/// patrón que ya usa con Idioma).
struct PaisConocido: Identifiable, Hashable {
    var id: String { flag }
    let flag: String
    let nombre: String
}

let paisesConocidos: [PaisConocido] = [
    PaisConocido(flag: "🇦🇷", nombre: "Argentina"),
    PaisConocido(flag: "🇦🇺", nombre: "Australia"),
    PaisConocido(flag: "🇦🇹", nombre: "Austria"),
    PaisConocido(flag: "🇨🇱", nombre: "Chile"),
    PaisConocido(flag: "🇨🇴", nombre: "Colombia"),
    PaisConocido(flag: "🇪🇸", nombre: "España"),
    PaisConocido(flag: "🇺🇸", nombre: "Estados Unidos"),
    PaisConocido(flag: "🇮🇹", nombre: "Italia"),
    PaisConocido(flag: "🇯🇲", nombre: "Jamaica"),
    PaisConocido(flag: "🇲🇽", nombre: "México"),
    PaisConocido(flag: "🇳🇴", nombre: "Noruega"),
    PaisConocido(flag: "🇵🇪", nombre: "Perú"),
    PaisConocido(flag: "🇵🇷", nombre: "Puerto Rico"),
    PaisConocido(flag: "🇬🇧", nombre: "Reino Unido"),
    PaisConocido(flag: "🇺🇾", nombre: "Uruguay"),
]
