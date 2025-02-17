import SwiftUI
import SwiftData

struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.number) private var players: [Player]
    @State private var showingAddPlayer = false
    
    var body: some View {
        List {
            ForEach(players) { player in
                HStack {
                    Text("\(player.number ?? 0)")
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                    Text(player.name)
                    Spacer()
                    Text(player.position.rawValue)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deletePlayers)
        }
        .navigationTitle("球员名单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddPlayer = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
    }
    
    private func deletePlayers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(players[index])
            }
        }
    }
}

#Preview {
    PlayerListView()
        .modelContainer(for: Player.self, inMemory: true)
} 