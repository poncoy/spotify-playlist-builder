//
//  ModuleHeaderBar.swift
//  LaSed
//
//  Versión app:  0.3.0
//  Fase:         3 — Song Editor
//  Modificado:   10/09/2026 (Lima)
//
//  Barra de identificación de módulo, primer elemento visible en cada
//  pantalla principal (no depende de navigationTitle/subtitle del sistema).

import SwiftUI

struct ModuleHeaderBar: View {
    let titulo: String

    var body: some View {
        Text(titulo.uppercased())
            .font(.caption.bold())
            .kerning(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
    }
}
