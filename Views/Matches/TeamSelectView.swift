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
    
    // 接收选定的赛季ID
    var selectedSeasonID: UUID?
    
    init(selectedPlayers: [Player], selectedSeasonID: UUID? = nil) {
        self._selectedPlayers = State(initialValue: selectedPlayers)
        self.selectedSeasonID = selectedSeasonID
    }
    
    // 查询所有赛季
    @Query private var seasons: [Season]
    
    // 获取当前选择的赛季
    var selectedSeason: Season? {
        if let id = selectedSeasonID {
            return seasons.first { $0.id == id }
        }
        return nil
    }
    
    var redTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .red }
    }
    
    var blueTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .blue }
    }
    
    private func randomizeTeams() {
        // 清空现有分配
        playerColors.removeAll()
        
        // 随机打乱球员顺序
        let shuffledPlayers = selectedPlayers.shuffled()
        
        // 计算每队应有人数
        let totalPlayers = selectedPlayers.count
        let redTeamSize = totalPlayers / 2 + (totalPlayers % 2) // 如果是奇数，红队多一人
        
        // 分配球员
        for (index, player) in shuffledPlayers.enumerated() {
            playerColors[player.id] = index < redTeamSize ? .red : .blue
        }
    }
    
    var body: some View {
        VStack {
            // 显示当前选择的赛季
            if let season = selectedSeason {
                HStack {
                    Text("当前赛季:")
                        .foregroundColor(.gray)
                    Text(season.name)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // 显示队伍人数
            teamCountsView
            
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
        }
        .navigationTitle("选择球队")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 添加随机分队按钮
                Button(action: randomizeTeams) {
                    Image(systemName: "shuffle.circle")
                }
                
                Button("开始比赛") {
                    createAndStartMatch()
                }
            }
        }
        
        .onChange(of: showingMatchRecord) { oldValue, newValue in
            if !newValue {
                dismiss() // 当 MatchRecordView 关闭时，返回到 MatchesView
            }
        }
        .fullScreenCover(isPresented: $showingMatchRecord) {
            if let match = currentMatch {
                MatchRecordView(match: match)
            }
        }
        .onAppear {
            randomizeTeams() // 初始自动随机分队
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
        
        // 关联到选定的赛季
        if let selectedSeason = selectedSeason {
            newMatch.season = selectedSeason
            selectedSeason.matches.append(newMatch)
        }
        
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
        try? modelContext.save()
        
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
    
    // 添加队伍人数显示
    var teamCountsView: some View {
        HStack {
            Text("红队: \(redTeam.count)人")
                .foregroundColor(.red)
            Spacer()
            Text("蓝队: \(blueTeam.count)人")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

#Preview {
    TeamSelectView(selectedPlayers: [Player(name: "球员1", position: .forward), Player(name: "球员2", position: .midfielder)])
} 
