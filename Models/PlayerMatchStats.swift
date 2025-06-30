import Foundation
import SwiftData

@Model
final class PlayerMatchStats {
    var id: UUID
    @Relationship var player: Player?
    @Relationship var match: Match?
    var isHomeTeam: Bool
    
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
        self.isHomeTeam = false // 默认值
        self.goals = 0
        self.assists = 0
        self.saves = 0
        self.fouls = 0
        self.minutesPlayed = 0
    }

    /// 单场评分算法，满分10分，基础分6.0
    var score: Double {
        let goalScore = 3.5 * (1 - exp(-1.0 * Double(goals)))
        let assistScore = 2.1 * (1 - exp(-0.8 * Double(assists)))
        let saveScore = 2.2 * (1 - exp(-0.9 * Double(saves)))
        let rawScore = 5.0 + goalScore + assistScore + saveScore
        return min(rawScore, 10.0)
    }


} 
