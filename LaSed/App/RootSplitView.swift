//
//  RootSplitView.swift
//  LaSed
//
//  Versión app:  0.6.0
//  Fase:         4 — Setlists
//  Modificado:   14/09/2026
//

import SwiftUI

enum SeccionPrincipal: Hashable {
    case biblioteca
    case setlist(String)
}

struct RootSplitView: View {
    @State private var seccion: SeccionPrincipal? = .biblioteca
    @State private var setlists: [Setlist] = []
    @State private var selectedSongIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var mostrandoNuevoSetlist = false
    @State private var nuevoNombre = ""

    private let setlistRepo = SetlistRepository()

    var body: some View {
        NavigationSplitView {
            List(selection: $seccion) {
                Label("Biblioteca", systemImage: "music.note.list")
                    .tag(SeccionPrincipal.biblioteca)

                Section {
                    ForEach(setlists, id: \.id) { setlist in
                        Label(setlist.name, systemImage: "music.mic")
                            .tag(SeccionPrincipal.setlist(setlist.id))
                            .contextMenu {
                                Button("Duplicar") { duplicar(setlist) }
                                Button("Eliminar", role: .destructive) { eliminar(setlist) }
                            }
                    }
                } header: {
                    HStack {
                        Text("Setlists")
                        Spacer()
                        Button {
                            nuevoNombre = ""
                            mostrandoNuevoSetlist = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Nuevo setlist")
                    }
                }
            }
            .navigationTitle("La Sed")
            .onAppear { cargarSetlists() }
            .alert("Nuevo setlist", isPresented: $mostrandoNuevoSetlist) {
                TextField("Nombre (ej: Fiesta Rosario 20/09)", text: $nuevoNombre)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") { crearSetlist() }
            }
        } content: {
            switch seccion {
            case .setlist(let id):
                SetlistContentView(setlistId: id, selectedSongIds: $selectedSongIds)
                    .id(id)
            case .biblioteca, nil:
                BibliotecaContentView(selectedSongIds: $selectedSongIds)
            }
        } detail: {
            detalle
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detalle: some View {
        if selectedSongIds.count == 1, let unicoId = selectedSongIds.first {
            EditSongView(
                songId: unicoId,
                onChanged: {},
                onDeleted: { selectedSongIds = [] }
            )
            .id(unicoId)
        } else if selectedSongIds.count > 1 {
            ContentUnavailableView(
                "\(selectedSongIds.count) canciones seleccionadas",
                systemImage: "checkmark.circle"
            )
        } else {
            ContentUnavailableView("Selecciona una canción", systemImage: "music.note")
        }
    }

    private func cargarSetlists() {
        do {
            setlists = try setlistRepo.fetchAllActive()
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "No se pudieron cargar los setlists."
        }
    }

    private func crearSetlist() {
        let nombre = nuevoNombre.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        let setlist = Setlist(
            id: UUID().uuidString,
            name: nombre,
            venue: nil,
            date: nil,
            notes: nil,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            rev: 1,
            lastEditedBy: "manual"
        )
        do {
            try setlistRepo.create(setlist)
            cargarSetlists()
            seccion = .setlist(setlist.id)
        } catch {
            errorMessage = "No se pudo crear el setlist."
        }
    }

    private func eliminar(_ setlist: Setlist) {
        do {
            try setlistRepo.softDelete(id: setlist.id, by: "manual")
            if seccion == .setlist(setlist.id) { seccion = .biblioteca }
            cargarSetlists()
        } catch {
            errorMessage = "No se pudo eliminar el setlist."
        }
    }

    private func duplicar(_ setlist: Setlist) {
        let blockRepo = SetBlockRepository()
        let itemRepo = SetlistItemRepository()
        do {
            var copia = setlist
            copia.id = UUID().uuidString
            copia.name = setlist.name + " (copia)"
            copia.createdAt = Date()
            copia.updatedAt = Date()
            copia.deletedAt = nil
            copia.rev = 1
            try setlistRepo.create(copia)

            let bloques = try blockRepo.fetchActiveBySetlist(setlist.id)
            for bloque in bloques {
                var bloqueCopia = bloque
                bloqueCopia.id = UUID().uuidString
                bloqueCopia.setlistId = copia.id
                bloqueCopia.createdAt = Date()
                bloqueCopia.updatedAt = Date()
                bloqueCopia.deletedAt = nil
                bloqueCopia.rev = 1
                try blockRepo.create(bloqueCopia)

                let items = try itemRepo.fetchActiveByBlock(bloque.id)
                for item in items {
                    var itemCopia = item
                    itemCopia.id = UUID().uuidString
                    itemCopia.blockId = bloqueCopia.id
                    itemCopia.createdAt = Date()
                    itemCopia.updatedAt = Date()
                    itemCopia.deletedAt = nil
                    itemCopia.rev = 1
                    try itemRepo.create(itemCopia)
                }
            }
            cargarSetlists()
        } catch {
            errorMessage = "No se pudo duplicar el setlist."
        }
    }
}
