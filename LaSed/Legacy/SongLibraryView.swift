//
//  SongLibraryView.swift
//  LaSed
//
//  Versión app:  0.5.1
//  Fase:         2/3 — cierre de pendientes menores
//  Modificado:   11/09/2026 (hora no disponible para Claude, sin reloj real) —
//                agregado botón "Auditoría Unicode" (P14) en el toolbar
//  canciones a la vez con resumen previo (pedido explícito: "NO HAY OPCIÓN
//  DE ELIMINAR MÁS DE UNA CANCIÓN"). Antes selectedSongId era String? (una
//  sola); ahora selectedSongIds es Set<String>, que en macOS List habilita
//  selección múltiple nativa (⌘-clic, ⇧-clic) sin código extra.
//
//  ⚠️ NO COMPILADO POR CLAUDE — sin toolchain de Swift disponible. Compila en
//  Xcode y pasa el primer error tal cual lo muestra el Issue Navigator.

import SwiftUI

struct SongLibraryView: View {
    @State private var songs: [Song] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showingAddSong = false
    @State private var showingImporter = false
    @State private var selectedSongIds: Set<String> = []
    @State private var mostrandoConfirmEliminar = false
    @State private var mostrandoAuditoriaUnicode = false

    private let repo = SongRepository()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ModuleHeaderBar(titulo: "Biblioteca de canciones")
                List(selection: $selectedSongIds) {
                    ForEach(songs, id: \.id) { song in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.titleDisplay)
                                .font(.headline)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .tag(song.id)
                    }
                }
                .navigationTitle("Canciones")
                .searchable(text: $searchText, prompt: "Buscar por título, artista o alias")
                .onChange(of: searchText) { _, newValue in
                    loadSongs(query: newValue)
                }
                .onAppear {
                    loadSongs(query: searchText)
                }
                .overlay {
                    if songs.isEmpty {
                        ContentUnavailableView(
                            "Sin canciones",
                            systemImage: "music.note.list",
                            description: Text("Toca + para agregar tu primera canción.")
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddSong = true
                        } label: {
                            Label("Agregar", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Importar notas", systemImage: "square.and.arrow.down.on.square")
                        }
                    }
                    // Nuevo: eliminar todo lo seleccionado (⌘-clic o ⇧-clic
                    // para elegir varias). Vive acá, no en EditSongView,
                    // porque EditSongView solo se muestra cuando hay UNA
                    // seleccionada.
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            mostrandoConfirmEliminar = true
                        } label: {
                            Label("Eliminar (\(selectedSongIds.count))", systemImage: "trash")
                        }
                        .disabled(selectedSongIds.isEmpty)
                    }
                    // P14 (backlog Fase 2): auditoría de U+00A0 en canciones
                    // ya guardadas antes del fix de normalización. Vive en
                    // el toolbar principal porque no depende de ninguna
                    // selección — escanea toda la biblioteca activa.
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            mostrandoAuditoriaUnicode = true
                        } label: {
                            Label("Auditoría Unicode", systemImage: "text.magnifyingglass")
                        }
                    }
                }
                .sheet(isPresented: $showingAddSong) {
                    AddSongView(onSaved: { loadSongs(query: searchText) })
                }
                .sheet(isPresented: $showingImporter, onDismiss: { loadSongs(query: searchText) }) {
                    NotesImportPreviewView()
                }
                .sheet(isPresented: $mostrandoConfirmEliminar) {
                    EliminarCancionesView(
                        canciones: songs
                            .filter { selectedSongIds.contains($0.id) }
                            .sorted { $0.titleDisplay.localizedStandardCompare($1.titleDisplay) == .orderedAscending },
                        onConfirmar: {
                            eliminarSeleccionadas()
                            mostrandoConfirmEliminar = false
                        },
                        onCancelar: { mostrandoConfirmEliminar = false }
                    )
                }
                .sheet(isPresented: $mostrandoAuditoriaUnicode, onDismiss: { loadSongs(query: searchText) }) {
                    AuditoriaUnicodeView()
                }
            }
        } detail: {
            if selectedSongIds.count == 1, let unicoId = selectedSongIds.first {
                EditSongView(
                    songId: unicoId,
                    onChanged: { loadSongs(query: searchText) },
                    onDeleted: {
                        selectedSongIds = []
                        loadSongs(query: searchText)
                    }
                )
                .id(unicoId)
            } else if selectedSongIds.count > 1 {
                ContentUnavailableView(
                    "\(selectedSongIds.count) canciones seleccionadas",
                    systemImage: "checkmark.circle",
                    description: Text("Usa el botón Eliminar de la barra de herramientas para borrarlas juntas, o deja solo una seleccionada para editarla.")
                )
            } else {
                ContentUnavailableView(
                    "Selecciona una canción",
                    systemImage: "music.note",
                    description: Text("Elige una canción de la lista para ver o editar sus detalles. ⌘-clic o ⇧-clic para elegir varias.")
                )
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadSongs(query: String) {
        do {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            let resultados = trimmed.isEmpty ? try repo.fetchAllActive() : try repo.search(trimmed)
            // Fix real: SongRepository.fetchAllActive()/.search() no tienen
            // ORDER BY, así que SQLite devolvía en un orden arbitrario
            // (reportado: "eso sí fue en desorden sin orden alfabético").
            // Se ordena acá, en la vista, en vez de tocar el SQL de GRDB —
            // localizedStandardCompare ya se usa en el resto del proyecto y
            // maneja bien tildes/eñe, a diferencia de la colación NOCASE de
            // SQLite (solo ASCII).
            songs = resultados.sorted { $0.titleDisplay.localizedStandardCompare($1.titleDisplay) == .orderedAscending }
        } catch {
            errorMessage = "No se pudo cargar: \(error.localizedDescription)"
        }
    }

    private func eliminarSeleccionadas() {
        var idsConError: [String] = []
        for id in selectedSongIds {
            do {
                try repo.softDelete(id: id, by: "manual_multiple")
            } catch {
                idsConError.append(id)
            }
        }
        selectedSongIds = []
        loadSongs(query: searchText)
        if !idsConError.isEmpty {
            errorMessage = "No se pudieron eliminar: \(idsConError.joined(separator: ", "))"
        }
    }
}

/// Resumen previo a eliminar varias canciones — pedido explícito ("debería
/// haber... un resumen de lo que eliminarías"). Sigue el mismo patrón ya
/// establecido en el proyecto (ResumenLoteView, SeleccionLoteView): nunca un
/// .alert() de texto corrido para una lista, siempre una pantalla real con
/// List. Soft delete, no DELETE físico — misma regla que el resto de la app.
private struct EliminarCancionesView: View {
    let canciones: [Song]
    var onConfirmar: () -> Void
    var onCancelar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Eliminar canciones")

            VStack(alignment: .leading, spacing: 4) {
                Text("¿Eliminar \(canciones.count) canción(es)?")
                    .font(.headline)
                Text("Dejan de aparecer en la biblioteca. No se borran del todo (soft delete), pero hoy no hay pantalla para recuperarlas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            List(canciones, id: \.id) { song in
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.titleDisplay)
                    Text("\(song.artist) · \(song.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button("Cancelar") { onCancelar() }
                Spacer()
                Button("Eliminar \(canciones.count)", role: .destructive) { onConfirmar() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 380, idealWidth: 460, maxWidth: .infinity, minHeight: 360, idealHeight: 520, maxHeight: .infinity)
    }
}
