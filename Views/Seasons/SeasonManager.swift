import SwiftUI
import SwiftData

struct SeasonManager: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    @State private var showingAddSeason = false
    
    var body: some View {
        List {
            ForEach(seasons) { season in
                NavigationLink(destination: SeasonDetailView(season: season)) {
                    VStack(alignment: .leading) {
                        Text(season.name)
                            .font(.headline)
                        
                        Text("\(season.startDate.formatted(date: .abbreviated, time: .omitted)) - \(season.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("比赛: \(season.matches.count)场")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteSeasons)
        }
        .navigationTitle("赛季管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddSeason = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSeason) {
            AddSeasonView()
        }
    }
    
    private func deleteSeasons(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(seasons[index])
        }
        try? modelContext.save()
    }
}

struct AddSeasonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24*90) // 默认3个月
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("赛季信息")) {
                    TextField("赛季名称", text: $name)
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                }
                
                Section(header: Text("备注")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("添加赛季")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSeason()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveSeason() {
        let newSeason = Season(
            name: name,
            startDate: startDate,
            endDate: endDate,
            notes: notes.isEmpty ? nil : notes
        )
        
        modelContext.insert(newSeason)
        try? modelContext.save()
        dismiss()
    }
}

struct SeasonDetailView: View {
    @Bindable var season: Season
    
    var body: some View {
        List {
            Section(header: Text("赛季信息")) {
                LabeledContent("开始日期", value: season.startDate.formatted(date: .long, time: .omitted))
                LabeledContent("结束日期", value: season.endDate.formatted(date: .long, time: .omitted))
                if let notes = season.notes, !notes.isEmpty {
                    LabeledContent("备注", value: notes)
                }
            }
            
            Section(header: Text("比赛")) {
                ForEach(season.matches.sorted(by: { $0.matchDate > $1.matchDate })) { match in
                    NavigationLink(destination: matchDestination(for: match)) {
                        VStack(alignment: .leading) {
                            Text(match.matchDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Text(match.homeTeamName)
                                    .foregroundColor(.red)
                                Text("\(match.homeScore) - \(match.awayScore)")
                                    .font(.headline)
                                Text(match.awayTeamName)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(season.name)
    }
    
    @ViewBuilder
    private func matchDestination(for match: Match) -> some View {
        if match.status == .finished {
            MatchStatsView(match: match)
        } else {
            MatchRecordView(match: match)
        }
    }
}

#Preview {
    NavigationStack {
        SeasonManager()
    }
} 