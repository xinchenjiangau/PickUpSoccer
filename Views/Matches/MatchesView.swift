import SwiftUI
import SwiftData

struct MatchesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingParticipationSelect = false
    @State private var showingSeasonManager = false
    @State private var selectedSeasonID: UUID?
    
    // 查询所有赛季
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    
    // 根据选择的赛季过滤比赛
    var filteredMatches: [Match] {
        if let selectedSeasonID = selectedSeasonID,
           let selectedSeason = seasons.first(where: { $0.id == selectedSeasonID }) {
            return selectedSeason.matches.sorted(by: { $0.matchDate > $1.matchDate })
        } else {
            // 如果没有选择赛季，显示所有比赛
            return allMatches
        }
    }
    
    // 查询所有比赛
    @Query(sort: \Match.matchDate, order: .reverse) private var allMatches: [Match]
    
    // 按状态分组的比赛
    var matchesByStatus: [(status: MatchStatus, matches: [Match])] {
        let grouped = Dictionary(grouping: filteredMatches) { $0.status }
        return MatchStatus.allCases
            .map { status in
                (status: status, matches: grouped[status] ?? [])
            }
            .filter { !$0.matches.isEmpty } // 只显示有比赛的状态
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 赛季选择器
                if !seasons.isEmpty {
                    Picker("选择赛季", selection: $selectedSeasonID) {
                        Text("全部比赛").tag(nil as UUID?)
                        ForEach(seasons) { season in
                            Text(season.name).tag(season.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }
                
                List {
                    ForEach(matchesByStatus, id: \.status) { section in
                        Section(header: Text(section.status.rawValue)) {
                            ForEach(section.matches) { match in
                                if match.status == .finished {
                                    // 已结束的比赛导航到统计视图
                                    NavigationLink {
                                        MatchStatsView(match: match)
                                    } label: {
                                        MatchRowView(match: match)
                                    }
                                } else {
                                    // 进行中的比赛导航到记录视图
                                    NavigationLink {
                                        MatchRecordView(match: match)
                                    } label: {
                                        MatchRowView(match: match)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                // 获取当前分组中的比赛
                                let matchesToDelete = indexSet.map { section.matches[$0] }
                                for match in matchesToDelete {
                                    modelContext.delete(match)
                                }
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
            .navigationTitle("比赛")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingParticipationSelect = true
                        }) {
                            Label("新建比赛", systemImage: "plus")
                        }
                        
                        Button(action: {
                            showingSeasonManager = true
                        }) {
                            Label("管理赛季", systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingParticipationSelect) {
                ParticipationSelectView(selectedSeasonID: selectedSeasonID)
            }
            .sheet(isPresented: $showingSeasonManager) {
                NavigationStack {
                    SeasonManager()
                }
            }
            .onAppear {
                // 如果没有选择赛季且有赛季数据，默认选择最新的赛季
                if selectedSeasonID == nil && !seasons.isEmpty {
                    selectedSeasonID = seasons.first?.id
                }
            }
        }
    }
}

// 比赛行视图
struct MatchRowView: View {
    let match: Match
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 比赛日期
            Text(match.matchDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.gray)
            
            // 比分
            HStack {
                Text(match.homeTeamName)
                    .foregroundColor(.red)
                Text("\(match.homeScore) - \(match.awayScore)")
                    .font(.headline)
                Text(match.awayTeamName)
                    .foregroundColor(.blue)
            }
            
            // 比赛状态
            Text(match.status.rawValue)
                .font(.caption)
                .foregroundColor(match.status == .finished ? .gray : .green)
            
            // 显示赛季信息（如果有）
            if let season = match.season {
                Text("赛季: \(season.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MatchesView()
    }
} 