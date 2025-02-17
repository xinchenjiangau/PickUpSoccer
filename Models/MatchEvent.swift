import Foundation
import SwiftData

@Model
final class MatchEvent {
    var id: UUID
    var eventType: EventType
    var timestamp: Date
    
    @Relationship var match: Match?
    @Relationship var scorer: Player? // 进球者
    @Relationship var assistant: Player? // 助攻者
    
    init(id: UUID = UUID(),
         eventType: EventType,
         timestamp: Date,
         match: Match? = nil,
         scorer: Player? = nil,
         assistant: Player? = nil) {
        self.id = id
        self.eventType = eventType
        self.timestamp = timestamp
        self.match = match
        self.scorer = scorer
        self.assistant = assistant
    }
} 