import SwiftUI
import SwiftData

struct MatchRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var match: Match
    @State private var showingEventSelection = false
    
    var redTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
    }
    
    var blueTeamPlayers: [Player] {
        match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 比分区域 (2/5)
            VStack(spacing: 16) {
                // 比分显示
                HStack {
                    VStack {
                        Text("红队")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("\(match.homeScore)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("VS")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    VStack {
                        Text("蓝队")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("\(match.awayScore)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)
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
            
            // 时间线区域 (3/5)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(match.events.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                        TimelineEventView(event: event)
                    }
                    if match.events.isEmpty {
                        Text("暂无比赛事件")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
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
        .sheet(isPresented: $showingEventSelection) {
            EventSelectionView(match: match)
        }
    }
    
    private func endMatch() {
        match.status = .finished
        dismiss()
    }
}

struct TimelineEventView: View {
    let event: MatchEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 时间线圆点和线
            VStack {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 10)
                if true { // 如果不是最后一个事件
                    Rectangle()
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            
            // 事件内容
            VStack(alignment: .leading, spacing: 8) {
                Text(event.eventType.rawValue)
                    .font(.headline)
                Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
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