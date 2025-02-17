//
//  ContentView.swift
//  PickUpSoccer
//
//  Created by xc j on 2/17/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            MatchesView()
                .tabItem {
                    Label("比赛", systemImage: "soccerball")
                }
            
            PlayersView()
                .tabItem {
                    Label("球员", systemImage: "person")
                }
            
            LeaderboardView()
                .tabItem {
                    Label("排行榜", systemImage: "list.number")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
