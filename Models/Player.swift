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
    
    @Relationship(deleteRule: .cascade) var matchStats: [PlayerMatchStats]
    
    init(id: UUID = UUID(),
         name: String,
         number: Int? = nil,
         position: PlayerPosition) {
        self.id = id
        self.name = name
        self.number = number
        self.position = position
        self.matchStats = []
    }
    
    var totalGoals: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.goals
        }
    }
    
    var totalAssists: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.assists
        }
    }
    
    var totalMatches: Int {
        matchStats.count
    }
    
    var totalSaves: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.saves
        }
    }
}

extension Player {
    var isProfileComplete: Bool {
        return name != "新用户" && number != nil && profilePicture != nil
    }
} 