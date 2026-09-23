//
//  DisplaySettingsView.swift
//  LaSed
//
//  Versión: 0.4.10
//  Actualizado: 11/09/2026
//
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum LetterCasePreference: String, CaseIterable, Identifiable {
    case original
    case mayusculas
    case minusculas

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Original"
        case .mayusculas: return "MAYÚSCULAS"
        case .minusculas: return "minúsculas"
        }
    }

    var textCase: Text.Case? {
        switch self {
        case .original: return nil
        case .mayusculas: return .uppercase
        case .minusculas: return .lowercase
        }
    }
}

enum DisplayPreferenceKeys {
    static let fontSize = "display.fontSize"
    static let lineSpacing = "display.lineSpacing"
    static let lineGap = "display.lineGap"
    static let sectionGap = "display.sectionGap"
    static let letterCase = "display.letterCase"
    static let fontFamily = "display.fontFamily"
}

/// Familias de letra disponibles para letra + acordes. SIEMPRE
/// monoespaciadas a propósito — el anclaje de acordes por columna de
/// carácter (NotesImportParser.anclarAcordesALinea) asume que cada
/// carácter mide exactamente lo mismo. Una fuente proporcional rompe la
/// alineación visual acorde/sílaba por completo, así que esta lista NUNCA
/// debe incluir una fuente que no sea monoespaciada.
///
/// (probable) Los nombres PostScript de negrita/cursiva de Menlo/Monaco/
/// Courier/Courier New son los estándar de Apple, pero no los verifiqué en
/// tu máquina exacta (sin toolchain). Si alguna combinación se ve rara,
/// cónfirmalo en Font Book buscando el nombre PostScript real.
nonisolated enum ChordFontFamily: String, CaseIterable, Identifiable {
    case sistema, menlo, monaco, courierNew, courier, andaleMono, ocrA

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sistema: return "Sistema (SF Mono)"
        case .menlo: return "Menlo"
        case .monaco: return "Monaco"
        case .courierNew: return "Courier New"
        case .courier: return "Courier"
        case .andaleMono: return "Andale Mono"
        case .ocrA: return "OCR A Std"
        }
    }

    /// (suposición) Andale Mono y OCR A Std son clásicas de macOS pero NO
    /// las verifiqué en tu máquina ni confío en que existan igual en
    /// iPhone/iPad (target multiplataforma). Si al elegirlas el texto se
    /// ve con una fuente random, es que el nombre no existe ahí —
    /// Font.custom() sustituye en silencio, no truena. Quita la opción de
    /// este enum si pasa eso.
    private func nombrePostScript(negrita: Bool, cursiva: Bool) -> String? {
        switch self {
        case .sistema:
            return nil
        case .menlo:
            switch (negrita, cursiva) {
            case (true, true): return "Menlo-BoldItalic"
            case (true, false): return "Menlo-Bold"
            case (false, true): return "Menlo-Italic"
            case (false, false): return "Menlo-Regular"
            }
        case .monaco:
            // Monaco no tiene variante curva/itálica real en macOS — si se
            // pide cursiva, se queda en Monaco regular (mejor que fallar
            // en silencio a otra fuente por completo).
            return negrita ? "Monaco-Bold" : "Monaco"
        case .courierNew:
            switch (negrita, cursiva) {
            case (true, true): return "CourierNewPS-BoldItalicMT"
            case (true, false): return "CourierNewPS-BoldMT"
            case (false, true): return "CourierNewPS-ItalicMT"
            case (false, false): return "CourierNewPSMT"
            }
        case .courier:
            switch (negrita, cursiva) {
            case (true, true): return "Courier-BoldOblique"
            case (true, false): return "Courier-Bold"
            case (false, true): return "Courier-Oblique"
            case (false, false): return "Courier"
            }
        case .andaleMono, .ocrA:
            // Fuentes de un solo peso, sin negrita/cursiva real conocida.
            // Nunca se inventa un nombre "-Bold" que probablemente no
            // existe — se queda en la regular siempre, aunque el usuario
            // haya pedido negrita/cursiva (mejor eso que sustituir a una
            // fuente completamente distinta sin avisar).
            return self == .andaleMono ? "AndaleMono" : "OCRAStd"
        }
    }

    func font(size: Double, negrita: Bool = false, cursiva: Bool = false) -> Font {
        guard let nombre = nombrePostScript(negrita: negrita, cursiva: cursiva) else {
            var f = Font.system(size: size, design: .monospaced)
            // .weight(.heavy) en vez de .bold() (= .weight(.bold)): a este
            // tamaño de letra .bold se sentía muy sutil, pedido explícito
            // del usuario de que la negrita "se sienta más".
            if negrita { f = f.weight(.heavy) }
            if cursiva { f = f.italic() }
            return f
        }
        return .custom(nombre, size: size)
    }

    #if os(iOS)
    /// Mismo criterio que `font(size:negrita:cursiva:)` pero devolviendo un
    /// `UIFont` real — lo necesita el editor de iOS (`SongContentEditorView`)
    /// porque ahí el negrita/cursiva se detecta leyendo los symbolic traits
    /// de la fuente de cada tramo, no un `Font` de SwiftUI.
    func uiFont(size: Double, negrita: Bool = false, cursiva: Bool = false) -> UIFont {
        guard let nombre = nombrePostScript(negrita: negrita, cursiva: cursiva) else {
            let base = UIFont.monospacedSystemFont(ofSize: size, weight: negrita ? .heavy : .regular)
            guard cursiva, let descriptorCursivo = base.fontDescriptor.withSymbolicTraits(.traitItalic) else {
                return base
            }
            return UIFont(descriptor: descriptorCursivo, size: size)
        }
        return UIFont(name: nombre, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: negrita ? .heavy : .regular)
    }
    #endif
}

struct DisplaySettingsView: View {
    @AppStorage(DisplayPreferenceKeys.fontSize) private var fontSize: Double = 15
    @AppStorage(DisplayPreferenceKeys.lineSpacing) private var lineSpacing: Double = 0
    @AppStorage(DisplayPreferenceKeys.lineGap) private var lineGap: Double = 2
    @AppStorage(DisplayPreferenceKeys.sectionGap) private var sectionGap: Double = 18
    @AppStorage(DisplayPreferenceKeys.letterCase) private var letterCaseRaw: String = LetterCasePreference.original.rawValue
    @AppStorage(DisplayPreferenceKeys.fontFamily) private var fontFamilyRaw: String = ChordFontFamily.sistema.rawValue

    @Environment(\.dismiss) private var dismiss

    private var letterCaseBinding: Binding<LetterCasePreference> {
        Binding(
            get: { LetterCasePreference(rawValue: letterCaseRaw) ?? .original },
            set: { letterCaseRaw = $0.rawValue }
        )
    }

    private var fontFamilyBinding: Binding<ChordFontFamily> {
        Binding(
            get: { ChordFontFamily(rawValue: fontFamilyRaw) ?? .sistema },
            set: { fontFamilyRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Ajustes de letra")
                        .font(.headline)
                    Spacer()
                    Button("Listo") { dismiss() }
                }

                control("Tamaño de letra", valor: fontSize, sufijo: "pt", binding: $fontSize, rango: 10...28)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tipo de letra (siempre monoespaciada, para que el acorde quede alineado sobre la sílaba)")
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

                control("Acorde ↔ su letra (misma línea)", valor: lineSpacing, sufijo: "pt", binding: $lineSpacing, rango: 0...16)
                control("Entre líneas de una estrofa", valor: lineGap, sufijo: "pt", binding: $lineGap, rango: 0...16)
                control("Entre estrofas / secciones", valor: sectionGap, sufijo: "pt", binding: $sectionGap, rango: 4...48)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mayúsculas / minúsculas (solo la letra, nunca los acordes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: letterCaseBinding) {
                        ForEach(LetterCasePreference.allCases) { opcion in
                            Text(opcion.label).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                Text("Vista previa")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: lineGap) {
                        parLinea("C                    G", "que el tiempo es muy poco")
                        parLinea("Am                   F", "y hay tanto que decir")
                    }
                    Color.clear.frame(height: min(sectionGap, 90))
                    VStack(alignment: .leading, spacing: lineGap) {
                        parLinea("F                    C", "otra estrofa distinta")
                        parLinea("G                    Am", "para ver el corte real")
                    }
                }
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 340, minHeight: 480)
        #endif
    }

    @ViewBuilder
    private func control(_ titulo: String, valor: Double, sufijo: String, binding: Binding<Double>, rango: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(titulo): \(Int(valor)) \(sufijo)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: binding, in: rango, step: 1)
        }
    }

    @ViewBuilder
    private func parLinea(_ acordes: String, _ letra: String) -> some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            Text(acordes)
                .font(fontFamilyBinding.wrappedValue.font(size: fontSize))
                .foregroundStyle(.blue)
            Text(letra)
                .font(fontFamilyBinding.wrappedValue.font(size: fontSize))
                .textCase(letterCaseBinding.wrappedValue.textCase)
        }
    }
}
