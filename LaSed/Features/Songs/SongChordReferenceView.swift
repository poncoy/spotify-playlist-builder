//
//  SongChordReferenceView.swift
//  LaSed
//
//  Versión: 0.4.4
//  Actualizado: 10/09/2026
//
import SwiftUI

struct SongChordReferenceView: View {
    let content: ParsedSongContent
    @Environment(\.dismiss) private var dismiss

    private var acordesUnicos: [Chord] {
        var vistos = Set<String>()
        var resultado: [Chord] = []
        for seccion in content.sections {
            for linea in seccion.lines {
                for segmento in linea.segments {
                    guard let chord = segmento.chord else { continue }
                    let clave = [
                        chord.root, chord.accidental ?? "", chord.quality.rawValue,
                        chord.extensionNumero ?? "", chord.bassRoot ?? ""
                    ].joined(separator: "|")
                    if !vistos.contains(clave) {
                        vistos.insert(clave)
                        resultado.append(chord)
                    }
                }
            }
        }
        return resultado
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if acordesUnicos.isEmpty {
                    Text("Esta canción no tiene acordes detectados todavía.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 16) {
                        ForEach(Array(acordesUnicos.enumerated()), id: \.offset) { _, chord in
                            if let forma = GuitarChordLibrary.forma(para: chord) {
                                ChordDiagramView(nombre: nombreLegible(chord), forma: forma)
                            } else {
                                VStack(spacing: 4) {
                                    Text(nombreLegible(chord)).font(.headline)
                                    Text("Diagrama no disponible todavía")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 100, height: 90)
                                .padding(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Acordes de esta canción")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(width: 420, height: 480)
        #endif
    }

    private func nombreLegible(_ c: Chord) -> String {
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
}
