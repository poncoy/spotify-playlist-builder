//
//  ChordDiagramView.swift
//  LaSed
//
//  Versión app:  0.4.4
//  Fase:         3 — Librería de acordes (guitarra)
//  Modificado:   10/09/2026 (Lima)
//
//  Diagrama de trastes (6 cuerdas x 4 trastes) a partir de un GuitarChordShape.

import SwiftUI

struct ChordDiagramView: View {
    let nombre: String
    let forma: GuitarChordShape

    private let numCuerdas = 6
    private let numTrastesMostrados = 4

    var body: some View {
        VStack(spacing: 6) {
            Text(nombre)
                .font(.headline)

            if forma.esCejilla {
                Text("Cejilla, traste \(forma.baseFret)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let ancho = geo.size.width
                let alto = geo.size.height
                let margenSuperior: CGFloat = 18
                let espacioCuerdas = ancho / CGFloat(numCuerdas - 1)
                let espacioTrastes = (alto - margenSuperior) / CGFloat(numTrastesMostrados)

                ZStack(alignment: .topLeading) {
                    ForEach(0..<numCuerdas, id: \.self) { i in
                        Path { p in
                            let x = CGFloat(i) * espacioCuerdas
                            p.move(to: CGPoint(x: x, y: margenSuperior))
                            p.addLine(to: CGPoint(x: x, y: alto))
                        }
                        .stroke(Color.secondary, lineWidth: 1)
                    }

                    ForEach(0...numTrastesMostrados, id: \.self) { j in
                        Path { p in
                            let y = margenSuperior + CGFloat(j) * espacioTrastes
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: ancho, y: y))
                        }
                        .stroke(Color.secondary, lineWidth: j == 0 ? 3 : 1)
                    }

                    ForEach(0..<numCuerdas, id: \.self) { i in
                        let x = CGFloat(i) * espacioCuerdas
                        let traste = forma.frets[i]
                        if let traste, traste > 0 {
                            let trasteRelativo = forma.esCejilla ? (traste - forma.baseFret + 1) : traste
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 16, height: 16)
                                .position(x: x, y: margenSuperior + (CGFloat(trasteRelativo) - 0.5) * espacioTrastes)
                        } else {
                            Text(traste == 0 ? "O" : "X")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(traste == 0 ? .primary : .secondary)
                                .position(x: x, y: margenSuperior / 2)
                        }
                    }
                }
            }
            .frame(width: 100, height: 120)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5, opacity: 0.08)))
    }
}
