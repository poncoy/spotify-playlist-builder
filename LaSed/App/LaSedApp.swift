//
//  LaSedApp.swift
//  LaSed
//
//  Created by Paul on 9/09/26.
//

import SwiftUI

@main
struct LaSedApp: App {
    init() {
        DispatchQueue.global(qos: .utility).async {
            _ = MetronomeSoundEngine.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            RootSplitView()
        }
    }
}
