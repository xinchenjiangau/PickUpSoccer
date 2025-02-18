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
    var duration: Int?
    var homeScore: Int
    var awayScore: Int
    
    @Relationship var season: Season?
    @Relationship(deleteRule: .cascade) var events: [MatchEvent]
    @Relationship(deleteRule: .cascade) var playerStats: [PlayerMatchStats]
    
    init(
        id: UUID = UUID(),
        status: MatchStatus = .notStarted,
        homeTeamName: String,
        awayTeamName: String
    ) {
        self.id = id
        self.status = status
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.matchDate = Date()
        self.location = nil
        self.weather = nil
        self.referee = nil
        self.duration = nil
        self.homeScore = 0
        self.awayScore = 0
        self.events = []
        self.playerStats = []
    }
} 