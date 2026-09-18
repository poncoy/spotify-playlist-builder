//
//  ModuleHeaderBar.swift
//  LaSed
//
//  Versión: 0.3.0
//  Actualizado: 10/09/2026
//
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
