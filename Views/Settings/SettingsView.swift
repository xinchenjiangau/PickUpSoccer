import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: PlayerListView()) {
                        Label("球员名单", systemImage: "person.3")
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Player.self, inMemory: true)
} 