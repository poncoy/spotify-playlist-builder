//
//  ArtistSuggestionService.swift
//  LaSed
//
//  Versión: 0.3.2
//  Actualizado: 11/09/2026
//
import Foundation

struct SugerenciaArtista {
    let artista: String
    let tituloConocido: String
    let confianza: Double
    let pareceEnVivo: Bool
    /// No-nil cuando otro artista DISTINTO tiene un score casi igual al
    /// mejor (mismo título, cover/versión de otro autor — ej. "Quedate"
    /// de Christian Meier vs "Quédate" de Zen, idénticos tras normalizar).
    /// Nunca se auto-elige uno solo en ese caso; la UI debe avisar.
    let artistaAlternativo: (artista: String, tituloConocido: String, confianza: Double)?
}

final class ArtistSuggestionService {
    static let shared = ArtistSuggestionService()

    private let repertorio: [(titulo: String, artista: String)]
    private let umbralMinimo = 0.6
    private let margenAmbiguedad = 0.05

    private init() {
        repertorio = Self.cargarDesdeCSV()
    }

    private static func cargarDesdeCSV() -> [(titulo: String, artista: String)] {
        guard let url = Bundle.main.url(forResource: "RepertorioConocido", withExtension: "csv") else {
            print("⚠️ RepertorioConocido.csv no está en el bundle. Agrégalo al proyecto (Copy Bundle Resources).")
            return []
        }
        guard let contenido = try? String(contentsOf: url, encoding: .utf8) else {
            print("⚠️ No se pudo leer RepertorioConocido.csv")
            return []
        }

        var resultado: [(String, String)] = []
        let lineas = contenido.components(separatedBy: "\n")
        for (indice, linea) in lineas.enumerated() {
            guard indice > 0 else { continue }  // salta encabezado
            let limpia = linea.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !limpia.isEmpty else { continue }
            let campos = parsearLineaCSV(limpia)
            guard campos.count >= 2, !campos[0].isEmpty, !campos[1].isEmpty else { continue }
            resultado.append((campos[0], campos[1]))
        }
        return resultado
    }

    /// Parser CSV simple: soporta comillas dobles para campos con comas (ej. títulos con coma).
    private static func parsearLineaCSV(_ linea: String) -> [String] {
        var campos: [String] = []
        var actual = ""
        var dentroDeComillas = false
        for char in linea {
            if char == "\"" {
                dentroDeComillas.toggle()
            } else if char == "," && !dentroDeComillas {
                campos.append(actual)
                actual = ""
            } else {
                actual.append(char)
            }
        }
        campos.append(actual)
        return campos
    }

    func sugerirArtista(paraTitulo titulo: String) -> SugerenciaArtista? {
        guard !repertorio.isEmpty else { return nil }
        let tituloNormalizado = normalizar(titulo)
        guard !tituloNormalizado.isEmpty else { return nil }

        // Mejor score POR ARTISTA (no por fila) — dos filas del mismo
        // artista (ej. estudio + vivo) no deben marcarse como ambiguas
        // entre sí, solo artistas DISTINTOS con score casi igual.
        var mejorPorArtista: [String: (titulo: String, score: Double)] = [:]
        for par in repertorio {
            for variante in variantesNormalizadas(par.titulo) {
                let score = similitud(tituloNormalizado, variante)
                if score > (mejorPorArtista[par.artista]?.score ?? 0) {
                    mejorPorArtista[par.artista] = (par.titulo, score)
                }
            }
        }

        let candidatos = mejorPorArtista
            .map { (artista: $0.key, titulo: $0.value.titulo, score: $0.value.score) }
            .sorted { $0.score > $1.score }

        guard let mejor = candidatos.first, mejor.score >= umbralMinimo else { return nil }

        let palabrasEnVivo = ["vivo", "live", "gira", "tour", "unplugged", "concierto"]
        func esEnVivo(_ t: String) -> Bool {
            let l = t.lowercased()
            return palabrasEnVivo.contains { l.contains($0) }
        }

        var alternativo: (artista: String, tituloConocido: String, confianza: Double)? = nil
        if candidatos.count > 1 {
            let segundo = candidatos[1]
            if segundo.score >= umbralMinimo, (mejor.score - segundo.score) < margenAmbiguedad {
                alternativo = (segundo.artista, segundo.titulo, segundo.score)
            }
        }

        return SugerenciaArtista(
            artista: mejor.artista,
            tituloConocido: mejor.titulo,
            confianza: mejor.score,
            pareceEnVivo: esEnVivo(mejor.titulo),
            artistaAlternativo: alternativo
        )
    }

    /// Autocompletar simple para el campo manual de artista (pedido: "sería
    /// cool que se propongan artistas candidatos... como un predictivo").
    /// Distinto de sugerirArtista(): aquí no se compara el TÍTULO de la
    /// canción, se filtran los NOMBRES de artista del repertorio que
    /// contienen el texto que el usuario ya escribió — sin Levenshtein, es
    /// una coincidencia de substring normalizado, más barata y más
    /// predecible mientras se escribe letra por letra.
    func artistasCandidatos(paraTexto texto: String, limite: Int = 6) -> [String] {
        let query = normalizar(texto)
        guard !query.isEmpty else { return [] }
        let distintos = Set(repertorio.map(\.artista))
        return distintos
            .filter { normalizar($0).contains(query) }
            .sorted { a, b in
                let aEmpieza = normalizar(a).hasPrefix(query)
                let bEmpieza = normalizar(b).hasPrefix(query)
                if aEmpieza != bEmpieza { return aEmpieza }
                return a.localizedStandardCompare(b) == .orderedAscending
            }
            .prefix(limite)
            .map { $0 }
    }

    // MARK: - Normalización y variantes (sin lista de palabras de ruido)

    /// Muchos títulos de tu Excel traen sufijos pegados con " - " que no son
    /// parte del título real: nombre de gira ("Prófugos - Gira Me Verás
    /// Volver"), remaster ("Hotel California - 2013 Remaster"), álbum en
    /// vivo, etc. En vez de mantener una lista de palabras clave (frágil,
    /// siempre va a faltar una), se compara SIEMPRE contra el título completo
    /// Y contra la parte antes del primer " - ", y se toma el mejor score.
    private func variantesNormalizadas(_ titulo: String) -> [String] {
        var variantes = [normalizar(titulo)]
        if let rango = titulo.range(of: " - ") {
            variantes.append(normalizar(String(titulo[..<rango.lowerBound])))
        }
        return variantes
    }

    private func normalizar(_ texto: String) -> String {
        let sinParentesis = texto.replacingOccurrences(of: #"\(.*?\)|\[.*?\]"#, with: "", options: .regularExpression)
        let sinAcentos = sinParentesis.folding(options: .diacriticInsensitive, locale: .current)
        // Reemplaza (no borra) cualquier carácter que no sea letra/número
        // por un espacio. Antes se borraba directo con .filter, lo que
        // fusionaba palabras cuando había puntuación pegada (ej. "12.Baby"
        // -> "12baby", nunca matcheaba contra el repertorio limpio). Esto es
        // una segunda defensa aparte del fix en limpiarTitulo() — esta
        // función no debería confiar en que el llamador ya vino limpio.
        var resultado = ""
        for char in sinAcentos.lowercased() {
            if char.isLetter || char.isNumber {
                resultado.append(char)
            } else {
                resultado.append(" ")
            }
        }
        resultado = resultado.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return resultado.trimmingCharacters(in: .whitespaces)
    }

    /// Similitud basada en distancia de Levenshtein normalizada (1.0 = idéntico, 0.0 = nada en común).
    private func similitud(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        let distancia = levenshtein(Array(a), Array(b))
        let largoMax = max(a.count, b.count)
        guard largoMax > 0 else { return 0 }
        return 1.0 - (Double(distancia) / Double(largoMax))
    }

    private func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        var previo = Array(0...n)
        var actual = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            actual[0] = i
            for j in 1...n {
                let costo = a[i - 1] == b[j - 1] ? 0 : 1
                actual[j] = min(
                    previo[j] + 1,
                    actual[j - 1] + 1,
                    previo[j - 1] + costo
                )
            }
            previo = actual
        }
        return previo[n]
    }
}
