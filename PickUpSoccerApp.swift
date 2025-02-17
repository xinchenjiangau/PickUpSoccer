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
    let container: ModelContainer
    
    init() {
        do {
            // 配置 SwiftData 容器
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: Player.self, configurations: config)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
