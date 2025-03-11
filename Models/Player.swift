import Foundation
import SwiftData

@Model
final class Player {
    var id: UUID
    var name: String
    var number: Int?
    var position: PlayerPosition
    var phone: String?
    var email: String?
    var profilePicture: URL?
    var age: Int?
    var gender: String?
    var height: Double?
    var weight: Double?
    var appleUserID: String?
    var nickname: String?
    
    @Relationship(deleteRule: .cascade) var matchStats: [PlayerMatchStats]
    @Relationship(deleteRule: .cascade) var importedStats: [ImportedPlayerStats]
    
    init(id: UUID = UUID(),
         name: String,
         number: Int? = nil,
         position: PlayerPosition) {
        self.id = id
        self.name = name
        self.number = number
        self.position = position
        self.matchStats = []
        self.importedStats = []
    }
    
    // 比赛中的进球数
    var matchGoals: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.goals
        }
    }
    
    // 导入的进球数
    var importedGoals: Int {
        importedStats.reduce(into: 0) { result, stats in
            result += stats.goals
        }
    }
    
    // 总进球数（比赛 + 导入）
    var totalGoals: Int {
        matchGoals + importedGoals
    }
    
    // 比赛中的助攻数
    var matchAssists: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.assists
        }
    }
    
    // 导入的助攻数
    var importedAssists: Int {
        importedStats.reduce(into: 0) { result, stats in
            result += stats.assists
        }
    }
    
    // 总助攻数（比赛 + 导入）
    var totalAssists: Int {
        matchAssists + importedAssists
    }
    
    // 比赛场次
    var matchCount: Int {
        matchStats.count
    }
    
    // 导入的比赛场次
    var importedMatchCount: Int {
        importedStats.reduce(into: 0) { result, stats in
            result += stats.matches
        }
    }
    
    // 总比赛场次（比赛 + 导入）
    var totalMatches: Int {
        matchCount + importedMatchCount
    }
    
    // 比赛中的扑救数
    var matchSaves: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.saves
        }
    }
    
    // 导入的扑救数
    var importedSaves: Int {
        importedStats.reduce(into: 0) { result, stats in
            result += stats.saves
        }
    }
    
    // 总扑救数（比赛 + 导入）
    var totalSaves: Int {
        matchSaves + importedSaves
    }
    
    // 按赛季筛选的统计方法
    func matchGoalsForSeason(_ season: Season?) -> Int {
        guard let season = season else { return matchGoals }
        return matchStats.filter { $0.match?.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.goals
        }
    }
    
    func importedGoalsForSeason(_ season: Season?) -> Int {
        guard let season = season else { return importedGoals }
        return importedStats.filter { $0.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.goals
        }
    }
    
    func totalGoalsForSeason(_ season: Season?) -> Int {
        matchGoalsForSeason(season) + importedGoalsForSeason(season)
    }
    
    func matchAssistsForSeason(_ season: Season?) -> Int {
        guard let season = season else { return matchAssists }
        return matchStats.filter { $0.match?.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.assists
        }
    }
    
    func importedAssistsForSeason(_ season: Season?) -> Int {
        guard let season = season else { return importedAssists }
        return importedStats.filter { $0.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.assists
        }
    }
    
    func totalAssistsForSeason(_ season: Season?) -> Int {
        matchAssistsForSeason(season) + importedAssistsForSeason(season)
    }
    
    func matchCountForSeason(_ season: Season?) -> Int {
        guard let season = season else { return matchCount }
        return matchStats.filter { $0.match?.season?.id == season.id }.count
    }
    
    func importedMatchCountForSeason(_ season: Season?) -> Int {
        guard let season = season else { return importedMatchCount }
        return importedStats.filter { $0.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.matches
        }
    }
    
    func totalMatchesForSeason(_ season: Season?) -> Int {
        matchCountForSeason(season) + importedMatchCountForSeason(season)
    }
    
    func matchSavesForSeason(_ season: Season?) -> Int {
        guard let season = season else { return matchSaves }
        return matchStats.filter { $0.match?.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.saves
        }
    }
    
    func importedSavesForSeason(_ season: Season?) -> Int {
        guard let season = season else { return importedSaves }
        return importedStats.filter { $0.season?.id == season.id }.reduce(into: 0) { result, stats in
            result += stats.saves
        }
    }
    
    func totalSavesForSeason(_ season: Season?) -> Int {
        matchSavesForSeason(season) + importedSavesForSeason(season)
    }
}

extension Player {
    var isProfileComplete: Bool {
        return name != "新用户" && number != nil && profilePicture != nil
    }
} 