import SwiftUI

struct TeamSelectView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var selectedPlayers: [Player]
    @State private var playerColors: [UUID: Color] = [:] // 存储每个球员的颜色
    @State private var firstPlayerSelected: Bool = false // 记录是否已选择第一个球员
    @State private var showingMatchRecord = false // 状态变量
    
    var redTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .red }
    }
    
    var blueTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .blue }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(selectedPlayers, id: \.id) { player in
                    Button(action: {
                        togglePlayerColor(player)
                    }) {
                        HStack {
                            Text(player.name)
                                .foregroundColor(playerColors[player.id] ?? .gray) // 默认灰色
                        }
                    }
                }
            }
            .navigationTitle("选择球队")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("开始比赛") {
                        showingMatchRecord = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingMatchRecord) {
                MatchRecordView(redTeam: redTeam, blueTeam: blueTeam)
            }
        }
    }
    
    private func togglePlayerColor(_ player: Player) {
        if !firstPlayerSelected {
            // 第一次点击，设置第一个球员为红色，其他为蓝色
            playerColors[player.id] = .red
            firstPlayerSelected = true
            
            // 将其他球员设置为蓝色
            for otherPlayer in selectedPlayers where otherPlayer.id != player.id {
                playerColors[otherPlayer.id] = .blue
            }
        } else {
            // 如果已经选择了第一个球员，切换颜色
            if playerColors[player.id] == .red {
                playerColors[player.id] = .blue // 切换为蓝色
            } else {
                playerColors[player.id] = .red // 切换为红色
            }
        }
    }
}

#Preview {
    TeamSelectView(selectedPlayers: [Player(name: "球员1", position: .forward), Player(name: "球员2", position: .midfielder)])
} 