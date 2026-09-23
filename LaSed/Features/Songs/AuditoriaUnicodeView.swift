//
//  AuditoriaUnicodeView.swift
//  LaSed
//
//  Versión: 0.5.1
//  Actualizado: 11/09/2026
//
import SwiftUI

struct HallazgoUnicode: Identifiable {
    let id: String  // song.id
    let titulo: String
    let artista: String
    let enTitulo: Int
    let enArtista: Int
    let enContenido: Int

    var total: Int { enTitulo + enArtista + enContenido }
}

struct AuditoriaUnicodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hallazgos: [HallazgoUnicode] = []
    @State private var escaneando = true
    @State private var limpiando = false
    @State private var mensajeError: String?
    @State private var totalEscaneadas = 0

    private let repo = SongRepository()
    private let nbsp: Character = "\u{00A0}"

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Auditoría Unicode (P14)")

            HStack {
                Text(escaneando
                     ? "Escaneando..."
                     : "\(hallazgos.count) de \(totalEscaneadas) canciones con U+00A0 (espacio duro)")
                    .font(.headline)
                Spacer()
                Button("Cerrar") { dismiss() }
            }
            .padding()

            Divider()

            if escaneando {
                VStack {
                    Spacer()
                    ProgressView("Revisando título, artista y contenido de cada canción...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hallazgos.isEmpty {
                VStack {
                    Spacer()
                    Label("Ninguna canción activa tiene U+00A0.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(hallazgos) { h in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.titulo).font(.headline)
                        Text(h.artista).font(.subheadline).foregroundStyle(.secondary)
                        Text(detalle(h)).font(.caption).foregroundStyle(.orange)
                    }
                }

                Divider()

                HStack {
                    if let mensajeError {
                        Text(mensajeError).font(.caption).foregroundStyle(.red)
                    }
                    Spacer()
                    Button(limpiando ? "Limpiando..." : "Limpiar las \(hallazgos.count)") {
                        limpiarTodas()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(limpiando)
                }
                .padding()
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 520, minHeight: 380, idealHeight: 560)
        #endif
        .onAppear { escanear() }
    }

    private func detalle(_ h: HallazgoUnicode) -> String {
        var partes: [String] = []
        if h.enTitulo > 0 { partes.append("título (\(h.enTitulo))") }
        if h.enArtista > 0 { partes.append("artista (\(h.enArtista))") }
        if h.enContenido > 0 { partes.append("letra/acordes (\(h.enContenido))") }
        return "En: " + partes.joined(separator: ", ")
    }

    private func contar(_ texto: String?) -> Int {
        guard let texto else { return 0 }
        return texto.filter { $0 == nbsp }.count
    }

    private func escanear() {
        escaneando = true
        do {
            let canciones = try repo.fetchAllActive()
            totalEscaneadas = canciones.count
            hallazgos = canciones.compactMap { song -> HallazgoUnicode? in
                let enTitulo = contar(song.titleDisplay)
                let enArtista = contar(song.artist)
                let enContenido = contar(song.contentASTJson)
                guard enTitulo + enArtista + enContenido > 0 else { return nil }
                return HallazgoUnicode(
                    id: song.id,
                    titulo: song.titleDisplay,
                    artista: song.artist,
                    enTitulo: enTitulo,
                    enArtista: enArtista,
                    enContenido: enContenido
                )
            }
        } catch {
            mensajeError = "No se pudo escanear: \(error.localizedDescription)"
        }
        escaneando = false
    }

    /// Reemplaza U+00A0 por espacio normal en título, artista y en el JSON
    /// crudo del contenido, y guarda cada canción afectada. Re-escanea al
    /// final para confirmar visualmente que quedó en cero.
    private func limpiarTodas() {
        limpiando = true
        mensajeError = nil
        var errores: [String] = []
        for h in hallazgos {
            guard var song = try? repo.fetchById(h.id) else {
                errores.append(h.id)
                continue
            }
            song.titleDisplay = song.titleDisplay.replacingOccurrences(of: String(nbsp), with: " ")
            song.artist = song.artist.replacingOccurrences(of: String(nbsp), with: " ")
            if let json = song.contentASTJson {
                song.contentASTJson = json.replacingOccurrences(of: String(nbsp), with: " ")
            }
            song.lastEditedBy = "auditoria_unicode_p14"
            do {
                try repo.update(song)
            } catch {
                errores.append(h.id)
            }
        }
        limpiando = false
        if errores.isEmpty {
            escanear()
        } else {
            mensajeError = "Error guardando: \(errores.joined(separator: ", "))"
        }
    }
}
