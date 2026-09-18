//
//  SongStyleSheetView.swift
//  LaSed
//
//  Versión: 0.4.16
//  Actualizado: 14/09/2026
//
import SwiftUI

struct SongStyleSheetView: View {
    @Binding var song: Song
    var content: ParsedSongContent?
    var onSave: (Song) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var mostrandoConfirmAplicarTodas = false
    @State private var errorMessage: String?

    @AppStorage(DisplayPreferenceKeys.fontSize) private var globalFontSize: Double = 15
    @AppStorage(DisplayPreferenceKeys.fontFamily) private var globalFontFamilyRaw: String = ChordFontFamily.sistema.rawValue
    @AppStorage(DisplayPreferenceKeys.lineSpacing) private var globalLineSpacing: Double = 0
    @AppStorage(DisplayPreferenceKeys.lineGap) private var globalLineGap: Double = 2
    @AppStorage(DisplayPreferenceKeys.sectionGap) private var globalSectionGap: Double = 18

    private var personalizado: Bool { song.styleFontFamily != nil }

    private var previewContent: ParsedSongContent? {
        guard let content, !content.sections.isEmpty else { return nil }
        return ParsedSongContent(
            sections: Array(content.sections.prefix(4)),
            notacionDetectada: content.notacionDetectada
        )
    }

    private var fontFamilyBinding: Binding<ChordFontFamily> {
        Binding(
            get: { ChordFontFamily(rawValue: song.styleFontFamily ?? globalFontFamilyRaw) ?? .sistema },
            set: { nuevo in
                song.styleFontFamily = nuevo.rawValue
                persistir()
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Estilo de esta canción")
                            .font(.headline)
                        Spacer()
                        Button("Listo") { dismiss() }
                    }

                    Toggle("Personalizar el estilo solo para esta canción", isOn: Binding(
                        get: { personalizado },
                        set: { activar in
                            if activar {
                                song.styleFontFamily = globalFontFamilyRaw
                                song.styleFontSize = globalFontSize
                                song.styleLineSpacing = globalLineSpacing
                                song.styleLineGap = globalLineGap
                                song.styleSectionGap = globalSectionGap
                            } else {
                                song.styleFontFamily = nil
                                song.styleFontSize = nil
                                song.styleLineSpacing = nil
                                song.styleLineGap = nil
                                song.styleSectionGap = nil
                            }
                            persistir()
                        }
                    ))

                    if personalizado {
                        control("Tamaño de letra", valor: song.styleFontSize ?? globalFontSize, sufijo: "pt", rango: 10...28) { nuevo in
                            song.styleFontSize = nuevo
                            persistir()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tipo de letra (siempre monoespaciada)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: fontFamilyBinding) {
                                ForEach(ChordFontFamily.allCases) { opcion in
                                    Text(opcion.displayName)
                                        .font(opcion.font(size: 16))
                                        .tag(opcion)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        control("Acorde ↔ su letra (misma línea)", valor: song.styleLineSpacing ?? globalLineSpacing, sufijo: "pt", rango: 0...16) { nuevo in
                            song.styleLineSpacing = nuevo
                            persistir()
                        }
                        control("Entre líneas de una estrofa", valor: song.styleLineGap ?? globalLineGap, sufijo: "pt", rango: 0...16) { nuevo in
                            song.styleLineGap = nuevo
                            persistir()
                        }
                        control("Entre estrofas / secciones", valor: song.styleSectionGap ?? globalSectionGap, sufijo: "pt", rango: 4...48) { nuevo in
                            song.styleSectionGap = nuevo
                            persistir()
                        }

                        Text("Mayúsculas/minúsculas sigue el ajuste global de la app (Ajustes de letra).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Divider()

                        Button("Aplicar este estilo a TODAS las canciones") {
                            mostrandoConfirmAplicarTodas = true
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Esta canción usa el ajuste global de la app (Ajustes de letra). Actívalo arriba para cambiar solo esta.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .frame(width: 320)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Vista previa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.top, .horizontal])

                if let previewContent {
                    ScrollView {
                        ChordChartView(content: previewContent, song: song)
                            .padding(.horizontal)
                    }
                } else {
                    Spacer()
                    Text("Esta canción no tiene letra cargada todavía.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 520)
        .confirmationDialog(
            "¿Aplicar este estilo a todas las canciones?",
            isPresented: $mostrandoConfirmAplicarTodas,
            titleVisibility: .visible
        ) {
            Button("Aplicar a todas", role: .destructive) { aplicarATodas() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esto se vuelve el estilo global de la app Y borra la personalización propia de TODAS las demás canciones (quedan usando este mismo estilo, como el global). No afecta mayúsculas/minúsculas.")
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

    private func aplicarATodas() {
        globalFontFamilyRaw = song.styleFontFamily ?? globalFontFamilyRaw
        globalFontSize = song.styleFontSize ?? globalFontSize
        globalLineSpacing = song.styleLineSpacing ?? globalLineSpacing
        globalLineGap = song.styleLineGap ?? globalLineGap
        globalSectionGap = song.styleSectionGap ?? globalSectionGap

        do {
            let repo = SongRepository()
            let todas = try repo.fetchAllActive()
            for var s in todas where s.id != song.id {
                s.styleFontFamily = nil
                s.styleFontSize = nil
                s.styleLineSpacing = nil
                s.styleLineGap = nil
                s.styleSectionGap = nil
                try repo.update(s)
            }
        } catch {
            errorMessage = "No se pudo aplicar a todas las canciones."
        }
    }

    private func persistir() {
        onSave(song)
    }

    @ViewBuilder
    private func control(_ titulo: String, valor: Double, sufijo: String, rango: ClosedRange<Double>, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(titulo): \(Int(valor)) \(sufijo)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: Binding(get: { valor }, set: onChange), in: rango, step: 1)
        }
    }
}
