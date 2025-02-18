import Foundation
import SwiftData

@Model
final class Match {
    var id: UUID
    var status: MatchStatus
    var homeTeamName: String
    var awayTeamName: String
    var matchDate: Date
    var location: String?
    var weather: String?
    var referee: String?
    var duration: Int? // 修改为可选类型
    var homeScore: Int
    var awayScore: Int
    
    @Relationship var season: Season?
    @Relationship(deleteRule: .cascade) var events: [MatchEvent]
    @Relationship(deleteRule: .cascade) var playerStats: [PlayerMatchStats]
    
    init(
        id: UUID = UUID(),
        status: MatchStatus = .notStarted,
        homeTeamName: String,
        awayTeamName: String,
        matchDate: Date,
        location: String? = nil,
        weather: String? = nil,
        referee: String? = nil,
        duration: Int? = nil
    ) {
        self.id = id
        self.status = status
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.matchDate = matchDate
        self.location = location
        self.weather = weather
        self.referee = referee
        self.duration = duration
        self.homeScore = 0
        self.awayScore = 0
        self.events = []
        self.playerStats = []
    }
} 