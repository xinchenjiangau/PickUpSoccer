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
              let eventTypeStr = message["eventType"] as? String else {
            return
        }

        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }

        let translatedType = translatedEventType(from: eventTypeStr)
        let newEvent = MatchEvent(eventType: translatedType, timestamp: Date(), isHomeTeam: false)

        if translatedType == .save {
            // 优先处理 goalkeeperId
            if let goalkeeperIdStr = message["goalkeeperId"] as? String,
               let goalkeeperId = UUID(uuidString: goalkeeperIdStr),
               let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {
                newEvent.goalkeeper = goalkeeperStats.player
                goalkeeperStats.saves += 1
                newEvent.isHomeTeam = goalkeeperStats.isHomeTeam
            }
        } else {
            // 处理 scorer
            if let scorerIdStr = message["playerId"] as? String,
               let scorerId = UUID(uuidString: scorerIdStr),
               let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {
                newEvent.scorer = scorerStats.player
                newEvent.isHomeTeam = scorerStats.isHomeTeam
                scorerStats.goals += 1
            }

            // 助攻
            if let assistantIdStr = message["assistantId"] as? String,
               let assistantId = UUID(uuidString: assistantIdStr),
               let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                newEvent.assistant = assistantStats.player
                assistantStats.assists += 1
            }
        }

        updateMatchStats(for: newEvent, in: match)
        newEvent.match = match
        context.insert(newEvent)
        match.events.append(newEvent)
        try? context.save()

        print("✅ 当前 match.id: \(match.id.uuidString)")
        print("🧩 scorerId: \(newEvent.scorer?.id.uuidString ?? "nil")")
        print("🧩 assistantId: \(newEvent.assistant?.id.uuidString ?? "nil")")
        print("🧩 goalkeeperId: \(newEvent.goalkeeper?.id.uuidString ?? "nil")")

        for e in match.events {
            print("📄 已有事件: \(e.eventType.rawValue), scorerId: \(e.scorer?.id.uuidString ?? "nil")")
        }

        for e in match.events {
            print("📄 事件: \(e.eventType.rawValue), scorerId: \(e.scorer?.id.uuidString ?? "nil")")
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

        // ✅ 彻底删除旧事件（从数据库中删除，而不仅仅是从 match.events 中移除）
        let allEvents = try? context.fetch(FetchDescriptor<MatchEvent>())
        if let eventsToDelete = allEvents?.filter({ $0.match?.id == match.id }) {
            for e in eventsToDelete {
                context.delete(e)
            }
        }
        match.events = []
        
        // 清空 player stats 的所有历史分
        for stats in match.playerStats {
            stats.goals = 0
            stats.assists = 0
            stats.saves = 0
        }

        // ✅ 重建新事件
        if let rawEvents = message["events"] as? [[String: Any]] {
            for raw in rawEvents {
                guard
                    let typeStr = raw["eventType"] as? String,
                    let eventType = EventType(rawValue: typeStr),
                    let timestamp = raw["timestamp"] as? Double,
                    let playerIdStr = raw["playerId"] as? String,
                    let playerId = UUID(uuidString: playerIdStr)
                else { continue }

                let event = MatchEvent(
                    eventType: eventType,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    isHomeTeam: raw["isHomeTeam"] as? Bool ?? false
                )
                event.match = match

                if let scorerStats = match.playerStats.first(where: { $0.player?.id == playerId }) {
                    event.scorer = scorerStats.player
                }

                if let assistantStr = raw["assistantId"] as? String,
                   let assistantId = UUID(uuidString: assistantStr),
                   let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                    event.assistant = assistantStats.player
                }
                event.match = match
                context.insert(event) // SwiftData 自动建立关系
                match.events.append(event)
            }
        }

        match.status = .finished
        match.updateMatchStats()
        try? context.save()

        print("✅ 完整结束：事件数量 = \(match.events.count)")
        objectWillChange.send()
    


        print("📦 当前 match.id = \(match.id.uuidString)")
        print("📦 match.events.count = \(match.events.count)")
        for e in match.events {
            print("📝 事件：\(e.eventType.rawValue) 时间：\(e.timestamp)")
        }
        if let allEvents = try? context.fetch(FetchDescriptor<MatchEvent>()) {
            print("📦 所有 MatchEvent 数量 = \(allEvents.count)")
            for e in allEvents {
                print("📄 事件ID: \(e.id.uuidString), match.id = \(e.match?.id.uuidString ?? "nil"), 类型: \(e.eventType.rawValue)")
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
    
    // ✅ 新增：接收 transferUserInfo 消息
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            await handleIncomingBackupEvent(userInfo)
        }
    }

    // ✅ 新增：处理 transferUserInfo 的逻辑
    func handleIncomingBackupEvent(_ message: [String: Any]) async {
        guard let command = message["command"] as? String, command == "newEventBackup" else { return }

        print("📦 收到 transferUserInfo 事件备份: \(message)")

        await MainActor.run {
            self.session(WCSession.default, didReceiveMessage: message)
        }
    }




}

