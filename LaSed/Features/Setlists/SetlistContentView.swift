//
//  SetlistContentView.swift
//  LaSed
//
//  Versión: 0.11.0
//  Actualizado: 15/09/2026
//
import SwiftUI
import os
import UniformTypeIdentifiers

private let logDiag = Logger(subsystem: "com.poncoy.LaSed", category: "diagnostico")

struct SetlistContentView: View {
    let setlistId: String
    @Binding var selectedSongIds: Set<String>
    var onSetlistChanged: () -> Void = {}

    @State private var setlist: Setlist?
    @State private var bloques: [SetBlock] = []
    @State private var itemsPorBloque: [String: [(item: SetlistItem, song: Song)]] = [:]
    @State private var errorMessage: String?
    @State private var mostrandoNuevoBloque = false
    @State private var sugerenciasBloque: [String] = []
    @State private var mostrandoAgregarCancion = false
    @State private var bloqueParaAgregarCancion: SetBlock?
    @State private var itemParaEditarOverrides: SetlistItem?
    @State private var mostrandoEditarSetlist = false
    @State private var bloqueParaRenombrar: SetBlock?
    @State private var mostrandoRenombrarBloque = false
    @State private var nombreRenombrarBloque = ""

    private let blockRepo = SetBlockRepository()
    private let itemRepo = SetlistItemRepository()
    private let songRepo = SongRepository()

    var body: some View {
        VStack(spacing: 0) {
            Button {
                mostrandoEditarSetlist = true
            } label: {
                HStack(spacing: 6) {
                    Text((setlist?.name ?? "Setlist").uppercased())
                        .font(.caption.bold())
                        .kerning(0.5)
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .opacity(0.75)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Editar nombre, lugar, fecha y notas")

            HStack(spacing: 0) {
                Button {
                    agregarCancionSinBloque()
                } label: {
                    Label("Agregar canción", systemImage: "plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 16)

                Button {
                    mostrandoNuevoBloque = true
                } label: {
                    Label("Bloque", systemImage: "plus.rectangle.on.folder")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))

            List {
                ForEach(bloques, id: \.id) { bloque in
                    let items = itemsPorBloque[bloque.id] ?? []
                    Section {
                        ForEach(items, id: \.item.id) { par in
                            CancionEnSetlistRow(
                                song: par.song,
                                resumenOverrides: overridesResumen(par.item),
                                seleccionada: selectedSongIds.contains(par.song.id)
                            )
                            .onTapGesture {
                                selectedSongIds = [par.song.id]
                            }
                            .contextMenu {
                                Button("Editar tono/capo") {
                                    itemParaEditarOverrides = par.item
                                }
                                Button("Quitar del bloque", role: .destructive) {
                                    eliminarItem(par.item)
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
                        .buttonStyle(.plain)
                    } header: {
                        HStack(spacing: 6) {
                            Text(bloque.name)
                            Text("(\(items.count)\(duracionBloque(items)))")
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Renombrar bloque") { iniciarRenombrarBloque(bloque) }
                            Button("Eliminar bloque", role: .destructive) {
                                eliminarBloque(bloque)
                            }
                        }
                        .onDrag {
                            NSItemProvider(object: NSString(string: bloque.id))
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            guard let provider = providers.first else { return false }
                            _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                                guard let draggedId = reading as? String else { return }
                                DispatchQueue.main.async {
                                    reordenarBloque(draggedId: draggedId, sobreId: bloque.id)
                                }
                            }
                            return true
                        }
                    }
                }
            }
            .overlay {
                if bloques.isEmpty {
                    ContentUnavailableView {
                        Label("Setlist vacío", systemImage: "music.note.list")
                    } description: {
                        Text("Agregá canciones directo, o organizalas en bloques (A, B, SUP) si tocás en más de un momento.")
                    } actions: {
                        VStack(spacing: 8) {
                            Button("Agregar canción") {
                                agregarCancionSinBloque()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Organizar en bloques") {
                                mostrandoNuevoBloque = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .onAppear { cargarTodo() }
        .sheet(isPresented: $mostrandoNuevoBloque) {
            NuevoBloqueView(sugerencias: sugerenciasBloque, onCrear: crearBloque)
        }
        .sheet(isPresented: $mostrandoAgregarCancion) {
            if let bloque = bloqueParaAgregarCancion {
                AgregarCancionABloqueView(bloque: bloque, onAgregada: { cargarTodo() })
            }
        }
        .sheet(item: $itemParaEditarOverrides) { item in
            EditItemOverridesView(item: item, onGuardado: { cargarTodo() })
        }
        .sheet(isPresented: $mostrandoEditarSetlist) {
            if let setlist {
                EditSetlistView(setlist: setlist, onGuardado: {
                    cargarTodo()
                    onSetlistChanged()
                })
            }
        }
        .alert("Renombrar bloque", isPresented: $mostrandoRenombrarBloque) {
            TextField("Nombre", text: $nombreRenombrarBloque)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { renombrarBloque() }
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
        let idActual = setlistId
        let blockRepo = self.blockRepo
        let itemRepo = self.itemRepo
        let songRepo = self.songRepo
        let inicio = Date()
        logDiag.info("cargarTodo START \(idActual, privacy: .public)")
        Task.detached(priority: .userInitiated) {
            do {
                let setlistCargado = try SetlistRepository().fetchById(idActual)
                let bloquesCargados = try blockRepo.fetchActiveBySetlist(idActual)
                let sugerenciasCargadas = try blockRepo.nombresMasUsados()

                var itemsPorBloqueId: [String: [SetlistItem]] = [:]
                var idsDeCanciones = Set<String>()
                for bloque in bloquesCargados {
                    let items = try itemRepo.fetchActiveByBlock(bloque.id)
                    itemsPorBloqueId[bloque.id] = items
                    idsDeCanciones.formUnion(items.map(\.songId))
                }
                let cancionesPorId = Dictionary(
                    uniqueKeysWithValues: try songRepo.fetchByIds(Array(idsDeCanciones)).map { ($0.id, $0) }
                )
                let mapaFinal = itemsPorBloqueId.mapValues { items in
                    items.compactMap { item in
                        cancionesPorId[item.songId].map { (item: item, song: $0) }
                    }
                }

                let ms = Date().timeIntervalSince(inicio) * 1000
                logDiag.info("cargarTodo DATA LISTA \(idActual, privacy: .public) en \(ms, privacy: .public) ms")
                await MainActor.run {
                    setlist = setlistCargado
                    bloques = bloquesCargados
                    sugerenciasBloque = sugerenciasCargadas
                    itemsPorBloque = mapaFinal
                    let msTotal = Date().timeIntervalSince(inicio) * 1000
                    let msDesdeClic = (CFAbsoluteTimeGetCurrent() - MedicionClicSidebar.inicio) * 1000
                    logDiag.info("cargarTodo UI ACTUALIZADA \(idActual, privacy: .public) en \(msTotal, privacy: .public) ms — TOTAL desde clic: \(msDesdeClic, privacy: .public) ms")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "No se pudo cargar el setlist."
                }
            }
        }
    }

    private func crearBloque(nombre: String) {
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

    /// Setlist sin bloques todavía: crea uno "Canciones" invisible para el
    /// usuario (no le pide nombre) y abre directo "Agregar canción" ahí.
    /// Los bloques (A/B/SUP) son opcionales — organizarlos es un paso extra,
    /// no un requisito para armar una lista simple.
    /// Botón "Agregar canción" de arriba, siempre visible: si ya hay al
    /// menos un bloque usa el primero, si no hay ninguno crea uno
    /// "Canciones" invisible para el usuario. Nunca obliga a pensar en
    /// bloques antes de poder agregar una canción.
    private func agregarCancionSinBloque() {
        logDiag.info("agregarCancionSinBloque TOCADO, bloques.count=\(bloques.count, privacy: .public)")
        if let primero = bloques.first {
            bloqueParaAgregarCancion = primero
            mostrandoAgregarCancion = true
            return
        }
        let nuevo = SetBlock(
            id: UUID().uuidString,
            setlistId: setlistId,
            name: "Canciones",
            position: 0,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            rev: 1,
            lastEditedBy: "manual"
        )
        do {
            try blockRepo.create(nuevo)
            bloqueParaAgregarCancion = nuevo
            mostrandoAgregarCancion = true
            cargarTodo()
        } catch {
            errorMessage = "No se pudo crear el setlist."
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
        for (indice, elemento) in items.enumerated() where elemento.item.position != indice {
            var item = elemento.item
            item.position = indice
            try? itemRepo.update(item)
        }
    }

    private func eliminarItem(_ item: SetlistItem) {
        do {
            try itemRepo.softDelete(id: item.id, by: "manual")
            cargarTodo()
        } catch {
            errorMessage = "No se pudo quitar la canción."
        }
    }

    private func eliminarItems(en bloque: SetBlock, indices: IndexSet) {
        let items = itemsPorBloque[bloque.id] ?? []
        for indice in indices {
            try? itemRepo.softDelete(id: items[indice].item.id, by: "manual")
        }
        cargarTodo()
    }

    private func iniciarRenombrarBloque(_ bloque: SetBlock) {
        bloqueParaRenombrar = bloque
        nombreRenombrarBloque = bloque.name
        mostrandoRenombrarBloque = true
    }

    private func renombrarBloque() {
        guard let bloque = bloqueParaRenombrar else { return }
        let nombre = nombreRenombrarBloque.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        var actualizado = bloque
        actualizado.name = nombre
        do {
            try blockRepo.update(actualizado)
            cargarTodo()
        } catch {
            errorMessage = "No se pudo renombrar el bloque."
        }
    }

    private func reordenarBloque(draggedId: String, sobreId: String) {
        guard draggedId != sobreId,
              let origenIdx = bloques.firstIndex(where: { $0.id == draggedId }),
              let destinoIdx = bloques.firstIndex(where: { $0.id == sobreId }) else { return }
        var reordenados = bloques
        let arrastrado = reordenados.remove(at: origenIdx)
        reordenados.insert(arrastrado, at: destinoIdx)
        bloques = reordenados
        do {
            for (indice, bloque) in reordenados.enumerated() where bloque.position != indice {
                var actualizado = bloque
                actualizado.position = indice
                try blockRepo.update(actualizado)
            }
            cargarTodo()
        } catch {
            errorMessage = "No se pudo reordenar el bloque."
            cargarTodo()
        }
    }

    /// " · 12 min" cuando al menos una canción del bloque tiene duración
    /// cargada; vacío si ninguna la tiene (no mostrar "0 min" engañoso).
    private func duracionBloque(_ items: [(item: SetlistItem, song: Song)]) -> String {
        let segundos = items.compactMap { $0.song.durationSec }.reduce(0, +)
        guard segundos > 0 else { return "" }
        return " · \(segundos / 60) min"
    }

    private func overridesResumen(_ item: SetlistItem) -> String {
        var partes: [String] = []
        if let tono = item.keyOverride { partes.append(tono) }
        if let capo = item.capoOverride { partes.append("Capo \(capo)") }
        return partes.joined(separator: " · ")
    }
}

private struct CancionEnSetlistRow: View {
    let song: Song
    let resumenOverrides: String
    let seleccionada: Bool

    private var subtitulo: String {
        var partes = [song.artist]
        if !resumenOverrides.isEmpty { partes.append(resumenOverrides) }
        else if let tono = song.originalKey, !tono.isEmpty { partes.append(tono) }
        return partes.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(song.titleDisplay)
                .fontWeight(.medium)
            Text(subtitulo)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .listRowBackground(seleccionada ? Color.secondary.opacity(0.25) : Color.clear)
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
        #if os(macOS)
        .frame(width: 360, height: 260)
        #endif
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

private struct EditSetlistView: View {
    let setlist: Setlist
    var onGuardado: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nombre: String
    @State private var lugar: String
    @State private var tieneFecha: Bool
    @State private var fecha: Date
    @State private var notas: String
    @State private var errorMessage: String?

    private let setlistRepo = SetlistRepository()

    init(setlist: Setlist, onGuardado: @escaping () -> Void) {
        self.setlist = setlist
        self.onGuardado = onGuardado
        _nombre = State(initialValue: setlist.name)
        _lugar = State(initialValue: setlist.venue ?? "")
        _tieneFecha = State(initialValue: setlist.date != nil)
        _fecha = State(initialValue: setlist.date ?? Date())
        _notas = State(initialValue: setlist.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Editar setlist")
            Form {
                TextField("Nombre", text: $nombre)
                TextField("Lugar (ej: Fiesta Rosario)", text: $lugar)
                Toggle("Tiene fecha", isOn: $tieneFecha)
                if tieneFecha {
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                }
                TextField("Notas", text: $notas)
            }
            .padding()
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Guardar") { guardar() }
                    .buttonStyle(.borderedProminent)
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 420, height: 360)
        #endif
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
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        guard !nombreLimpio.isEmpty else { return }
        var actualizado = setlist
        actualizado.name = nombreLimpio
        let lugarLimpio = lugar.trimmingCharacters(in: .whitespaces)
        actualizado.venue = lugarLimpio.isEmpty ? nil : lugarLimpio
        actualizado.date = tieneFecha ? fecha : nil
        let notasLimpias = notas.trimmingCharacters(in: .whitespaces)
        actualizado.notes = notasLimpias.isEmpty ? nil : notasLimpias
        do {
            try setlistRepo.update(actualizado)
            onGuardado()
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar."
        }
    }
}

private struct NuevoBloqueView: View {
    let sugerencias: [String]
    var onCrear: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nombre = ""

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Nuevo bloque")
            VStack(alignment: .leading, spacing: 16) {
                if !sugerencias.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Usados antes — toca para crear directo")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(sugerencias, id: \.self) { sugerencia in
                                Button(sugerencia) {
                                    onCrear(sugerencia)
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                TextField("O escribe un nombre nuevo (ej: Bloque 3)", text: $nombre)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { crear() }
            }
            .padding()
            Spacer()
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Crear") { crear() }
                    .buttonStyle(.borderedProminent)
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 420, height: 320)
        #endif
    }

    private func crear() {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return }
        onCrear(limpio)
        dismiss()
    }
}

/// Envuelve botones a la siguiente línea cuando no entran, tipo "chips".
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct AgregarCancionABloqueView: View {
    let bloque: SetBlock
    var onAgregada: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var canciones: [Song]
    @State private var sugeridas: [Song]
    @State private var idsYaAgregados: Set<String>
    @State private var errorMessage: String?
    @State private var sugeridasExpandidas = true

    private let songRepo = SongRepository()
    private let itemRepo = SetlistItemRepository()

    init(bloque: SetBlock, onAgregada: @escaping () -> Void) {
        self.bloque = bloque
        self.onAgregada = onAgregada
        let itemRepo = SetlistItemRepository()
        let songRepo = SongRepository()
        let idsAgregados = (try? itemRepo.fetchActiveByBlock(bloque.id).map(\.songId)) ?? []
        let idsSugeridos = (try? itemRepo.songIdsFrecuentesPorNombreDeBloque(
            bloque.name,
            excluir: Set(idsAgregados)
        )) ?? []
        let cancionesPorId = Dictionary(
            uniqueKeysWithValues: ((try? songRepo.fetchByIds(idsSugeridos)) ?? []).map { ($0.id, $0) }
        )
        _idsYaAgregados = State(initialValue: Set(idsAgregados))
        _sugeridas = State(initialValue: idsSugeridos.compactMap { cancionesPorId[$0] })
        let todas = (try? songRepo.fetchAllActive()) ?? []
        _canciones = State(initialValue: todas.sorted {
            $0.titleDisplay.localizedStandardCompare($1.titleDisplay) == .orderedAscending
        })
    }

    var body: some View {
        #if os(iOS)
        NavigationStack { contenido }
        #else
        contenido
        #endif
    }

    private var contenido: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Agregar a \(bloque.name) — \(canciones.count) canciones")
            List {
                if searchText.isEmpty, !sugeridas.isEmpty {
                    DisclosureGroup("Sugeridas (de setlists anteriores)", isExpanded: $sugeridasExpandidas) {
                        ForEach(sugeridas, id: \.id) { song in fila(song) }
                    }
                }
                Section(searchText.isEmpty && !sugeridas.isEmpty ? "Todas las canciones" : "") {
                    ForEach(canciones, id: \.id) { song in fila(song) }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar canción")
            .onChange(of: searchText) { _, nuevo in cargar(query: nuevo) }
            HStack {
                Text("\(idsYaAgregados.count) agregada(s) — podés seguir tocando canciones")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Button("Listo") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 460, height: 560)
        #endif
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
    private func fila(_ song: Song) -> some View {
        let yaAgregada = idsYaAgregados.contains(song.id)
        Button {
            agregar(song)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(song.titleDisplay)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(subtitulo(song))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if yaAgregada {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func subtitulo(_ song: Song) -> String {
        var partes = [song.artist]
        if let tono = song.originalKey, !tono.isEmpty { partes.append(tono) }
        if let bpm = song.bpm { partes.append("\(bpm) bpm") }
        return partes.joined(separator: " · ")
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
        guard !idsYaAgregados.contains(song.id) else { return }
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
            idsYaAgregados.insert(song.id)
            onAgregada()
        } catch {
            errorMessage = "No se pudo agregar la canción."
        }
    }
}
