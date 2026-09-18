//
//  SongContentEditorView.swift
//  LaSed
//
//  Versión: 0.4.10
//  Actualizado: 11/09/2026
//
import SwiftUI

struct SongContentEditorView: View {
    @Binding var attributedText: AttributedString
    var song: Song? = nil
    var onSave: (AttributedString) -> Void
    var onCancel: () -> Void

    @State private var selection = AttributedTextSelection()
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

            TextEditor(text: $attributedText, selection: $selection)
                .textEditorStyle(.plain)
                .font(fontFamily.font(size: fontSize))
                .autocorrectionDisabled()
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button("Guardar") { onSave(attributedText) }
                .buttonStyle(.borderedProminent)
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

    // MARK: - Acciones de formato

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

