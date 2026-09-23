//
//  LaSedApp.swift
//  LaSed
//
//  Created by Paul on 9/09/26.
//

import SwiftUI

@main
struct LaSedApp: App {
    // (seguro) Antes esto pre-calentaba MetronomeSoundEngine.shared al
    // abrir la app. En iOS, con hardware real, el solo hecho de construir
    // el AVAudioEngine (attach/connect, sin arrancarlo) alcanza para que
    // el sistema active la sesión de audio por defecto (.soloAmbient) y
    // corte lo que estuviera sonando en otra app (reportado: Spotify se
    // pausaba al abrir LaSed). El ahorro de unos ms en el primer toque del
    // metrónomo no vale ese costo — se deja crear perezosamente en el
    // primer uso real, como ya estaba pensado para el arranque del motor.

    var body: some Scene {
        WindowGroup {
            RootSplitView()
        }
    }
}
