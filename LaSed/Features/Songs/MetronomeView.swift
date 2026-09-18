//
//  MetronomeView.swift
//  LaSed
//
//  Versión: 0.4.15
//  Actualizado: 13/09/2026
//
import SwiftUI

struct MetronomeView: View {
    @Binding var bpm: Int

    @State private var compas: Int = 4
    @State private var acentoIndice: Int = 0
    @State private var timbre: TimbreMetronomo = .clic
    @State private var volumen: Float = MetronomeSoundEngine.shared.volumen
    @State private var activo = false
    @State private var beatEnCurso: Int = 0
    @State private var beatVisual: Int = 0
    @State private var pulso = false
    @State private var timer: Timer?

    private var bpmDouble: Binding<Double> {
        Binding(
            get: { Double(bpm) },
            set: { nuevo in
                bpm = Int(nuevo.rounded())
                if activo { reiniciarConNuevoTempo() }
            }
        )
    }

    private var volumenDouble: Binding<Double> {
        Binding(
            get: { Double(volumen) },
            set: { nuevo in
                volumen = Float(nuevo)
                MetronomeSoundEngine.shared.volumen = volumen
            }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("\(bpm) BPM")
                .font(.largeTitle)
                .bold()
                .monospacedDigit()

            HStack {
                Text("40").font(.caption).foregroundStyle(.secondary)
                Slider(value: bpmDouble, in: 40...240, step: 1)
                Text("240").font(.caption).foregroundStyle(.secondary)
            }

            Picker("Compás", selection: $compas) {
                Text("2 tiempos").tag(2)
                Text("3 tiempos").tag(3)
                Text("4 tiempos").tag(4)
                Text("6 tiempos").tag(6)
            }
            .pickerStyle(.segmented)
            .onChange(of: compas) { _, nuevo in
                beatEnCurso = 0
                beatVisual = 0
                if acentoIndice >= nuevo { acentoIndice = 0 }
                if activo { reiniciarConNuevoTempo() }
            }

            Picker("Sonido", selection: $timbre) {
                ForEach(TimbreMetronomo.allCases) { opcion in
                    Text(opcion.rawValue).tag(opcion)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
                Slider(value: volumenDouble, in: 0...1)
                Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(0..<compas, id: \.self) { indice in
                    let esAcento = indice == acentoIndice
                    let iluminado = pulso && beatVisual == indice
                    Circle()
                        .fill(
                            iluminado
                                ? (esAcento ? Color.orange : Color.accentColor)
                                : (esAcento ? Color.orange.opacity(0.25) : Color.gray.opacity(0.25))
                        )
                        .frame(width: esAcento ? 30 : 22, height: esAcento ? 30 : 22)
                        .onTapGesture { acentoIndice = indice }
                }
            }
            .animation(.easeOut(duration: 0.1), value: pulso)
            .frame(height: 34)

            Button(activo ? "Detener" : "Iniciar") {
                activo ? detener() : iniciar()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(bpm == 0)
        }
        .padding(24)
        .frame(minWidth: 280)
        .onAppear {
            if bpm == 0 { bpm = 120 }
        }
        .onDisappear { detener() }
    }

    private func iniciar() {
        guard bpm > 0 else { return }
        timer?.invalidate()
        activo = true
        beatEnCurso = 0
        programarTimer()
        tick()
    }

    private func reiniciarConNuevoTempo() {
        timer?.invalidate()
        programarTimer()
    }

    private func programarTimer() {
        let intervalo = 60.0 / Double(bpm)
        let nuevoTimer = Timer(timeInterval: intervalo, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(nuevoTimer, forMode: .common)
        timer = nuevoTimer
    }

    private func detener() {
        activo = false
        timer?.invalidate()
        timer = nil
        pulso = false
    }

    private func tick() {
        let beat = beatEnCurso
        let esAcento = beat == acentoIndice
        MetronomeSoundEngine.shared.reproducir(timbre: timbre, acento: esAcento)
        beatVisual = beat
        pulso = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            pulso = false
        }
        beatEnCurso = (beat + 1) % max(compas, 1)
    }
}
