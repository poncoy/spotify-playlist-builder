//
//  ChordChartView.swift
//  LaSed
//
//  Versión: 0.4.10
//  Actualizado: 11/09/2026
//
import SwiftUI

struct ChordChartView: View {
    let content: ParsedSongContent
    var song: Song? = nil

    @AppStorage(DisplayPreferenceKeys.fontSize) private var globalFontSize: Double = 15
    @AppStorage(DisplayPreferenceKeys.lineSpacing) private var globalLineSpacing: Double = 0
    @AppStorage(DisplayPreferenceKeys.lineGap) private var globalLineGap: Double = 2
    @AppStorage(DisplayPreferenceKeys.sectionGap) private var globalSectionGap: Double = 18
    @AppStorage(DisplayPreferenceKeys.letterCase) private var letterCaseRaw: String = LetterCasePreference.original.rawValue
    @AppStorage(DisplayPreferenceKeys.fontFamily) private var globalFontFamilyRaw: String = ChordFontFamily.sistema.rawValue

    // Efectivo: override de la canción (StyleSheet) si existe, si no el
    // global de la app. `song` es nil en el preview del importador (aún no
    // hay canción guardada) — ahí siempre se usa el global.
    private var fontSize: Double { song?.effectiveFontSize(global: globalFontSize) ?? globalFontSize }
    private var lineSpacingPref: Double { song?.effectiveLineSpacing(global: globalLineSpacing) ?? globalLineSpacing }
    private var lineGapPref: Double { song?.effectiveLineGap(global: globalLineGap) ?? globalLineGap }
    private var sectionGapPref: Double { song?.effectiveSectionGap(global: globalSectionGap) ?? globalSectionGap }

    private var letterCase: LetterCasePreference {
        LetterCasePreference(rawValue: letterCaseRaw) ?? .original
    }

    private var fontFamily: ChordFontFamily {
        song?.effectiveFontFamily(globalRaw: globalFontFamilyRaw) ?? (ChordFontFamily(rawValue: globalFontFamilyRaw) ?? .sistema)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(nombreNotacion(content.notacionDetectada), systemImage: "music.quarternote.3")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(content.sections.enumerated()), id: \.offset) { indice, seccion in
                        if indice > 0 {
                            separadorDeSeccion(seccion)
                        }
                        VStack(alignment: .leading, spacing: lineGapPref) {
                            ForEach(Array(seccion.lines.enumerated()), id: \.offset) { _, linea in
                                vistaDeLinea(linea)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func separadorDeSeccion(_ seccion: ParsedSection) -> some View {
        let multiplicador = Double(min(5, max(1, seccion.separacionPrevia)))
        let alto = min(sectionGapPref * multiplicador, 90)
        if seccion.separadorVisible {
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: 1, idealHeight: 1, maxHeight: 1)
                .padding(.vertical, alto / 2)
        } else {
            Color.clear.frame(height: alto)
        }
    }

    @ViewBuilder
    private func vistaDeLinea(_ linea: ParsedLine) -> some View {
        switch linea.type {
        case .letraConAcordes:
            VStack(alignment: .leading, spacing: lineSpacingPref) {
                Text(lineaDeAcordesTexto(linea.segments))
                    .font(fontFamily.font(size: fontSize))
                    .foregroundStyle(.blue)
                Text(NotesImportParser.segmentosAAttributed(linea.segments, fontSize: fontSize, fontFamily: fontFamily))
                    .font(fontFamily.font(size: fontSize))
                    .textCase(letterCase.textCase)
            }
            .frame(maxWidth: .infinity, alignment: marcoDeAlineacion(linea.alignment))
        case .instrumental:
            Text(linea.segments.compactMap { $0.chord.map(nombreLegibleDeAcorde) }.joined(separator: "  "))
                .font(fontFamily.font(size: fontSize))
                .foregroundStyle(.blue)
        case .letraPlana:
            Text(NotesImportParser.segmentosAAttributed(linea.segments, fontSize: fontSize, fontFamily: fontFamily))
                .font(fontFamily.font(size: fontSize))
                .textCase(letterCase.textCase)
                .frame(maxWidth: .infinity, alignment: marcoDeAlineacion(linea.alignment))
        case .anotacion:
            Text(linea.segments.first?.text ?? "")
                .font(fontFamily.font(size: fontSize * 0.85, cursiva: true))
                .foregroundStyle(.secondary)
        }
    }

    private func marcoDeAlineacion(_ alineacion: ParagraphAlignment?) -> Alignment {
        switch alineacion {
        case .center: return .center
        case .right: return .trailing
        case .left, nil: return .leading
        }
    }

    private func lineaDeAcordesTexto(_ segments: [LineSegment]) -> String {
        segments.map { seg -> String in
            guard let chord = seg.chord else {
                return String(repeating: " ", count: seg.text.count)
            }
            let nombre = nombreLegibleDeAcorde(chord)
            let relleno = max(0, seg.text.count - nombre.count)
            return nombre + String(repeating: " ", count: relleno)
        }.joined()
    }

    private func nombreNotacion(_ n: NotacionAcorde) -> String {
        switch n {
        case .inglesa: return "Acordes: letras (C, D, E…)"
        case .solfeo: return "Acordes: solfeo (Do, Re, Mi…)"
        case .ninguna: return "Sin acordes"
        }
    }

    private func nombreLegibleDeAcorde(_ c: Chord) -> String {
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
