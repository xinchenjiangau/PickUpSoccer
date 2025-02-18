import SwiftUI

struct EventSelectionView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("比赛事件选择")
                    .font(.largeTitle)
                // 这里可以添加事件选择的内容
            }
            .navigationTitle("选择事件")
        }
    }
}

#Preview {
    EventSelectionView()
} 