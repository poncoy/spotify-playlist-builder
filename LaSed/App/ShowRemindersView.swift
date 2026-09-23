//
//  ShowRemindersView.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 23/09/2026
//
//  Checklist de cosas para mencionar en vivo (cumpleaños, aniversarios,
//  etc.) — vive en UserDefaults a propósito: es una lista descartable que
//  se reinicia show a show, no un dato de negocio que necesite la base.
import SwiftUI

struct RecordatorioShow: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var texto: String
    var marcado: Bool = false
}

private enum RecordatoriosStore {
    private static let key = "com.poncoy.lased.recordatoriosShow"

    static let sugeridos: [String] = [
        "¿Alguien cumple años hoy?",
        "¿Cuántos enamorados hay esta noche?",
        "Aniversario o fecha especial para mencionar"
    ]

    static func cargar() -> [RecordatorioShow] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let lista = try? JSONDecoder().decode([RecordatorioShow].self, from: data) else {
            return sugeridos.map { RecordatorioShow(texto: $0) }
        }
        return lista
    }

    static func guardar(_ lista: [RecordatorioShow]) {
        guard let data = try? JSONEncoder().encode(lista) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct ShowRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [RecordatorioShow] = []
    @State private var nuevoTexto = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($items) { $item in
                        Button {
                            item.marcado.toggle()
                            RecordatoriosStore.guardar(items)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.marcado ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.marcado ? Color.green : Color.secondary)
                                    .font(.title3)
                                Text(item.texto)
                                    .strikethrough(item.marcado)
                                    .foregroundStyle(item.marcado ? Color.secondary : Color.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indices in
                        items.remove(atOffsets: indices)
                        RecordatoriosStore.guardar(items)
                    }
                } header: {
                    Text("Para mencionar hoy")
                }

                Section {
                    HStack {
                        TextField("Agregar recordatorio…", text: $nuevoTexto)
                            .onSubmit { agregar() }
                        Button("Agregar") { agregar() }
                            .disabled(nuevoTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Recordatorios del show")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reiniciar") { reiniciar() }
                }
            }
            .onAppear { items = RecordatoriosStore.cargar() }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 420, idealHeight: 520)
        #endif
    }

    private func agregar() {
        let limpio = nuevoTexto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return }
        items.append(RecordatorioShow(texto: limpio))
        nuevoTexto = ""
        RecordatoriosStore.guardar(items)
    }

    /// No borra la lista — solo destilda todo, para no perder recordatorios
    /// personalizados que el usuario haya agregado de una noche a la otra.
    private func reiniciar() {
        for indice in items.indices { items[indice].marcado = false }
        RecordatoriosStore.guardar(items)
    }
}
