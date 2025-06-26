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

    // 让外部注入 ModelContainer
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

    func sendStartMatchToWatch(match: Match) {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            print("WCSession not available or watch app not installed.")
            return
        }

        // 从 PlayerMatchStats 中获取球员列表和队伍信息
        let playersData = match.playerStats.map { stats -> [String: Any] in
            return [
                "id": stats.player!.id.uuidString,
                "name": stats.player!.name,
                "isHomeTeam": stats.isHomeTeam
            ]
        }

        let matchContext: [String: Any] = [
            "command": "startMatch",
            "matchId": match.id.uuidString,
            "homeTeamName": match.homeTeamName,
            "awayTeamName": match.awayTeamName,
            "players": playersData
        ]

        // Use updateApplicationContext for durable data transfer
        do {
            try session.updateApplicationContext(matchContext)
            print("Match start context sent to watch.")
            print("updateApplicationContext已调用，内容：\(matchContext)")
            print("isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled)")
        } catch {
            print("Error sending context to watch: \(error.localizedDescription)")
        }
    }
    
    func sendEndMatchToWatch(matchId: UUID) {
        guard let session = session, session.isReachable else { return }
        let context: [String: Any] = ["command": "endMatch", "matchId": matchId.uuidString]
        session.sendMessage(context, replyHandler: nil) { error in
            print("Error sending end match message: \(error.localizedDescription)")
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

    // !! **核心逻辑：接收来自手表的消息** !!
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["command"] as? String else { return }

        // 将任务派发到主线程，安全地操作数据库
        Task { @MainActor in
            guard let context = self.modelContainer?.mainContext else {
                print("Error: ModelContext is not available.")
                return
            }

            switch command {
            case "newEvent":
                handleNewEvent(from: message, context: context)
            case "newPlayer":
                handleNewPlayer(from: message, context: context)
            case "matchEndedFromWatch":
                handleMatchEnded(from: message, context: context)
            default:
                print("Received unknown command from watch: \(command)")
            }
        }
    }

    // MARK: - Message Handlers

    private func handleNewEvent(from message: [String: Any], context: ModelContext) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let eventType = message["eventType"] as? String else {
            return
        }
        
        // 1. 找到对应的比赛
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }

        // 2. 创建新事件
        let newEvent = MatchEvent(eventType: EventType(rawValue: eventType) ?? .goal, timestamp: Date(), isHomeTeam: false)
        newEvent.match = match
        
        // 3. 关联球员并更新 PlayerMatchStats
        if let scorerIdStr = message["scorerId"] as? String, let scorerId = UUID(uuidString: scorerIdStr),
           let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {
            
            newEvent.scorer = scorerStats.player
            newEvent.isHomeTeam = scorerStats.isHomeTeam
            scorerStats.goals += 1 // 进球数+1
        }
        
        if let assistantIdStr = message["assistantId"] as? String, let assistantId = UUID(uuidString: assistantIdStr),
           let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
            
            newEvent.assistant = assistantStats.player
            assistantStats.assists += 1 // 助攻数+1
        }
        
        if let goalkeeperIdStr = message["goalkeeperId"] as? String, let goalkeeperId = UUID(uuidString: goalkeeperIdStr),
           let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {
            
            // 扑救事件，我们只记录扑救者，事件本身不归属于某队
            goalkeeperStats.saves += 1 // 扑救数+1
        }
        
        // 4. 保存事件
        context.insert(newEvent)
        try? context.save()
        print("✅ Saved new event '\(eventType)' from watch.")
    }

    private func handleNewPlayer(from message: [String: Any], context: ModelContext) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let playerIdStr = message["playerId"] as? String,
              let playerId = UUID(uuidString: playerIdStr),
              let name = message["name"] as? String,
              let isHomeTeam = message["isHomeTeam"] as? Bool else {
            return
        }

        // 1. 找到比赛
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }

        // 2. 创建新球员（假设新球员需要一个默认位置）
        let newPlayer = Player(name: name, position: .midfielder)
        newPlayer.id = playerId // 使用手表生成的ID以保持一致
        
        // 3. 为新球员创建本场比赛的统计数据
        let newPlayerStats = PlayerMatchStats(player: newPlayer, match: match)
        newPlayerStats.isHomeTeam = isHomeTeam
        
        // 4. 保存
        context.insert(newPlayer)
        context.insert(newPlayerStats)
        try? context.save()
        print("✅ Added new player '\(name)' from watch.")
    }
    
    private func handleMatchEnded(from message: [String: Any], context: ModelContext) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr) else { return }
        
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }
        
        match.status = .finished // 更新比赛状态
        match.updateMatchStats() // 调用您已有的方法来计算最终统计数据
        try? context.save()
        print("✅ Match ended from watch and stats updated.")
    }
}

