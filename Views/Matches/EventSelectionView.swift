import SwiftUI
import SwiftData

struct EventSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @Bindable var match: Match
    
    var body: some View {
        NavigationView {
            VStack {
                Text("比赛事件选择")
                    .font(.largeTitle)
                // 这里可以添加事件选择的内容
            }
            .navigationTitle("选择事件")
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
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
        awayTeamName: "蓝队"
    )
    return EventSelectionView(match: newMatch)
        .modelContainer(container)
} 