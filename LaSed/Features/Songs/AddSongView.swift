//
//  AddSongView.swift
//  LaSed
//
//  Versión app:  0.3.3
//  Fase:         3 — Song Editor (ajustes de usabilidad)
//  Modificado:   10/09/2026 (Lima) — fix definitivo (los 2 anteriores NO
//  funcionaron): se elimina Form por completo. Confirmado con capturas del
//  usuario que envolver el TextField en un VStack no evitaba que macOS Form
//  igual usara su texto de placeholder como etiqueta externa en una columna
//  aparte — el mecanismo de Form busca un TextField-con-título en cualquier
//  profundidad de la fila, no solo como hijo directo de Section. Ahora es
//  ScrollView + VStack + GroupBox, sin ningún layout automático de columnas:
//  cada campo es Text(etiqueta) + TextField(placeholder) uno debajo del
//  otro, con .textFieldStyle(.roundedBorder). País/Idioma pasan a HStack
//  manual (Text + Spacer + Picker sin label) para imitar el layout de fila
//  clásico sin depender de ningún comportamiento implícito.
//  País ahora es Picker fijo
//  (paisesConocidos en Repository.swift), igual que Idioma, en vez de
//  texto libre. Ventana redimensionable y más grande (antes chica y fija,
//  (¿en vivo?, país, idioma, nivel) que ya existían en el modelo Song desde
//  Fase 2 pero faltaban en este formulario — antes solo se podían cargar
//  editando la canción después de crearla.
//
//  ⚠️ NO COMPILADO POR CLAUDE — sin toolchain de Swift disponible. Compila en
//  Xcode y pasa el primer error tal cual lo muestra el Issue Navigator.

import SwiftUI

struct AddSongView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var songCode = ""
    @State private var titleDisplay = ""
    @State private var artist = ""
    @State private var spotifyId = ""
    @State private var isLive = false
    @State private var country = ""
    @State private var language = ""
    @State private var level: Int = 0
    @State private var errorMessage: String?

    // Misma decisión que en EditSongView: idioma como selección controlada,
    // no texto libre. Orden alfabético (antes era orden de escritura, sin
    // criterio; reportado como raro en el picker).
    private static let idiomasDisponibles = ["Alemán", "Español", "Francés", "Inglés", "Italiano", "Portugués"]

    private let repo = SongRepository()
    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ModuleHeaderBar(titulo: "Agregar canción — Biblioteca")
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        GroupBox("Identificación") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Código").font(.caption).foregroundStyle(.secondary)
                                TextField("LS-0001", text: $songCode)
                                    .textFieldStyle(.roundedBorder)
                                    #if os(iOS)
                                    .textInputAutocapitalization(.characters)
                                    #endif
                                Text("Sugerido automáticamente. Si ya tiene código en tu Excel, pégalo aquí y pisa la sugerencia.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GroupBox("Canción") {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Título").font(.caption).foregroundStyle(.secondary)
                                    TextField("Nombre de la canción", text: $titleDisplay)
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Artista").font(.caption).foregroundStyle(.secondary)
                                    TextField("Nombre del artista o banda", text: $artist)
                                        .textFieldStyle(.roundedBorder)
                                }
                                Toggle("¿Es versión en vivo?", isOn: $isLive)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GroupBox("Datos adicionales (opcional)") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("País")
                                    Spacer()
                                    Picker("", selection: $country) {
                                        Text("Sin especificar").tag("")
                                        ForEach(paisesConocidos) { pais in
                                            Text("\(pais.flag) \(pais.nombre)").tag(pais.flag)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                HStack {
                                    Text("Idioma")
                                    Spacer()
                                    Picker("", selection: $language) {
                                        Text("Sin especificar").tag("")
                                        ForEach(Self.idiomasDisponibles, id: \.self) { idioma in
                                            Text(idioma).tag(idioma)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                Stepper("Nivel: \(level)", value: $level, in: 0...5)
                                    .help("Nivel de complejidad de la canción, de 0 a 5")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GroupBox("Spotify (opcional)") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Spotify ID").font(.caption).foregroundStyle(.secondary)
                                TextField("22 caracteres", text: $spotifyId)
                                    .textFieldStyle(.roundedBorder)
                                    #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    #endif
                                    .autocorrectionDisabled()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Agregar canción")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(songCode.trimmingCharacters(in: .whitespaces).isEmpty
                                  || titleDisplay.trimmingCharacters(in: .whitespaces).isEmpty
                                  || artist.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if songCode.isEmpty {
                    songCode = (try? repo.suggestNextCode()) ?? ""
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        // Antes esta vista no tenía .frame: el sheet se dibujaba con el
        // tamaño mínimo que pedía el contenido, chico y sin poder
        // arrastrar para agrandar (reportado: "no poder maximizar nada").
        // Con min/ideal/max se vuelve redimensionable de verdad.
        .frame(minWidth: 480, idealWidth: 560, maxWidth: 700, minHeight: 480, idealHeight: 620, maxHeight: 800)
    }

    private func save() {
        let code = songCode.trimmingCharacters(in: .whitespaces).uppercased()

        guard code.range(of: #"^LS-\d{4}$"#, options: .regularExpression) != nil else {
            errorMessage = "El código debe tener el formato LS-0001 (LS-guion-4 números)."
            return
        }

        do {
            if try repo.fetchByCode(code) != nil {
                errorMessage = "El código \(code) ya existe. Escribe uno diferente."
                return
            }
            try repo.create(Song(
                id: code,
                spotifyId: spotifyId.trimmingCharacters(in: .whitespaces).isEmpty ? nil : spotifyId,
                titleDisplay: titleDisplay.trimmingCharacters(in: .whitespaces),
                titleSpotify: nil,
                artist: artist.trimmingCharacters(in: .whitespaces),
                matchKey: "",
                isLive: isLive,
                originalKey: nil,
                durationSec: nil,
                country: country.trimmingCharacters(in: .whitespaces).isEmpty ? nil : country,
                language: language.trimmingCharacters(in: .whitespaces).isEmpty ? nil : language,
                level: level == 0 ? nil : level,
                notes: nil,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil,
                rev: 1,
                lastEditedBy: "manual",
                youtubeUrl: nil,
                physicalNotes: nil,
                contentASTJson: nil))
            onSaved()
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar. Intenta de nuevo."
        }
    }
}
