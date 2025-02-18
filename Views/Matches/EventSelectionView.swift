import SwiftUI
import SwiftData

struct EventSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @Bindable var match: Match
    let isHomeTeam: Bool
    
    @State private var selectedTab = 0 // 0: 进球, 1: 扑救
    @State private var showingAssistSelection = false
    @State private var currentScorer: Player? // 临时存储进球球员
    
    var selectedTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam == isHomeTeam }.map { $0.player! }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 进球选择页面
            VStack {
                Text("选择进球球员")
                    .font(.headline)
                    .padding()
                
                List(selectedTeamPlayers) { player in
                    Button(action: {
                        handleGoalScorer(player)
                    }) {
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text("选择")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .tag(0)
            
            // 扑救选择页面
            VStack {
                Text("选择扑救球员")
                    .font(.headline)
                    .padding()
                
                List(selectedTeamPlayers.filter { $0.position == .goalkeeper }) { player in
                    Button(action: {
                        recordSave(player)
                    }) {
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text("选择")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .navigationTitle("\(isHomeTeam ? "红队" : "蓝队")事件")
        .navigationBarItems(trailing: Button("完成") {
            presentationMode.wrappedValue.dismiss()
        })
        .sheet(isPresented: $showingAssistSelection) {
            AssistSelectionView(
                players: selectedTeamPlayers,
                onAssistSelected: { assistPlayer in
                    if let scorer = currentScorer {
                        recordGoal(scorer, assistant: assistPlayer)
                    }
                },
                onSkip: {
                    if let scorer = currentScorer {
                        recordGoal(scorer, assistant: nil)
                    }
                }
            )
        }
    }
    
    private func handleGoalScorer(_ player: Player) {
        currentScorer = player
        showingAssistSelection = true
    }
    
    private func recordGoal(_ scorer: Player, assistant: Player?) {
        let event = MatchEvent(
            eventType: .goal,
            timestamp: Date(),
            match: match,
            scorer: scorer,
            assistant: assistant
        )
        
        // 更新比分
        if isHomeTeam {
            match.homeScore += 1
        } else {
            match.awayScore += 1
        }
        
        // 更新球员统计
        if let stats = match.playerStats.first(where: { $0.player?.id == scorer.id }) {
            stats.goals += 1
        }
        if let assistant = assistant,
           let assistStats = match.playerStats.first(where: { $0.player?.id == assistant.id }) {
            assistStats.assists += 1
        }
        
        match.events.append(event)
        try? modelContext.save()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func recordSave(_ player: Player) {
        let event = MatchEvent(
            eventType: .save,
            timestamp: Date(),
            match: match,
            scorer: player,
            assistant: nil
        )
        
        // 更新球员统计
        if let stats = match.playerStats.first(where: { $0.player?.id == player.id }) {
            stats.saves += 1
        }
        
        match.events.append(event)
        try? modelContext.save()
        presentationMode.wrappedValue.dismiss()
    }
}

// 助攻选择视图
struct AssistSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    let players: [Player]
    let onAssistSelected: (Player) -> Void
    let onSkip: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("无助攻") {
                        onSkip()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                Section("选择助攻球员") {
                    ForEach(players) { player in
                        Button(action: {
                            onAssistSelected(player)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(player.name)
                        }
                    }
                }
            }
            .navigationTitle("选择助攻")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Match.self, configurations: config)
    
    let newMatch = Match(
        id: UUID(),
        status: .notStarted,
        homeTeamName: "红队",
        awayTeamName: "蓝队"
    )
    return EventSelectionView(match: newMatch, isHomeTeam: true)
        .modelContainer(container)
} 