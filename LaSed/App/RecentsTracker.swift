//
//  RecentsTracker.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 23/09/2026
//
//  Lo último que se abrió (setlists/canciones), para la pantalla de Inicio.
//  Guardado en UserDefaults — es solo una conveniencia de navegación, no
//  necesita sincronizarse ni sobrevivir a una reinstalación.
import Foundation

struct RecentEntry: Codable, Identifiable, Equatable {
    enum Tipo: String, Codable {
        case setlist, cancion
    }

    var id: String
    var tipo: Tipo
    var titulo: String
    var subtitulo: String?
    var fecha: Date
}

enum RecentsTracker {
    private static let key = "com.poncoy.lased.recientes"
    private static let maximo = 8

    static func registrar(id: String, tipo: RecentEntry.Tipo, titulo: String, subtitulo: String? = nil) {
        var lista = obtener()
        lista.removeAll { $0.id == id && $0.tipo == tipo }
        lista.insert(RecentEntry(id: id, tipo: tipo, titulo: titulo, subtitulo: subtitulo, fecha: Date()), at: 0)
        if lista.count > maximo {
            lista = Array(lista.prefix(maximo))
        }
        guard let data = try? JSONEncoder().encode(lista) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func obtener() -> [RecentEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let lista = try? JSONDecoder().decode([RecentEntry].self, from: data) else {
            return []
        }
        return lista
    }
}
