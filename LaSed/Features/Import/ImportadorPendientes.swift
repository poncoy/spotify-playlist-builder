//
//  ImportadorPendientes.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 24/09/2026
//
//  Cuenta cuántos archivos de la última carpeta importada todavía no están
//  en la Biblioteca, consultando la base de datos en cada llamada (no un
//  contador guardado aparte) — así nunca queda desincronizado de lo que el
//  usuario ya importó a mano o en lote.
//
import Foundation

struct ResumenPendientes {
    var requierenRevision: Int
    var sinArtista: Int
    var total: Int { requierenRevision + sinArtista }
}

enum ImportadorPendientes {
    private static let ultimaCarpetaKey = "com.poncoy.lased.ultimaCarpetaImportadorBookmark"

    static func contar() -> ResumenPendientes? {
        guard let bookmark = UserDefaults.standard.data(forKey: ultimaCarpetaKey) else { return nil }

        var esObsoleto = false
        #if os(macOS)
        let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &esObsoleto)
        #else
        let url = try? URL(resolvingBookmarkData: bookmark, relativeTo: nil, bookmarkDataIsStale: &esObsoleto)
        #endif
        guard let url else { return nil }

        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let archivos = try? FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension.lowercased() == "txt" })
        else { return nil }

        let repo = SongRepository()
        var revision = 0
        var sinArtista = 0

        for archivo in archivos {
            guard let contenido = try? String(contentsOf: archivo, encoding: .utf8) else { continue }
            let r = NotesImportParser.parse(rawText: contenido, fileName: archivo.lastPathComponent)

            if yaEstaEnBiblioteca(r, repo: repo) { continue }

            if r.requiereRevision {
                revision += 1
            } else {
                sinArtista += 1
            }
        }

        return ResumenPendientes(requierenRevision: revision, sinArtista: sinArtista)
    }

    private static func yaEstaEnBiblioteca(_ r: ParsedNoteResult, repo: SongRepository) -> Bool {
        if let sugerencia = ArtistSuggestionService.shared.sugerirArtista(paraTitulo: r.tituloLimpio),
           sugerencia.artistaAlternativo == nil {
            let clave = normalizeForMatching("\(r.tituloLimpio) \(sugerencia.artista)")
            if (try? repo.fetchByMatchKey(clave)) != nil { return true }
        }
        // Sin sugerencia de artista (o el import fue manual con un artista
        // distinto al sugerido): comparamos por título, que es lo único que
        // podemos conocer de antemano sin adivinar qué artista tipeó el usuario.
        if let coincidencias = try? repo.search(r.tituloLimpio) {
            return coincidencias.contains { $0.titleDisplay.localizedCaseInsensitiveCompare(r.tituloLimpio) == .orderedSame }
        }
        return false
    }
}
