//
//  PickUpSoccerApp.swift
//  PickUpSoccer
//
//  Created by xc j on 2/17/25.
//

import SwiftUI
import SwiftData

@main
struct PickUpSoccerApp: App {
    let modelContainer: ModelContainer
    @StateObject private var authManager: AuthManager
    
    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: Match.self, Player.self, configurations: config)
            self.modelContainer = container
            self._authManager = StateObject(wrappedValue: AuthManager(modelContext: container.mainContext))
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environmentObject(authManager)
                .modelContainer(modelContainer)
        }
    }
}
