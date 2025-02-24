import SwiftUI
import SwiftData

struct MatchStatsView: View {
    let match: Match
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 比赛基本信息
                VStack(spacing: 8) {
                    Text("比赛时间：\(match.matchDate.formatted(date: .numeric, time: .shortened))")
                        .foregroundColor(.gray)
                    
                    // 比分区域
                    HStack(spacing: 20) {
                        Text(match.homeTeamName)
                            .foregroundColor(.red)
                        Text("\(match.homeScore) - \(match.awayScore)")
                            .font(.title.bold())
                        Text(match.awayTeamName)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                
                // 比赛数据
                VStack(alignment: .leading, spacing: 15) {
                    DataRow(title: "人数", value: "\(match.playerCount)")
                    if let duration = match.duration {
                        DataRow(title: "比赛时长", value: "\(duration)分钟")
                    }
                    if let referee = match.referee {
                        DataRow(title: "比赛裁判", value: referee)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                
                // 最佳球员
                VStack(alignment: .leading, spacing: 15) {
                    if let mvp = match.mvp {
                        PlayerAwardRow(title: "MVP", player: mvp)
                    }
                    if let topScorer = match.topScorer {
                        PlayerAwardRow(title: "最佳射手", player: topScorer)
                    }
                    if let topGoalkeeper = match.topGoalkeeper {
                        PlayerAwardRow(title: "最佳门将", player: topGoalkeeper)
                    }
                    if let topPlaymaker = match.topPlaymaker {
                        PlayerAwardRow(title: "最佳组织", player: topPlaymaker)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
            }
            .padding()
        }
        .background(ThemeColor.background)
        .navigationTitle("比赛数据")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 数据行组件
struct DataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.black)
        }
    }
}

// 球员奖项行组件
struct PlayerAwardRow: View {
    let title: String
    let player: Player
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(player.name)
                .foregroundColor(.black)
        }
    }
} 
