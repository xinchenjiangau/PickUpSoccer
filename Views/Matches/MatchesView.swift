import SwiftUI
import SwiftData

struct MatchesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.matchDate) private var matches: [Match]
    @State private var showingParticipationSelect = false // 状态变量
    
    var body: some View {
        NavigationView {
            List {
                // 按状态分类
                ForEach(MatchStatus.allCases, id: \.self) { status in
                    let filteredMatches = matches.filter { $0.status == status }
                    if !filteredMatches.isEmpty { // 只有在有比赛时才显示标题
                        Section(header: Text(status.rawValue)) {
                            ForEach(filteredMatches) { match in
                                HStack {
                                    Text("\(match.homeTeamName) vs \(match.awayTeamName)")
                                    Spacer()
                                    Text("\(match.homeScore) - \(match.awayScore)")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("比赛")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingParticipationSelect = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingParticipationSelect) {
                ParticipationSelectView()
            }
        }
    }
}

#Preview {
    MatchesView()
} 