import SwiftUI
import SwiftData

struct MatchRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var match: Match
    @State private var showingEventSelection = false
    
    var redTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
    }
    
    var blueTeamPlayers: [Player] {
        match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 比分区域
                VStack {
                    HStack {
                        VStack {
                            Text("红队")
                                .font(.headline)
                            Text("\(match.homeScore)") // 红队得分
                                .font(.largeTitle)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("比赛时间")
                                .font(.headline)
                            Text("60:22")
                                .font(.title)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("蓝队")
                                .font(.headline)
                            Text("\(match.awayScore)") // 蓝队得分
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(10)
                    .padding()
                    
                    HStack {
                        Button(action: {
                            showingEventSelection = true
                        }) {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.red)
                                Text("红队: \(redTeamPlayers.count)人")
                            }
                        }
                        Spacer()
                        Button(action: {
                            showingEventSelection = true
                        }) {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.blue)
                                Text("蓝队: \(blueTeamPlayers.count)人")
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: UIScreen.main.bounds.height * 0.2)
                
                // 时间线区域
                ScrollView {
                    VStack {
                        ForEach(match.events.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                            Text("\(event.eventType.rawValue)")
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("比赛记录")
            .navigationBarItems(leading: Button("返回") {
                // 返回到 MatchesView
            }, trailing: Button("结束比赛") {
                match.status = .finished
                // 返回到 MatchesView
            })
            .fullScreenCover(isPresented: $showingEventSelection) {
                EventSelectionView(match: match)
            }
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
        awayTeamName: "蓝队",
        matchDate: Date(),
        duration: nil
    )
    return MatchRecordView(match: newMatch)
        .modelContainer(container)
} 