import SwiftUI
import SwiftData

struct MatchRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var match: Match
    @State private var showingEventSelection = false
    @State private var selectedTeamIsHome = true // 用于标识选中的是主队还是客队
    @State private var shouldDismissToRoot = false // 用于控制返回到根视图
    
    var redTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
    }
    
    var blueTeamPlayers: [Player] {
        match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
    }
    
    var matchDuration: String {
        let duration = Date().timeIntervalSince(match.matchDate)
        let minutes = Int(duration / 60)
        return "\(minutes)'"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 比分区域
                VStack(spacing: 16) {
                    // 比赛时间显示
                    Text(matchDuration)
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    // 比分显示
                    HStack {
                        // 红队按钮
                        Button(action: {
                            selectedTeamIsHome = true
                            showingEventSelection = true
                        }) {
                            VStack {
                                Text("红队")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("\(match.homeScore)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Text("VS")
                            .font(.title)
                            .foregroundColor(.gray)
                        
                        // 蓝队按钮
                        Button(action: {
                            selectedTeamIsHome = false
                            showingEventSelection = true
                        }) {
                            VStack {
                                Text("蓝队")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text("\(match.awayScore)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(15)
                    
                    // 球员信息
                    HStack {
                        VStack(alignment: .leading) {
                            Text("红队: \(redTeamPlayers.count)人")
                                .foregroundColor(.red)
                            ForEach(redTeamPlayers) { player in
                                Text(player.name)
                                    .font(.caption)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("蓝队: \(blueTeamPlayers.count)人")
                                .foregroundColor(.blue)
                            ForEach(blueTeamPlayers) { player in
                                Text(player.name)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: UIScreen.main.bounds.height * 0.2)
                .background(Color.white)
                .shadow(radius: 2)
                
                // 时间线区域
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        let sortedEvents = match.events.sorted(by: { $0.timestamp > $1.timestamp })
                        ForEach(Array(sortedEvents.enumerated()), id: \.element.id) { index, event in
                            TimelineEventView(
                                event: event,
                                isLastEvent: index == sortedEvents.count - 1
                            )
                        }
                        if match.events.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "soccerball")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("暂无比赛事件")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        }
                    }
                    .padding(.vertical)
                }
                .frame(maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("结束比赛") {
                        endMatch()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEventSelection) {
            EventSelectionView(match: match, isHomeTeam: selectedTeamIsHome)
        }
    }
    
    private func endMatch() {
        // 更新比赛状态
        match.status = .finished
        match.duration = Int(Date().timeIntervalSince(match.matchDate) / 60)
        
        // 保存更改
        try? modelContext.save()
        
        // 返回到 MatchesView
        dismiss()
    }
}

struct TimelineEventView: View {
    let event: MatchEvent
    let isLastEvent: Bool
    
    var eventTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.timestamp)
    }
    
    var eventDescription: String {
        switch event.eventType {
        case .goal:
            if let assistant = event.assistant {
                return "\(event.scorer?.name ?? "") 进球！\n助攻：\(assistant.name)"
            } else {
                return "\(event.scorer?.name ?? "") 进球！"
            }
        case .assist:
            return "\(event.scorer?.name ?? "") 助攻"
        case .foul:
            return "\(event.scorer?.name ?? "") 犯规"
        case .save:
            return "\(event.scorer?.name ?? "") 扑救"
        case .yellowCard:
            return "\(event.scorer?.name ?? "") 黄牌"
        case .redCard:
            return "\(event.scorer?.name ?? "") 红牌"
        }
    }
    
    var eventColor: Color {
        switch event.eventType {
        case .goal:
            return .yellow
        case .assist:
            return .green
        case .foul:
            return .orange
        case .save:
            return .blue
        case .yellowCard:
            return .yellow
        case .redCard:
            return .red
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 时间线
            VStack(spacing: 0) {
                // 时间
                Text(eventTimeString)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)
                
                // 时间线圆点
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)
                
                // 连接线
                if !isLastEvent {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 40)
                }
            }
            
            // 事件内容
            VStack(alignment: .leading, spacing: 8) {
                // 事件类型标签
                HStack {
                    Image(systemName: event.eventType == .goal ? "soccerball" : "hand.raised.fill")
                        .foregroundColor(eventColor)
                    Text(event.eventType.rawValue)
                        .font(.headline)
                        .foregroundColor(eventColor)
                }
                
                // 事件描述
                Text(eventDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
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
    return MatchRecordView(match: newMatch)
        .modelContainer(container)
} 