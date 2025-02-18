import SwiftUI

struct MatchRecordView: View {
    var redTeam: [Player]
    var blueTeam: [Player]
    
    @State private var showingEventSelection = false // 状态变量
    
    var body: some View {
        NavigationView {
            VStack {
                // 比分区域
                VStack {
                    HStack {
                        VStack {
                            Text("红队")
                                .font(.headline)
                            Text("0") // 红队得分
                                .font(.largeTitle)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("比赛时间")
                                .font(.headline)
                            Text("60:22") // 示例时间
                                .font(.title)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("蓝队")
                                .font(.headline)
                            Text("0") // 蓝队得分
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
                                Image(systemName: "circle.fill") // 红队图标
                                    .foregroundColor(.red)
                                Text("红队: \(redTeam.count)人")
                            }
                        }
                        Spacer()
                        Button(action: {
                            showingEventSelection = true
                        }) {
                            HStack {
                                Image(systemName: "circle.fill") // 蓝队图标
                                    .foregroundColor(.blue)
                                Text("蓝队: \(blueTeam.count)人")
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: UIScreen.main.bounds.height * 0.2) // 占屏幕总高度的2/5
                
                // 时间线区域
                ScrollView {
                    VStack {
                        ForEach(0..<20) { index in
                            Text("事件 \(index + 1)")
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity) // 占屏幕总高度的3/5
            }
            .navigationTitle("比赛记录")
            .navigationBarItems(leading: Button("返回") {
                // 返回到 MatchesView
            }, trailing: Button("结束比赛") {
                // 结束比赛并返回到 MatchesView
            })
            .fullScreenCover(isPresented: $showingEventSelection) {
                EventSelectionView() // 跳转到比赛事件选择页面
            }
        }
    }
}

#Preview {
    MatchRecordView(redTeam: [Player(name: "球员1", position: .forward)], blueTeam: [Player(name: "球员2", position: .midfielder)])
} 