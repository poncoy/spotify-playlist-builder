//
//  BibliotecaContentView.swift
//  LaSed
//
//  Versión: 0.6.0
//  Actualizado: 14/09/2026
//
import SwiftUI

struct BibliotecaContentView: View {
    @Binding var selectedSongIds: Set<String>

    @State private var songs: [Song] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showingAddSong = false
    @State private var showingImporter = false
    @State private var mostrandoConfirmEliminar = false
    @State private var mostrandoAuditoriaUnicode = false

    private let repo = SongRepository()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Biblioteca de canciones")
            List(selection: $selectedSongIds) {
                ForEach(songs, id: \.id) { song in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.titleDisplay).font(.headline)
                        Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .tag(song.id)
                    .draggable(CancionArrastrada(songId: song.id))
                }
            }
            .navigationTitle("Canciones")
            .searchable(text: $searchText, prompt: "Buscar por título, artista o alias")
            .onChange(of: searchText) { _, newValue in loadSongs(query: newValue) }
            .onAppear { loadSongs(query: searchText) }
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
                    Button { showingAddSong = true } label: { Label("Agregar", systemImage: "plus") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingImporter = true } label: { Label("Importar notas", systemImage: "square.and.arrow.down.on.square") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) { mostrandoConfirmEliminar = true } label: {
                        Label("Eliminar (\(selectedSongIds.count))", systemImage: "trash")
                    }
                    .disabled(selectedSongIds.isEmpty)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { mostrandoAuditoriaUnicode = true } label: {
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
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func loadSongs(query: String) {
        do {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            let resultados = trimmed.isEmpty ? try repo.fetchAllActive() : try repo.search(trimmed)
            songs = resultados.sorted { $0.titleDisplay.localizedStandardCompare($1.titleDisplay) == .orderedAscending }
        } catch {
            errorMessage = "No se pudo cargar: \(error.localizedDescription)"
        }
    }

    private func eliminarSeleccionadas() {
        var idsConError: [String] = []
        for id in selectedSongIds {
            do { try repo.softDelete(id: id, by: "manual_multiple") }
            catch { idsConError.append(id) }
        }
        selectedSongIds = []
        loadSongs(query: searchText)
        if !idsConError.isEmpty {
            errorMessage = "No se pudieron eliminar: \(idsConError.joined(separator: ", "))"
        }
    }
}

private struct EliminarCancionesView: View {
    let canciones: [Song]
    var onConfirmar: () -> Void
    var onCancelar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Eliminar canciones")
            VStack(alignment: .leading, spacing: 4) {
                Text("¿Eliminar \(canciones.count) canción(es)?").font(.headline)
                Text("Dejan de aparecer en la biblioteca. No se borran del todo (soft delete), pero hoy no hay pantalla para recuperarlas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            Divider()
            List(canciones, id: \.id) { song in
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.titleDisplay)
                    Text("\(song.artist) · \(song.id)").font(.caption).foregroundStyle(.secondary)
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
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 460, maxWidth: .infinity, minHeight: 360, idealHeight: 520, maxHeight: .infinity)
        #endif
    }
}
