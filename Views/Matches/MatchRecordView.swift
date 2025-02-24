import SwiftUI
import SwiftData

struct MatchRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var match: Match
    @State private var showingEventSelection = false
    @State private var selectedTeamIsHome = true // 用于标识选中的是主队还是客队
    @State private var shouldNavigateToMatches = false  // 用于控制返回到 MatchesView
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var redTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
    }
    
    var blueTeamPlayers: [Player] {
        match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
    }
    
    var matchDuration: String {
        let duration = currentTime.timeIntervalSince(match.matchDate)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 比分区域
                VStack(spacing: 20) {
                    // 比赛时间显示
                    Text(matchDuration)
                        .font(.custom("DingTalk JinBuTi", size: 20))
                        .foregroundColor(.black)
                        .padding(.top, 10)
                        .onReceive(timer) { _ in
                            // 只在比赛进行中更新时间
                            if match.status == .inProgress {
                                currentTime = Date()
                            }
                        }
                    
                    // 队伍名称
                    HStack(spacing: 140) {
                        Text("红队")
                            .font(.custom("PingFang MO", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        
                        Text("蓝队")
                            .font(.custom("PingFang MO", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 0.26, green: 0.56, blue: 0.81))
                    }
                    .padding(.horizontal, 40)
                    
                    // 比分显示
                    HStack(spacing: 30) {
                        // 红队按钮
                        Button(action: {
                            selectedTeamIsHome = true
                            showingEventSelection = true
                        }) {
                            Text("\(match.homeScore)")
                                .font(.custom("Poppins", size: 60))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(width: 100, height: 100)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        
                        Text("-")
                            .font(.custom("Poppins", size: 60))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        
                        // 蓝队按钮
                        Button(action: {
                            selectedTeamIsHome = false
                            showingEventSelection = true
                        }) {
                            Text("\(match.awayScore)")
                                .font(.custom("Poppins", size: 60))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(width: 100, height: 100)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.vertical, 20)
                .background(Color.white)
                .shadow(radius: 1)
                
                // 时间线标题
                Text("时间线")
                    .font(.custom("PingFang MO", size: 24))
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.15, green: 0.50, blue: 0.27))
                    .padding(.vertical, 20)
                
                // 时间线视图
                TimelineView(match: match)
                    .frame(maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        shouldNavigateToMatches = true
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("结束比赛") {
                        endMatch()
                    }
                }
            }
            .navigationDestination(isPresented: $shouldNavigateToMatches) {
                MatchesView()
            }
        }
        .sheet(isPresented: $showingEventSelection) {
            EventSelectionView(match: match, isHomeTeam: selectedTeamIsHome)
        }
    }
    
    private func endMatch() {
        // 停止计时
        timer.upstream.connect().cancel()
        
        // 更新比赛状态为已结束
        match.status = .finished
        
        // 计算并保存比赛时长（只保存分钟数）
        match.duration = Int(currentTime.timeIntervalSince(match.matchDate) / 60)
        
        // 保存更改
        try? modelContext.save()
        
        // 返回到 MatchesView
        shouldNavigateToMatches = true
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
            // 时间显示
            Text(eventTimeString)
                .font(.custom("DingTalk JinBuTi", size: 14))
                .foregroundColor(.black)
            
            // 时间线
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)
                
                if !isLastEvent {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 40)
                }
            }
            
            // 事件内容
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: event.eventType == .goal ? "soccerball" : "hand.raised.fill")
                        .foregroundColor(eventColor)
                    Text(event.eventType.rawValue)
                        .font(.custom("PingFang MO", size: 16))
                        .foregroundColor(eventColor)
                }
                
                Text(eventDescription)
                    .font(.custom("PingFang MO", size: 14))
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
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
