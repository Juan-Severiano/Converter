//
//  ConverterApp.swift
//  Converter
//
//  Created by Francisco Juan on 03/09/26.
//

import ConvertCore
import SwiftUI

@main
struct ConverterApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("Convert", id: "main") {
            ContentView()
                .environmentObject(appModel)
                .onOpenURL { url in
                    appModel.handleIncomingURL(url)
                }
        }
        .defaultSize(width: 480, height: 360)
        .windowResizability(.contentMinSize)

        WindowGroup("Convert", id: "conversion", for: UUID.self) { $sessionID in
            if let sessionID, let session = appModel.session(for: sessionID) {
                ConversionConfigView(session: session)
                    .environmentObject(appModel)
            }
        }
        .defaultSize(width: 420, height: 460)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
