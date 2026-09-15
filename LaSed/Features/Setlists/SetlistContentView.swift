//
//  SetlistContentView.swift
//  LaSed
//
//  Versión app:  0.7.0
//  Fase:         4 — Setlists: bloques, canciones, reordenar, tono/capo
//  Modificado:   14/09/2026
//
//  Reordenar bloques entre sí: botones Subir/Bajar en el menú del bloque
//  (swap de `position` con el vecino). Reordenar canciones dentro de un
//  bloque sigue siendo por drag (.onMove).
//  Tono/capo por canción: contextMenu en cada fila -> EditItemOverridesView.

import SwiftUI

struct SetlistContentView: View {
    let setlistId: String
    @Binding var selectedSongIds: Set<String>

    @State private var setlist: Setlist?
    @State private var bloques: [SetBlock] = []
    @State private var itemsPorBloque: [String: [(item: SetlistItem, song: Song)]] = [:]
    @State private var errorMessage: String?
    @State private var mostrandoNuevoBloque = false
    @State private var nombreNuevoBloque = ""
    @State private var mostrandoAgregarCancion = false
    @State private var bloqueParaAgregarCancion: SetBlock?
    @State private var itemParaEditarOverrides: SetlistItem?

    private let blockRepo = SetBlockRepository()
    private let itemRepo = SetlistItemRepository()
    private let songRepo = SongRepository()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: setlist?.name ?? "Setlist")

            List {
                ForEach(bloques, id: \.id) { bloque in
                    let items = itemsPorBloque[bloque.id] ?? []
                    Section {
                        ForEach(items, id: \.item.id) { par in
                            HStack {
                                Text("\(par.song.titleDisplay) — \(par.song.artist)")
                                Spacer()
                                if par.item.keyOverride != nil || par.item.capoOverride != nil {
                                    Text(overridesResumen(par.item))
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .listRowBackground(
                                selectedSongIds.contains(par.song.id)
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .onTapGesture {
                                selectedSongIds = [par.song.id]
                            }
                            .contextMenu {
                                Button("Editar tono/capo") {
                                    itemParaEditarOverrides = par.item
                                }
                            }
                        }
                        .onMove { origen, destino in mover(en: bloque, origen: origen, destino: destino) }
                        .onDelete { indices in eliminarItems(en: bloque, indices: indices) }

                        Button {
                            bloqueParaAgregarCancion = bloque
                            mostrandoAgregarCancion = true
                        } label: {
                            Label("Agregar canción", systemImage: "plus")
                        }
                    } header: {
                        HStack {
                            Text(bloque.name)
                            Spacer()
                            Menu {
                                Button("Subir bloque") { moverBloque(bloque, arriba: true) }
                                    .disabled(bloque.position == 0)
                                Button("Bajar bloque") { moverBloque(bloque, arriba: false) }
                                    .disabled(bloque.position == bloques.count - 1)
                                Divider()
                                Button("Eliminar bloque", role: .destructive) {
                                    eliminarBloque(bloque)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        nombreNuevoBloque = ""
                        mostrandoNuevoBloque = true
                    } label: {
                        Label("Bloque", systemImage: "plus.rectangle.on.folder")
                    }
                }
            }
            .overlay {
                if bloques.isEmpty {
                    ContentUnavailableView(
                        "Sin bloques",
                        systemImage: "rectangle.stack",
                        description: Text("Toca el botón de arriba para crear el primero (ej: A, B, SUP).")
                    )
                }
            }
        }
        .onAppear { cargarTodo() }
        .alert("Nuevo bloque", isPresented: $mostrandoNuevoBloque) {
            TextField("Nombre (ej: A, B, SUP)", text: $nombreNuevoBloque)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") { crearBloque() }
        }
        .sheet(isPresented: $mostrandoAgregarCancion) {
            if let bloque = bloqueParaAgregarCancion {
                AgregarCancionABloqueView(bloque: bloque, onAgregada: { cargarTodo() })
            }
        }
        .sheet(item: $itemParaEditarOverrides) { item in
            EditItemOverridesView(item: item, onGuardado: { cargarTodo() })
        }
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func cargarTodo() {
        do {
            setlist = try SetlistRepository().fetchById(setlistId)
            bloques = try blockRepo.fetchActiveBySetlist(setlistId)
            var mapa: [String: [(item: SetlistItem, song: Song)]] = [:]
            for bloque in bloques {
                let items = try itemRepo.fetchActiveByBlock(bloque.id)
                var pares: [(item: SetlistItem, song: Song)] = []
                for item in items {
                    if let song = try songRepo.fetchById(item.songId) {
                        pares.append((item, song))
                    }
                }
                mapa[bloque.id] = pares
            }
            itemsPorBloque = mapa
        } catch {
            errorMessage = "No se pudo cargar el setlist."
        }
    }

    private func crearBloque() {
        let nombre = nombreNuevoBloque.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        let nuevo = SetBlock(
            id: UUID().uuidString,
            setlistId: setlistId,
            name: nombre,
            position: bloques.count,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            rev: 1,
            lastEditedBy: "manual"
        )
        do {
            try blockRepo.create(nuevo)
            cargarTodo()
        } catch {
            errorMessage = "No se pudo crear el bloque."
        }
    }

    private func eliminarBloque(_ bloque: SetBlock) {
        do {
            try blockRepo.softDelete(id: bloque.id, by: "manual")
            cargarTodo()
        } catch {
            errorMessage = "No se pudo eliminar el bloque."
        }
    }

    private func mover(en bloque: SetBlock, origen: IndexSet, destino: Int) {
        var items = itemsPorBloque[bloque.id] ?? []
        items.move(fromOffsets: origen, toOffset: destino)
        itemsPorBloque[bloque.id] = items
        for (indice, par) in items.enumerated() where par.item.position != indice {
            var item = par.item
            item.position = indice
            try? itemRepo.update(item)
        }
    }

    private func eliminarItems(en bloque: SetBlock, indices: IndexSet) {
        let items = itemsPorBloque[bloque.id] ?? []
        for indice in indices {
            try? itemRepo.softDelete(id: items[indice].item.id, by: "manual")
        }
        cargarTodo()
    }

    private func moverBloque(_ bloque: SetBlock, arriba: Bool) {
        let vecinoPosicion = bloque.position + (arriba ? -1 : 1)
        guard let vecino = bloques.first(where: { $0.position == vecinoPosicion }) else { return }
        do {
            var a = bloque
            var b = vecino
            a.position = vecinoPosicion
            b.position = bloque.position
            try blockRepo.update(a)
            try blockRepo.update(b)
            cargarTodo()
        } catch {
            errorMessage = "No se pudo reordenar el bloque."
        }
    }

    private func overridesResumen(_ item: SetlistItem) -> String {
        var partes: [String] = []
        if let tono = item.keyOverride { partes.append(tono) }
        if let capo = item.capoOverride { partes.append("Capo \(capo)") }
        return partes.joined(separator: " · ")
    }
}

private struct EditItemOverridesView: View {
    let item: SetlistItem
    var onGuardado: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tono: String
    @State private var capoTexto: String
    @State private var errorMessage: String?

    private let itemRepo = SetlistItemRepository()

    init(item: SetlistItem, onGuardado: @escaping () -> Void) {
        self.item = item
        self.onGuardado = onGuardado
        _tono = State(initialValue: item.keyOverride ?? "")
        _capoTexto = State(initialValue: item.capoOverride.map(String.init) ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Tono / capo")
            Form {
                TextField("Tono (ej: G, Am, D)", text: $tono)
                TextField("Capo (número de traste)", text: $capoTexto)
            }
            .padding()
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Guardar") { guardar() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 320, minHeight: 220)
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func guardar() {
        let tonoLimpio = tono.trimmingCharacters(in: .whitespaces)
        let capoLimpio = capoTexto.trimmingCharacters(in: .whitespaces)
        var actualizado = item
        actualizado.keyOverride = tonoLimpio.isEmpty ? nil : tonoLimpio
        actualizado.capoOverride = capoLimpio.isEmpty ? nil : Int(capoLimpio)
        do {
            try itemRepo.update(actualizado)
            onGuardado()
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar."
        }
    }
}

private struct AgregarCancionABloqueView: View {
    let bloque: SetBlock
    var onAgregada: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var canciones: [Song] = []
    @State private var errorMessage: String?

    private let songRepo = SongRepository()
    private let itemRepo = SetlistItemRepository()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Agregar a \(bloque.name)")
            List(canciones, id: \.id) { song in
                Button {
                    agregar(song)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.titleDisplay)
                        Text(song.artist).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Buscar canción")
            .onChange(of: searchText) { _, nuevo in cargar(query: nuevo) }
            .onAppear { cargar(query: "") }
        }
        .frame(minWidth: 380, minHeight: 480)
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func cargar(query: String) {
        do {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            let resultados = trimmed.isEmpty ? try songRepo.fetchAllActive() : try songRepo.search(trimmed)
            canciones = resultados.sorted { $0.titleDisplay.localizedStandardCompare($1.titleDisplay) == .orderedAscending }
        } catch {
            errorMessage = "No se pudo buscar."
        }
    }

    private func agregar(_ song: Song) {
        do {
            let items = try itemRepo.fetchActiveByBlock(bloque.id)
            let item = SetlistItem(
                id: UUID().uuidString,
                blockId: bloque.id,
                songId: song.id,
                position: items.count,
                keyOverride: nil,
                capoOverride: nil,
                notes: nil,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil,
                rev: 1,
                lastEditedBy: "manual"
            )
            try itemRepo.create(item)
            onAgregada()
            dismiss()
        } catch {
            errorMessage = "No se pudo agregar la canción."
        }
    }
}
