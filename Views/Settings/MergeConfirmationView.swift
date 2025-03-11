import SwiftUI
import SwiftData

enum MergeStrategy {
    case sum      // 求和
    case replace  // 覆盖
    case skip     // 跳过
}

struct MergeConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let existingPlayer: Player
    let importedData: [String: Any]
    let onComplete: (MergeStrategy) -> Void
    
    @State private var selectedStrategy: MergeStrategy = .sum
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("发现同名球员")) {
                    if let lineNumber = importedData["lineNumber"] as? Int {
                        Text("第 \(lineNumber) 行数据")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Text("已找到同名球员：\(existingPlayer.name)")
                        .fontWeight(.bold)
                    
                    if let number = existingPlayer.number {
                        Text("号码：\(number)")
                    }
                    
                    Text("位置：\(existingPlayer.position.rawValue)")
                }
                
                if let season = importedSeason {
                    Section(header: Text("导入赛季")) {
                        Text("数据将关联到赛季：\(season.name)")
                            .foregroundColor(.blue)
                    }
                } else {
                    Section(header: Text("导入赛季")) {
                        Text("数据不关联赛季")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("数据对比")) {
                    ComparisonRow(title: "进球", existing: existingPlayer.totalGoals, imported: importedGoals)
                    ComparisonRow(title: "助攻", existing: existingPlayer.totalAssists, imported: importedAssists)
                    ComparisonRow(title: "扑救", existing: existingPlayer.totalSaves, imported: importedSaves)
                    ComparisonRow(title: "比赛", existing: existingPlayer.totalMatches, imported: importedMatches)
                }
                
                Section(header: Text("合并方式")) {
                    Picker("选择合并方式", selection: $selectedStrategy) {
                        Text("求和（合并数据）").tag(MergeStrategy.sum)
                        Text("覆盖（使用导入数据）").tag(MergeStrategy.replace)
                        Text("跳过（保留现有数据）").tag(MergeStrategy.skip)
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button(action: {
                        onComplete(selectedStrategy)
                        dismiss()
                    }) {
                        Text("确认")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    
                    Button(action: {
                        onComplete(.skip)
                        dismiss()
                    }) {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.red)
                    }
                    .listRowBackground(Color.gray.opacity(0.2))
                }
            }
            .navigationTitle("数据合并确认")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // 从导入数据中获取赛季
    private var importedSeason: Season? {
        return importedData["season"] as? Season
    }
    
    // 从导入数据中获取进球数
    private var importedGoals: Int {
        return importedData["goals"] as? Int ?? 0
    }
    
    // 从导入数据中获取助攻数
    private var importedAssists: Int {
        return importedData["assists"] as? Int ?? 0
    }
    
    // 从导入数据中获取扑救数
    private var importedSaves: Int {
        return importedData["saves"] as? Int ?? 0
    }
    
    // 从导入数据中获取比赛数
    private var importedMatches: Int {
        return importedData["matches"] as? Int ?? 0
    }
}

// 数据对比行
struct ComparisonRow: View {
    let title: String
    let existing: Int
    let imported: Int
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            HStack(spacing: 15) {
                Text("现有: \(existing)")
                    .foregroundColor(.blue)
                Text("导入: \(imported)")
                    .foregroundColor(.green)
                Text("合并: \(existing + imported)")
                    .foregroundColor(.orange)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, configurations: config)
    
    let player = Player(name: "测试球员", number: 10, position: .forward)
    
    return MergeConfirmationView(
        existingPlayer: player,
        importedData: ["goals": 5, "assists": 3, "saves": 0, "matches": 10],
        onComplete: { _ in }
    )
    .modelContainer(container)
} 