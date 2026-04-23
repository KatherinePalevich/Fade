//
//  FadeApp.swift
//  Fade
//
//  Created by Katherine Palevich on 4/15/26.
//

import SwiftUI
import SwiftData

@main
struct FadeApp: App {
    init() {
        _ = NotificationManager.shared
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RashSite.self, RashEntry.self, TreatmentLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
