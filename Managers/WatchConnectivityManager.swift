//
//  WatchConnectivityManager.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import Foundation
import WatchConnectivity
import SwiftData

@MainActor
class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    private var session: WCSession?
    private var modelContainer: ModelContainer?

    // Allows external injection of ModelContainer
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Sending Data to Watch

    /// Sends initial match data to the Watch.
    func sendStartMatchToWatch(match: Match) {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            print("WCSession not available or watch app not installed.")
            return
        }

        let playersPayload = match.playerStats.map { stats in
            [
                "id": stats.player!.id.uuidString,
                "name": stats.player!.name,
                "isHomeTeam": stats.isHomeTeam
            ]
        }
        let payload: [String: Any] = [
            "command": "startMatch",
            "matchId": match.id.uuidString,
            "homeTeamName": match.homeTeamName,
            "awayTeamName": match.awayTeamName,
            "players": playersPayload
        ]
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - New unified function to send complete match end data to Watch
    /// Sends comprehensive match end data including scores and all events to the Watch.
    func sendFullMatchEndToWatch(match: Match) {
        guard let session = session, session.isReachable else {
            print("WCSession not reachable for sending full match end data.")
            return
        }

        let eventsPayload = match.events.map { event in
            [
                "eventType": event.eventType.rawValue,
                "timestamp": event.timestamp.timeIntervalSince1970,
                "isHomeTeam": event.isHomeTeam,
                "playerId": event.scorer?.id.uuidString ?? "", // Scorer or Goalkeeper for saves
                "assistantId": event.assistant?.id.uuidString ?? ""
            ]
        }

        let payload: [String: Any] = [
            "command": "matchEndedFromPhone",
            "matchId": match.id.uuidString,
            "homeScore": match.homeScore,
            "awayScore": match.awayScore,
            "events": eventsPayload // Include all events
        ]
        
        session.sendMessage(payload, replyHandler: nil) { error in
            print("❌ Failed to send full match end message to watch: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate (iOS side)

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Optional: Handle activation completion
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Optional: Handle session becoming inactive
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Session might deactivate if the user unpairs their watch.
        // We should reactivate it to be ready for a new watch.
        session.activate()
    }

    // !! **Core Logic: Receiving messages from Watch** !!
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["command"] as? String else {
            print("❌ Command field not received")
            return
        }

        print("📨 Phone received command from Watch: \(command)")

        // Dispatch asynchronous task using detached to prevent blocking the main thread
        Task.detached(priority: .userInitiated) {
            let startTime = Date()

            await MainActor.run {
                guard let context = self.modelContainer?.mainContext else {
                    print("⚠️ Could not get ModelContext")
                    return
                }

                switch command {
                case "newEvent":
                    self.handleNewEvent(from: message, context: context)
                case "matchEndedFromWatch":
                    self.handleMatchEnded(from: message, context: context)
                case "updateScore":
                    self.handleScoreUpdate(from: message)
                case "matchEndedFromPhone":
                    // This command is sent from phone to watch, so phone won't process it as incoming
                    break
                default:
                    print("⚠️ Unknown command: \(command)")
                }

                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 1.5 {
                    print("⏱️ Warning: Processing command \(command) took \(elapsed) seconds, consider optimization")
                }
            }
        }
    }

    // MARK: - Message Handlers

    private func handleNewEvent(from message: [String: Any], context: ModelContext) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let eventTypeStr = message["eventType"] as? String else {
            return
        }

        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }

        let translatedType = translatedEventType(from: eventTypeStr)
        let newEvent = MatchEvent(eventType: translatedType, timestamp: Date(), isHomeTeam: false)

        // WatchConnectivityManager.swift -> handleNewEvent method
        if translatedType == .save {
            if let goalkeeperIdStr = message["goalkeeperId"] as? String,
               let goalkeeperId = UUID(uuidString: goalkeeperIdStr),
               let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {
                newEvent.goalkeeper = goalkeeperStats.player // ✅ Set goalkeeper here
                goalkeeperStats.saves += 1
                newEvent.isHomeTeam = goalkeeperStats.isHomeTeam
            }
        } else {
            // Handle scorer
            if let scorerIdStr = message["playerId"] as? String,
               let scorerId = UUID(uuidString: scorerIdStr),
               let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {
                newEvent.scorer = scorerStats.player
                newEvent.isHomeTeam = scorerStats.isHomeTeam
                scorerStats.goals += 1
            }

            // Assist
            if let assistantIdStr = message["assistantId"] as? String,
               let assistantId = UUID(uuidString: assistantIdStr),
               let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                newEvent.assistant = assistantStats.player
                assistantStats.assists += 1
            }
        }

        // Set event ownership
        newEvent.match = match
        context.insert(newEvent)
        // match.events.append(newEvent) // ⚠️ Removed: SwiftData handles inverse relationships automatically

        // ✅ Update score
        if newEvent.eventType == .goal {
            if newEvent.isHomeTeam {
                match.homeScore += 1
            } else {
                match.awayScore += 1
            }
        }

        // ✅ Player stats (goals, assists, saves) are already updated above

        try? context.save()

        print("✅ Current match.id: \(match.id.uuidString)")
        print("🧩 scorerId: \(newEvent.scorer?.id.uuidString ?? "nil")")
        print("🧩 assistantId: \(newEvent.assistant?.id.uuidString ?? "nil")")
        print("🧩 goalkeeperId: \(newEvent.goalkeeper?.id.uuidString ?? "nil")")

        for e in match.events {
            print("📄 Existing event: \(e.eventType.rawValue), scorerId: \(e.scorer?.id.uuidString ?? "nil")")
        }

        for e in match.events {
            print("📄 Event: \(e.eventType.rawValue), scorerId: \(e.scorer?.id.uuidString ?? "nil")")
        }
        print("✅ match.events.count = \(match.events.count)")
        print("✅ newEvent.match id = \(newEvent.match?.id.uuidString ?? "nil")")
    }

    private func translatedEventType(from raw: String) -> EventType {
        switch raw {
        case "goal": return .goal
        case "assist": return .assist
        case "foul": return .foul
        case "save": return .save
        case "yellowCard": return .yellowCard
        case "redCard": return .redCard
        default: return .goal
        }
    }
    
    private func handleMatchEnded(from message: [String: Any], context: ModelContext) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr) else { return }

        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }

        if let homeScore = message["homeScore"] as? Int {
            match.homeScore = homeScore
        }
        if let awayScore = message["awayScore"] as? Int {
            match.awayScore = awayScore
        }

        // ✅ Thoroughly delete old events (delete from database, not just remove from match.events)
        let allEvents = try? context.fetch(FetchDescriptor<MatchEvent>())
        if let eventsToDelete = allEvents?.filter({ $0.match?.id == match.id }) {
            for e in eventsToDelete {
                context.delete(e)
            }
        }
        match.events = []
        
        // Clear all historical scores for player stats
        for stats in match.playerStats {
            stats.goals = 0
            stats.assists = 0
            stats.saves = 0
        }

        // ✅ Rebuild new events
        if let rawEvents = message["events"] as? [[String: Any]] {
            for raw in rawEvents {
                guard
                    let typeStr = raw["eventType"] as? String,
                    let eventType = EventType(rawValue: typeStr),
                    let timestamp = raw["timestamp"] as? Double,
                    // Use playerId for both scorer and goalkeeper based on eventType
                    let primaryPlayerIdStr = raw["playerId"] as? String,
                    let primaryPlayerId = UUID(uuidString: primaryPlayerIdStr)
                else { continue }

                let event = MatchEvent(
                    eventType: eventType,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    isHomeTeam: raw["isHomeTeam"] as? Bool ?? false
                )
                event.match = match

                if eventType == .save {
                    if let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == primaryPlayerId }) {
                        event.goalkeeper = goalkeeperStats.player
                    }
                } else {
                    if let scorerStats = match.playerStats.first(where: { $0.player?.id == primaryPlayerId }) {
                        event.scorer = scorerStats.player
                    }
                }

                if let assistantStr = raw["assistantId"] as? String,
                   let assistantId = UUID(uuidString: assistantStr),
                   let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                    event.assistant = assistantStats.player
                }
                event.match = match
                context.insert(event) // SwiftData automatically establishes relationships
                match.events.append(event)
            }
        }

        match.status = .finished
        match.updateMatchStats()
        try? context.save()

        print("✅ Full end: Event count = \(match.events.count)")
        objectWillChange.send()
    
        print("📦 Current match.id = \(match.id.uuidString)")
        print("📦 match.events.count = \(match.events.count)")
        for e in match.events {
            print("📝 Event: \(e.eventType.rawValue), scorerId: \(e.scorer?.id.uuidString ?? "nil")")
        }
        if let allEvents = try? context.fetch(FetchDescriptor<MatchEvent>()) {
            print("📦 All MatchEvent count = \(allEvents.count)")
            for e in allEvents {
                print("📄 Event ID: \(e.id.uuidString), match.id = \(e.match?.id.uuidString ?? "nil"), Type: \(e.eventType.rawValue)")
            }
        }
    }

    private func handleScoreUpdate(from message: [String: Any]) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let homeScore = message["homeScore"] as? Int,
              let awayScore = message["awayScore"] as? Int else { return }
        
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? modelContainer?.mainContext.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }
        
        // Update score
        match.homeScore = homeScore
        match.awayScore = awayScore
        
        // Save and notify UI update
        try? modelContainer?.mainContext.save()
        print("iOS received score update: \(homeScore)-\(awayScore)")
    }
    
    func syncPlayerToWatchIfNeeded(player: Player, match: Match) {
        guard let isHomeTeam = match.playerStats.first(where: { $0.player?.id == player.id })?.isHomeTeam else {
            print("⚠️ Unable to determine player's team, skipping sync: \(player.name)")
            return
        }
        sendNewPlayerToWatch(player: player, isHomeTeam: isHomeTeam, matchId: match.id)
    }
    
    func sendNewPlayerToWatch(player: Player, isHomeTeam: Bool, matchId: UUID) {
        let payload: [String: Any] = [
            "command": "newPlayer",
            "playerId": player.id.uuidString, // ✅ This is SwiftData's ID
            "name": player.name,
            "isHomeTeam": isHomeTeam,
            "matchId": matchId.uuidString
        ]

        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("❌ Failed to sync new player: \(error.localizedDescription)")
        }
    }
    
    // ✅ New: Receive transferUserInfo message
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            await handleIncomingBackupEvent(userInfo)
        }
    }

    // ✅ New: Logic to handle transferUserInfo
    func handleIncomingBackupEvent(_ message: [String: Any]) async {
        guard let command = message["command"] as? String, command == "newEventBackup" else { return }

        print("📦 Received transferUserInfo event backup: \(message)")

        await MainActor.run {
            self.session(WCSession.default, didReceiveMessage: message)
        }
    }
}
