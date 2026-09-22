//
//  ImportarSetlistCSVView.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 22/09/2026
//
//  Fase 5: el CSV es un BUSCARV contra la biblioteca existente, nunca crea
//  canciones nuevas. Formatos reales soportados (detectados por el
//  separador del encabezado):
//    crudo:      Bloque;Orden;Canción;Artista;País;Versión
//    enriquecido: Bloque,Orden,Canción,Artista,...,Tonalidad,...,ID Spotify,...
//  "Orden" puede ser numérico o "AUX" (canción extra, va al final del bloque).
import SwiftUI
import UniformTypeIdentifiers

struct FilaCSVSetlist: Identifiable {
    let id = UUID()
    let bloque: String
    let orden: String
    let titulo: String
    let artista: String
    let tono: String?
    let spotifyId: String?
    let esEnVivo: Bool
    let duracionSeg: Int?
    var songIdElegido: String?
    var candidato: Song?
    var confianza: Double

    var estado: EstadoMatch {
        if songIdElegido != nil { return .confirmado }
        if candidato != nil { return .porConfirmar }
        return .sinMatch
    }
}

enum EstadoMatch {
    case confirmado, porConfirmar, sinMatch
}

struct ImportarSetlistCSVView: View {
    var onCreado: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mostrandoSelector = false
    @State private var filas: [FilaCSVSetlist] = []
    @State private var nombreSetlist = ""
    @State private var errorMessage: String?
    @State private var filaParaElegirCancion: FilaCSVSetlist.ID?
    @State private var sugerenciasNombre: [String] = []

    private let songRepo = SongRepository()
    private let setlistRepo = SetlistRepository()

    private var bloquesEnOrden: [String] {
        var vistos: [String] = []
        for fila in filas where !vistos.contains(fila.bloque) {
            vistos.append(fila.bloque)
        }
        return vistos
    }

    private var confirmadas: Int {
        filas.filter { $0.estado == .confirmado }.count
    }

    private var sugeridasSinConfirmar: Int {
        filas.filter { $0.estado == .porConfirmar }.count
    }

    private var sinEncontrar: Int {
        filas.filter { $0.estado == .sinMatch }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Importar setlist desde CSV")

            if filas.isEmpty {
                ContentUnavailableView {
                    Label("Elegí un archivo CSV", systemImage: "square.and.arrow.down.on.square")
                } description: {
                    Text("Bloque, Orden, Canción, Artista — el mismo que genera tu herramienta de Spotify. Solo hace match contra tu biblioteca, no crea canciones nuevas.")
                } actions: {
                    Button("Elegir archivo…") { mostrandoSelector = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Ponele un nombre a este setlist", text: $nombreSetlist)
                        .textFieldStyle(.roundedBorder)
                    if !sugerenciasNombre.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(sugerenciasNombre, id: \.self) { sugerencia in
                                Button(sugerencia) { nombreSetlist = sugerencia }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                .padding()
                .onAppear { cargarSugerenciasNombre() }

                List {
                    ForEach(bloquesEnOrden, id: \.self) { bloque in
                        Section(bloque) {
                            ForEach(filas.filter { $0.bloque == bloque }) { fila in
                                filaVista(fila)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if sugeridasSinConfirmar > 0 {
                        HStack {
                            Text("\(sugeridasSinConfirmar) sugeridas sin confirmar — si creás ahora, esas quedan afuera")
                                .font(.caption)
                                .foregroundStyle(Color.orange)
                            Spacer()
                            Button("Confirmar todas las sugeridas") { confirmarTodasLasSugeridas() }
                                .buttonStyle(.bordered)
                        }
                    }
                    if sinEncontrar > 0 {
                        Text("\(sinEncontrar) no se encontraron en la biblioteca — se omiten al crear")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    if nombreSetlist.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Falta ponerle nombre al setlist para poder crearlo")
                            .font(.caption)
                            .foregroundStyle(Color.red)
                    }
                    HStack {
                        Text("\(confirmadas) de \(filas.count) canciones listas")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Button("Cancelar") { dismiss() }
                        Button("Crear setlist") { crearSetlist() }
                            .buttonStyle(.borderedProminent)
                            .disabled(nombreSetlist.trimmingCharacters(in: .whitespaces).isEmpty || confirmadas == 0)
                    }
                }
                .padding()
            }
        }
        .frame(width: 560, height: 620)
        .fileImporter(
            isPresented: $mostrandoSelector,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { resultado in
            switch resultado {
            case .success(let url): cargarArchivo(url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: Binding(
            get: { filaParaElegirCancion != nil },
            set: { mostrando in if !mostrando { filaParaElegirCancion = nil } }
        )) {
            if let idFila = filaParaElegirCancion, let indice = filas.firstIndex(where: { $0.id == idFila }) {
                ElegirCancionParaFilaView(
                    tituloBuscado: filas[indice].titulo,
                    onElegida: { song in
                        filas[indice].candidato = song
                        filas[indice].songIdElegido = song.id
                        filas[indice].confianza = 1.0
                        filaParaElegirCancion = nil
                    }
                )
            }
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

    @ViewBuilder
    private func filaVista(_ fila: FilaCSVSetlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(fila.orden). \(fila.titulo)")
                    .fontWeight(.medium)
                Text(filaSubtitulo(fila))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            switch fila.estado {
            case .confirmado:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            case .porConfirmar:
                Button {
                    if let indice = filas.firstIndex(where: { $0.id == fila.id }) {
                        filas[indice].songIdElegido = filas[indice].candidato?.id
                    }
                } label: {
                    Label("¿\(fila.candidato?.titleDisplay ?? "")?", systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .foregroundStyle(Color.orange)
            case .sinMatch:
                Button("Buscar…") { filaParaElegirCancion = fila.id }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func filaSubtitulo(_ fila: FilaCSVSetlist) -> String {
        var partes = [fila.artista]
        if let tono = fila.tono, !tono.isEmpty, tono.localizedCaseInsensitiveCompare("Desconocida") != .orderedSame {
            partes.append(tono)
        }
        if fila.esEnVivo { partes.append("Vivo") }
        return partes.joined(separator: " · ")
    }

    /// "Hoy + lugar más repetido de tu historial" — ej. si siempre tocás en
    /// "Diagonal", sugiere "22/09 Diagonal" directo.
    private func cargarSugerenciasNombre() {
        guard sugerenciasNombre.isEmpty else { return }
        let lugares = (try? setlistRepo.lugaresFrecuentes(limite: 3)) ?? []
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        let hoy = formatter.string(from: Date())
        sugerenciasNombre = lugares.map { "\(hoy) \($0)" }
    }

    private func confirmarTodasLasSugeridas() {
        for indice in filas.indices where filas[indice].estado == .porConfirmar {
            filas[indice].songIdElegido = filas[indice].candidato?.id
        }
    }

    private func cargarArchivo(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "No se pudo abrir el archivo."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let contenido = try leerTextoConEncodingDetectado(url)
            let parseadas = ParserCSVSetlist.parsear(contenido)
            guard !parseadas.isEmpty else {
                errorMessage = "El archivo no tiene filas reconocibles (se esperan columnas Bloque, Orden, Canción, Artista)."
                return
            }
            filas = try emparejarConBiblioteca(parseadas)
        } catch {
            errorMessage = "No se pudo leer el archivo: \(error.localizedDescription)"
        }
    }

    private func leerTextoConEncodingDetectado(_ url: URL) throws -> String {
        if let texto = try? String(contentsOf: url, encoding: .utf8) { return texto }
        let datos = try Data(contentsOf: url)
        if let texto = String(data: datos, encoding: .isoLatin1) { return texto }
        return String(decoding: datos, as: UTF8.self)
    }

    private func emparejarConBiblioteca(_ parseadas: [ParserCSVSetlist.Fila]) throws -> [FilaCSVSetlist] {
        let biblioteca = try songRepo.fetchAllActive()
        return parseadas.map { cruda in
            func fila(songId: String?, candidato: Song?, confianza: Double) -> FilaCSVSetlist {
                FilaCSVSetlist(
                    bloque: cruda.bloque, orden: cruda.orden, titulo: cruda.titulo,
                    artista: cruda.artista, tono: cruda.tono, spotifyId: cruda.spotifyId,
                    esEnVivo: cruda.esEnVivo, duracionSeg: cruda.duracionSeg,
                    songIdElegido: songId, candidato: candidato, confianza: confianza
                )
            }

            let matchKey = normalizeForMatching("\(cruda.titulo) \(cruda.artista)")
            if let exacto = biblioteca.first(where: { $0.matchKey == matchKey }) {
                return fila(songId: exacto.id, candidato: exacto, confianza: 1.0)
            }
            if let spotifyId = cruda.spotifyId, let porSpotify = biblioteca.first(where: { $0.spotifyId == spotifyId }) {
                return fila(songId: porSpotify.id, candidato: porSpotify, confianza: 1.0)
            }
            // Popurrí/mix: el título buscado puede estar CONTENIDO en una
            // canción más larga de la biblioteca ("Mix de Hits" incluye
            // varios temas). Se busca por mismo artista primero, como pidió
            // el usuario, para no matchear un título corto contra cualquier
            // canción de cualquier artista que lo contenga.
            let artistaObjetivo = normalizeForMatching(cruda.artista)
            let tituloObjetivo = normalizeForMatching(cruda.titulo)
            if let porMix = biblioteca.first(where: {
                normalizeForMatching($0.artist) == artistaObjetivo
                    && $0.titleDisplay.count > cruda.titulo.count
                    && normalizeForMatching($0.titleDisplay).contains(tituloObjetivo)
            }) {
                return fila(songId: nil, candidato: porMix, confianza: 0.85)
            }
            let (mejor, score) = mejorCandidatoFuzzy(titulo: cruda.titulo, artista: cruda.artista, esEnVivo: cruda.esEnVivo, en: biblioteca)
            return fila(songId: nil, candidato: score >= 0.75 ? mejor : nil, confianza: score)
        }
    }

    /// Penaliza (no descarta) un candidato en vivo cuando el CSV no pidió
    /// explícitamente una versión en vivo, y viceversa — evita que un match
    /// "en vivo" se cuele por accidente cuando la lista es de estudio.
    private func mejorCandidatoFuzzy(titulo: String, artista: String, esEnVivo: Bool, en biblioteca: [Song]) -> (Song?, Double) {
        let objetivo = normalizeForMatching("\(titulo) \(artista)")
        var mejor: Song?
        var mejorScore = 0.0
        for song in biblioteca {
            var score = similitudLevenshtein(objetivo, song.matchKey)
            if song.isLive != esEnVivo { score -= 0.15 }
            if score > mejorScore {
                mejorScore = score
                mejor = song
            }
        }
        return (mejor, mejorScore)
    }

    private func crearSetlist() {
        let nombre = nombreSetlist.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        let blockRepo = SetBlockRepository()
        let itemRepo = SetlistItemRepository()
        let setlistRepo = SetlistRepository()
        do {
            let setlist = Setlist(
                id: UUID().uuidString, name: nombre, venue: nil, date: nil, notes: nil,
                createdAt: Date(), updatedAt: Date(), deletedAt: nil, rev: 1, lastEditedBy: "manual"
            )
            try setlistRepo.create(setlist)

            for (indiceBloque, nombreBloque) in bloquesEnOrden.enumerated() {
                let bloque = SetBlock(
                    id: UUID().uuidString, setlistId: setlist.id, name: nombreBloque,
                    position: indiceBloque, createdAt: Date(), updatedAt: Date(),
                    deletedAt: nil, rev: 1, lastEditedBy: "manual"
                )
                try blockRepo.create(bloque)

                let filasDelBloque = filas
                    .filter { $0.bloque == nombreBloque && $0.songIdElegido != nil }
                    .sorted { ordenComparable($0.orden) < ordenComparable($1.orden) }

                for (posicion, fila) in filasDelBloque.enumerated() {
                    guard let songId = fila.songIdElegido else { continue }
                    let tonoLimpio = fila.tono?.trimmingCharacters(in: .whitespaces)
                    let tonoValido = (tonoLimpio?.isEmpty ?? true) || tonoLimpio?.localizedCaseInsensitiveCompare("Desconocida") == .orderedSame
                        ? nil : tonoLimpio
                    let item = SetlistItem(
                        id: UUID().uuidString, blockId: bloque.id, songId: songId, position: posicion,
                        keyOverride: tonoValido, capoOverride: nil, notes: nil,
                        createdAt: Date(), updatedAt: Date(), deletedAt: nil, rev: 1, lastEditedBy: "manual"
                    )
                    try itemRepo.create(item)

                    // Enriquece la canción con la duración del CSV solo si
                    // todavía no la tenía — nunca pisa un dato ya cargado.
                    if let duracion = fila.duracionSeg, var song = fila.candidato, song.durationSec == nil {
                        song.durationSec = duracion
                        try songRepo.update(song)
                    }
                }
            }
            onCreado(setlist.id)
            dismiss()
        } catch {
            errorMessage = "No se pudo crear el setlist."
        }
    }

    /// "AUX" ordena al final del bloque, no antes del 1.
    private func ordenComparable(_ orden: String) -> Int {
        Int(orden) ?? Int.max
    }
}

private func similitudLevenshtein(_ a: String, _ b: String) -> Double {
    if a == b { return 1.0 }
    let ac = Array(a), bc = Array(b)
    let m = ac.count, n = bc.count
    if m == 0 || n == 0 { return 0 }
    var previo = Array(0...n)
    var actual = Array(repeating: 0, count: n + 1)
    for i in 1...m {
        actual[0] = i
        for j in 1...n {
            let costo = ac[i - 1] == bc[j - 1] ? 0 : 1
            actual[j] = min(previo[j] + 1, actual[j - 1] + 1, previo[j - 1] + costo)
        }
        previo = actual
    }
    let distancia = previo[n]
    return 1.0 - (Double(distancia) / Double(max(m, n)))
}

/// Parser tolerante: separador `;` (formato crudo) o `,` (formato
/// enriquecido con Spotify) detectado por el encabezado; columnas
/// identificadas por nombre, no por posición, para no romper si la
/// herramienta de Spotify agrega/reordena columnas.
enum ParserCSVSetlist {
    struct Fila {
        let bloque: String
        let orden: String
        let titulo: String
        let artista: String
        let tono: String?
        let spotifyId: String?
        let esEnVivo: Bool
        let duracionSeg: Int?
    }

    static func parsear(_ contenido: String) -> [Fila] {
        let lineas = contenido
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard let encabezado = lineas.first else { return [] }

        let separador: Character = encabezado.filter { $0 == ";" }.count > encabezado.filter { $0 == "," }.count ? ";" : ","
        let columnas = parsearLinea(encabezado, separador: separador).map { normalizarNombreColumna($0) }

        func indice(de nombres: [String]) -> Int? {
            for nombre in nombres {
                if let i = columnas.firstIndex(of: nombre) { return i }
            }
            return nil
        }

        guard let iBloque = indice(de: ["bloque"]),
              let iOrden = indice(de: ["orden"]),
              let iTitulo = indice(de: ["cancion", "titulo"]),
              let iArtista = indice(de: ["artista", "bandaartista"]) else {
            return []
        }
        let iTono = indice(de: ["tonalidad", "tono"])
        let iSpotify = indice(de: ["idspotify", "spotifyid"])
        let iVersion = indice(de: ["version", "versión"])
        let iDuracion = indice(de: ["duracionhhmmss", "duracion"])

        var resultado: [Fila] = []
        for linea in lineas.dropFirst() {
            let campos = parsearLinea(linea, separador: separador)
            guard campos.count > max(iBloque, iOrden, iTitulo, iArtista) else { continue }
            let titulo = campos[iTitulo].trimmingCharacters(in: .whitespaces)
            let artista = campos[iArtista].trimmingCharacters(in: .whitespaces)
            guard !titulo.isEmpty, !artista.isEmpty else { continue }
            let tono = iTono.flatMap { campos.indices.contains($0) ? campos[$0].trimmingCharacters(in: .whitespaces) : nil }
            var spotifyId = iSpotify.flatMap { campos.indices.contains($0) ? campos[$0].trimmingCharacters(in: .whitespaces) : nil }
            if spotifyId?.isEmpty == true || spotifyId?.localizedCaseInsensitiveCompare("No encontrada") == .orderedSame {
                spotifyId = nil
            }
            let versionTexto = iVersion.flatMap { campos.indices.contains($0) ? campos[$0] : nil } ?? ""
            let esEnVivo = normalizeForMatching(versionTexto).contains("vivo")
                || normalizeForMatching(versionTexto).contains("live")
                || normalizeForMatching(titulo).contains("vivo")
            let duracionTexto = iDuracion.flatMap { campos.indices.contains($0) ? campos[$0].trimmingCharacters(in: .whitespaces) : nil }
            let duracionSeg = duracionTexto.flatMap(segundosDesde)
            resultado.append(Fila(
                bloque: campos[iBloque].trimmingCharacters(in: .whitespaces),
                orden: campos[iOrden].trimmingCharacters(in: .whitespaces),
                titulo: titulo, artista: artista, tono: tono, spotifyId: spotifyId,
                esEnVivo: esEnVivo, duracionSeg: duracionSeg
            ))
        }
        return resultado
    }

    /// "00:03:37" (HH:MM:SS) o "3:37" (MM:SS) → segundos. "00:00:00" se
    /// trata como "no se sabe" (canción no encontrada en Spotify).
    private static func segundosDesde(_ texto: String) -> Int? {
        let partes = texto.split(separator: ":").compactMap { Int($0) }
        let segundos: Int
        switch partes.count {
        case 3: segundos = partes[0] * 3600 + partes[1] * 60 + partes[2]
        case 2: segundos = partes[0] * 60 + partes[1]
        default: return nil
        }
        return segundos > 0 ? segundos : nil
    }

    private static func normalizarNombreColumna(_ nombre: String) -> String {
        normalizeForMatching(nombre).replacingOccurrences(of: " ", with: "")
    }

    /// Soporta comillas dobles para campos con comas (ej: "122,791,003").
    private static func parsearLinea(_ linea: String, separador: Character) -> [String] {
        var campos: [String] = []
        var actual = ""
        var dentroDeComillas = false
        for char in linea {
            if char == "\"" {
                dentroDeComillas.toggle()
            } else if char == separador && !dentroDeComillas {
                campos.append(actual)
                actual = ""
            } else {
                actual.append(char)
            }
        }
        campos.append(actual)
        return campos
    }
}

private struct ElegirCancionParaFilaView: View {
    let tituloBuscado: String
    var onElegida: (Song) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var canciones: [Song] = []

    private let songRepo = SongRepository()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Elegir canción para \"\(tituloBuscado)\"")
            List(canciones, id: \.id) { song in
                Button {
                    onElegida(song)
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
            .onAppear {
                searchText = tituloBuscado
                cargar(query: tituloBuscado)
            }
            HStack {
                Spacer()
                Button("Cerrar sin elegir") { dismiss() }
            }
            .padding()
        }
        .frame(width: 380, height: 480)
    }

    private func cargar(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        canciones = ((try? (trimmed.isEmpty ? songRepo.fetchAllActive() : songRepo.search(trimmed))) ?? [])
            .sorted { $0.titleDisplay.localizedStandardCompare($1.titleDisplay) == .orderedAscending }
    }
}
