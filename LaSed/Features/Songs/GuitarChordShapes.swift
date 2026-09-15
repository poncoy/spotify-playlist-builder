//
//  GuitarChordShapes.swift
//  LaSed
//
//  Versión app:  0.4.4
//  Fase:         3 — Librería de acordes (guitarra)
//  Modificado:   10/09/2026 (Lima)
//
//  Digitaciones en afinación estándar. Cobertura: mayor, menor y séptima
//  dominante en las 12 raíces (posición abierta si existe, cejilla CAGED
//  movible si no). Fuera de alcance a propósito: dim, aug, sus, add, m7,
//  acordes con bajo — mejor no mostrar nada que mostrar una digitación
//  incorrecta en un instrumento real.

import Foundation

struct GuitarChordShape {
    /// Trastes por cuerda, 6ta (Mi grave) a 1ra (Mi agudo). nil = muda, 0 = al aire.
    let frets: [Int?]
    let baseFret: Int
    let esCejilla: Bool
}

enum GuitarChordLibrary {

    private static let semitonos: [String: Int] = [
        "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
        "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
    ]

    private static let equivalenteBemol: [String: String] = [
        "Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#", "Cb": "B", "Fb": "E"
    ]

    private static let abiertos: [String: GuitarChordShape] = [
        "C-mayor": GuitarChordShape(frets: [nil, 3, 2, 0, 1, 0], baseFret: 1, esCejilla: false),
        "D-mayor": GuitarChordShape(frets: [nil, nil, 0, 2, 3, 2], baseFret: 1, esCejilla: false),
        "E-mayor": GuitarChordShape(frets: [0, 2, 2, 1, 0, 0], baseFret: 1, esCejilla: false),
        "G-mayor": GuitarChordShape(frets: [3, 2, 0, 0, 0, 3], baseFret: 1, esCejilla: false),
        "A-mayor": GuitarChordShape(frets: [nil, 0, 2, 2, 2, 0], baseFret: 1, esCejilla: false),
        "A-menor": GuitarChordShape(frets: [nil, 0, 2, 2, 1, 0], baseFret: 1, esCejilla: false),
        "D-menor": GuitarChordShape(frets: [nil, nil, 0, 2, 3, 1], baseFret: 1, esCejilla: false),
        "E-menor": GuitarChordShape(frets: [0, 2, 2, 0, 0, 0], baseFret: 1, esCejilla: false),
        "A-dominante7": GuitarChordShape(frets: [nil, 0, 2, 0, 2, 0], baseFret: 1, esCejilla: false),
        "B-dominante7": GuitarChordShape(frets: [nil, 2, 1, 2, 0, 2], baseFret: 1, esCejilla: false),
        "C-dominante7": GuitarChordShape(frets: [nil, 3, 2, 3, 1, 0], baseFret: 1, esCejilla: false),
        "D-dominante7": GuitarChordShape(frets: [nil, nil, 0, 2, 1, 2], baseFret: 1, esCejilla: false),
        "E-dominante7": GuitarChordShape(frets: [0, 2, 0, 1, 0, 0], baseFret: 1, esCejilla: false),
        "G-dominante7": GuitarChordShape(frets: [3, 2, 0, 0, 0, 1], baseFret: 1, esCejilla: false)
    ]

    // Formas movibles CAGED (cejilla en traste n).
    private static func formaEMayor(_ n: Int) -> [Int?] { [n, n + 2, n + 2, n + 1, n, n] }
    private static func formaEMenor(_ n: Int) -> [Int?] { [n, n + 2, n + 2, n, n, n] }
    private static func formaEDominante7(_ n: Int) -> [Int?] { [n, n + 2, n, n + 1, n, n] }
    private static func formaAMayor(_ n: Int) -> [Int?] { [nil, n, n + 2, n + 2, n + 2, n] }
    private static func formaAMenor(_ n: Int) -> [Int?] { [nil, n, n + 2, n + 2, n + 1, n] }
    private static func formaADominante7(_ n: Int) -> [Int?] { [nil, n, n + 2, n, n + 2, n] }

    private static func notaNormalizada(_ root: String, _ accidental: String?) -> String {
        let combinado = root + (accidental ?? "")
        return equivalenteBemol[combinado] ?? combinado
    }

    private static func distancia(desde origen: String, hasta destino: String) -> Int? {
        guard let a = semitonos[origen], let b = semitonos[destino] else { return nil }
        return (b - a + 12) % 12
    }

    static func forma(para chord: Chord) -> GuitarChordShape? {
        guard chord.bassRoot == nil else { return nil }
        let nota = notaNormalizada(chord.root, chord.accidental)

        let clave: String
        switch (chord.quality, chord.extensionNumero) {
        case (.mayor, nil): clave = "\(nota)-mayor"
        case (.menor, nil): clave = "\(nota)-menor"
        case (.mayor, "7"): clave = "\(nota)-dominante7"
        default: return nil
        }

        if let abierta = abiertos[clave] { return abierta }

        guard let nDesdeE = distancia(desde: "E", hasta: nota),
              let nDesdeA = distancia(desde: "A", hasta: nota),
              nDesdeE > 0, nDesdeA > 0 else { return nil }

        let candidatoE: [Int?]
        let candidatoA: [Int?]
        switch (chord.quality, chord.extensionNumero) {
        case (.mayor, nil):
            candidatoE = formaEMayor(nDesdeE)
            candidatoA = formaAMayor(nDesdeA)
        case (.menor, nil):
            candidatoE = formaEMenor(nDesdeE)
            candidatoA = formaAMenor(nDesdeA)
        case (.mayor, "7"):
            candidatoE = formaEDominante7(nDesdeE)
            candidatoA = formaADominante7(nDesdeA)
        default:
            return nil
        }

        if nDesdeE <= nDesdeA {
            return GuitarChordShape(frets: candidatoE, baseFret: nDesdeE, esCejilla: true)
        } else {
            return GuitarChordShape(frets: candidatoA, baseFret: nDesdeA, esCejilla: true)
        }
    }
}
