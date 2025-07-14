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
    /// 根据手表传来的英文枚举名，手动映射到正确的 EventType 枚举成员
    private func eventType(fromCaseName name: String) -> EventType? {
        switch name {
        case "goal": return .goal
        case "foul": return .foul
        case "save": return .save
        case "yellowCard": return .yellowCard
        case "redCard": return .redCard
        default:
            print("⚠️ 未知的事件类型名称: \(name)")
            return nil
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

    // In xinchenjiangau/pickupsoccer/PickUpSoccer-46a3117d7232204197ff70efc5a54e3337afc15c/Managers/WatchConnectivityManager.swift

    private func handleNewEvent(from message: [String: Any], context: ModelContext) {
        // 1. 验证收到的消息是否完整
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let eventTypeStr = message["eventType"] as? String else {
            print("❌ [WatchKit] 收到不完整的新事件数据。")
            return
        }

        // 2. 根据ID查找对应的比赛
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else {
            print("❌ [WatchKit] 无法找到比赛，ID: \(matchIdStr)")
            return
        }

        // 3. 将字符串类型的事件转换为枚举类型
        let eventType = translatedEventType(from: eventTypeStr)
        let newEvent = MatchEvent(eventType: eventType, timestamp: Date(), isHomeTeam: false, match: match)

        // 4. 根据事件类型，分别处理数据
        if eventType == .goal {
            // --- 处理进球者 ---
            if let scorerIdStr = message["playerId"] as? String,
               let scorerId = UUID(uuidString: scorerIdStr),
               let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {

                newEvent.scorer = scorerStats.player
                // [修复] 关键修复：正确设置事件属于主队还是客队
                newEvent.isHomeTeam = scorerStats.isHomeTeam
                scorerStats.goals += 1

                // [修复] 实时更新比赛比分
                if scorerStats.isHomeTeam {
                    match.homeScore += 1
                } else {
                    match.awayScore += 1
                }
            }

            // --- 处理助攻者 ---
            if let assistantIdStr = message["assistantId"] as? String,
               let assistantId = UUID(uuidString: assistantIdStr),
               let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                newEvent.assistant = assistantStats.player
                // [修复] 增加助攻者的助攻统计
                assistantStats.assists += 1
            }

        } else if eventType == .save {
            // --- 处理扑救者 ---
            // 优先使用 "goalkeeperId" 字段
            if let goalkeeperIdStr = message["goalkeeperId"] as? String,
               let goalkeeperId = UUID(uuidString: goalkeeperIdStr),
               let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {

                newEvent.goalkeeper = goalkeeperStats.player
                // [修复] 正确设置事件属于主队还是客队
                newEvent.isHomeTeam = goalkeeperStats.isHomeTeam
                // [修复] 增加扑救者的扑救统计
                goalkeeperStats.saves += 1
                
            // 如果没有 "goalkeeperId"，则尝试使用 "playerId" 作为备用
            } else if let playerIdStr = message["playerId"] as? String,
                      let playerId = UUID(uuidString: playerIdStr),
                      let playerStats = match.playerStats.first(where: { $0.player?.id == playerId }) {

                // 在扑救事件中，将扑救者信息存入goalkeeper字段
                newEvent.goalkeeper = playerStats.player
                newEvent.isHomeTeam = playerStats.isHomeTeam
                playerStats.saves += 1
            }
        }

        // 5. 插入新事件并保存
        context.insert(newEvent)
        //match.events.append(newEvent)

        do {
            try context.save()
            print("✅ [WatchKit] 已成功保存事件: \(eventType.rawValue)。比赛 \(match.id) 现在有 \(match.events.count) 个事件。")
        } catch {
            print("❌ [WatchKit] 保存上下文时出错: \(error)")
            // 如果保存失败，打印出更详细的错误
            print("Error details: \((error as NSError).userInfo)")
        }
    }

    private func translatedEventType(from raw: String) -> EventType {
        switch raw {
        case "goal": return .goal
        
        case "foul": return .foul
        case "save": return .save
        case "yellowCard": return .yellowCard
        case "redCard": return .redCard
        default: return .goal
        }
    }
    
    // 请将旧的 handleMatchEnded 函数替换为这个修正后的版本

    // 请将旧的 handleMatchEnded 函数替换为这个最终修正后的版本

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

        let fetchDescriptor = FetchDescriptor<MatchEvent>(predicate: #Predicate { $0.match?.id == matchId })
        if let eventsToDelete = try? context.fetch(fetchDescriptor) {
            for event in eventsToDelete {
                context.delete(event)
            }
        }
        match.events.removeAll()
        
        for stats in match.playerStats {
            stats.goals = 0
            stats.assists = 0
            stats.saves = 0
        }

        if let rawEvents = message["events"] as? [[String: Any]] {
            for raw in rawEvents {
                
                // MARK: - 最终修复
                // 1. 获取事件的英文名称字符串
                let typeName = String(describing: raw["eventType"] ?? "")
                
                // 2. 使用新的辅助函数将英文名称映射到枚举成员
                let finalEventType = eventType(fromCaseName: typeName)
                
                // 3. 健壮地解析布尔值
                let isHomeTeam = (raw["isHomeTeam"] as? NSNumber)?.boolValue ?? (raw["isHomeTeam"] as? Bool ?? false)

                guard let eventType = finalEventType, let timestamp = raw["timestamp"] as? Double else {
                    print("❌ [WatchKit Final Sync] 跳过格式错误的事件：\(raw)")
                    continue
                }

                let event = MatchEvent(
                    eventType: eventType,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    isHomeTeam: isHomeTeam
                )
                event.match = match
                
                if eventType == .goal {
                    if let scorerIdStr = raw["playerId"] as? String,
                       let scorerId = UUID(uuidString: scorerIdStr),
                       let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {
                        event.scorer = scorerStats.player
                        scorerStats.goals += 1
                    }
                    if let assistantStr = raw["assistantId"] as? String,
                       let assistantId = UUID(uuidString: assistantStr),
                       !assistantStr.isEmpty,
                       let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                        event.assistant = assistantStats.player
                        assistantStats.assists += 1
                    }
                } else if eventType == .save {
                    var goalkeeperIdStr: String?
                    if let id = raw["goalkeeperId"] as? String {
                        goalkeeperIdStr = id
                    } else if let id = raw["playerId"] as? String {
                        goalkeeperIdStr = id
                    }
                    
                    if let idStr = goalkeeperIdStr,
                       let goalkeeperId = UUID(uuidString: idStr),
                       let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {
                        event.goalkeeper = goalkeeperStats.player
                        goalkeeperStats.saves += 1
                    }
                }
                
                context.insert(event)
                match.events.append(event)
            }
        }

        match.status = .finished
        match.updateMatchStats()
        try? context.save()

        print("✅ Full end: Event count = \(match.events.count)")
        objectWillChange.send()
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
    
    // In xinchenjiangau/pickupsoccer/PickUpSoccer-46a3117d7232204197ff70efc5a54e3337afc15c/Managers/WatchConnectivityManager.swift

    /// 将手机端创建的单个比赛事件实时同步到手表。
    func sendEventToWatch(_ event: MatchEvent, matchId: UUID) {
        guard let session = session, session.isReachable else {
            print("❌ [WatchKit] WCSession 不可达，无法发送事件。")
            return
        }

        var payload: [String: Any] = [
            "command": "newEvent", // 复用手表端已有的 "newEvent" 命令
            "matchId": matchId.uuidString,
            "eventType": event.eventType.rawValue,
            "isHomeTeam": event.isHomeTeam,
            "timestamp": event.timestamp.timeIntervalSince1970
        ]

        // 根据事件类型，添加不同的球员ID
        switch event.eventType {
        case .goal:
            payload["playerId"] = event.scorer?.id.uuidString
            if let assistantId = event.assistant?.id.uuidString {
                payload["assistantId"] = assistantId
            }
        case .save:
            // 对于扑救事件，我们将扑救者ID放在 "goalkeeperId" 字段
            payload["goalkeeperId"] = event.goalkeeper?.id.uuidString
        default:
            // 为其他未来可能出现的事件类型准备
            payload["playerId"] = event.scorer?.id.uuidString
        }

        session.sendMessage(payload, replyHandler: nil) { error in
            print("❌ [WatchKit] 发送新事件到手表失败: \(error.localizedDescription)")
        }
        print("✅ [WatchKit] 成功发送事件到手表: \(event.eventType.rawValue)")
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
