import SwiftUI
import SwiftData

struct TeamSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var selectedPlayers: [Player]
    @State private var playerColors: [UUID: Color] = [:] // 存储每个球员的颜色
    @State private var firstPlayerSelected: Bool = false // 记录是否已选择第一个球员
    @State private var showingMatchRecord = false // 状态变量
    @State private var currentMatch: Match? // 存储当前创建的比赛
    
    var redTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .red }
    }
    
    var blueTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .blue }
    }
    
    var body: some View {
        List {
            ForEach(selectedPlayers, id: \.id) { player in
                Button(action: {
                    togglePlayerColor(player)
                }) {
                    HStack {
                        Text(player.name)
                            .foregroundColor(playerColors[player.id] ?? .gray) // 默认灰色
                    }
                }
            }
        }
        .navigationTitle("选择球队")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("开始比赛") {
                    createAndStartMatch()
                }
            }
        }
        .onChange(of: showingMatchRecord) { newValue in
            if !newValue {
                dismiss() // 当 MatchRecordView 关闭时，返回到 MatchesView
            }
        }
        .fullScreenCover(isPresented: $showingMatchRecord) {
            if let match = currentMatch {
                MatchRecordView(match: match)
            }
        }
    }
    
    private func createAndStartMatch() {
        // 创建新的比赛，只传入必要参数
        let newMatch = Match(
            id: UUID(),
            status: .inProgress,  // 创建时直接设置为进行中
            homeTeamName: "红队",
            awayTeamName: "蓝队"
        )
        
        // 初始化比分
        newMatch.homeScore = 0
        newMatch.awayScore = 0
        
        // 初始化空数组
        newMatch.events = []
        newMatch.playerStats = []
        
        // 为每个球员创建比赛统计
        for player in redTeam {
            let stats = PlayerMatchStats(player: player, match: newMatch)
            stats.isHomeTeam = true
            newMatch.playerStats.append(stats)
        }
        
        for player in blueTeam {
            let stats = PlayerMatchStats(player: player, match: newMatch)
            stats.isHomeTeam = false
            newMatch.playerStats.append(stats)
        }
        
        // 保存到数据库
        modelContext.insert(newMatch)
        
        // 保存当前比赛并显示比赛记录页面
        currentMatch = newMatch
        showingMatchRecord = true
    }
    
    private func togglePlayerColor(_ player: Player) {
        if !firstPlayerSelected {
            // 第一次点击，设置第一个球员为红色，其他为蓝色
            playerColors[player.id] = .red
            firstPlayerSelected = true
            
            // 将其他球员设置为蓝色
            for otherPlayer in selectedPlayers where otherPlayer.id != player.id {
                playerColors[otherPlayer.id] = .blue
            }
        } else {
            // 如果已经选择了第一个球员，切换颜色
            if playerColors[player.id] == .red {
                playerColors[player.id] = .blue // 切换为蓝色
            } else {
                playerColors[player.id] = .red // 切换为红色
            }
        }
    }
}

#Preview {
    TeamSelectView(selectedPlayers: [Player(name: "球员1", position: .forward), Player(name: "球员2", position: .midfielder)])
} 