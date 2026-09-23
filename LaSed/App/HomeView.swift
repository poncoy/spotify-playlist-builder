//
//  HomeView.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 23/09/2026
//
//  Primera pantalla al abrir la app: lo último que se usó + accesos
//  rápidos. La grilla es adaptativa (LazyVGrid .adaptive) a propósito —
//  se reacomoda sola de 2 columnas en iPhone a 4-5 en iPad/Mac, sin
//  ramas por plataforma.
import SwiftUI

struct HomeView: View {
    @Binding var seccion: SeccionPrincipal?
    var onNuevoSetlist: () -> Void
    var onImportarCSV: () -> Void

    @State private var recientes: [RecentEntry] = []
    @State private var mostrandoMetronomo = false
    @State private var mostrandoRecordatorios = false
    @State private var bpmMetronomoGeneral = 120

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("La Sed")
                    .font(.largeTitle.bold())
                    .padding(.top, 8)

                if !recientes.isEmpty {
                    seccionRecientes
                }

                seccionAccesosRapidos
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Inicio")
        .onAppear { recientes = RecentsTracker.obtener() }
        .sheet(isPresented: $mostrandoMetronomo) { MetronomeView(bpm: $bpmMetronomoGeneral) }
        .sheet(isPresented: $mostrandoRecordatorios) { ShowRemindersView() }
    }

    private var seccionRecientes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECIENTES")
                .font(.caption.bold())
                .foregroundStyle(Color.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recientes) { reciente in
                        Button {
                            abrirReciente(reciente)
                        } label: {
                            tarjetaReciente(reciente)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func tarjetaReciente(_ r: RecentEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: r.tipo == .setlist ? "music.mic" : "music.note")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Spacer(minLength: 0)
            Text(r.titulo)
                .font(.subheadline.bold())
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            if let subtitulo = r.subtitulo, !subtitulo.isEmpty {
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 160, height: 104, alignment: .topLeading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var seccionAccesosRapidos: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCESOS RÁPIDOS")
                .font(.caption.bold())
                .foregroundStyle(Color.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                accesoRapido("Biblioteca", "music.note.list", .blue) {
                    seccion = .biblioteca
                }
                accesoRapido("Nuevo setlist", "plus.circle", .orange) {
                    onNuevoSetlist()
                }
                accesoRapido("Metrónomo", "metronome", .green) {
                    mostrandoMetronomo = true
                }
                accesoRapido("Recordatorios del show", "list.bullet.clipboard", .purple) {
                    mostrandoRecordatorios = true
                }
                accesoRapido("Importar CSV", "square.and.arrow.down.on.square", .teal) {
                    onImportarCSV()
                }
            }
        }
    }

    private func accesoRapido(_ titulo: String, _ icono: String, _ color: Color, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icono)
                    .font(.title)
                    .foregroundStyle(color)
                Text(titulo)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func abrirReciente(_ r: RecentEntry) {
        switch r.tipo {
        case .setlist:
            seccion = .setlist(r.id)
        case .cancion:
            // Las canciones no tienen ruta propia en el sidebar todavía —
            // por ahora lo más útil es mandar a Biblioteca y que la busque.
            seccion = .biblioteca
        }
    }
}
