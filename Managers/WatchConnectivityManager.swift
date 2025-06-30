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
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["command"] as? String else {
            print("❌ 未收到 command 字段")
            return
        }

        print("📨 手机端收到来自手表的命令: \(command)")

        // 使用 detached 分发异步任务，避免主线程阻塞
        Task.detached(priority: .userInitiated) {
            let startTime = Date()

            await MainActor.run {
                guard let context = self.modelContainer?.mainContext else {
                    print("⚠️ 无法获取 ModelContext")
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
                    break
                default:
                    print("⚠️ 未知命令: \(command)")
                }

                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 1.5 {
                    print("⏱️ 警告：处理命令 \(command) 用时 \(elapsed) 秒，建议优化")
                }
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
        
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }

        let translatedType = translatedEventType(from: eventType)
        let newEvent = MatchEvent(eventType: translatedType, timestamp: Date(), isHomeTeam: false)


        // scorerId 字段应为 playerId
        if let scorerIdStr = message["playerId"] as? String,
           let scorerId = UUID(uuidString: scorerIdStr),
           let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {
            newEvent.scorer = scorerStats.player
            newEvent.isHomeTeam = scorerStats.isHomeTeam
            scorerStats.goals += 1
        }

        if let assistantIdStr = message["assistantId"] as? String, let assistantId = UUID(uuidString: assistantIdStr),
           let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
            newEvent.assistant = assistantStats.player
            assistantStats.assists += 1
        }

        if let goalkeeperIdStr = message["goalkeeperId"] as? String,
        let goalkeeperId = UUID(uuidString: goalkeeperIdStr),
        let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {
            newEvent.goalkeeper = goalkeeperStats.player
            goalkeeperStats.saves += 1
            newEvent.isHomeTeam = goalkeeperStats.isHomeTeam // 设置归属方
        }


        context.insert(newEvent)
        match.events.append(newEvent)
        try? context.save()
        print("✅ Saved new event '\(eventType)' from watch.")
        print("收到事件 playerId: \(message["playerId"] ?? "nil")")
        print("本地球员ID列表：", match.playerStats.map { $0.player?.id.uuidString ?? "" })
        print("收到 assistantId: \(message["assistantId"] ?? "nil")")
        print("本地球员ID列表: \(match.playerStats.map { $0.player?.id.uuidString ?? "nil" })")
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
        
        // 同步比分
        if let homeScore = message["homeScore"] as? Int {
            match.homeScore = homeScore
        }
        if let awayScore = message["awayScore"] as? Int {
            match.awayScore = awayScore
        }

        match.status = .finished
        match.updateMatchStats()
        try? context.save()
        print("✅ Match ended from watch and stats updated.")
        print("🏁 handleMatchEnded 被调用，比分：\(match.homeScore)-\(match.awayScore)")
        // 通知 UI 层刷新
        objectWillChange.send()
    }

    private func handleScoreUpdate(from message: [String: Any]) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let homeScore = message["homeScore"] as? Int,
              let awayScore = message["awayScore"] as? Int else { return }
        
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? modelContainer?.mainContext.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }
        
        // 更新比分
        match.homeScore = homeScore
        match.awayScore = awayScore
        
        // 保存并通知 UI 更新
        try? modelContainer?.mainContext.save()
        print("iOS端收到比分更新: \(homeScore)-\(awayScore)")
    }
    
    func syncPlayerToWatchIfNeeded(player: Player, match: Match) {
        guard let isHomeTeam = match.playerStats.first(where: { $0.player?.id == player.id })?.isHomeTeam else {
            print("⚠️ 无法判断球员归属队伍，跳过同步：\(player.name)")
            return
        }
        sendNewPlayerToWatch(player: player, isHomeTeam: isHomeTeam, matchId: match.id)
    }
    
    func sendNewPlayerToWatch(player: Player, isHomeTeam: Bool, matchId: UUID) {
        let payload: [String: Any] = [
            "command": "newPlayer",
            "playerId": player.id.uuidString, // ✅ 这里是 SwiftData 的 id
            "name": player.name,
            "isHomeTeam": isHomeTeam,
            "matchId": matchId.uuidString
        ]

        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("❌ 同步新球员失败：\(error.localizedDescription)")
        }
    }



}

