import SwiftUI

struct TimelineView: View {
    let match: Match
    
    // 添加动画状态
    @State private var showEvents = false
    
    // 计算比赛时长（分钟）
    private var matchDuration: Int {
        if match.status == .finished {
            return match.duration ?? 0  // 使用 ?? 运算符提供默认值
        }
        return max(Int(Date().timeIntervalSince(match.matchDate) / 60), 1)
    }
    
    // 将事件按队伍分组并排序
    private var groupedEvents: (home: [MatchEvent], away: [MatchEvent]) {
        let sortedEvents = match.events.sorted { $0.timestamp < $1.timestamp }
        print("总事件数: \(sortedEvents.count)")  // 调试输出
        
        let (home, away) = sortedEvents.reduce(into: ([MatchEvent](), [MatchEvent]())) { result, event in
            if let stats = match.playerStats.first(where: { $0.player?.id == event.scorer?.id }) {
                if stats.isHomeTeam {
                    result.0.append(event)
                } else {
                    result.1.append(event)
                }
            }
        }
        
        print("主队事件: \(home.count), 客队事件: \(away.count)")  // 调试输出
        return (home: home, away: away)
    }
    
    var body: some View {
        if match.events.isEmpty {
            // 显示空状态
            VStack {
                Image(systemName: "soccerball")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("暂无比赛事件")
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    // 主队事件（左侧）
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(groupedEvents.home) { event in
                            EventCard(event: event, isHomeTeam: true)
                                .padding(.vertical, getEventPadding(for: event))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 时间线（中间）
                    TimelineBar(events: match.events, duration: matchDuration)
                        .frame(width: 2)
                    
                    // 客队事件（右侧）
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedEvents.away) { event in
                            EventCard(event: event, isHomeTeam: false)
                                .padding(.vertical, getEventPadding(for: event))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .frame(minHeight: UIScreen.main.bounds.height * 0.7)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showEvents = true
                    }
                }
            }
        }
    }
    
    // 计算事件之间的间距
    private func getEventPadding(for event: MatchEvent) -> CGFloat {
        let eventTime = Int(event.timestamp.timeIntervalSince(match.matchDate) / 60)
        return CGFloat(eventTime) * 2 // 每分钟2个点的间距
    }
}

// 时间线组件
struct TimelineBar: View {
    let events: [MatchEvent]
    let duration: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // 时间线
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                // 事件标记点
                ForEach(events.sorted { $0.timestamp < $1.timestamp }) { event in
                    TimelinePoint(event: event)
                        .position(x: geometry.size.width / 2,
                                y: getEventPosition(event, height: geometry.size.height))
                }
            }
        }
    }
    
    private func getEventPosition(_ event: MatchEvent, height: CGFloat) -> CGFloat {
        let eventMinute = Int(event.timestamp.timeIntervalSince(event.match?.matchDate ?? Date()) / 60)
        let position = (CGFloat(eventMinute) / CGFloat(max(duration, 1))) * height
        return min(max(position, 0), height) // 确保位置在有效范围内
    }
}

// 时间点组件
struct TimelinePoint: View {
    let event: MatchEvent
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(getEventMinute())'")
                .font(.caption2)
                .foregroundColor(.gray)
            
            Circle()
                .fill(getEventColor())
                .frame(width: 8, height: 8)
        }
    }
    
    private func getEventMinute() -> Int {
        guard let matchDate = event.match?.matchDate else { return 0 }
        return Int(event.timestamp.timeIntervalSince(matchDate) / 60)
    }
    
    private func getEventColor() -> Color {
        switch event.eventType {
        case .goal:
            return .yellow
        case .assist:
            return .green
        case .save:
            return .blue
        case .yellowCard:
            return .yellow
        case .redCard:
            return .red
        case .foul:
            return .orange
        }
    }
}

// 事件卡片组件
struct EventCard: View {
    let event: MatchEvent
    let isHomeTeam: Bool
    
    var body: some View {
        HStack {
            if isHomeTeam {
                eventContent
                Spacer()
            } else {
                Spacer()
                eventContent
            }
        }
        .padding(.horizontal)
    }
    
    private var eventContent: some View {
        VStack(alignment: isHomeTeam ? .trailing : .leading) {
            Text(getEventDescription())
                .font(.subheadline)
            if let assistant = event.assistant {
                Text("助攻：\(assistant.name)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func getEventDescription() -> String {
        switch event.eventType {
        case .goal:
            return "\(event.scorer?.name ?? "") 进球！"
        case .save:
            return "\(event.scorer?.name ?? "") 扑救"
        case .assist:
            return "\(event.scorer?.name ?? "") 助攻"
        case .foul:
            return "\(event.scorer?.name ?? "") 犯规"
        case .yellowCard:
            return "\(event.scorer?.name ?? "") 黄牌"
        case .redCard:
            return "\(event.scorer?.name ?? "") 红牌"
        }
    }
} 