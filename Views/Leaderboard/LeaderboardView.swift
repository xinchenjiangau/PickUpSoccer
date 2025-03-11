import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var seasons: [Season]
    @State private var selectedTab = 0
    @State private var selectedSeasonID: UUID?
    @State private var includeImportedData = true
    @State private var selectedPlayer: Player? = nil
    @State private var showingPlayerDetail = false
    
    // 根据选择的赛季过滤比赛统计数据
    var filteredMatchStats: [PlayerMatchStats] {
        if let selectedSeasonID = selectedSeasonID,
           let selectedSeason = seasons.first(where: { $0.id == selectedSeasonID }) {
            // 获取该赛季的所有比赛
            let seasonMatches = selectedSeason.matches
            
            // 过滤出这些比赛的统计数据
            return players.flatMap { player in
                player.matchStats.filter { stats in
                    if let match = stats.match {
                        return seasonMatches.contains(match)
                    }
                    return false
                }
            }
        } else {
            // 如果没有选择赛季，返回所有统计数据
            return players.flatMap { $0.matchStats }
        }
    }
    
    // 根据选择的赛季过滤导入的统计数据
    var filteredImportedStats: [ImportedPlayerStats] {
        if let selectedSeasonID = selectedSeasonID {
            return players.flatMap { player in
                player.importedStats.filter { stats in
                    stats.season?.id == selectedSeasonID
                }
            }
        } else {
            // 如果没有选择赛季，返回所有导入的统计数据
            return players.flatMap { $0.importedStats }
        }
    }
    
    // 进球排行
    var goalScorers: [(player: Player, goals: Int)] {
        var result: [(player: Player, goals: Int)] = []
        
        // 从比赛统计中获取进球数
        let matchGoals = Dictionary(grouping: filteredMatchStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.goals }
            }
        
        // 从导入统计中获取进球数
        let importedGoals = includeImportedData ? Dictionary(grouping: filteredImportedStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.goals }
            } : [:]
        
        // 合并数据
        for player in players {
            let matchGoal = matchGoals[player] ?? 0
            let importedGoal = importedGoals[player] ?? 0
            let totalGoals = matchGoal + importedGoal
            
            if totalGoals > 0 {
                result.append((player: player, goals: totalGoals))
            }
        }
        
        return result.sorted { $0.goals > $1.goals }
    }
    
    // 助攻排行
    var assistLeaders: [(player: Player, assists: Int)] {
        var result: [(player: Player, assists: Int)] = []
        
        // 从比赛统计中获取助攻数
        let matchAssists = Dictionary(grouping: filteredMatchStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.assists }
            }
        
        // 从导入统计中获取助攻数
        let importedAssists = includeImportedData ? Dictionary(grouping: filteredImportedStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.assists }
            } : [:]
        
        // 合并数据
        for player in players {
            let matchAssist = matchAssists[player] ?? 0
            let importedAssist = importedAssists[player] ?? 0
            let totalAssists = matchAssist + importedAssist
            
            if totalAssists > 0 {
                result.append((player: player, assists: totalAssists))
            }
        }
        
        return result.sorted { $0.assists > $1.assists }
    }
    
    // 扑救排行
    var saveLeaders: [(player: Player, saves: Int)] {
        var result: [(player: Player, saves: Int)] = []
        
        // 从比赛统计中获取扑救数
        let matchSaves = Dictionary(grouping: filteredMatchStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.saves }
            }
        
        // 从导入统计中获取扑救数
        let importedSaves = includeImportedData ? Dictionary(grouping: filteredImportedStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.saves }
            } : [:]
        
        // 合并数据
        for player in players {
            let matchSave = matchSaves[player] ?? 0
            let importedSave = importedSaves[player] ?? 0
            let totalSaves = matchSave + importedSave
            
            if totalSaves > 0 {
                result.append((player: player, saves: totalSaves))
            }
        }
        
        return result.sorted { $0.saves > $1.saves }
    }
    
    // 标题数据
    private let titles = ["进球榜", "助攻榜", "扑救榜"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 赛季选择器
                if !seasons.isEmpty {
                    Picker("选择赛季", selection: $selectedSeasonID) {
                        Text("全部赛季").tag(nil as UUID?)
                        ForEach(seasons) { season in
                            Text(season.name).tag(season.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }
                
                // 数据来源选择
                Toggle("包含导入数据", isOn: $includeImportedData)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // 标题栏
                HStack {
                    ForEach(0..<3) { index in
                        Button(action: {
                            withAnimation {
                                selectedTab = index
                            }
                        }) {
                            Text(["进球榜", "助攻榜", "扑救榜"][index])
                                .foregroundColor(selectedTab == index ? .black : .gray)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 排行榜内容
                TabView(selection: $selectedTab) {
                    // 进球榜
                    LeaderboardTabView(
                        title: "进球榜",
                        items: goalScorers.map { (player: $0.player, value: $0.goals) },
                        valueLabel: "进球",
                        getValue: { $0 },
                        onPlayerSelected: { player in
                            selectedPlayer = player
                            showingPlayerDetail = true
                        }
                    )
                    .tag(0)
                    
                    // 助攻榜
                    LeaderboardTabView(
                        title: "助攻榜",
                        items: assistLeaders.map { (player: $0.player, value: $0.assists) },
                        valueLabel: "助攻",
                        getValue: { $0 },
                        onPlayerSelected: { player in
                            selectedPlayer = player
                            showingPlayerDetail = true
                        }
                    )
                    .tag(1)
                    
                    // 扑救榜
                    LeaderboardTabView(
                        title: "扑救榜",
                        items: saveLeaders.map { (player: $0.player, value: $0.saves) },
                        valueLabel: "扑救",
                        getValue: { $0 },
                        onPlayerSelected: { player in
                            selectedPlayer = player
                            showingPlayerDetail = true
                        }
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("排行榜")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // 如果没有选择赛季且有赛季数据，默认选择最新的赛季
                if selectedSeasonID == nil && !seasons.isEmpty {
                    selectedSeasonID = seasons.first?.id
                }
            }
            .sheet(isPresented: $showingPlayerDetail) {
                if let player = selectedPlayer {
                    PlayerStatsDetailView(
                        player: player,
                        season: selectedSeasonID != nil ? seasons.first(where: { $0.id == selectedSeasonID }) : nil
                    )
                }
            }
        }
    }
}

// 排行榜标签页视图
struct LeaderboardTabView<T: BinaryInteger>: View {
    let title: String
    let items: [(player: Player, value: T)]
    let valueLabel: String
    let getValue: (T) -> T
    let onPlayerSelected: (Player) -> Void
    
    var body: some View {
        List {
            if items.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.player.id) { index, item in
                    Button {
                        onPlayerSelected(item.player)
                    } label: {
                        HStack {
                            // 排名
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(width: 30)
                            
                            // 球员信息
                            VStack(alignment: .leading) {
                                Text(item.player.name)
                                    .font(.headline)
                                HStack {
                                    Text(item.player.position.rawValue)
                                    if let number = item.player.number {
                                        Text("#\(number)")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // 数据
                            HStack {
                                Text("\(getValue(item.value))")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text(valueLabel)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// 球员统计详情视图
struct PlayerStatsDetailView: View {
    let player: Player
    let season: Season?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PlayerInfoSection(player: player)
                    MatchStatsSection(player: player, season: season)
                    
                    if !player.importedStats.isEmpty {
                        ImportedDataSection(player: player, season: season)
                        ImportedRecordsSection(player: player, season: season)
                    }
                    
                    TotalStatsSection(player: player, season: season)
                }
                .padding(.vertical)
            }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 拆分为更小的组件
struct PlayerInfoSection: View {
    let player: Player
    
    var body: some View {
        GroupBox(label: Text("球员信息").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("姓名:").foregroundColor(.gray)
                    Spacer()
                    Text(player.name)
                }
                
                HStack {
                    Text("号码:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.number ?? 0)")
                }
                
                HStack {
                    Text("位置:").foregroundColor(.gray)
                    Spacer()
                    Text(player.position.rawValue)
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
}

struct MatchStatsSection: View {
    let player: Player
    let season: Season?
    
    var body: some View {
        GroupBox(label: Text("比赛统计").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("比赛场次:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.matchCountForSeason(season))")
                }
                
                HStack {
                    Text("进球:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.matchGoalsForSeason(season))")
                }
                
                HStack {
                    Text("助攻:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.matchAssistsForSeason(season))")
                }
                
                HStack {
                    Text("扑救:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.matchSavesForSeason(season))")
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
}

struct ImportedDataSection: View {
    let player: Player
    let season: Season?
    
    var body: some View {
        GroupBox(label: Text("导入数据").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("导入比赛场次:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.importedMatchCountForSeason(season))")
                }
                
                HStack {
                    Text("导入进球:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.importedGoalsForSeason(season))")
                }
                
                HStack {
                    Text("导入助攻:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.importedAssistsForSeason(season))")
                }
                
                HStack {
                    Text("导入扑救:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.importedSavesForSeason(season))")
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
}

struct ImportedRecordsSection: View {
    let player: Player
    let season: Season?
    
    var filteredStats: [ImportedPlayerStats] {
        if let season = season {
            return player.importedStats.filter { $0.season?.id == season.id }
        } else {
            return player.importedStats
        }
    }
    
    var body: some View {
        if !filteredStats.isEmpty {
            GroupBox(label: Text("导入记录").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredStats) { stats in
                        ImportedRecordRow(stats: stats)
                        
                        if stats.id != filteredStats.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
        } else {
            EmptyView()
        }
    }
}

struct ImportedRecordRow: View {
    let stats: ImportedPlayerStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("导入时间: \(stats.importDate.formatted())")
                .font(.caption)
            if let statsSeason = stats.season {
                Text("赛季: \(statsSeason.name)")
                    .font(.caption)
            } else {
                Text("赛季: 未关联")
                    .font(.caption)
            }
            Text("来源: \(stats.source ?? "未知")")
                .font(.caption)
            Text("数据: \(stats.goals)进球, \(stats.assists)助攻, \(stats.saves)扑救, \(stats.matches)场比赛")
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct TotalStatsSection: View {
    let player: Player
    let season: Season?
    
    var body: some View {
        GroupBox(label: Text("总计").font(.headline)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("总比赛场次:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.totalMatchesForSeason(season))")
                }
                
                HStack {
                    Text("总进球:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.totalGoalsForSeason(season))")
                }
                
                HStack {
                    Text("总助攻:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.totalAssistsForSeason(season))")
                }
                
                HStack {
                    Text("总扑救:").foregroundColor(.gray)
                    Spacer()
                    Text("\(player.totalSavesForSeason(season))")
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
}

#Preview {
    LeaderboardView()
} 