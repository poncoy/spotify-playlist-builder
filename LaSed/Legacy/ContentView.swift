import SwiftUI
import GRDB

struct ContentView: View {
    @State private var resultado = "Sin probar"

    var body: some View {
        VStack(spacing: 20) {
            Text("La Sed").font(.largeTitle)
            Text(resultado)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Probar base de datos") { probar() }
        }
        .padding(40)
    }

    func probar() {
        do {
            let repo = SongRepository()
            let id = "LS-0001"

            if let existente = try repo.fetchById(id) {
                var actualizado = existente
                actualizado.notes = "Probado: \(Date().formatted(date: .omitted, time: .standard))"
                try repo.update(actualizado)
            } else {
                let nueva = Song(
                    id: id,
                    spotifyId: nil,
                    titleDisplay: "Loco",
                    titleSpotify: nil,
                    artist: "Andrés Calamaro",
                    matchKey: "loco|andres calamaro",
                    isLive: false,
                    originalKey: "G",
                    durationSec: 217,
                    country: "Argentina",
                    language: "ESP",
                    level: 2,
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date(),
                    deletedAt: nil,
                    rev: 1,
                    lastEditedBy: DeviceID.current)
                try repo.create(nueva)
            }

            guard let actual = try repo.fetchById(id) else {
                resultado = "❌ No se encontró después de guardar"
                return
            }
            let total = try repo.fetchAllActive().count
            let matchOk = try repo.fetchByMatchKey("loco|andres calamaro") != nil

            resultado = """
            ✅ rev: \(actual.rev)
            notes: \(actual.notes ?? "-")
            activas: \(total)
            matchKey lookup: \(matchOk ? "OK" : "FALLÓ")
            """
        } catch {
            resultado = "❌ \(error)"
        }
    }
}

#Preview { ContentView() }
