import SwiftUI
import SwiftData

struct MatchesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.matchDate, order: .reverse) private var matches: [Match]
    @State private var showingParticipationSelect = false // 状态变量
    
    var body: some View {
        NavigationView {
            List {
                ForEach(matches) { match in
                    NavigationLink {
                        MatchRecordView(match: match)
                    } label: {
                        MatchRowView(match: match)
                    }
                }
                .onDelete(perform: deleteMatches)
            }
            .navigationTitle("比赛记录")
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
    
    private func deleteMatches(at offsets: IndexSet) {
        for index in offsets {
            let match = matches[index]
            // 由于设置了 cascade 删除规则，只需要删除 Match 即可
            modelContext.delete(match)
        }
        // 保存更改
        try? modelContext.save()
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MatchesView()
    }
} 