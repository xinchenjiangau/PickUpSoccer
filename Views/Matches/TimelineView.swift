import SwiftUI

struct TimelineView: View {
    let match: Match
    
    // 定义UI常量
    private let eventUnitHeight: CGFloat = 50  // 事件卡片固定高度
    private let eventSpacing: CGFloat = 18     // 事件间固定间距
    private let sideSpacing: CGFloat = 16      // 事件卡片到时间线的水平间距
    
    // 按时间排序的所有事件
    private var sortedEvents: [MatchEvent] {
        match.events.sorted { $0.timestamp < $1.timestamp }
    }
    
    // 计算时间线总高度
    private var timelineHeight: CGFloat {
        let eventCount = CGFloat(sortedEvents.count)
        let totalHeight = eventCount * eventUnitHeight + (eventCount - 1) * eventSpacing
        return max(totalHeight, UIScreen.main.bounds.height * 0.7)
    }
    
    var body: some View {
        if match.events.isEmpty {
            EmptyTimelineView()
        } else {
            ScrollView {
                ZStack(alignment: .top) {
                    // 时间线（中间）
                    Rectangle()
                        .fill(Color(red: 0.15, green: 0.50, blue: 0.27))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, UIScreen.main.bounds.width / 2 - 1)
                    
                    // 所有事件和时间点
                    ForEach(Array(sortedEvents.enumerated()), id: \.element.id) { index, event in
                        let yPosition = CGFloat(index) * (eventUnitHeight + eventSpacing)
                        
                        // 主队事件（左侧）
                        if let stats = match.playerStats.first(where: { $0.player?.id == event.scorer?.id }),
                           stats.isHomeTeam {
                            EventCard(event: event, isHomeTeam: true)
                                .frame(height: eventUnitHeight)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, sideSpacing + 16)
                                .position(x: UIScreen.main.bounds.width / 2,
                                        y: yPosition + eventUnitHeight / 2)
                        }
                        
                        // 时间点
                        TimelinePoint(event: event)
                            .position(x: UIScreen.main.bounds.width / 2,
                                    y: yPosition + eventUnitHeight / 2)
                        
                        // 客队事件（右侧）
                        if let stats = match.playerStats.first(where: { $0.player?.id == event.scorer?.id }),
                           !stats.isHomeTeam {
                            EventCard(event: event, isHomeTeam: false)
                                .frame(height: eventUnitHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, sideSpacing + 16)
                                .position(x: UIScreen.main.bounds.width / 2,
                                        y: yPosition + eventUnitHeight / 2)
                        }
                    }
                }
                .frame(height: timelineHeight)
            }
        }
    }
}

// 空状态视图
struct EmptyTimelineView: View {
    var body: some View {
        VStack {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("暂无比赛事件")
                .foregroundColor(.gray)
        }
    }
}

// 时间点组件
struct TimelinePoint: View {
    let event: MatchEvent
    
    var body: some View {
        ZStack {
            // 外圈
            Circle()
                .stroke(Color(red: 0.15, green: 0.50, blue: 0.27), lineWidth: 2)
                .frame(width: 32, height: 32)
            
            // 内圈（白色背景）
            Circle()
                .fill(.white)
                .frame(width: 30, height: 30)
            
            // 时间显示
            Text("\(getEventMinute())'")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 28, height: 28)  // 确保文字在圆圈内
        }
    }
    
    private func getEventMinute() -> Int {
        guard let matchDate = event.match?.matchDate else { return 0 }
        return Int(event.timestamp.timeIntervalSince(matchDate) / 60)
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

// 用于收集事件卡片高度的 PreferenceKey
struct EventHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
} 
    