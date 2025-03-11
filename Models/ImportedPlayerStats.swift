import Foundation
import SwiftData

@Model
final class ImportedPlayerStats {
    var id: UUID
    @Relationship var player: Player?
    @Relationship var season: Season?
    
    var goals: Int
    var assists: Int
    var saves: Int
    var matches: Int
    var importDate: Date
    var source: String?
    
    init(id: UUID = UUID(),
         player: Player? = nil,
         season: Season? = nil,
         goals: Int = 0,
         assists: Int = 0,
         saves: Int = 0,
         matches: Int = 0,
         source: String? = nil) {
        self.id = id
        self.player = player
        self.season = season
        self.goals = goals
        self.assists = assists
        self.saves = saves
        self.matches = matches
        self.importDate = Date()
        self.source = source
    }
} 