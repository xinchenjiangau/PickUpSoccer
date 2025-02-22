//
//  ContentView.swift
//  PickUpSoccer
//
//  Created by xc j on 2/17/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showUserPlayerSheet = false

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MatchesView()
                    .onAppear {
                        // 判断当前 Player 是否存在且资料不完整
                        if let player = authManager.currentPlayer, !player.isProfileComplete {
                            showUserPlayerSheet = true
                        }
                    }
                    .sheet(isPresented: $showUserPlayerSheet) {
                        UserPlayerView()
                            .environmentObject(authManager)
                    }
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, configurations: config)
    
    return ContentView()
        .modelContainer(container)
        .environmentObject(AuthManager(modelContext: container.mainContext))
}
