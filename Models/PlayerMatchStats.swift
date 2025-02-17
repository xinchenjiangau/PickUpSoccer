import Foundation
import SwiftData

@Model
final class PlayerMatchStats {
    var id: UUID
    @Relationship var player: Player?
    @Relationship var match: Match?
    
    var goals: Int
    var assists: Int
    var saves: Int
    var fouls: Int
    var minutesPlayed: Int
    var distance: Double? // 跑动距离（米）
    
    init(id: UUID = UUID(),
         player: Player? = nil,
         match: Match? = nil) {
        self.id = id
        self.player = player
        self.match = match
        self.goals = 0
        self.assists = 0
        self.saves = 0
        self.fouls = 0
        self.minutesPlayed = 0
    }
} 