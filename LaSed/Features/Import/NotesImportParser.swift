//
//  NotesImportParser.swift
//  LaSed
//
//  Versión: 0.4.11
//  Actualizado: 11/09/2026
//
import Foundation
import SwiftUI

// MARK: - Modelo de acorde

nonisolated enum CalidadAcorde: String, Codable, Hashable {
    case mayor, menor, disminuido, aumentado, sus2, sus4, add
}

nonisolated enum NotacionAcorde: String, Codable, Hashable {
    case inglesa, solfeo, ninguna
}

nonisolated struct Chord: Codable, Equatable, Hashable {
    var root: String
    var accidental: String?
    var quality: CalidadAcorde
    var extensionNumero: String?
    var bassRoot: String?
    var raw: String
    var notacionOrigen: NotacionAcorde
}

// MARK: - Formato de texto (negrita, cursiva, color, resaltado, alineación)

/// Paleta fija — nunca un color libre. Un color no reconocido se deja como
/// texto literal, igual que un acorde no reconocido: nunca se inventa.
nonisolated enum MarkColor: String, Codable, Hashable, CaseIterable {
    case rojo, naranja, amarillo, verde, azul, morado, gris

    var color: Color {
        switch self {
        case .rojo: return .red
        case .naranja: return .orange
        case .amarillo: return .yellow
        case .verde: return .green
        case .azul: return .blue
        case .morado: return .purple
        case .gris: return .gray
        }
    }
}

nonisolated enum TextMarkType: String, Codable, Hashable {
    case bold, italic, color, highlight
}

nonisolated struct TextMark: Codable, Equatable, Hashable {
    var type: TextMarkType
    /// Solo aplica cuando type es .color o .highlight.
    var color: MarkColor?
}

/// Atributos propios (independientes de `Font`) para trackear negrita y
/// cursiva. NUNCA usar `Font.Resolved.isBold`/`isItalic` como fuente de
/// verdad para decidir si un tramo YA está en negrita: si el usuario tiene
/// activada la opción de accesibilidad "Texto en negrita" (macOS/iOS), el
/// sistema resuelve TODA fuente como negrita — no solo la marcada a mano —
/// lo que rompería el botón (negrita nunca se activaría, solo se
/// desactivaría) Y el guardado (extraerMarcasGlobales marcaría TODO el
/// texto como negrita). Estos dos flags booleanos son la única fuente de
/// verdad; Font.bold()/.italic() se sigue aplicando solo para que SE VEA,
/// nunca se vuelve a leer de vuelta para decidir estado.
nonisolated struct LaSedBoldKey: AttributedStringKey {
    typealias Value = Bool
    static let name = "laSedBold"
}

nonisolated struct LaSedItalicKey: AttributedStringKey {
    typealias Value = Bool
    static let name = "laSedItalic"
}

extension AttributeScopes {
    nonisolated struct LaSedAttributes: AttributeScope {
        let bold: LaSedBoldKey
        let italic: LaSedItalicKey
    }
    nonisolated var laSed: LaSedAttributes.Type { LaSedAttributes.self }
}

extension AttributeDynamicLookup {
    nonisolated subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.LaSedAttributes, T>) -> T {
        self[T.self]
    }
}

nonisolated enum ParagraphAlignment: String, Codable, Hashable {
    case left, center, right
}

// MARK: - Líneas y segmentos

nonisolated struct LineSegment: Codable, Equatable, Hashable {
    var chord: Chord?
    var text: String
    /// Campo agregado con canciones reales ya guardadas — un [] por defecto
    /// en un Codable no-opcional NO tolera JSON viejo sin esta clave, por
    /// eso init(from:)/encode(to:) manuales, mismo patrón que ParsedSection.
    var marks: [TextMark]

    init(chord: Chord? = nil, text: String, marks: [TextMark] = []) {
        self.chord = chord
        self.text = text
        self.marks = marks
    }

    private enum CodingKeys: String, CodingKey {
        case chord, text, marks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chord = try container.decodeIfPresent(Chord.self, forKey: .chord)
        text = try container.decode(String.self, forKey: .text)
        marks = try container.decodeIfPresent([TextMark].self, forKey: .marks) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(chord, forKey: .chord)
        try container.encode(text, forKey: .text)
        try container.encode(marks, forKey: .marks)
    }
}

nonisolated enum TipoLinea: String, Codable, Hashable {
    case letraConAcordes, letraPlana, instrumental, anotacion
}

nonisolated struct ParsedLine: Codable, Equatable, Hashable {
    var type: TipoLinea
    var segments: [LineSegment]
    /// Optional -> el Codable sintetizado ya tolera JSON viejo sin esta
    /// clave (decodeIfPresent automático de Swift para Optional). No hace
    /// falta init(from:) manual aquí, a diferencia de LineSegment.marks.
    var alignment: ParagraphAlignment?
}

nonisolated struct ParsedSection: Codable, Equatable, Hashable {
    var lines: [ParsedLine]
    /// Cantidad de líneas en blanco antes de esta sección (mínimo 1) —
    /// controla el TAMAÑO del espacio.
    var separacionPrevia: Int
    /// true si el usuario escribió "---" — controla si hay RAYA visible,
    /// independiente del tamaño.
    var separadorVisible: Bool

    private enum CodingKeys: String, CodingKey {
        case lines, separacionPrevia, separadorVisible
    }

    init(lines: [ParsedLine], separacionPrevia: Int = 1, separadorVisible: Bool = false) {
        self.lines = lines
        self.separacionPrevia = separacionPrevia
        self.separadorVisible = separadorVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lines = try container.decode([ParsedLine].self, forKey: .lines)
        separacionPrevia = try container.decodeIfPresent(Int.self, forKey: .separacionPrevia) ?? 1
        separadorVisible = try container.decodeIfPresent(Bool.self, forKey: .separadorVisible) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lines, forKey: .lines)
        try container.encode(separacionPrevia, forKey: .separacionPrevia)
        try container.encode(separadorVisible, forKey: .separadorVisible)
    }
}

nonisolated struct ParsedSongContent: Codable, Equatable, Hashable {
    var sections: [ParsedSection]
    var notacionDetectada: NotacionAcorde
}

// MARK: - Issues

nonisolated enum ImportIssueType: String, Codable, Hashable {
    case sinAcordesAnclados, contenidoPerdido, notaVaciaOBasura, notacionAmbigua
}

nonisolated struct ImportIssue: Codable, Equatable, Hashable {
    var type: ImportIssueType
    var detalle: String
}

nonisolated struct ParsedNoteResult: Codable, Equatable, Hashable {
    var archivoOriginal: String
    var tituloCrudo: String
    var tituloLimpio: String
    var banderaPaisDetectada: String?
    var contentAST: ParsedSongContent
    var requiereRevision: Bool
    var issues: [ImportIssue]
}

// MARK: - Parser principal

nonisolated enum NotesImportParser {

    private static let anchoDeTab = 4
    private static let notasSolfa = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"]
    private static let notasIngles = ["A", "B", "C", "D", "E", "F", "G"]
    private static let mapaSolfaAIngles: [String: String] = [
        "do": "C", "re": "D", "mi": "E", "fa": "F", "sol": "G", "la": "A", "si": "B"
    ]
    private static let calidades: [(String, CalidadAcorde)] = [
        ("maj", .mayor), ("min", .menor), ("m", .menor),
        ("dim", .disminuido), ("aug", .aumentado),
        ("sus2", .sus2), ("sus4", .sus4), ("sus", .sus4), ("add", .add)
    ]
    private static let separadores: Set<String> = ["-", "(", ")", "|", "/", "(bis)", "x2", "x3", "x4"]

    // MARK: Detección de notación

    private static func tieneAlteracionOCalidad(_ resto: String) -> Bool {
        guard !resto.isEmpty else { return false }
        if resto.hasPrefix("#") || resto.lowercased().hasPrefix("b") { return true }
        if resto.hasPrefix("(") { return true }
        for (prefijo, _) in calidades {
            if resto.lowercased().hasPrefix(prefijo) { return true }
        }
        return false
    }

    private static func evidenciaFuerte(_ token: String) -> NotacionAcorde? {
        let t = token.trimmingCharacters(in: CharacterSet(charactersIn: "()-,."))
        guard !t.isEmpty else { return nil }

        for nota in notasIngles {
            if t.hasPrefix(nota), tieneAlteracionOCalidad(String(t.dropFirst(nota.count))) {
                return .inglesa
            }
        }
        for nota in notasSolfa {
            if t.lowercased().hasPrefix(nota.lowercased()),
               tieneAlteracionOCalidad(String(t.dropFirst(nota.count))) {
                return .solfeo
            }
        }
        return nil
    }

    static func detectarNotacion(_ contenido: String) -> NotacionAcorde {
        var hitsIngles = 0
        var hitsSolfeo = 0
        for linea in contenido.components(separatedBy: "\n") {
            for token in linea.split(separator: " ").map(String.init) {
                switch evidenciaFuerte(token) {
                case .inglesa: hitsIngles += 1
                case .solfeo: hitsSolfeo += 1
                default: break
                }
            }
        }
        if hitsIngles > 0 || hitsSolfeo > 0 {
            return hitsSolfeo > hitsIngles ? .solfeo : .inglesa
        }
        return detectarNotacionDebil(contenido)
    }

    private static func detectarNotacionDebil(_ contenido: String) -> NotacionAcorde {
        var lineasConEvidenciaDebil = 0
        for linea in contenido.components(separatedBy: "\n") {
            let tokens = linea.split(separator: " ").map(String.init).filter { !$0.isEmpty }
            let significativos = tokens.filter { !separadores.contains($0.lowercased()) }
            guard significativos.count >= 2 else { continue }
            if significativos.allSatisfy({ parsearAcorde($0, notacion: .inglesa) != nil }) {
                lineasConEvidenciaDebil += 1
            }
        }
        return lineasConEvidenciaDebil >= 2 ? .inglesa : .ninguna
    }

    // MARK: Parseo de un token como acorde

    static func parsearAcorde(_ tokenOriginal: String, notacion: NotacionAcorde) -> Chord? {
        let token = tokenOriginal.trimmingCharacters(in: CharacterSet(charactersIn: "()-,."))
        guard !token.isEmpty else { return nil }

        var root: String? = nil
        var resto = token

        if notacion == .inglesa {
            if let primera = token.first, notasIngles.contains(String(primera)) {
                root = String(primera)
                resto = String(token.dropFirst())
            }
        } else if notacion == .solfeo {
            for nombre in notasSolfa {
                if token.lowercased().hasPrefix(nombre.lowercased()) {
                    root = mapaSolfaAIngles[nombre.lowercased()]
                    resto = String(token.dropFirst(nombre.count))
                    break
                }
            }
        }

        guard let raiz = root else { return nil }

        var accidental: String? = nil
        if resto.hasPrefix("#") {
            accidental = "#"
            resto.removeFirst()
        } else if resto.lowercased().hasPrefix("sost") {
            accidental = "#"
            resto = String(resto.dropFirst(resto.lowercased().hasPrefix("sost.") ? 5 : 4))
        } else if resto.lowercased().hasPrefix("bem") {
            accidental = "b"
            resto = String(resto.dropFirst(resto.lowercased().hasPrefix("bem.") ? 4 : 3))
        } else if resto.lowercased().hasPrefix("b"), !resto.lowercased().hasPrefix("bm") {
            accidental = "b"
            resto.removeFirst()
        }

        var quality: CalidadAcorde = .mayor
        for (prefijo, cal) in calidades {
            if resto.lowercased().hasPrefix(prefijo) {
                quality = cal
                resto = String(resto.dropFirst(prefijo.count))
                break
            }
        }

        var bassRoot: String? = nil
        if resto.contains("/") {
            let partes = resto.split(separator: "/", maxSplits: 1).map(String.init)
            resto = partes.first ?? ""
            if partes.count > 1 {
                let bajo = partes[1]
                if notacion == .inglesa, let primera = bajo.first, notasIngles.contains(String(primera)) {
                    bassRoot = String(primera)
                } else if notacion == .solfeo {
                    for nombre in notasSolfa where bajo.lowercased().hasPrefix(nombre.lowercased()) {
                        bassRoot = mapaSolfaAIngles[nombre.lowercased()]
                        break
                    }
                }
            }
        }

        let numeros = resto.filter { $0.isNumber }
        let extensionNumero = numeros.isEmpty ? nil : numeros

        return Chord(
            root: raiz,
            accidental: accidental,
            quality: quality,
            extensionNumero: extensionNumero,
            bassRoot: bassRoot,
            raw: tokenOriginal,
            notacionOrigen: notacion
        )
    }

    // MARK: Clasificación de línea de acordes

    private enum TipoLineaAcorde {
        case anclable, resumen
    }

    private static func tipoDeLineaAcorde(_ linea: String, notacion: NotacionAcorde) -> TipoLineaAcorde? {
        guard notacion != .ninguna else { return nil }
        let tokens = linea.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        if linea.contains("  ") {
            let coincidencias = tokens.filter { parsearAcorde($0, notacion: notacion) != nil }.count
            if Double(coincidencias) >= Double(tokens.count) * 0.5 {
                return .anclable
            }
        }

        let significativos = tokens.filter { !separadores.contains($0.lowercased()) }

        if significativos.count == 1, notacion == .inglesa,
           let token = significativos.first,
           parsearAcorde(token, notacion: notacion) != nil,
           tieneAlteracionOCalidad(String(token.dropFirst())) {
            return .resumen
        }

        if significativos.count >= 2 {
            let coincidenciasSig = significativos.filter { parsearAcorde($0, notacion: notacion) != nil }.count
            if coincidenciasSig == significativos.count {
                return .resumen
            }
        }

        return nil
    }

    // MARK: Normalización y anclaje

    static func normalizarTabs(_ linea: String) -> String {
        linea.replacingOccurrences(of: "\t", with: String(repeating: " ", count: anchoDeTab))
    }

    static func extraerAcordesConPosicion(_ linea: String, notacion: NotacionAcorde) -> [(chord: Chord, columna: Int)] {
        var resultado: [(Chord, Int)] = []
        var columna = 0
        for tokenSub in linea.split(separator: " ", omittingEmptySubsequences: false) {
            let token = String(tokenSub)
            if !token.isEmpty, let acorde = parsearAcorde(token, notacion: notacion) {
                resultado.append((acorde, columna))
            }
            columna += token.count + 1
        }
        return resultado
    }

    static func anclarAcordesALinea(_ acordes: [(chord: Chord, columna: Int)], lineaLetra: String) -> [LineSegment] {
        guard !acordes.isEmpty else {
            return [LineSegment(chord: nil, text: lineaLetra)]
        }
        let caracteres = Array(lineaLetra)
        var segments: [LineSegment] = []
        var cursor = 0
        let acordesOrdenados = acordes.sorted { $0.columna < $1.columna }

        for (indice, item) in acordesOrdenados.enumerated() {
            let posicion = min(item.columna, caracteres.count)
            if posicion > cursor {
                segments.append(LineSegment(chord: nil, text: String(caracteres[cursor..<posicion])))
            }
            let finDeSegmento = indice + 1 < acordesOrdenados.count
                ? min(acordesOrdenados[indice + 1].columna, caracteres.count)
                : caracteres.count
            let textoSegmento = posicion < finDeSegmento ? String(caracteres[posicion..<finDeSegmento]) : ""
            segments.append(LineSegment(chord: item.chord, text: textoSegmento))
            cursor = finDeSegmento
        }
        return segments
    }

    // MARK: - Alineación y marcas de formato (negrita/cursiva/color/resaltado)

    /// Todo el detector vive aquí. Sintaxis v1, SIN anidamiento (una marca
    /// por tramo de texto) — igual que la Librería de acordes: mejor no
    /// soportar una combinación que soportarla mal.
    private nonisolated enum FormatoLineaParser {

        /// El marcador de alineación envuelve la línea COMPLETA. Se queda
        /// como convención escrita (>>/> ... <) — a diferencia de las
        /// marcas de negrita/cursiva/color, que ahora vienen de atributos
        /// reales del AttributedString, no de texto tecleado.
        static func extraerAlineacion(_ linea: String) -> (texto: String, alineacion: ParagraphAlignment?, prefijoLen: Int) {
            if linea.hasPrefix(">>") {
                return (String(linea.dropFirst(2)), .right, 2)
            }
            if linea.hasPrefix(">"), linea.hasSuffix("<"), linea.count >= 2 {
                return (String(linea.dropFirst().dropLast()), .center, 1)
            }
            return (linea, nil, 0)
        }

        /// Reparte marcas (en coordenadas LOCALES a esta línea, ya
        /// recortado el prefijo de alineación) entre los LineSegment ya
        /// anclados, partiendo un segmento si un rango cae a mitad de él.
        static func aplicarMarcas(_ segments: [LineSegment], _ marcas: [(rango: Range<Int>, marca: TextMark)]) -> [LineSegment] {
            guard !marcas.isEmpty else { return segments }
            var resultado: [LineSegment] = []
            var cursor = 0

            for seg in segments {
                let inicioSeg = cursor
                let finSeg = cursor + seg.text.count
                cursor = finSeg

                let marcasAplicables = marcas.filter { $0.rango.lowerBound < finSeg && $0.rango.upperBound > inicioSeg }
                guard !marcasAplicables.isEmpty else {
                    resultado.append(seg)
                    continue
                }

                var cortes: Set<Int> = [inicioSeg, finSeg]
                for m in marcasAplicables {
                    cortes.insert(max(inicioSeg, m.rango.lowerBound))
                    cortes.insert(min(finSeg, m.rango.upperBound))
                }
                let puntos = cortes.sorted()
                let caracteres = Array(seg.text)

                for i in 0..<(puntos.count - 1) {
                    let a = puntos[i], b = puntos[i + 1]
                    guard a < b else { continue }
                    let subTexto = String(caracteres[(a - inicioSeg)..<(b - inicioSeg)])
                    let marksDeTrozo = marcasAplicables
                        .filter { $0.rango.lowerBound < b && $0.rango.upperBound > a }
                        .map(\.marca)
                    let chordDeTrozo = (i == 0) ? seg.chord : nil // el chord vive en el primer trozo, nunca se repite
                    resultado.append(LineSegment(chord: chordDeTrozo, text: subTexto, marks: marksDeTrozo))
                }
            }
            return resultado
        }

        /// Reinserta ** / _ / [color] al EXPORTAR a texto plano (compartir,
        /// futuro ChordPro) — nunca al editar; el editor usa AttributedString.
        static func reinsertarMarcas(_ segments: [LineSegment]) -> String {
            segments.map { seg -> String in
                var texto = seg.text
                for marca in seg.marks {
                    switch marca.type {
                    case .bold: texto = "**" + texto + "**"
                    case .italic: texto = "_" + texto + "_"
                    case .color: texto = "[" + (marca.color?.rawValue ?? "gris") + "]" + texto + "[/color]"
                    case .highlight: texto = "[hl:" + (marca.color?.rawValue ?? "amarillo") + "]" + texto + "[/hl]"
                    }
                }
                return texto
            }.joined()
        }

        static func envolverAlineacion(_ texto: String, _ alineacion: ParagraphAlignment?) -> String {
            switch alineacion {
            case .center: return ">" + texto + "<"
            case .right: return ">>" + texto
            case .left, nil: return texto
            }
        }
    }

    // MARK: Parseo del cuerpo (compartido por importador y editor)

    static func parseCuerpo(
        _ lineasCuerpo: [String],
        notacion: NotacionAcorde,
        marcasGlobales: [(rango: Range<Int>, marca: TextMark)] = []
    ) -> (secciones: [ParsedSection], lineasAncladas: Int) {
        let lineasNormalizadas = lineasCuerpo.map(normalizarTabs)

        // Offset global (en caracteres) donde empieza cada línea — así se
        // sabe qué marcas (calculadas sobre el AttributedString completo)
        // caen en cada línea. Ojo: normalizarTabs puede desalinear esto si
        // hay tabs reales en el texto (no resuelto en v1, caso raro).
        var offsetsPorLinea: [Int] = []
        var acumulado = 0
        for linea in lineasNormalizadas {
            offsetsPorLinea.append(acumulado)
            acumulado += linea.count + 1
        }

        func marcasLocalesParaLinea(_ indiceLinea: Int, prefijoLen: Int, longitudTexto: Int) -> [(rango: Range<Int>, marca: TextMark)] {
            guard !marcasGlobales.isEmpty else { return [] }
            let inicioGlobal = offsetsPorLinea[indiceLinea] + prefijoLen
            let finGlobal = inicioGlobal + longitudTexto
            return marcasGlobales.compactMap { m in
                let a = max(m.rango.lowerBound, inicioGlobal)
                let b = min(m.rango.upperBound, finGlobal)
                guard a < b else { return nil }
                return ((a - inicioGlobal)..<(b - inicioGlobal), m.marca)
            }
        }

        var secciones: [ParsedSection] = []
        var lineasSeccionActual: [ParsedLine] = []
        var separacionPreviaActual = 1
        var separadorVisibleActual = false
        var blancosEnCurso = 0
        var separadorVistoEnCurso = false
        var totalLineasAncladas = 0

        var indice = 0
        while indice < lineasNormalizadas.count {
            let lineaOriginal = lineasNormalizadas[indice]
            let lineaSinEspacios = lineaOriginal.trimmingCharacters(in: .whitespaces)
            let esMarcadorDeRaya = lineaSinEspacios.range(of: "^-{3,}$", options: .regularExpression) != nil

            if lineaSinEspacios.isEmpty || esMarcadorDeRaya {
                if !lineasSeccionActual.isEmpty {
                    secciones.append(ParsedSection(lines: lineasSeccionActual, separacionPrevia: separacionPreviaActual, separadorVisible: separadorVisibleActual))
                    lineasSeccionActual = []
                }
                if esMarcadorDeRaya {
                    separadorVistoEnCurso = true
                } else {
                    blancosEnCurso += 1
                }
                indice += 1
                continue
            }

            if lineasSeccionActual.isEmpty {
                separacionPreviaActual = max(1, blancosEnCurso)
                separadorVisibleActual = separadorVistoEnCurso
                blancosEnCurso = 0
                separadorVistoEnCurso = false
            }

            let tipoAcorde = tipoDeLineaAcorde(lineaOriginal, notacion: notacion)

            switch tipoAcorde {
            case .anclable:
                totalLineasAncladas += 1
                let acordesPos = extraerAcordesConPosicion(lineaOriginal, notacion: notacion)
                let hayLineaSiguiente = indice + 1 < lineasNormalizadas.count
                let siguiente = hayLineaSiguiente ? lineasNormalizadas[indice + 1] : ""
                let ultimaColumna = acordesPos.map(\.columna).max() ?? 0
                let siguienteEsLetra = hayLineaSiguiente
                    && !siguiente.trimmingCharacters(in: .whitespaces).isEmpty
                    && tipoDeLineaAcorde(siguiente, notacion: notacion) == nil
                    && ultimaColumna <= siguiente.count + 10

                if siguienteEsLetra {
                    // Formato se quita ANTES de anclar: el anclaje asume
                    // columna N de la línea de acordes == carácter N de la
                    // letra ya limpia. Las marcas (negrita/cursiva/color)
                    // ya NO viven en este texto — vienen del
                    // AttributedString original, en marcasGlobales.
                    let (letraLimpia, alineacion, prefijoLen) = FormatoLineaParser.extraerAlineacion(siguiente)
                    let marcasLinea = marcasLocalesParaLinea(indice + 1, prefijoLen: prefijoLen, longitudTexto: letraLimpia.count)
                    let segmentosBase = anclarAcordesALinea(acordesPos, lineaLetra: letraLimpia)
                    let segments = FormatoLineaParser.aplicarMarcas(segmentosBase, marcasLinea)
                    lineasSeccionActual.append(ParsedLine(type: .letraConAcordes, segments: segments, alignment: alineacion))
                    indice += 2
                } else {
                    let segments = acordesPos.map { LineSegment(chord: $0.chord, text: "") }
                    lineasSeccionActual.append(ParsedLine(type: .instrumental, segments: segments))
                    indice += 1
                }

            case .resumen:
                let acordesPos = extraerAcordesConPosicion(lineaOriginal, notacion: notacion)
                let segments = acordesPos.map { LineSegment(chord: $0.chord, text: "") }
                lineasSeccionActual.append(ParsedLine(type: .instrumental, segments: segments))
                indice += 1

            case .none:
                let (textoLimpio, alineacion, prefijoLen) = FormatoLineaParser.extraerAlineacion(lineaOriginal)
                let marcasLinea = marcasLocalesParaLinea(indice, prefijoLen: prefijoLen, longitudTexto: textoLimpio.count)
                let textoSinEspacios = textoLimpio.trimmingCharacters(in: .whitespaces)
                let esAnotacion = textoSinEspacios.count < 20 &&
                    (textoSinEspacios == textoSinEspacios.uppercased()
                     || textoSinEspacios.hasPrefix("(") || textoSinEspacios.hasPrefix("["))
                let tipo: TipoLinea = esAnotacion ? .anotacion : .letraPlana
                let segments = FormatoLineaParser.aplicarMarcas([LineSegment(chord: nil, text: textoLimpio)], marcasLinea)
                lineasSeccionActual.append(ParsedLine(type: tipo, segments: segments, alignment: alineacion))
                indice += 1
            }
        }

        if !lineasSeccionActual.isEmpty {
            secciones.append(ParsedSection(lines: lineasSeccionActual, separacionPrevia: separacionPreviaActual, separadorVisible: separadorVisibleActual))
        }

        return (secciones, totalLineasAncladas)
    }

    /// Variante para el editor real (AttributedString con formato aplicado
    /// por botones, ya no texto con marcadores tecleados).
    static func parseCuerpo(
        _ attributed: AttributedString,
        notacion: NotacionAcorde
    ) -> (secciones: [ParsedSection], lineasAncladas: Int) {
        let texto = String(attributed.characters)
        let lineas = texto.components(separatedBy: "\n")
        let marcas = extraerMarcasGlobales(attributed)
        return parseCuerpo(lineas, notacion: notacion, marcasGlobales: marcas)
    }

    /// Lee negrita/cursiva/color/resaltado directo de los runs del
    /// AttributedString. NUNCA se lee de Font.resolve().isBold/isItalic —
    /// esa lectura se rompe si el usuario tiene activado "Texto en
    /// negrita" (Accesibilidad), que fuerza isBold=true para CUALQUIER
    /// fuente del sistema. En vez de eso se leen los flags propios
    /// laSed.bold/laSed.italic (ver LaSedBoldKey/LaSedItalicKey más
    /// arriba), que el editor y astToAttributedString/segmentoAAttributed
    /// escriben explícitamente.
    static func extraerMarcasGlobales(_ attributed: AttributedString) -> [(rango: Range<Int>, marca: TextMark)] {
        var resultado: [(Range<Int>, TextMark)] = []
        for run in attributed.runs {
            let inicio = attributed.characters.distance(from: attributed.startIndex, to: run.range.lowerBound)
            let fin = attributed.characters.distance(from: attributed.startIndex, to: run.range.upperBound)
            guard fin > inicio else { continue }
            let rango = inicio..<fin

            if run.laSed.bold == true {
                resultado.append((rango, TextMark(type: .bold, color: nil)))
            }
            if run.laSed.italic == true {
                resultado.append((rango, TextMark(type: .italic, color: nil)))
            }
            if let fg = run.foregroundColor, let color = colorMasCercano(fg) {
                resultado.append((rango, TextMark(type: .color, color: color)))
            }
            if let bg = run.backgroundColor, let color = colorMasCercano(bg) {
                resultado.append((rango, TextMark(type: .highlight, color: color)))
            }
        }
        return resultado
    }

    /// Compara por RGBA resuelto, NUNCA por igualdad directa de `Color`:
    /// el valor que vuelve de un run del editor puede llegar ya resuelto
    /// a un `Color` distinto (mismo aspecto, representación interna
    /// distinta) del que se guardó originalmente — esto se rompió en la
    /// práctica (el resaltado desaparecía al guardar) hasta este fix.
    private static func colorMasCercano(_ color: Color) -> MarkColor? {
        let entorno = EnvironmentValues()
        let resuelto = color.resolve(in: entorno)
        return MarkColor.allCases.first { $0.color.resolve(in: entorno) == resuelto }
    }

    /// AST -> AttributedString real, para ABRIR el editor. Reemplaza usar
    /// aTextoPlano() como punto de entrada al editor (aTextoPlano se queda
    /// solo para EXPORTAR/compartir texto plano).
    static func astToAttributedString(_ content: ParsedSongContent, fontSize: Double = 15, fontFamily: ChordFontFamily = .sistema) -> AttributedString {
        var resultado = AttributedString()
        for (indice, seccion) in content.sections.enumerated() {
            if indice > 0 {
                let blancos = max(1, seccion.separacionPrevia)
                resultado += AttributedString(String(repeating: "\n", count: blancos + 1))
                if seccion.separadorVisible {
                    resultado += AttributedString("---\n")
                }
            }
            resultado += seccionAAttributed(seccion, fontSize: fontSize, fontFamily: fontFamily)
        }
        return resultado
    }

    /// Solo para MODO LECTURA (ChordChartView): igual que astToAttributedString
    /// pero sin la fila de acordes ni el marcador de sección, un solo
    /// renglon de letra ya con sus marks aplicados.
    static func segmentosAAttributed(_ segments: [LineSegment], fontSize: Double = 15, fontFamily: ChordFontFamily = .sistema) -> AttributedString {
        segments.reduce(into: AttributedString()) { acc, seg in
            acc += segmentoAAttributed(seg, fontSize: fontSize, fontFamily: fontFamily)
        }
    }

    private static func seccionAAttributed(_ seccion: ParsedSection, fontSize: Double, fontFamily: ChordFontFamily) -> AttributedString {
        var resultado = AttributedString()
        for (indice, linea) in seccion.lines.enumerated() {
            if indice > 0 {
                resultado += AttributedString("\n")
            }
            switch linea.type {
            case .letraConAcordes:
                let filaAcordes = linea.segments.map { seg -> String in
                    guard let chord = seg.chord else {
                        return String(repeating: " ", count: seg.text.count)
                    }
                    let nombre = nombreLegible(chord)
                    let relleno = max(0, seg.text.count - nombre.count)
                    return nombre + String(repeating: " ", count: relleno)
                }.joined()
                var filaLetra = segmentosAAttributed(linea.segments, fontSize: fontSize, fontFamily: fontFamily)
                filaLetra = envolverAlineacionAttributed(filaLetra, linea.alignment)
                resultado += AttributedString(filaAcordes) + AttributedString("\n") + filaLetra
            case .instrumental:
                let texto = linea.segments.compactMap { $0.chord.map(nombreLegible) }.joined(separator: "  ")
                resultado += AttributedString(texto)
            case .letraPlana, .anotacion:
                var texto = segmentosAAttributed(linea.segments, fontSize: fontSize, fontFamily: fontFamily)
                texto = envolverAlineacionAttributed(texto, linea.alignment)
                resultado += texto
            }
        }
        return resultado
    }

    private static func segmentoAAttributed(_ seg: LineSegment, fontSize: Double, fontFamily: ChordFontFamily) -> AttributedString {
        var attr = AttributedString(seg.text)
        let esNegrita = seg.marks.contains { $0.type == .bold }
        let esCursiva = seg.marks.contains { $0.type == .italic }
        // Negrita y cursiva se resuelven JUNTAS, de una sola vez, en vez de
        // encadenar .bold()/.italic() sobre un Font previo: para fuentes
        // con nombre fijo (Menlo, Courier...) negrita/cursiva son archivos
        // de fuente DISTINTOS, no un modifier — encadenar no funciona ahí.
        if esNegrita || esCursiva {
            attr.font = fontFamily.font(size: fontSize, negrita: esNegrita, cursiva: esCursiva)
            if esNegrita { attr.laSed.bold = true }   // fuente de verdad si se reabre en el editor
            if esCursiva { attr.laSed.italic = true } // fuente de verdad si se reabre en el editor
        }
        for marca in seg.marks {
            switch marca.type {
            case .bold, .italic:
                break // ya resuelto arriba
            case .color:
                attr.foregroundColor = marca.color?.color ?? .primary
            case .highlight:
                attr.backgroundColor = marca.color?.color ?? .yellow
            }
        }
        return attr
    }

    private static func envolverAlineacionAttributed(_ texto: AttributedString, _ alineacion: ParagraphAlignment?) -> AttributedString {
        switch alineacion {
        case .center: return AttributedString(">") + texto + AttributedString("<")
        case .right: return AttributedString(">>") + texto
        case .left, nil: return texto
        }
    }

    private static func nombreLegible(_ c: Chord) -> String {
        var s = c.root + (c.accidental ?? "")
        switch c.quality {
        case .mayor: break
        case .menor: s += "m"
        case .disminuido: s += "dim"
        case .aumentado: s += "aug"
        case .sus2: s += "sus2"
        case .sus4: s += "sus4"
        case .add: s += "add"
        }
        if let ext = c.extensionNumero { s += ext }
        if let bajo = c.bassRoot { s += "/" + bajo }
        return s
    }

    private static func seccionATextoPlano(_ seccion: ParsedSection) -> String {
        seccion.lines.map { linea -> String in
            switch linea.type {
            case .letraConAcordes:
                // Aviso: si hay marks, la fila de letra crece (**/_/[color])
                // y la fila de acordes de arriba deja de quedar perfecta
                // en columnas EN ESTE TEXTO EDITABLE — costo cosmético
                // aceptado en v1. El AST guardado es correcto y el render
                // final (no editable) no pasa por este texto reconstruido.
                let filaLetra = FormatoLineaParser.reinsertarMarcas(linea.segments)
                let filaAcordes = linea.segments.map { seg -> String in
                    guard let chord = seg.chord else {
                        return String(repeating: " ", count: seg.text.count)
                    }
                    let nombre = nombreLegible(chord)
                    let relleno = max(0, seg.text.count - nombre.count)
                    return nombre + String(repeating: " ", count: relleno)
                }.joined()
                let filaLetraFinal = FormatoLineaParser.envolverAlineacion(filaLetra, linea.alignment)
                return filaAcordes + "\n" + filaLetraFinal
            case .instrumental:
                return linea.segments.compactMap { $0.chord.map(nombreLegible) }.joined(separator: "  ")
            case .letraPlana, .anotacion:
                let texto = FormatoLineaParser.reinsertarMarcas(linea.segments)
                return FormatoLineaParser.envolverAlineacion(texto, linea.alignment)
            }
        }.joined(separator: "\n")
    }

    static func aTextoPlano(_ content: ParsedSongContent) -> String {
        var resultado = ""
        for (indice, seccion) in content.sections.enumerated() {
            if indice > 0 {
                let blancos = max(1, seccion.separacionPrevia)
                resultado += String(repeating: "\n", count: blancos + 1)
                if seccion.separadorVisible {
                    resultado += "---\n"
                }
            }
            resultado += seccionATextoPlano(seccion)
        }
        return resultado
    }

    // MARK: Limpieza de título

    private static func limpiarTitulo(_ tituloCrudo: String) -> (limpio: String, bandera: String?) {
        var texto = tituloCrudo

        var bandera: String? = nil
        let scalars = Array(texto.unicodeScalars)
        var i = 0
        while i < scalars.count - 1 {
            if (0x1F1E6...0x1F1FF).contains(scalars[i].value),
               (0x1F1E6...0x1F1FF).contains(scalars[i + 1].value) {
                bandera = String(String.UnicodeScalarView([scalars[i], scalars[i + 1]]))
                break
            }
            i += 1
        }

        // Prefijo de lista numerada pegado al título (ej. "12.BABY I LOVE
        // YOUR WAY", típico de notas copiadas de un setlist numerado). Se
        // quita ANTES de comparar contra el repertorio — si no, el "." se
        // borra sin dejar espacio y el título queda pegado ("12baby..."),
        // rompiendo la sugerencia de artista en silencio.
        texto = texto.replacingOccurrences(of: #"^\d{1,3}[\.\)]\s*"#, with: "", options: .regularExpression)
        texto = texto.replacingOccurrences(of: #"^[A-Z]-\d+\s*"#, with: "", options: .regularExpression)

        var textoFiltrado = ""
        for scalar in texto.unicodeScalars {
            if scalar.value < 0x2190 || scalar.value > 0x1FAFF {
                textoFiltrado.unicodeScalars.append(scalar)
            }
        }
        textoFiltrado = textoFiltrado.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (textoFiltrado.isEmpty ? tituloCrudo : textoFiltrado, bandera)
    }

    // MARK: - Entrada principal

    static func parse(rawText rawTextOriginal: String, fileName: String) -> ParsedNoteResult {
        let rawText = rawTextOriginal.replacingOccurrences(of: "\u{00A0}", with: " ")
        var issues: [ImportIssue] = []

        let lineasCrudas = rawText.components(separatedBy: "\n")
        let lineasNoVacias = lineasCrudas.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let tituloCrudo = lineasNoVacias.first ?? fileName
        let (tituloLimpio, bandera) = limpiarTitulo(tituloCrudo)

        if rawText.contains("\u{FFFC}") {
            issues.append(ImportIssue(
                type: .contenidoPerdido,
                detalle: "La nota contenía un objeto incrustado (imagen/tabla) que se perdió al exportar a texto plano."
            ))
        }

        if lineasNoVacias.count <= 2 {
            issues.append(ImportIssue(
                type: .notaVaciaOBasura,
                detalle: "La nota tiene muy poco contenido (\(lineasNoVacias.count) líneas no vacías)."
            ))
        }

        let notacion = detectarNotacion(rawText)
        if notacion == .ninguna {
            issues.append(ImportIssue(
                type: .notacionAmbigua,
                detalle: "No se encontró evidencia clara de acordes en ninguna notación."
            ))
        }

        var lineasCuerpo = lineasCrudas
        if let idx = lineasCrudas.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            lineasCuerpo.remove(at: idx)
        }

        let (secciones, totalLineasAncladas) = parseCuerpo(lineasCuerpo, notacion: notacion)

        if totalLineasAncladas == 0 {
            let detalle = notacion == .ninguna
                ? "La nota no trae acordes; se importa como letra sola."
                : "Se detectó notación \(notacion.rawValue) pero ninguna línea de acorde pudo anclarse por sílaba a una línea de letra (puede ser solo un resumen/progresión, no un chart completo)."
            issues.append(ImportIssue(type: .sinAcordesAnclados, detalle: detalle))
        }

        let contentAST = ParsedSongContent(sections: secciones, notacionDetectada: notacion)

        return ParsedNoteResult(
            archivoOriginal: fileName,
            tituloCrudo: tituloCrudo,
            tituloLimpio: tituloLimpio,
            banderaPaisDetectada: bandera,
            contentAST: contentAST,
            requiereRevision: !issues.isEmpty,
            issues: issues
        )
    }
}
