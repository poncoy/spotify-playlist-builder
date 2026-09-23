//
//  RootSplitView.swift
//  LaSed
//
//  Versión: 0.7.0
//  Actualizado: 15/09/2026
//
import SwiftUI
import UniformTypeIdentifiers
import os

private let logPerf = Logger(subsystem: "com.poncoy.LaSed", category: "diagnostico")

/// Momento del último clic real en una fila de la sidebar. Vive acá porque
/// se necesita medir desde RootSplitView (dónde ocurre el clic) hasta
/// SetlistContentView (dónde termina de pintarse el contenido), dos vistas
/// en archivos distintos.
enum MedicionClicSidebar {
    static var inicio: CFAbsoluteTime = 0
}

/// Encadena varias vueltas de runloop después del clic. Si esto también da
/// tiempos bajos pero la pantalla igual se siente lenta, el cuello de
/// botella está fuera del hilo principal de la app (compositor/WindowServer),
/// no en código Swift que se pueda optimizar acá.
private func medirVueltasDeRunloop(etiqueta: String, vuelta: Int = 1) {
    DispatchQueue.main.async {
        let ms = (CFAbsoluteTimeGetCurrent() - MedicionClicSidebar.inicio) * 1000
        logPerf.info("\(etiqueta, privacy: .public) vuelta runloop #\(vuelta) — Δ: \(ms, privacy: .public) ms")
        if vuelta < 10 {
            medirVueltasDeRunloop(etiqueta: etiqueta, vuelta: vuelta + 1)
        }
    }
}

enum SeccionPrincipal: Hashable {
    case inicio
    case biblioteca
    case setlist(String)
}

/// Carga de arrastre para una canción (Biblioteca → Setlist). Tipo propio
/// (no String pelado) para que no se confunda con el arrastre de un setlist
/// hacia una carpeta — ambos son IDs, pero representan cosas distintas.
struct CancionArrastrada: Codable, Transferable {
    let songId: String
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}

/// Carga de arrastre para mover un setlist hacia una carpeta.
struct SetlistArrastrado: Codable, Transferable {
    let setlistId: String
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}

struct RootSplitView: View {
    @State private var seccion: SeccionPrincipal? = .inicio
    @State private var setlists: [Setlist] = []
    @State private var selectedSongIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var mostrandoNuevoSetlist = false
    @State private var nuevoNombre = ""
    @State private var setlistParaRenombrar: Setlist?
    @State private var mostrandoRenombrar = false
    @State private var nombreRenombrar = ""
    @State private var setlistParaMover: Setlist?
    @State private var mostrandoNuevaCarpeta = false
    @State private var nombreNuevaCarpeta = ""
    @State private var carpetasColapsadas: Set<String> = []
    @State private var mostrandoNuevaCarpetaDesdeCero = false
    @State private var carpetaPendiente: String?
    @State private var carpetaParaRenombrar: String?
    @State private var mostrandoRenombrarCarpeta = false
    @State private var nombreRenombrarCarpeta = ""
    @State private var mostrandoImportarCSV = false

    private let setlistRepo = SetlistRepository()

    var body: some View {
        NavigationSplitView {
            Group {
                #if os(iOS)
                List(selection: $seccion) { filasSidebar }
                #else
                List { filasSidebar }
                #endif
            }
            .listStyle(.sidebar)
            .navigationTitle("La Sed")
            .onAppear { cargarSetlists() }
            .onChange(of: seccion) { _, nuevo in
                let deltaClic = (CFAbsoluteTimeGetCurrent() - MedicionClicSidebar.inicio) * 1000
                logPerf.info("seccion CAMBIO a \(String(describing: nuevo), privacy: .public) — Δ desde clic: \(deltaClic, privacy: .public) ms")
                selectedSongIds = []
                if case .setlist(let id) = nuevo, let setlist = setlists.first(where: { $0.id == id }) {
                    RecentsTracker.registrar(id: setlist.id, tipo: .setlist, titulo: setlist.name, subtitulo: setlist.venue)
                }
            }
            .alert("Nuevo setlist", isPresented: $mostrandoNuevoSetlist) {
                TextField("Nombre (ej: Fiesta Rosario 20/09)", text: $nuevoNombre)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") { crearSetlist() }
            }
            .alert("Renombrar setlist", isPresented: $mostrandoRenombrar) {
                TextField("Nombre", text: $nombreRenombrar)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") { renombrar() }
            }
            .alert("Nueva carpeta", isPresented: $mostrandoNuevaCarpetaDesdeCero) {
                TextField("Nombre (ej: La Sed, Acústicon)", text: $nombreNuevaCarpeta)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") {
                    carpetaPendiente = nombreNuevaCarpeta.trimmingCharacters(in: .whitespaces)
                    nuevoNombre = ""
                    mostrandoNuevoSetlist = true
                }
            } message: {
                Text("Ahora ponele nombre al primer setlist de esta carpeta.")
            }
            .alert("Nueva carpeta", isPresented: $mostrandoNuevaCarpeta) {
                TextField("Nombre (ej: La Sed, Acústicon)", text: $nombreNuevaCarpeta)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") {
                    if let setlist = setlistParaMover {
                        moverACarpeta(setlist, carpeta: nombreNuevaCarpeta)
                    }
                }
            }
            .alert("Renombrar carpeta", isPresented: $mostrandoRenombrarCarpeta) {
                TextField("Nombre", text: $nombreRenombrarCarpeta)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") { renombrarCarpeta() }
            }
            .sheet(isPresented: $mostrandoImportarCSV) {
                ImportarSetlistCSVView(onCreado: { id in
                    cargarSetlists()
                    seccion = .setlist(id)
                })
            }
        } content: {
            Group {
                switch seccion {
                case .setlist(let id):
                    SetlistContentView(
                        setlistId: id,
                        selectedSongIds: $selectedSongIds,
                        onSetlistChanged: { cargarSetlists() }
                    )
                    .id(id)
                case .biblioteca:
                    BibliotecaContentView(selectedSongIds: $selectedSongIds)
                case .inicio, nil:
                    HomeView(
                        seccion: $seccion,
                        onNuevoSetlist: {
                            carpetaPendiente = nil
                            nuevoNombre = ""
                            mostrandoNuevoSetlist = true
                        },
                        onImportarCSV: { mostrandoImportarCSV = true }
                    )
                }
            }
            .transaction { $0.disablesAnimations = true }
        } detail: {
            detalle
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
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

    /// Filas del sidebar. En iOS necesita ir dentro de un `List(selection:)`
    /// real — sin eso, `NavigationSplitView` no empuja la columna de
    /// contenido en pantallas angostas (UISplitViewController solo dispara
    /// esa navegación desde su propio mecanismo de selección nativo). En Mac
    /// las tres columnas están siempre visibles, así que ahí seguimos con la
    /// asignación manual directa (más rápida, ver `FilaConHover`).
    @ViewBuilder
    private var filasSidebar: some View {
        FilaConHover(seleccionada: seccion == .inicio) {
            Label("Inicio", systemImage: "house")
                .contentShape(Rectangle())
                #if os(macOS)
                .onTapGesture {
                    MedicionClicSidebar.inicio = CFAbsoluteTimeGetCurrent()
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { seccion = .inicio }
                }
                #endif
        }
        #if os(iOS)
        .tag(SeccionPrincipal.inicio)
        #endif

        FilaConHover(seleccionada: seccion == .biblioteca) {
            Label("Biblioteca", systemImage: "music.note.list")
                .contentShape(Rectangle())
                #if os(macOS)
                .onTapGesture {
                    MedicionClicSidebar.inicio = CFAbsoluteTimeGetCurrent()
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { seccion = .biblioteca }
                }
                #endif
        }
        #if os(iOS)
        .tag(SeccionPrincipal.biblioteca)
        #endif

        Section {
            if !setlistsSinCarpeta.isEmpty {
                ForEach(setlistsSinCarpeta, id: \.id) { setlist in
                    filaSetlist(setlist)
                }
            }
            ForEach(carpetas, id: \.self) { carpeta in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { !carpetasColapsadas.contains(carpeta) },
                        set: { expandido in
                            if expandido { carpetasColapsadas.remove(carpeta) }
                            else { carpetasColapsadas.insert(carpeta) }
                        }
                    )
                ) {
                    ForEach(setlistsEnCarpeta(carpeta), id: \.id) { setlist in
                        filaSetlist(setlist)
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.blue)
                        Text(carpeta)
                        Spacer()
                        Text("\(setlistsEnCarpeta(carpeta).count)")
                            .foregroundStyle(Color.secondary)
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Renombrar carpeta") {
                            carpetaParaRenombrar = carpeta
                            nombreRenombrarCarpeta = carpeta
                            mostrandoRenombrarCarpeta = true
                        }
                        Button("Eliminar carpeta", role: .destructive) {
                            eliminarCarpeta(carpeta)
                        }
                    }
                    .dropDestination(for: SetlistArrastrado.self) { arrastrados, _ in
                        for arrastrado in arrastrados {
                            guard let setlist = setlists.first(where: { $0.id == arrastrado.setlistId }) else { continue }
                            moverACarpeta(setlist, carpeta: carpeta)
                        }
                        return true
                    }
                }
            }
        } header: {
            HStack {
                Text("Setlists")
                Spacer()
                Button {
                    mostrandoImportarCSV = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
                .buttonStyle(.plain)
                .help("Importar setlist desde CSV")

                Button {
                    nombreNuevaCarpeta = ""
                    mostrandoNuevaCarpetaDesdeCero = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .help("Nueva carpeta")

                Button {
                    carpetaPendiente = nil
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

    private var carpetas: [String] {
        Set(setlists.compactMap(\.folder)).sorted()
    }

    private var setlistsSinCarpeta: [Setlist] {
        setlists.filter { $0.folder == nil }
    }

    private func setlistsEnCarpeta(_ carpeta: String) -> [Setlist] {
        setlists.filter { $0.folder == carpeta }
    }

    @ViewBuilder
    private func filaSetlist(_ setlist: Setlist) -> some View {
        FilaConHover(seleccionada: seccion == .setlist(setlist.id)) {
            Label(setlist.name, systemImage: "music.mic")
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Renombrar") { iniciarRenombrar(setlist) }
                    Menu("Mover a carpeta") {
                        if setlist.folder != nil {
                            Button("Sin carpeta") { moverACarpeta(setlist, carpeta: nil) }
                        }
                        ForEach(carpetas.filter { $0 != setlist.folder }, id: \.self) { carpeta in
                            Button(carpeta) { moverACarpeta(setlist, carpeta: carpeta) }
                        }
                        Divider()
                        Button("Nueva carpeta…") {
                            setlistParaMover = setlist
                            nombreNuevaCarpeta = ""
                            mostrandoNuevaCarpeta = true
                        }
                    }
                    Button("Duplicar") { duplicar(setlist) }
                    Button("Eliminar", role: .destructive) { eliminar(setlist) }
                }
                #if os(macOS)
                .simultaneousGesture(
                    TapGesture(count: 1).onEnded {
                        MedicionClicSidebar.inicio = CFAbsoluteTimeGetCurrent()
                        logPerf.info("CLIC en fila '\(setlist.name, privacy: .public)'")
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { seccion = .setlist(setlist.id) }
                        medirVueltasDeRunloop(etiqueta: "sidebar")
                    }
                )
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { iniciarRenombrar(setlist) }
                )
                #endif
                .dropDestination(for: CancionArrastrada.self) { canciones, _ in
                    agregarCanciones(canciones.map(\.songId), a: setlist)
                    return true
                }
                .draggable(SetlistArrastrado(setlistId: setlist.id))
        }
        #if os(iOS)
        .tag(SeccionPrincipal.setlist(setlist.id))
        #endif
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
        let carpeta = carpetaPendiente
        carpetaPendiente = nil
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
            lastEditedBy: "manual",
            folder: (carpeta?.isEmpty ?? true) ? nil : carpeta
        )
        do {
            try setlistRepo.create(setlist)
            cargarSetlists()
            seccion = .setlist(setlist.id)
        } catch {
            errorMessage = "No se pudo crear el setlist."
        }
    }

    private func iniciarRenombrar(_ setlist: Setlist) {
        setlistParaRenombrar = setlist
        nombreRenombrar = setlist.name
        mostrandoRenombrar = true
    }

    private func renombrar() {
        guard let setlist = setlistParaRenombrar else { return }
        let nombre = nombreRenombrar.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        var actualizado = setlist
        actualizado.name = nombre
        do {
            try setlistRepo.update(actualizado)
            cargarSetlists()
        } catch {
            errorMessage = "No se pudo renombrar el setlist."
        }
    }

    private func moverACarpeta(_ setlist: Setlist, carpeta: String?) {
        let limpia = carpeta?.trimmingCharacters(in: .whitespaces)
        var actualizado = setlist
        actualizado.folder = (limpia?.isEmpty ?? true) ? nil : limpia
        do {
            try setlistRepo.update(actualizado)
            cargarSetlists()
        } catch {
            errorMessage = "No se pudo mover el setlist de carpeta."
        }
    }

    /// Renombra la carpeta entera: reescribe `folder` en todos los setlists
    /// que la tengan asignada, de una sola vez.
    private func renombrarCarpeta() {
        guard let carpetaVieja = carpetaParaRenombrar else { return }
        let nombreNuevo = nombreRenombrarCarpeta.trimmingCharacters(in: .whitespaces)
        guard !nombreNuevo.isEmpty else { return }
        do {
            for setlist in setlistsEnCarpeta(carpetaVieja) {
                var actualizado = setlist
                actualizado.folder = nombreNuevo
                try setlistRepo.update(actualizado)
            }
            cargarSetlists()
        } catch {
            errorMessage = "No se pudo renombrar la carpeta."
        }
    }

    /// Los setlists de la carpeta vuelven a "Sin carpeta" — la carpeta en sí
    /// no es una entidad propia, desaparece sola cuando ningún setlist la usa.
    private func eliminarCarpeta(_ carpeta: String) {
        do {
            for setlist in setlistsEnCarpeta(carpeta) {
                var actualizado = setlist
                actualizado.folder = nil
                try setlistRepo.update(actualizado)
            }
            cargarSetlists()
        } catch {
            errorMessage = "No se pudo eliminar la carpeta."
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

    /// Arrastrar una o más canciones desde la Biblioteca directo a un
    /// setlist del sidebar (como arrastrar una nota a una carpeta en
    /// Notas): usa el primer bloque que tenga, o crea uno "Canciones"
    /// invisible si el setlist todavía no tiene ninguno.
    private func agregarCanciones(_ songIds: [String], a setlist: Setlist) {
        let blockRepo = SetBlockRepository()
        let itemRepo = SetlistItemRepository()
        do {
            var bloque = try blockRepo.fetchActiveBySetlist(setlist.id).first
            if bloque == nil {
                let nuevo = SetBlock(
                    id: UUID().uuidString,
                    setlistId: setlist.id,
                    name: "Canciones",
                    position: 0,
                    createdAt: Date(),
                    updatedAt: Date(),
                    deletedAt: nil,
                    rev: 1,
                    lastEditedBy: "manual"
                )
                try blockRepo.create(nuevo)
                bloque = nuevo
            }
            guard let bloqueDestino = bloque else { return }
            var posicion = try itemRepo.fetchActiveByBlock(bloqueDestino.id).count
            for songId in songIds {
                let item = SetlistItem(
                    id: UUID().uuidString,
                    blockId: bloqueDestino.id,
                    songId: songId,
                    position: posicion,
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
                posicion += 1
            }
        } catch {
            errorMessage = "No se pudo agregar la canción al setlist."
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

/// Resalta la fila al pasar el mouse por encima, no solo al seleccionarla —
/// sin esto (perdido al sacar el `selection:` nativo del List) la sidebar
/// se siente muerta porque no hay ninguna señal visual antes del clic.
private struct FilaConHover<Content: View>: View {
    let seleccionada: Bool
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        content()
            .listRowBackground(
                (seleccionada ? Color.accentColor.opacity(0.15)
                : hovering ? Color.secondary.opacity(0.15)
                : Color.clear)
                .animation(nil, value: seleccionada)
                .animation(nil, value: hovering)
            )
            .onHover { hovering = $0 }
    }
}
