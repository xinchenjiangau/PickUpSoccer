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
    var boots: String
    
    // 统计数据（可通过计算获得）
    var totalGoals: Int = 0
    var totalAssists: Int = 0
    var totalMatches: Int = 0
    
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
        self.boots = ""
    }
}

extension Player {
    var isProfileComplete: Bool {
        return name != "新用户" && number != nil && profilePicture != nil
    }
} 