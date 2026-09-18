//
//  EditSongView.swift
//  LaSed
//
//  Versión: 0.4.10
//  Actualizado: 11/09/2026
//
import SwiftUI
import Foundation

private enum PestañaEditor: String, CaseIterable {
    case contenido = "Letra y acordes"
    case datos = "Datos"
}

struct EditSongView: View {
    let songId: String
    var onChanged: () -> Void
    var onDeleted: () -> Void

    @State private var pestaña: PestañaEditor = .contenido

    @State private var song: Song?
    @State private var contentAST: ParsedSongContent?
    @State private var contentDecodeFailed = false
    @State private var titleDisplay = ""
    @State private var artist = ""
    @State private var spotifyId = ""
    @State private var youtubeUrl = ""
    @State private var physicalNotes = ""
    @State private var country = ""
    @State private var language = ""
    @State private var isLive = false
    @State private var level: Int = 0
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var showingDeleteConfirm = false

    @State private var modoEdicion = false
    @State private var editableAttributed = AttributedString()
    @AppStorage(DisplayPreferenceKeys.fontSize) private var globalFontSize: Double = 15
    @AppStorage(DisplayPreferenceKeys.fontFamily) private var globalFontFamilyRaw: String = ChordFontFamily.sistema.rawValue
    @State private var showingDisplaySettings = false
    @State private var showingChordReference = false
    @State private var showingMetronome = false
    @State private var bpm: Int = 0

    private var fontSize: Double { song?.effectiveFontSize(global: globalFontSize) ?? globalFontSize }
    private var fontFamily: ChordFontFamily {
        song?.effectiveFontFamily(globalRaw: globalFontFamilyRaw) ?? (ChordFontFamily(rawValue: globalFontFamilyRaw) ?? .sistema)
    }

    // Idioma como selección controlada (mapeo de NotesImportPreviewView);
    // valores libres previos se agregan como opción extra.
    private static let idiomasBase = ["Español", "Inglés", "Italiano", "Alemán", "Portugués", "Francés"]

    private var opcionesIdioma: [String] {
        var opciones = Self.idiomasBase
        if !language.isEmpty, !opciones.contains(language) {
            opciones.append(language)
        }
        return opciones.sorted()
    }

    private var opcionesPais: [(id: String, label: String)] {
        var opciones = paisesConocidos.map { (id: $0.flag, label: "\($0.flag) \($0.nombre)") }
        if !country.isEmpty, !opciones.contains(where: { $0.id == country }) {
            opciones.append((id: country, label: country))
        }
        return opciones
    }

    @State private var aliases: [SongAlias] = []
    @State private var newAliasText = ""

    private let repo = SongRepository()
    private let aliasRepo = SongAliasRepository()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Editor de canción")

            Picker("Vista", selection: $pestaña) {
                ForEach(PestañaEditor.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch pestaña {
            case .datos:
                datosForm
            case .contenido:
                contenidoTab
            }
        }
        .navigationTitle(titleDisplay.isEmpty ? "Canción" : titleDisplay)
        .navigationSubtitle("Editor de canción — Biblioteca")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
                    .disabled(titleDisplay.trimmingCharacters(in: .whitespaces).isEmpty
                              || artist.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            load()
            loadAliases()
        }
        .confirmationDialog(
            "¿Eliminar esta canción?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { delete() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Deja de aparecer en la biblioteca. No se borra del todo, pero hoy no hay pantalla para recuperarla.")
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

    // MARK: - Pestaña "Datos"

    private var datosForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Identificación") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Código")
                            Spacer()
                            Text(songId).foregroundStyle(.secondary)
                        }
                        if let s = song {
                            HStack {
                                Text("Última modificación")
                                Spacer()
                                Text(s.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Canción") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Título").font(.caption).foregroundStyle(.secondary)
                            TextField("Nombre de la canción", text: $titleDisplay)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Artista").font(.caption).foregroundStyle(.secondary)
                            TextField("Nombre del artista o banda", text: $artist)
                                .textFieldStyle(.roundedBorder)
                        }
                        Toggle("Es versión en vivo", isOn: $isLive)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Dónde escucharla") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Spotify ID").font(.caption).foregroundStyle(.secondary)
                            TextField("22 caracteres", text: $spotifyId)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                                .autocorrectionDisabled()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YouTube").font(.caption).foregroundStyle(.secondary)
                            TextField("Link del video", text: $youtubeUrl)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                                .autocorrectionDisabled()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas").font(.caption).foregroundStyle(.secondary)
                            TextField("ej: tengo el CD en casa", text: $physicalNotes)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Datos adicionales") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("País")
                            Spacer()
                            Picker("", selection: $country) {
                                Text("Sin especificar").tag("")
                                ForEach(opcionesPais, id: \.id) { opcion in
                                    Text(opcion.label).tag(opcion.id)
                                }
                            }
                            .labelsHidden()
                        }
                        HStack {
                            Text("Idioma")
                            Spacer()
                            Picker("", selection: $language) {
                                Text("Sin especificar").tag("")
                                ForEach(opcionesIdioma, id: \.self) { idioma in
                                    Text(idioma).tag(idioma)
                                }
                            }
                            .labelsHidden()
                        }
                        HStack {
                            Text("Nivel")
                            Spacer()
                            Picker("", selection: $level) {
                                Text("Sin especificar").tag(0)
                                Text("1 — Fácil").tag(1)
                                Text("2 — Calentar").tag(2)
                                Text("3 — Intermedio").tag(3)
                                Text("4 — Difícil").tag(4)
                                Text("5 — Yuca").tag(5)
                            }
                            .labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("BPM")
                                Spacer()
                                TextField("", value: $bpm, format: .number.grouping(.never))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(bpm) },
                                    set: { bpm = Int($0.rounded()) }
                                ),
                                in: 0...300,
                                step: 1
                            )
                        }
                        .help("Tempo de la canción, para el metrónomo. Spotify ya no provee este dato, se ingresa a mano.")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas").font(.caption).foregroundStyle(.secondary)
                            TextField("", text: $notes)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Alias (otros nombres con los que la conoces)") {
                    VStack(alignment: .leading, spacing: 8) {
                        if aliases.isEmpty {
                            Text("Sin alias todavía.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(aliases, id: \.id) { alias in
                            HStack {
                                Text(alias.aliasText)
                                Spacer()
                                Button {
                                    deleteAlias(alias)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        HStack {
                            TextField("Nuevo alias, ej: Hallelujah", text: $newAliasText)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .textInputAutocapitalization(.words)
                                #endif
                            Button("Agregar") {
                                addAlias()
                            }
                            .disabled(newAliasText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Eliminar canción", role: .destructive) {
                    showingDeleteConfirm = true
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }

    // MARK: - Pestaña "Letra y acordes"

    private var contenidoTab: some View {
        Group {
            if modoEdicion {
                SongContentEditorView(
                    attributedText: $editableAttributed,
                    song: song,
                    onSave: guardarContenidoEditado,
                    onCancel: cancelarEdicionContenido
                )
            } else if let contentAST {
                VStack(alignment: .trailing, spacing: 0) {
                    HStack {
                        Button {
                            showingChordReference = true
                        } label: {
                            Label("Acordes", systemImage: "guitars")
                        }
                        .help("Diagramas de los acordes de esta canción")
                        .popover(isPresented: $showingChordReference) {
                            SongChordReferenceView(content: contentAST)
                        }

                        Button {
                            showingMetronome = true
                        } label: {
                            Label("Metrónomo", systemImage: "metronome")
                        }
                        .help(bpm > 0 ? "Metrónomo (\(bpm) BPM)" : "Metrónomo — aún sin BPM, ajústalo aquí mismo")
                        .popover(isPresented: $showingMetronome) {
                            MetronomeView(bpm: Binding(
                                get: { bpm },
                                set: { nuevo in
                                    bpm = nuevo
                                    guardarBPM(nuevo)
                                }
                            ))
                        }

                        Button {
                            showingDisplaySettings = true
                        } label: {
                            Label("Estilo", systemImage: "textformat.size")
                        }
                        .help("Tamaño de letra, espaciado y mayúsculas de esta canción")
                        .popover(isPresented: $showingDisplaySettings) {
                            if let s = song {
                                SongStyleSheetView(
                                    song: Binding(
                                        get: { song ?? s },
                                        set: { song = $0 }
                                    ),
                                    content: contentAST,
                                    onSave: { actualizado in
                                        do {
                                            try repo.update(actualizado)
                                            song = actualizado
                                        } catch {
                                            errorMessage = "No se pudo guardar el estilo."
                                        }
                                    }
                                )
                            }
                        }

                        Button {
                            editableAttributed = NotesImportParser.astToAttributedString(contentAST, fontSize: fontSize, fontFamily: fontFamily)
                            withAnimation { modoEdicion = true }
                        } label: {
                            Label("Editar contenido", systemImage: "pencil")
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .padding([.top, .trailing])

                    ScrollView(.vertical, showsIndicators: true) {
                        ChordChartView(content: contentAST, song: song)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if contentDecodeFailed {
                VStack {
                    Spacer()
                    Label("No se pudo leer el contenido guardado (JSON corrupto o formato inesperado).", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Esta canción no tiene letra ni acordes cargados todavía.")
                        .foregroundStyle(.secondary)
                    Button {
                        editableAttributed = AttributedString()
                        withAnimation { modoEdicion = true }
                    } label: {
                        Label("Crear contenido", systemImage: "plus")
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func guardarContenidoEditado(_ attributed: AttributedString) {
        guard var s = song else { return }
        let textoPlano = String(attributed.characters)
        let notacion = NotesImportParser.detectarNotacion(textoPlano)
        let (secciones, _) = NotesImportParser.parseCuerpo(attributed, notacion: notacion)
        let nuevoAST = ParsedSongContent(sections: secciones, notacionDetectada: notacion)
        do {
            let data = try JSONEncoder().encode(nuevoAST)
            s.contentASTJson = String(data: data, encoding: .utf8)
            try repo.update(s)
            song = s
            contentAST = nuevoAST
            contentDecodeFailed = false
            withAnimation { modoEdicion = false }
            onChanged()
        } catch {
            errorMessage = "No se pudo guardar el contenido editado."
        }
    }

    private func guardarBPM(_ nuevo: Int) {
        guard var s = song else { return }
        s.bpm = nuevo == 0 ? nil : nuevo
        do {
            try repo.update(s)
            song = s
        } catch {
            errorMessage = "No se pudo guardar el BPM."
        }
    }

    private func cancelarEdicionContenido() {
        editableAttributed = AttributedString()
        withAnimation { modoEdicion = false }
    }

    private func load() {
        do {
            guard let s = try repo.fetchById(songId) else {
                errorMessage = "No se encontró la canción."
                return
            }
            song = s
            titleDisplay = s.titleDisplay
            artist = s.artist
            spotifyId = s.spotifyId ?? ""
            youtubeUrl = s.youtubeUrl ?? ""
            physicalNotes = s.physicalNotes ?? ""
            country = s.country ?? ""
            language = s.language ?? ""
            isLive = s.isLive
            level = s.level ?? 0
            bpm = s.bpm ?? 0
            notes = s.notes ?? ""
            decodeContentAST(from: s)
        } catch {
            errorMessage = "No se pudo cargar la canción."
        }
    }

    private func decodeContentAST(from s: Song) {
        guard let json = s.contentASTJson, let data = json.data(using: .utf8) else {
            contentAST = nil
            contentDecodeFailed = false
            return
        }
        if let decoded = try? JSONDecoder().decode(ParsedSongContent.self, from: data) {
            contentAST = decoded
            contentDecodeFailed = false
        } else {
            contentAST = nil
            contentDecodeFailed = true
        }
    }

    private func loadAliases() {
        do {
            aliases = try aliasRepo.fetchBySong(songId)
        } catch {
            errorMessage = "No se pudieron cargar los alias."
        }
    }

    private func addAlias() {
        let text = newAliasText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        do {
            try aliasRepo.create(songId: songId, aliasText: text, by: "manual")
            newAliasText = ""
            loadAliases()
        } catch SongAliasError.conflict(_, let existingTitle) {
            errorMessage = "Ese alias ya pertenece a '\(existingTitle)'. Escribe uno distinto."
        } catch {
            errorMessage = "No se pudo agregar el alias."
        }
    }

    private func deleteAlias(_ alias: SongAlias) {
        do {
            try aliasRepo.softDelete(id: alias.id, by: "manual")
            loadAliases()
        } catch {
            errorMessage = "No se pudo eliminar el alias."
        }
    }

    private func save() {
        guard var s = song else { return }
        s.titleDisplay = titleDisplay.trimmingCharacters(in: .whitespaces)
        s.artist = artist.trimmingCharacters(in: .whitespaces)
        s.spotifyId = spotifyId.trimmingCharacters(in: .whitespaces).isEmpty ? nil : spotifyId
        s.youtubeUrl = youtubeUrl.trimmingCharacters(in: .whitespaces).isEmpty ? nil : youtubeUrl
        s.physicalNotes = physicalNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : physicalNotes
        s.country = country.trimmingCharacters(in: .whitespaces).isEmpty ? nil : country
        s.language = language.trimmingCharacters(in: .whitespaces).isEmpty ? nil : language
        s.isLive = isLive
        s.level = level == 0 ? nil : level
        s.bpm = bpm == 0 ? nil : bpm
        s.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes
        do {
            try repo.update(s)
            song = s
            onChanged()
        } catch {
            errorMessage = "No se pudo guardar los cambios."
        }
    }

    private func delete() {
        do {
            try repo.softDelete(id: songId, by: "manual")
            onDeleted()
        } catch {
            errorMessage = "No se pudo eliminar."
        }
    }
}
