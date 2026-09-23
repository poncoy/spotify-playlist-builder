//
//  SongContentEditorView.swift
//  LaSed
//
//  Versión: 0.5.0
//  Actualizado: 23/09/2026
//
//  En Mac usa TextEditor(text:selection:) + AttributedTextSelection, la API
//  nativa de SwiftUI — pero es exclusiva de iOS/macOS 26+. En iOS (para
//  poder correr en dispositivos con OS más viejo, ej. iPad en iOS 18) usa
//  un UITextView de UIKit directo. Las dos versiones comparten la misma
//  entrada/salida (`AttributedString` con los atributos `laSed.bold`/
//  `.italic`) para que `NotesImportParser.parseCuerpo` no tenga que
//  distinguir de dónde vino el texto.
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SongContentEditorView: View {
    @Binding var attributedText: AttributedString
    var song: Song? = nil
    var onSave: (AttributedString) -> Void
    var onCancel: () -> Void

    #if os(macOS)
    @State private var selection = AttributedTextSelection()
    #else
    @State private var nsText: NSAttributedString = NSAttributedString()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    #endif
    @State private var mostrandoColorTexto = false
    @State private var mostrandoResaltado = false
    @State private var mostrandoAjustesFuente = false
    @AppStorage(DisplayPreferenceKeys.fontSize) private var globalFontSize: Double = 15
    @AppStorage(DisplayPreferenceKeys.fontFamily) private var globalFontFamilyRaw: String = ChordFontFamily.sistema.rawValue

    private var fontSize: Double { song?.effectiveFontSize(global: globalFontSize) ?? globalFontSize }
    private var fontFamily: ChordFontFamily {
        song?.effectiveFontFamily(globalRaw: globalFontFamilyRaw) ?? (ChordFontFamily(rawValue: globalFontFamilyRaw) ?? .sistema)
    }

    var body: some View {
        VStack(spacing: 0) {
            barraDeAcciones
            barraDeFormato

            #if os(macOS)
            TextEditor(text: $attributedText, selection: $selection)
                .textEditorStyle(.plain)
                .font(fontFamily.font(size: fontSize))
                .autocorrectionDisabled()
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            EditorUITextView(nsText: $nsText, selectedRange: $selectedRange)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { nsText = NSAttributedString(attributedText) }
            #endif
        }
    }

    private var barraDeAcciones: some View {
        HStack {
            Button("Cancelar", role: .cancel) { onCancel() }
            Spacer()
            Label("Editando contenido", systemImage: "pencil.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Spacer()
            #if os(macOS)
            Button("Guardar") { onSave(attributedText) }
                .buttonStyle(.borderedProminent)
            #else
            Button("Guardar") { onSave(construirAttributedStringParaGuardar()) }
                .buttonStyle(.borderedProminent)
            #endif
        }
        .padding()
        .background(Color.orange.opacity(0.12))
    }

    private var barraDeFormato: some View {
        HStack(spacing: 20) {
            Button {
                mostrandoAjustesFuente = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Ajuste global de tamaño/tipo de letra (afecta TODAS las canciones sin estilo propio) — para el estilo solo de esta canción, hazlo desde la vista de lectura, no aquí")
            .sheet(isPresented: $mostrandoAjustesFuente) {
                DisplaySettingsView()
            }

            Divider().frame(height: 20)

            Button {
                toggleNegrita()
            } label: {
                Image(systemName: "bold")
            }
            .help("Negrita")

            Button {
                toggleCursiva()
            } label: {
                Image(systemName: "italic")
            }
            .help("Cursiva")

            Button {
                mostrandoColorTexto = true
            } label: {
                Image(systemName: "character")
            }
            .help("Color de letra")
            .popover(isPresented: $mostrandoColorTexto) {
                selectorDeColor { color in
                    aplicarColorTexto(color)
                    mostrandoColorTexto = false
                }
            }

            Button {
                mostrandoResaltado = true
            } label: {
                Image(systemName: "highlighter")
            }
            .help("Resaltado")
            .popover(isPresented: $mostrandoResaltado) {
                selectorDeColor { color in
                    aplicarResaltado(color)
                    mostrandoResaltado = false
                }
            }

            Spacer()

            Button {
                quitarFormato()
            } label: {
                Image(systemName: "eraser")
            }
            .help("Quitar formato de la selección")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
    }

    // MARK: - Acciones de formato (macOS — AttributedTextSelection)

    #if os(macOS)
    private func toggleNegrita() {
        attributedText.transformAttributes(in: &selection) { contenedor in
            // (seguro) La decisión de "ya está en negrita" sale del flag
            // propio laSed.bold, nunca de Font.resolve().isBold (se rompe
            // con "Texto en negrita" de Accesibilidad). El font final se
            // arma completo con fontFamily, combinando negrita Y cursiva a
            // la vez — necesario para fuentes con nombre fijo (Menlo, etc.)
            // donde negrita/cursiva son archivos distintos, no un modifier.
            let negritaNueva = !(contenedor.laSed.bold ?? false)
            let cursivaActual = contenedor.laSed.italic ?? false
            contenedor.laSed.bold = negritaNueva
            contenedor.font = fontFamily.font(size: fontSize, negrita: negritaNueva, cursiva: cursivaActual)
        }
    }

    private func toggleCursiva() {
        attributedText.transformAttributes(in: &selection) { contenedor in
            let cursivaNueva = !(contenedor.laSed.italic ?? false)
            let negritaActual = contenedor.laSed.bold ?? false
            contenedor.laSed.italic = cursivaNueva
            contenedor.font = fontFamily.font(size: fontSize, negrita: negritaActual, cursiva: cursivaNueva)
        }
    }

    private func aplicarColorTexto(_ color: MarkColor) {
        attributedText.transformAttributes(in: &selection) { contenedor in
            contenedor.foregroundColor = color.color
        }
    }

    private func aplicarResaltado(_ color: MarkColor) {
        attributedText.transformAttributes(in: &selection) { contenedor in
            contenedor.backgroundColor = color.color
        }
    }

    private func quitarFormato() {
        attributedText.transformAttributes(in: &selection) { contenedor in
            contenedor.font = fontFamily.font(size: fontSize)
            contenedor.foregroundColor = nil
            contenedor.backgroundColor = nil
            contenedor.laSed.bold = nil
            contenedor.laSed.italic = nil
        }
    }
    #endif

    // MARK: - Acciones de formato (iOS — NSAttributedString/UITextView)

    #if os(iOS)
    /// Aplica `transformar` a cada tramo de fuente uniforme dentro de la
    /// selección — igual que `transformAttributes(in:)` en Mac, cada tramo
    /// se evalúa por separado (si la selección mezcla negrita y normal,
    /// cada uno alterna independiente, no se unifica).
    private func transformarSeleccion(_ transformar: (UIFont, NSMutableAttributedString, NSRange) -> Void) {
        guard selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: nsText)
        mutable.enumerateAttribute(.font, in: selectedRange, options: []) { valor, rango, _ in
            let fuenteActual = (valor as? UIFont) ?? fontFamily.uiFont(size: fontSize)
            transformar(fuenteActual, mutable, rango)
        }
        nsText = mutable
    }

    private func toggleNegrita() {
        transformarSeleccion { fuenteActual, mutable, rango in
            let negritaActual = fuenteActual.fontDescriptor.symbolicTraits.contains(.traitBold)
            let cursivaActual = fuenteActual.fontDescriptor.symbolicTraits.contains(.traitItalic)
            mutable.addAttribute(.font, value: fontFamily.uiFont(size: fontSize, negrita: !negritaActual, cursiva: cursivaActual), range: rango)
        }
    }

    private func toggleCursiva() {
        transformarSeleccion { fuenteActual, mutable, rango in
            let negritaActual = fuenteActual.fontDescriptor.symbolicTraits.contains(.traitBold)
            let cursivaActual = fuenteActual.fontDescriptor.symbolicTraits.contains(.traitItalic)
            mutable.addAttribute(.font, value: fontFamily.uiFont(size: fontSize, negrita: negritaActual, cursiva: !cursivaActual), range: rango)
        }
    }

    private func aplicarColorTexto(_ color: MarkColor) {
        guard selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: nsText)
        mutable.addAttribute(.foregroundColor, value: UIColor(color.color), range: selectedRange)
        nsText = mutable
    }

    private func aplicarResaltado(_ color: MarkColor) {
        guard selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: nsText)
        mutable.addAttribute(.backgroundColor, value: UIColor(color.color), range: selectedRange)
        nsText = mutable
    }

    private func quitarFormato() {
        guard selectedRange.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: nsText)
        mutable.setAttributes([.font: fontFamily.uiFont(size: fontSize)], range: selectedRange)
        nsText = mutable
    }

    /// Convierte el `NSAttributedString` de vuelta a `AttributedString` con
    /// los atributos `laSed.bold`/`.italic` que `NotesImportParser.
    /// parseCuerpo` necesita para armar el AST — acá el bold/italic sale
    /// directo de los symbolic traits reales de la UIFont de cada tramo:
    /// UIKit no tiene el problema de "Texto en negrita" de Accesibilidad
    /// que en Mac obliga a usar esa bandera aparte en vez de confiar en
    /// Font.resolve().
    private func construirAttributedStringParaGuardar() -> AttributedString {
        var resultado = AttributedString()
        nsText.enumerateAttributes(in: NSRange(location: 0, length: nsText.length), options: []) { atributos, rango, _ in
            let texto = (nsText.string as NSString).substring(with: rango)
            var tramo = AttributedString(texto)
            let fuente = (atributos[.font] as? UIFont) ?? fontFamily.uiFont(size: fontSize)
            let negrita = fuente.fontDescriptor.symbolicTraits.contains(.traitBold)
            let cursiva = fuente.fontDescriptor.symbolicTraits.contains(.traitItalic)
            tramo.font = fontFamily.font(size: fontSize, negrita: negrita, cursiva: cursiva)
            if negrita { tramo.laSed.bold = true }
            if cursiva { tramo.laSed.italic = true }
            if let color = atributos[.foregroundColor] as? UIColor {
                tramo.foregroundColor = Color(color)
            }
            if let resaltado = atributos[.backgroundColor] as? UIColor {
                tramo.backgroundColor = Color(resaltado)
            }
            resultado += tramo
        }
        return resultado
    }
    #endif

    /// Reemplaza los íconos de color dentro de un `Menu` nativo: esos
    /// salían siempre blancos porque macOS/iOS renderiza los íconos de un
    /// Menu en modo plantilla (monocromo), ignorando `.foregroundStyle()`.
    /// Un `Circle().fill()` dentro de un Button normal (no un ícono SF
    /// Symbol) no cae en ese modo plantilla, así que sí muestra el color
    /// real. Ver sección 9 del doc de continuidad v1.1.
    @ViewBuilder
    private func selectorDeColor(onSelect: @escaping (MarkColor) -> Void) -> some View {
        HStack(spacing: 14) {
            ForEach(MarkColor.allCases, id: \.self) { color in
                Button {
                    onSelect(color)
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(color.color)
                            .frame(width: 26, height: 26)
                        Text(color.rawValue.capitalized)
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

#if os(iOS)
/// Envoltorio de UITextView — la base del editor en iOS. Nada de
/// `AttributedTextSelection` (eso es iOS/macOS 26+ únicamente); acá el
/// rango seleccionado se seguí manualmente vía el delegate.
private struct EditorUITextView: UIViewRepresentable {
    @Binding var nsText: NSAttributedString
    @Binding var selectedRange: NSRange

    func makeUIView(context: Context) -> UITextView {
        let vista = UITextView()
        vista.delegate = context.coordinator
        vista.autocorrectionType = .no
        vista.backgroundColor = .clear
        vista.attributedText = nsText
        vista.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        return vista
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        guard uiView.attributedText != nsText else { return }
        let rangoPrevio = uiView.selectedRange
        uiView.attributedText = nsText
        if rangoPrevio.location != NSNotFound, rangoPrevio.upperBound <= uiView.attributedText.length {
            uiView.selectedRange = rangoPrevio
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let padre: EditorUITextView
        init(_ padre: EditorUITextView) { self.padre = padre }

        func textViewDidChange(_ textView: UITextView) {
            padre.nsText = textView.attributedText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            padre.selectedRange = textView.selectedRange
        }
    }
}
#endif
