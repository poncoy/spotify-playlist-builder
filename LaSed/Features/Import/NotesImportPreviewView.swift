//
//  NotesImportPreviewView.swift
//  LaSed
//
//  Versión: 0.3.2
//  Actualizado: 11/09/2026
//
import SwiftUI
import UniformTypeIdentifiers
import Charts

struct NotesImportPreviewView: View {
    @State private var resultados: [ParsedNoteResult] = []
    @State private var seleccionado: ParsedNoteResult?
    @State private var mostrandoSelectorDeCarpeta = false
    @State private var mensajeError: String?
    @State private var cargando = false
    @State private var importadas: Set<String> = []  // archivoOriginal de las ya importadas en esta sesión
    @State private var procesandoLote = false
    @State private var resumenLote: ResumenLote?
    @State private var ultimoLote: [ItemLoteImportado] = []
    @State private var mostrandoConfirmDeshacer = false
    @State private var resumenDeshacer: ResumenDeshacer?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var mostrandoSeleccionLote = false
    @State private var seleccionLote: Set<String> = []
    @State private var mostrandoResumenMotivos = false

    @Environment(\.dismiss) private var dismiss

    private var totalConRevision: Int {
        resultados.filter(\.requiereRevision).count
    }

    private var listasParaImportar: Int {
        resultados.filter { !$0.requiereRevision }.count
    }

    /// Motivo principal de revisión, agregado por tipo (pedido en este chat:
    /// "no se muestra un resumen de las observaciones y cuál es el motivo
    /// principal"). Cuenta NOTAS con al menos un issue de ese tipo, no
    /// issues sueltos — una nota con 2 avisos del mismo tipo cuenta una vez.
    private var resumenPorMotivo: [(tipo: ImportIssueType, cantidad: Int)] {
        var conteo: [ImportIssueType: Int] = [:]
        for r in resultados where r.requiereRevision {
            for t in Set(r.issues.map(\.type)) {
                conteo[t, default: 0] += 1
            }
        }
        return conteo.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private func nombreMotivo(_ t: ImportIssueType) -> String {
        switch t {
        case .sinAcordesAnclados: return "Acordes sin anclar a la letra"
        case .contenidoPerdido: return "Contenido perdido (imagen/objeto)"
        case .notaVaciaOBasura: return "Nota casi vacía"
        case .notacionAmbigua: return "No se detectaron acordes"
        }
    }

    /// Candidatas al lote: sin revisión pendiente y no importadas aún.
    /// Decisión de este chat: el lote SOLO auto-acepta cuando
    /// ArtistSuggestionService da una sugerencia (ya trae su propio umbral de
    /// 0.6). Sin sugerencia confiable, la nota queda fuera del lote y se
    /// importa a mano por el flujo existente (con el campo editable) — el
    /// lote no inventa un artista a ciegas.
    private var candidatosParaLote: [ParsedNoteResult] {
        resultados.filter { !$0.requiereRevision && !importadas.contains($0.archivoOriginal) }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            listaDeNotas
        } detail: {
            if let r = seleccionado {
                DetalleNotaParseadaView(
                    resultado: r,
                    yaImportada: importadas.contains(r.archivoOriginal),
                    onImportada: { importadas.insert(r.archivoOriginal) }
                )
                .id(r.archivoOriginal)
            } else {
                ContentUnavailableView(
                    "Selecciona una nota",
                    systemImage: "music.note.list",
                    description: Text("Elige una carpeta con los .txt exportados para empezar.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 700, idealWidth: 1100, maxWidth: .infinity, minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Mostrar u ocultar la lista de notas")
            }
        }
        .onAppear {
            cargarUltimaCarpetaSiExiste()
        }
        .sheet(isPresented: $mostrandoSeleccionLote) {
            SeleccionLoteView(
                candidatas: candidatosParaLote,
                seleccion: $seleccionLote,
                onConfirmar: {
                    let elegidas = seleccionLote
                    mostrandoSeleccionLote = false
                    importarLote(soloArchivos: elegidas)
                },
                onCancelar: { mostrandoSeleccionLote = false },
                onAbrirNota: { r in
                    mostrandoSeleccionLote = false
                    seleccionado = r
                }
            )
        }
        .fileImporter(
            isPresented: $mostrandoSelectorDeCarpeta,
            allowedContentTypes: [.folder]
        ) { resultado in
            switch resultado {
            case .success(let url):
                guardarBookmark(url)
                cargarCarpeta(url)
            case .failure(let error):
                mensajeError = error.localizedDescription
            }
        }
        .alert("Error", isPresented: Binding(
            get: { mensajeError != nil },
            set: { if !$0 { mensajeError = nil } }
        )) {
            Button("OK") { mensajeError = nil }
        } message: {
            Text(mensajeError ?? "")
        }
        .sheet(item: $resumenLote) { resumen in
            ResumenLoteView(resumen: resumen)
        }
        .confirmationDialog(
            "¿Deshacer el último lote?",
            isPresented: $mostrandoConfirmDeshacer,
            titleVisibility: .visible
        ) {
            Button("Deshacer \(ultimoLote.count) canción(es)", role: .destructive) { deshacerUltimoLote() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se marcan como borradas (soft delete), igual que borrar una canción a mano — no hay pantalla para recuperarlas después.")
        }
        .sheet(item: $resumenDeshacer) { resumen in
            ResumenDeshacerView(resumen: resumen)
        }
    }

    private var listaDeNotas: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Importador de notas")
            List(resultados, id: \.archivoOriginal, selection: $seleccionado) { r in
            HStack {
                Image(systemName: iconoPara(r))
                    .foregroundStyle(colorPara(r))
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.tituloLimpio)
                    if r.requiereRevision {
                        Text("\(r.issues.count) aviso(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tag(r)
        }
        .navigationTitle("Notas (\(resultados.count))")
        .overlay {
            if cargando {
                ProgressView("Procesando notas...")
            } else if procesandoLote {
                ProgressView("Importando lote...")
            } else if resultados.isEmpty {
                ContentUnavailableView(
                    "Sin notas cargadas",
                    systemImage: "folder",
                    description: Text("Elige la carpeta LaSed_Notas_Export")
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Elegir carpeta...") { mostrandoSelectorDeCarpeta = true }
            }
            ToolbarItem {
                Button("Importar lote (\(candidatosParaLote.count))") {
                    seleccionLote = Set(candidatosParaLote.map(\.archivoOriginal))
                    mostrandoSeleccionLote = true
                }
                .disabled(candidatosParaLote.isEmpty || procesandoLote)
            }
            if !ultimoLote.isEmpty {
                ToolbarItem {
                    Button("Deshacer lote (\(ultimoLote.count))", role: .destructive) {
                        mostrandoConfirmDeshacer = true
                    }
                    .disabled(procesandoLote)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !resultados.isEmpty {
                HStack {
                    Text("\(totalConRevision) requieren revisión · \(listasParaImportar) listas para importar · \(importadas.count) importadas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        mostrandoResumenMotivos = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $mostrandoResumenMotivos) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Motivo de las \(totalConRevision) que requieren revisión")
                                .font(.headline)
                            if resumenPorMotivo.isEmpty {
                                Text("Ninguna requiere revisión.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(resumenPorMotivo, id: \.tipo) { item in
                                    HStack {
                                        Text(nombreMotivo(item.tipo))
                                        Spacer()
                                        Text("\(item.cantidad)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(minWidth: 280)
                    }
                    Spacer()
                }
                .padding(8)
                .background(.bar)
            }
        }
        }
    }

    /// Fix real (reportado en este chat): el ícono "circle" (vacío) para
    /// notas listas-sin-avisos se confundía con un checkbox seleccionable.
    /// Cambiado a "music.note" — no se parece a ningún control interactivo
    /// real de macOS, así que no invita a tocarlo.
    private func iconoPara(_ r: ParsedNoteResult) -> String {
        if importadas.contains(r.archivoOriginal) { return "checkmark.circle.fill" }
        return r.requiereRevision ? "exclamationmark.triangle.fill" : "music.note"
    }

    private func colorPara(_ r: ParsedNoteResult) -> Color {
        if importadas.contains(r.archivoOriginal) { return .green }
        return r.requiereRevision ? .orange : .secondary
    }

    private func cargarCarpeta(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            mensajeError = "No se pudo acceder a la carpeta. Intenta elegirla de nuevo."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        cargando = true
        defer { cargando = false }

        do {
            let archivos = try FileManager.default
                .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "txt" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            if archivos.isEmpty {
                mensajeError = "No se encontraron archivos .txt en esa carpeta."
                return
            }

            var nuevos: [ParsedNoteResult] = []
            for archivo in archivos {
                let contenido = try String(contentsOf: archivo, encoding: .utf8)
                let resultado = NotesImportParser.parse(rawText: contenido, fileName: archivo.lastPathComponent)
                nuevos.append(resultado)
            }
            // Orden pedido: primero las que requieren revisión (para atacarlas
            // de una vez), luego las que no; alfabético dentro de cada grupo.
            // Antes quedaban en orden de archivo (001_, 002_...), sin relación
            // con el contenido.
            nuevos.sort { a, b in
                if a.requiereRevision != b.requiereRevision {
                    return a.requiereRevision && !b.requiereRevision
                }
                return a.tituloLimpio.localizedStandardCompare(b.tituloLimpio) == .orderedAscending
            }
            resultados = nuevos
        } catch {
            mensajeError = "Error leyendo la carpeta: \(error.localizedDescription)"
        }
    }

    // MARK: - Recordar última carpeta (bookmark de seguridad, sobrevive a reabrir la app)

    private static let ultimaCarpetaKey = "com.poncoy.lased.ultimaCarpetaImportadorBookmark"

    private func guardarBookmark(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.ultimaCarpetaKey)
        } catch {
            // No es crítico: si falla el guardado, simplemente no se recuerda
            // la próxima vez, pero la carpeta recién elegida ya se cargó igual.
            print("⚠️ No se pudo guardar bookmark de carpeta: \(error.localizedDescription)")
        }
    }

    private func cargarUltimaCarpetaSiExiste() {
        guard resultados.isEmpty, let bookmark = UserDefaults.standard.data(forKey: Self.ultimaCarpetaKey) else { return }
        do {
            var esObsoleto = false
            let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &esObsoleto)
            cargarCarpeta(url)
            if esObsoleto {
                guardarBookmark(url)
            }
        } catch {
            // La carpeta pudo moverse o borrarse desde la última vez — no es
            // grave, solo se deja de auto-cargar y se limpia la referencia vieja.
            UserDefaults.standard.removeObject(forKey: Self.ultimaCarpetaKey)
        }
    }

    /// Importa en lote todas las candidatas (sin revisión, con sugerencia de
    /// artista confiable). Nunca crea duplicados por matchKey; nunca inventa
    /// artista sin sugerencia — esas quedan para el flujo manual existente.
    private func importarLote(soloArchivos: Set<String>) {
        procesandoLote = true
        defer { procesandoLote = false }

        let candidatas = candidatosParaLote.filter { soloArchivos.contains($0.archivoOriginal) }

        let repo = SongRepository()
        var importadasCount = 0
        var duplicados: [(titulo: String, artista: String)] = []
        var sinArtista: [String] = []
        var errores: [(titulo: String, artista: String, detalle: String)] = []
        var nuevosDeEsteLote: [ItemLoteImportado] = []

        for r in candidatas {
            guard let sugerencia = ArtistSuggestionService.shared.sugerirArtista(paraTitulo: r.tituloLimpio),
                  sugerencia.artistaAlternativo == nil else {
                // Sin sugerencia O ambigua (2 artistas casi empatados) —
                // en ambos casos el lote no adivina, queda para el flujo manual.
                sinArtista.append(r.tituloLimpio)
                continue
            }

            let clave = normalizeForMatching("\(r.tituloLimpio) \(sugerencia.artista)")
            do {
                if try repo.fetchByMatchKey(clave) != nil {
                    duplicados.append((r.tituloLimpio, sugerencia.artista))
                    continue
                }

                let codigo = try repo.suggestNextCode()
                let jsonData = try JSONEncoder().encode(r.contentAST)
                let jsonTexto = String(data: jsonData, encoding: .utf8)

                try repo.create(Song(
                    id: codigo,
                    spotifyId: nil,
                    titleDisplay: r.tituloLimpio,
                    titleSpotify: nil,
                    artist: sugerencia.artista,
                    matchKey: "",
                    isLive: sugerencia.pareceEnVivo,
                    originalKey: nil,
                    durationSec: nil,
                    country: r.banderaPaisDetectada,
                    language: nil,
                    level: nil,
                    notes: "Importado en lote desde Apple Notes",
                    createdAt: Date(),
                    updatedAt: Date(),
                    deletedAt: nil,
                    rev: 1,
                    lastEditedBy: "importador_notes_lote",
                    youtubeUrl: nil,
                    physicalNotes: nil,
                    contentASTJson: jsonTexto
                ))
                importadas.insert(r.archivoOriginal)
                importadasCount += 1
                nuevosDeEsteLote.append(ItemLoteImportado(archivoOriginal: r.archivoOriginal, codigo: codigo, titulo: r.tituloLimpio))
            } catch {
                errores.append((r.tituloLimpio, sugerencia.artista, error.localizedDescription))
            }
        }

        // Solo reemplaza la referencia de "último lote" si este corrido
        // realmente creó algo — así un segundo lote vacío (todo duplicado o
        // sin artista) no te hace perder el "Deshacer" del lote anterior.
        if !nuevosDeEsteLote.isEmpty {
            ultimoLote = nuevosDeEsteLote
        }

        resumenLote = ResumenLote(importadas: importadasCount, duplicados: duplicados, sinArtista: sinArtista, errores: errores)
    }

    /// Deshace el último lote (no acumulativo): soft-delete de cada canción
    /// creada en esa corrida, vía el mismo softDelete() que usa EditSongView
    /// — nunca DELETE físico, respeta la decisión de tombstone del proyecto.
    private func deshacerUltimoLote() {
        let repo = SongRepository()
        var deshechas: [(codigo: String, titulo: String)] = []
        var errores: [(codigo: String, titulo: String, detalle: String)] = []

        for item in ultimoLote {
            do {
                try repo.softDelete(id: item.codigo, by: "importador_notes_lote_undo")
                importadas.remove(item.archivoOriginal)
                deshechas.append((item.codigo, item.titulo))
            } catch {
                errores.append((item.codigo, item.titulo, error.localizedDescription))
            }
        }

        ultimoLote = []
        resumenDeshacer = ResumenDeshacer(deshechas: deshechas, errores: errores)
    }
}

private struct ItemLoteImportado {
    let archivoOriginal: String
    let codigo: String
    let titulo: String
}

/// Resultado de deshacer un lote — mismo criterio que ResumenLote: antes era
/// un solo párrafo de texto en un .alert() ("115 deshecha(s). 2 con error:
/// LS-0231: ..., LS-0245: ..."), ilegible con más de unos pocos items. Ahora
/// es una lista real vía .sheet(item:).
private struct ResumenDeshacer: Identifiable {
    let id = UUID()
    var deshechas: [(codigo: String, titulo: String)]
    var errores: [(codigo: String, titulo: String, detalle: String)]
}

private struct ResumenDeshacerView: View {
    let resumen: ResumenDeshacer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Lote deshecho")
                    .font(.headline)
                Spacer()
                Button("Cerrar") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: resumen.deshechas.isEmpty ? "info.circle" : "arrow.uturn.backward.circle.fill")
                            .foregroundStyle(resumen.deshechas.isEmpty ? Color.secondary : Color.green)
                        Text(resumen.deshechas.isEmpty
                             ? "No se deshizo ninguna canción"
                             : "\(resumen.deshechas.count) canción(es) deshecha(s)")
                            .font(.title3)
                            .bold()
                    }

                    if !resumen.deshechas.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(resumen.deshechas, id: \.codigo) { item in
                                Text("\(item.titulo) (\(item.codigo))")
                                    .font(.callout)
                            }
                        }
                    }

                    if !resumen.errores.isEmpty {
                        Divider()
                        Label("Con error (\(resumen.errores.count))", systemImage: "xmark.octagon")
                            .font(.headline)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(resumen.errores, id: \.codigo) { item in
                                Text("\(item.titulo) (\(item.codigo)) — \(item.detalle)")
                                    .font(.callout)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 320, idealHeight: 480)
    }
}

/// Resumen mostrado tras correr el lote. Ninguna categoría se omite —
/// importar en silencio está prohibido desde Fase 0 — pero ya NO se muestra
/// como .alert(): con 100+ nombres en un solo párrafo era ilegible ("mensaje
/// cochinado", reportado). Ahora es Identifiable para presentarse como
/// .sheet(item:) con ResumenLoteView, una lista real con scroll.
private struct ResumenLote: Identifiable {
    let id = UUID()
    var importadas: Int
    var duplicados: [(titulo: String, artista: String)]
    var sinArtista: [String]
    var errores: [(titulo: String, artista: String, detalle: String)]
}

/// Pantalla de resultado del lote — reemplaza el .alert() de texto corrido.
/// Cada categoría es una lista real (una canción por línea), no un párrafo de
/// nombres separados por comas.
private struct ResumenLoteView: View {
    let resumen: ResumenLote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Resultado de la importación")
                    .font(.headline)
                Spacer()
                Button("Cerrar") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: resumen.importadas > 0 ? "checkmark.circle.fill" : "info.circle")
                            .foregroundStyle(resumen.importadas > 0 ? .green : .secondary)
                        Text(resumen.importadas > 0
                             ? "\(resumen.importadas) canción(es) importada(s)"
                             : "No se importó ninguna canción nueva")
                            .font(.title3)
                            .bold()
                    }

                    if !resumen.duplicados.isEmpty {
                        grupoAgrupado(
                            titulo: "Ya estaban en tu biblioteca",
                            cantidad: resumen.duplicados.count,
                            detalle: "Mismo título y artista — no se tocaron.",
                            grupos: agrupadoPorArtista(resumen.duplicados.map { ($0.titulo, $0.artista) }),
                            color: .secondary,
                            icono: "checkmark.circle"
                        )
                    }
                    if !resumen.sinArtista.isEmpty {
                        grupoSimple(
                            titulo: "Sin sugerencia de artista",
                            cantidad: resumen.sinArtista.count,
                            detalle: "Quedan para importar una por una, con el campo editable.",
                            items: resumen.sinArtista.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                            color: .orange,
                            icono: "exclamationmark.triangle"
                        )
                    }
                    if !resumen.errores.isEmpty {
                        grupoAgrupado(
                            titulo: "Con error al guardar",
                            cantidad: resumen.errores.count,
                            detalle: nil,
                            grupos: agrupadoPorArtista(resumen.errores.map { ("\($0.titulo) — \($0.detalle)", $0.artista) }),
                            color: .red,
                            icono: "xmark.octagon"
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 620)
    }

    /// Agrupa por artista y ordena alfabéticamente artista Y canción dentro
    /// de cada grupo (pedido de este chat).
    private func agrupadoPorArtista(_ items: [(titulo: String, artista: String)]) -> [(artista: String, titulos: [String])] {
        let agrupado = Dictionary(grouping: items) { $0.artista }
        return agrupado.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { artista in
                (artista, agrupado[artista]!.map { $0.titulo }.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
            }
    }

    @ViewBuilder
    private func grupoAgrupado(titulo: String, cantidad: Int, detalle: String?, grupos: [(artista: String, titulos: [String])], color: Color, icono: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(titulo) (\(cantidad))", systemImage: icono)
                .font(.headline)
                .foregroundStyle(color)
            if let detalle {
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(grupos, id: \.artista) { grupo in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grupo.artista)
                            .font(.subheadline.bold())
                        ForEach(grupo.titulos, id: \.self) { t in
                            Text(t)
                                .font(.callout)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .padding(.leading, 12)
        }
        Divider()
    }

    @ViewBuilder
    private func grupoSimple(titulo: String, cantidad: Int, detalle: String?, items: [String], color: Color, icono: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(titulo) (\(cantidad))", systemImage: icono)
                .font(.headline)
                .foregroundStyle(color)
            if let detalle {
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.callout)
                }
            }
            .padding(.leading, 12)
        }
        Divider()
    }
}

/// Pantalla de selección previa al lote — pedido explícito del usuario:
/// "no hay confirmación previa donde se puede seleccionar cuáles se
/// importan". Todo empieza marcado (comportamiento previo, todo-o-nada,
/// sigue disponible con un clic en "Todas"), pero ahora se puede desmarcar
/// nota por nota antes de tocar la base de datos. Las notas sin sugerencia
/// de artista aparecen atenuadas y no se pueden marcar — no hay forma de
/// forzar un artista que el motor no sugiere desde aquí, eso sigue siendo
/// flujo manual nota por nota.
///
/// CRÍTICO (bug real reportado: ~25s de freeze al tocar un solo checkbox):
/// `sugerirArtista()` hace Levenshtein contra todo el repertorio (~200
/// filas). La primera versión de esta vista lo llamaba desde un computed
/// property (`elegibles`) y directo en el `List`, así que CADA vez que
/// SwiftUI redibujaba (cualquier cambio de `seleccion`) se recalculaban las
/// ~200 sugerencias de nuevo, varias veces por interacción. Ahora se
/// calcula UNA sola vez en `.onAppear` y se guarda en un diccionario — los
/// toggles solo hacen lecturas O(1), nunca vuelven a llamar al servicio.
///
/// Agrupada por artista (pedido de este chat): marcar/desmarcar el grupo
/// completo con un toque, en vez de canción por canción cuando son del
/// mismo artista. "Todas"/"Ninguna" (global) se sacaron del toolbar del
/// NavigationStack — con placement .principal dentro de un .sheet no se
/// estaban viendo — y ahora son una fila fija en el cuerpo, siempre visible.
private struct SeleccionLoteView: View {
    let candidatas: [ParsedNoteResult]
    @Binding var seleccion: Set<String>
    var onConfirmar: () -> Void
    var onCancelar: () -> Void
    var onAbrirNota: (ParsedNoteResult) -> Void

    @State private var sugerencias: [String: SugerenciaArtista] = [:]  // archivoOriginal -> sugerencia, calculado una sola vez
    @State private var ambiguas: [String: SugerenciaArtista] = [:]  // archivoOriginal -> sugerencia CON artistaAlternativo (2 artistas casi empatados, no se auto-elige)
    @State private var elegiblesIds: [String] = []  // archivoOriginal de las que sí tienen sugerencia
    @State private var calculando = true
    @State private var textoBusqueda = ""

    private var seleccionValida: Set<String> {
        seleccion.intersection(elegiblesIds)
    }

    /// Filtra por título o artista cuando hay texto de búsqueda. Pedido en
    /// este chat: con 118+ candidatas repartidas en 70+ artistas, no había
    /// forma de encontrar una en particular sin scrollear a mano.
    private func coincideConBusqueda(_ r: ParsedNoteResult, artista: String) -> Bool {
        guard !textoBusqueda.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let query = textoBusqueda.localizedLowercase
        return r.tituloLimpio.localizedLowercase.contains(query) || artista.localizedLowercase.contains(query)
    }

    private var gruposPorArtista: [(artista: String, notas: [ParsedNoteResult])] {
        let elegibles = candidatas.filter { sugerencias[$0.archivoOriginal] != nil }
        let agrupado = Dictionary(grouping: elegibles) { sugerencias[$0.archivoOriginal]!.artista }
        return agrupado.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .compactMap { artista -> (artista: String, notas: [ParsedNoteResult])? in
                let notas = agrupado[artista]!
                    .filter { coincideConBusqueda($0, artista: artista) }
                    .sorted { $0.tituloLimpio.localizedStandardCompare($1.tituloLimpio) == .orderedAscending }
                return notas.isEmpty ? nil : (artista, notas)
            }
    }

    private var sinSugerencia: [ParsedNoteResult] {
        candidatas
            .filter { sugerencias[$0.archivoOriginal] == nil && ambiguas[$0.archivoOriginal] == nil }
            .filter { coincideConBusqueda($0, artista: "") }
            .sorted { $0.tituloLimpio.localizedStandardCompare($1.tituloLimpio) == .orderedAscending }
    }

    /// Distinto de "sin sugerencia": aquí SÍ hubo sugerencia, pero 2 artistas
    /// distintos casi empataron (ver ArtistSuggestionService.artistaAlternativo).
    /// Nunca se mezcla con "sin sugerencia" — el motivo y el mensaje al
    /// usuario son distintos (pedido: "no se entiende, ¿dónde aparte?").
    private var ambiguasOrdenadas: [ParsedNoteResult] {
        candidatas
            .filter { ambiguas[$0.archivoOriginal] != nil }
            .filter { r in
                let s = ambiguas[r.archivoOriginal]!
                return coincideConBusqueda(r, artista: "\(s.artista) \(s.artistaAlternativo?.artista ?? "")")
            }
            .sorted { $0.tituloLimpio.localizedStandardCompare($1.tituloLimpio) == .orderedAscending }
    }

    /// Vista previa ejecutiva pedida en este chat. OJO: "bandera de país" no
/// es lo mismo que idioma — es la única señal que existe en los datos
    /// (`banderaPaisDetectada`), y en la mayoría de tus notas SI correlaciona
    /// con el idioma real de la letra, pero no es un campo verificado. Se
    /// muestra igual porque aproxima bien, pero etiquetado como tal.
    private struct ConteoBarra: Identifiable {
        let id: String
        let etiqueta: String
        let cantidad: Int
    }

    private var conteoPorArtista: [ConteoBarra] {
        gruposPorArtista
            .map { ConteoBarra(id: $0.artista, etiqueta: $0.artista, cantidad: $0.notas.count) }
            .sorted { $0.cantidad > $1.cantidad }
    }

    /// Mapeo bandera -> idioma, a mano, cubre las banderas que aparecen en tu
    /// repertorio real (sección 5 del triage de Fase 2b). Es una aproximación
    /// deliberada, no un dato verificado: hay excepciones reales (ej. "Life
    /// is Life" tiene partes en alemán y en inglés, la bandera solo marca el
    /// origen del artista). Cualquier bandera no listada cae en "Otro / sin
    /// identificar" en vez de adivinar.
    private static let idiomaPorBandera: [String: String] = [
        "🇺🇸": "Inglés", "🇬🇧": "Inglés", "🇦🇺": "Inglés",
        "🇯🇲": "Inglés", "🇳🇴": "Inglés",
        "🇦🇷": "Español", "🇪🇸": "Español", "🇵🇪": "Español",
        "🇨🇴": "Español", "🇲🇽": "Español", "🇨🇱": "Español",
        "🇺🇾": "Español", "🇵🇷": "Español",
        "🇮🇹": "Italiano",
        "🇦🇹": "Alemán / otro",
    ]

    private func idiomaAproximado(_ bandera: String?) -> String {
        guard let bandera else { return "Otro / sin identificar" }
        return Self.idiomaPorBandera[bandera] ?? "Otro / sin identificar"
    }

    private var conteoPorIdioma: [ConteoBarra] {
        let elegibles = candidatas.filter { sugerencias[$0.archivoOriginal] != nil }
        let agrupado = Dictionary(grouping: elegibles) { idiomaAproximado($0.banderaPaisDetectada) }
        return agrupado
            .map { ConteoBarra(id: $0.key, etiqueta: $0.key, cantidad: $0.value.count) }
            .sorted { $0.cantidad > $1.cantidad }
    }

    /// Encerrado en una altura FIJA con su propio scroll interno. Antes esto
    /// no tenía límite y con 67 artistas + 15 banderas empujaba la lista de
    /// abajo fuera del área visible del sheet ("no se ve la lista, solo el
    /// gráfico" reportado). Ahora nunca puede pasar de 240pt sin importar
    /// cuántos artistas o idiomas haya.
    private var resumenVisual: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vista previa por artista y por idioma aproximado (por bandera detectada, no es un dato verificado)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                let topArtistas = Array(conteoPorArtista.prefix(6))
                Chart(topArtistas) { item in
                    BarMark(
                        x: .value("Canciones", item.cantidad),
                        y: .value("Artista", item.etiqueta)
                    )
                    .annotation(position: .trailing) {
                        Text("\(item.cantidad)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(topArtistas.count) * 20 + 16)
                if conteoPorArtista.count > topArtistas.count {
                    Text("+ \(conteoPorArtista.count - topArtistas.count) artista(s) más con menos temas")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Chart(conteoPorIdioma) { item in
                    BarMark(
                        x: .value("Canciones", item.cantidad),
                        y: .value("Idioma", item.etiqueta)
                    )
                    .annotation(position: .trailing) {
                        Text("\(item.cantidad)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(conteoPorIdioma.count) * 20 + 16)
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .frame(height: 240)
    }

    private func todasMarcadas(_ notas: [ParsedNoteResult]) -> Bool {
        notas.allSatisfy { seleccion.contains($0.archivoOriginal) }
    }

    private func alternarGrupo(_ notas: [ParsedNoteResult]) {
        if todasMarcadas(notas) {
            for n in notas { seleccion.remove(n.archivoOriginal) }
        } else {
            for n in notas { seleccion.insert(n.archivoOriginal) }
        }
    }

    @ViewBuilder
    private func fila(_ r: ParsedNoteResult) -> some View {
        let s = sugerencias[r.archivoOriginal]
        if let s {
            Toggle(isOn: Binding(
                get: { seleccion.contains(r.archivoOriginal) },
                set: { marcado in
                    if marcado { seleccion.insert(r.archivoOriginal) } else { seleccion.remove(r.archivoOriginal) }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.tituloLimpio)
                    Text("\(Int(s.confianza * 100))% parecido\(s.pareceEnVivo ? " · en vivo" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(nombreArchivo(r))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            // Antes esto era un Toggle deshabilitado con texto "ábrela en la
            // lista de notas (panel izquierdo)" — pero esta vista es un
            // .sheet modal, no hay panel izquierdo visible desde aquí.
            // Reportado: "no me deja subir nada" (el disabled se confundía
            // con un bug). Ahora hay un botón real que cierra este sheet y
            // abre la nota en el detalle, donde sí se puede ingresar el artista.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.tituloLimpio)
                    Text("Sin sugerencia de artista")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(nombreArchivo(r))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Abrir para decidir") { onAbrirNota(r) }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
    }

    /// Nombre de archivo mostrado en esta lista (pedido: "más intuitivo para
    /// guiarse de dónde viene el origen" — con 100+ filas agrupadas por
    /// artista, el título solo no basta para rastrear de qué .txt salió).
    /// Mismo criterio de limpieza que el encabezado del detalle: se quita el
    /// prefijo numérico pegado ("115_"); archivoOriginal como identificador
    /// interno no se toca.
    private func nombreArchivo(_ r: ParsedNoteResult) -> String {
        r.archivoOriginal.replacingOccurrences(of: #"^\d+_"#, with: "", options: .regularExpression)
    }

    /// Fila de solo-lectura para el caso "2 artistas casi empatados" — nunca
    /// seleccionable desde el lote (pedido: separar del mensaje genérico de
    /// "sin sugerencia", que no explicaba nada y generó la duda "¿dónde
    /// aparte?"). Muestra los 2 nombres directamente en la fila, sin que el
    /// usuario tenga que abrir el detalle para enterarse de cuáles son.
    @ViewBuilder
    private func filaAmbigua(_ r: ParsedNoteResult) -> some View {
        let s = ambiguas[r.archivoOriginal]!
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.tituloLimpio)
                if let alt = s.artistaAlternativo {
                    Text("¿\(s.artista) o \(alt.artista)? — no se puede decidir en lote")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(nombreArchivo(r))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Abrir para decidir") { onAbrirNota(r) }
                .font(.caption)
                .buttonStyle(.bordered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Importador de notas")
            HStack {
                Text("Importar \(seleccionValida.count) de \(elegiblesIds.count)")
                    .font(.headline)
                Spacer()
                Button("Todas") { seleccion = Set(elegiblesIds) }
                Button("Ninguna") { seleccion = [] }
            }
            .padding()

            Divider()

            if calculando {
                VStack {
                    Spacer()
                    ProgressView("Calculando sugerencias de artista...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(gruposPorArtista, id: \.artista) { grupo in
                        Section {
                            ForEach(grupo.notas, id: \.archivoOriginal) { r in
                                fila(r)
                            }
                        } header: {
                            HStack {
                                Text(grupo.artista)
                                Spacer()
                                Button(todasMarcadas(grupo.notas) ? "Ninguna" : "Todas") {
                                    alternarGrupo(grupo.notas)
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    if !ambiguasOrdenadas.isEmpty {
                        Section("Coinciden con 2 artistas distintos — elige a mano") {
                            ForEach(ambiguasOrdenadas, id: \.archivoOriginal) { r in
                                filaAmbigua(r)
                            }
                        }
                    }
                    if !sinSugerencia.isEmpty {
                        Section("Sin sugerencia de artista") {
                            ForEach(sinSugerencia, id: \.archivoOriginal) { r in
                                fila(r)
                            }
                        }
                    }
                }
                .layoutPriority(1)
                .frame(minHeight: 200)
                .searchable(text: $textoBusqueda, prompt: "Buscar canción o artista")

                Divider()

                resumenVisual
            }

            Divider()

            HStack {
                Button("Cancelar") { onCancelar() }
                Spacer()
                Button("Importar (\(seleccionValida.count))") { onConfirmar() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(seleccionValida.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 620, idealHeight: 780, maxHeight: 900)
        .onAppear {
            guard calculando else { return }
            let candidatasCopia = candidatas
            // Antes esto corría directo en el hilo principal dentro de
            // .onAppear: con ~118-200 candidatas x ~200 filas de repertorio,
            // se sentía como un freeze al abrir la pantalla, sin ni un
            // spinner ("hay un retraso al cargar esa vista", reportado).
            // Ahora corre en background y la UI muestra un ProgressView
            // mientras tanto.
            DispatchQueue.global(qos: .userInitiated).async {
                var mapa: [String: SugerenciaArtista] = [:]
                var mapaAmbiguas: [String: SugerenciaArtista] = [:]
                var ids: [String] = []
                for r in candidatasCopia {
                    guard let s = ArtistSuggestionService.shared.sugerirArtista(paraTitulo: r.tituloLimpio) else { continue }
                    if s.artistaAlternativo == nil {
                        mapa[r.archivoOriginal] = s
                        ids.append(r.archivoOriginal)
                    } else {
                        mapaAmbiguas[r.archivoOriginal] = s
                    }
                }
                DispatchQueue.main.async {
                    sugerencias = mapa
                    ambiguas = mapaAmbiguas
                    elegiblesIds = ids
                    calculando = false
                    // Fix real (reportado en este chat: "Importar 0 de 118"
                    // con todo destildado al abrir). Si la selección llega
                    // vacía a este punto — sea porque el prefill del botón en
                    // la vista padre no alcanzó a aplicarse a tiempo, o por
                    // cualquier otra razón — esta vista se autocorrige sola:
                    // preselecciona todo lo elegible por defecto, nunca deja
                    // un "0 de N" silencioso que el usuario tenga que notar y
                    // corregir a mano con "Todas".
                    if seleccion.isEmpty {
                        seleccion = Set(ids)
                    }
                }
            }
        }
    }
}

// MARK: - Detalle de una nota parseada + acción de importar

private struct DetalleNotaParseadaView: View {
    let resultado: ParsedNoteResult
    let yaImportada: Bool
    var onImportada: () -> Void

    @State private var artista: String = ""
    @State private var mensajeImportacion: String?
    @State private var coincidenciaExistente: Song?
    @State private var importadaLocal: Bool = false
    @State private var sugerenciaAplicada: SugerenciaArtista?
    @State private var esEnVivo: Bool = false
    @State private var artistaConfirmado: Bool = false
    @State private var candidatosAutocompletar: [String] = []

    private let repo = SongRepository()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderBar(titulo: "Importador de notas")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    encabezado

                    if resultado.requiereRevision {
                        avisos
                    }

                    panelDeImportacion

                    ChordChartView(content: resultado.contentAST)
                }
                .padding()
            }
        }
        .navigationTitle(resultado.tituloLimpio)
        .onAppear {
            importadaLocal = yaImportada
            if artista.isEmpty, let sugerencia = ArtistSuggestionService.shared.sugerirArtista(paraTitulo: resultado.tituloLimpio) {
                artista = sugerencia.artista
                sugerenciaAplicada = sugerencia
                esEnVivo = sugerencia.pareceEnVivo
            }
        }
        .alert("Ya existe una canción similar", isPresented: Binding(
            get: { coincidenciaExistente != nil },
            set: { if !$0 { coincidenciaExistente = nil } }
        )) {
            Button("Cancelar", role: .cancel) { coincidenciaExistente = nil }
            if let existente = coincidenciaExistente {
                Button("Actualizar contenido de '\(existente.id)'") {
                    coincidenciaExistente = nil
                    actualizarContenido(existente)
                }
            }
            Button("Crear de todos modos") {
                coincidenciaExistente = nil
                crearCancion()
            }
        } message: {
            if let existente = coincidenciaExistente {
                Text("Ya tienes '\(existente.titleDisplay)' de \(existente.artist) (\(existente.id)). 'Actualizar contenido' reemplaza solo la letra/acordes de esa canción y conserva Spotify, YouTube, alias, país, idioma, nivel y notas. 'Crear de todos modos' arma una canción nueva y separada.")
            }
        }
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(resultado.tituloLimpio)
                .font(.title2)
                .bold()
            HStack(spacing: 12) {
                if let bandera = resultado.banderaPaisDetectada {
                    Text(bandera)
                }
                Label(nombreNotacion(resultado.contentAST.notacionDetectada), systemImage: "music.quarternote.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(nombreArchivoParaMostrar)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Solo para mostrar en pantalla — archivoOriginal sigue siendo la clave
    /// real en los diccionarios de selección/importadas/deshacer del padre,
    /// nunca se toca. Pedido: el prefijo numérico pegado ("115_") no aporta
    /// nada para decidir si importar, solo ensucia el encabezado.
    private var nombreArchivoParaMostrar: String {
        resultado.archivoOriginal.replacingOccurrences(of: #"^\d+_"#, with: "", options: .regularExpression)
    }

    private var avisos: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(resultado.issues, id: \.detalle) { issue in
                Label(issue.detalle, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Pendiente #4 (v0.5, adelantado en este chat): la sugerencia empieza
    /// SIEMPRE editable, nunca se auto-confirma sola con solo prellenarla —
    /// se necesita una acción explícita ("Confirmar") para bloquearla antes
    /// de poder importar. "Editar" la vuelve a abrir. Esto NO aplica al lote
    /// (importarLote en la vista padre sigue auto-aceptando por diseño).
    ///
    /// Rediseño (reportado: "no es intuitivo, esperaba una elección"): el
    /// caso ambiguo (2 artistas casi empatados) ya NO es un TextField con un
    /// aviso de texto abajo — son 2 botones reales, uno por candidato, más
    /// un tercero para descartar ambos y escribir a mano. El caso manual
    /// ahora también propone artistas mientras escribes (autocompletar
    /// simple contra el repertorio conocido, ver
    /// ArtistSuggestionService.artistasCandidatos).
    private var panelDeImportacion: some View {
        VStack(alignment: .leading, spacing: 8) {
            if importadaLocal {
                Label("Ya importada a la biblioteca", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if artistaConfirmado {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artista).bold()
                        if esEnVivo {
                            Text("Versión en vivo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Editar") { artistaConfirmado = false }
                        .buttonStyle(.borderless)
                }
                Button("Importar a biblioteca") { importar() }
                if let mensaje = mensajeImportacion {
                    Text(mensaje)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else if let s = sugerenciaAplicada, let alt = s.artistaAlternativo {
                Text("Este título coincide con tu repertorio conocido bajo 2 artistas distintos — elige cuál es:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    artista = s.artista
                    esEnVivo = s.pareceEnVivo
                    artistaConfirmado = true
                } label: {
                    HStack {
                        Text(s.artista)
                        Spacer()
                        Text("\(Int(s.confianza * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                Button {
                    artista = alt.artista
                    esEnVivo = s.pareceEnVivo
                    artistaConfirmado = true
                } label: {
                    HStack {
                        Text(alt.artista)
                        Spacer()
                        Text("\(Int(alt.confianza * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                Button("Ninguno de los dos — escribir otro") {
                    artista = ""
                    sugerenciaAplicada = nil
                }
                .buttonStyle(.borderless)
                .font(.caption)
            } else {
                if let s = sugerenciaAplicada {
                    Text("Este título coincide con tu repertorio conocido ('\(s.tituloConocido)', \(Int(s.confianza * 100))% parecido) — confirma o cambia el artista")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                TextField("Artista / banda (obligatorio)", text: $artista)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: artista) { _, nuevo in
                        sugerenciaAplicada = nil
                        candidatosAutocompletar = ArtistSuggestionService.shared.artistasCandidatos(paraTexto: nuevo)
                    }
                if !candidatosAutocompletar.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(candidatosAutocompletar, id: \.self) { candidato in
                            Button(candidato) {
                                artista = candidato
                                candidatosAutocompletar = []
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    .padding(.leading, 4)
                }
                Toggle("¿Es versión en vivo?", isOn: $esEnVivo)
                Button("Confirmar artista") { artistaConfirmado = true }
                    .disabled(artista.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func importar() {
        let artistaLimpio = artista.trimmingCharacters(in: .whitespaces)
        guard !artistaLimpio.isEmpty else {
            mensajeImportacion = "Escribe el artista/banda antes de importar."
            return
        }
        do {
            let clave = normalizeForMatching("\(resultado.tituloLimpio) \(artistaLimpio)")
            if let existente = try repo.fetchByMatchKey(clave) {
                coincidenciaExistente = existente
                return
            }
            crearCancion()
        } catch {
            mensajeImportacion = "Error buscando duplicados: \(error.localizedDescription)"
        }
    }

    private func crearCancion() {
        let artistaLimpio = artista.trimmingCharacters(in: .whitespaces)
        do {
            let codigo = try repo.suggestNextCode()
            let jsonData = try JSONEncoder().encode(resultado.contentAST)
            let jsonTexto = String(data: jsonData, encoding: .utf8)

            try repo.create(Song(
                id: codigo,
                spotifyId: nil,
                titleDisplay: resultado.tituloLimpio,
                titleSpotify: nil,
                artist: artistaLimpio,
                matchKey: "",
                isLive: esEnVivo,
                originalKey: nil,
                durationSec: nil,
                country: resultado.banderaPaisDetectada,
                language: nil,
                level: nil,
                notes: resultado.requiereRevision ? "Importado desde Apple Notes, requiere revisión" : "Importado desde Apple Notes",
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil,
                rev: 1,
                lastEditedBy: "importador_notes",
                youtubeUrl: nil,
                physicalNotes: nil,
                contentASTJson: jsonTexto
            ))
            mensajeImportacion = nil
            importadaLocal = true
            onImportada()
        } catch {
            mensajeImportacion = "No se pudo guardar: \(error.localizedDescription). ¿Ese código ya existe?"
        }
    }

    /// P9 (v0.8 sección 8, prioridad Alta): reimportar SIEMPRE creaba una
    /// canción nueva con código distinto, perdiendo Spotify ID, YouTube,
    /// alias, país, idioma, nivel y notas manuales de la canción ya
    /// enriquecida. Esta ruta actualiza SOLO contentASTJson de la canción
    /// existente — todo lo demás (titleDisplay, artist, spotifyId,
    /// youtubeUrl, physicalNotes, country, language, level, notes, alias)
    /// queda intacto, y el song_code no cambia.
    private func actualizarContenido(_ existente: Song) {
        do {
            var s = existente
            let jsonData = try JSONEncoder().encode(resultado.contentAST)
            s.contentASTJson = String(data: jsonData, encoding: .utf8)
            s.lastEditedBy = "importador_notes_actualizar_contenido"
            try repo.update(s)
            mensajeImportacion = nil
            importadaLocal = true
            onImportada()
        } catch {
            mensajeImportacion = "No se pudo actualizar el contenido: \(error.localizedDescription)"
        }
    }

    private func nombreNotacion(_ n: NotacionAcorde) -> String {
        switch n {
        case .inglesa: return "Acordes: letras (C, D, E…)"
        case .solfeo: return "Acordes: solfeo (Do, Re, Mi…)"
        case .ninguna: return "Sin acordes"
        }
    }
}
