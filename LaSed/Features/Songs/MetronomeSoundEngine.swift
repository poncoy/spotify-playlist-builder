//
//  MetronomeSoundEngine.swift
//  LaSed
//
//  Versión app:  0.4.15
//  Fase:         3 — Song Editor
//  Modificado:   13/09/2026
//

import AVFoundation

enum TimbreMetronomo: String, CaseIterable, Identifiable {
    case clic = "Clic"
    case tock = "Tock"
    case beep = "Beep"

    var id: String { rawValue }

    fileprivate var parametros: (fAcento: Double, fNormal: Double, duracion: Double) {
        switch self {
        case .clic: return (1600, 1000, 0.02)
        case .tock: return (500, 300, 0.03)
        case .beep: return (1800, 1200, 0.06)
        }
    }
}

final class MetronomeSoundEngine {
    static let shared = MetronomeSoundEngine()

    private let engine = AVAudioEngine()
    private let jugadorAcento = AVAudioPlayerNode()
    private let jugadorNormal = AVAudioPlayerNode()
    private let formato: AVAudioFormat

    private var buffers: [TimbreMetronomo: (acento: AVAudioPCMBuffer, normal: AVAudioPCMBuffer)] = [:]

    var volumen: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    private init() {
        formato = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        engine.attach(jugadorAcento)
        engine.attach(jugadorNormal)
        engine.connect(jugadorAcento, to: engine.mainMixerNode, format: formato)
        engine.connect(jugadorNormal, to: engine.mainMixerNode, format: formato)
        engine.mainMixerNode.outputVolume = 0.8

        for timbre in TimbreMetronomo.allCases {
            let p = timbre.parametros
            buffers[timbre] = (
                acento: Self.generarClic(formato: formato, frecuencia: p.fAcento, duracionSeg: p.duracion),
                normal: Self.generarClic(formato: formato, frecuencia: p.fNormal, duracionSeg: p.duracion)
            )
        }

        do {
            try engine.start()
            jugadorAcento.play()
            jugadorNormal.play()
        } catch {}
    }

    func reproducir(timbre: TimbreMetronomo, acento: Bool) {
        guard let par = buffers[timbre] else { return }
        let jugador = acento ? jugadorAcento : jugadorNormal
        let buffer = acento ? par.acento : par.normal
        jugador.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    private static func generarClic(formato: AVAudioFormat, frecuencia: Double, duracionSeg: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(formato.sampleRate * duracionSeg)
        let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: frames)!
        buffer.frameLength = frames
        guard let datos = buffer.floatChannelData?[0] else { return buffer }
        let muestrasPorSeg = formato.sampleRate
        for i in 0..<Int(frames) {
            let t = Double(i) / muestrasPorSeg
            let envolvente = exp(-t * 60)
            datos[i] = Float(sin(2 * .pi * frecuencia * t) * envolvente)
        }
        return buffer
    }
}
