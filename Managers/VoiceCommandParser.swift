import Foundation

class VoiceCommandParser {
    // 定义事件关键词
    private static let goalKeywords = [
        "进球", "得分", "射门", "破门", "打进", "进了", "射进",
        "打入", "踢进", "头球", "点球"
    ]
    
    private static let saveKeywords = [
        "扑救", "救球", "扑出", "拦截", "挡出", "封堵", "没收",
        "抱住", "接住", "扑到"
    ]
    
    static func parseCommand(_ text: String, match: Match) -> MatchEvent? {
        // 将文本转换为小写并移除空格
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 解析进球命令
        if let goalEvent = parseGoalCommand(normalizedText, match: match) {
            return goalEvent
        }
        
        // 解析扑救命令
        if let saveEvent = parseSaveCommand(normalizedText, match: match) {
            return saveEvent
        }
        
        return nil
    }
    
    private static func parseGoalCommand(_ text: String, match: Match) -> MatchEvent? {
        // 获取主队和客队的球员
        let homeTeamPlayers = match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
        let awayTeamPlayers = match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
        
        // 为每个球员创建可能的名字变体（包括同音字和昵称）
        let playerNameVariants = (homeTeamPlayers + awayTeamPlayers).flatMap { player -> [(Player, String)] in
            var variants = [
                (player, player.name),
                (player, player.name.lowercased()),
                // 添加常见的同音字变体
                (player, player.name.replacingOccurrences(of: "华", with: "花")),
                (player, player.name.replacingOccurrences(of: "伟", with: "威")),
                // 如果有号码，添加号码识别
                (player, "\(player.number ?? 0)号")
            ]
            // 如果有昵称，添加昵称识别
            if let nickname = player.nickname {
                variants.append((player, nickname))
            }
            return variants
        }
        
        // 分析句子结构
        for (player, nameVariant) in playerNameVariants {
            // 检查球员名字是否在文本中
            guard text.contains(nameVariant.lowercased()) else { continue }
            
            // 检查是否包含进球相关关键词
            let hasGoalKeyword = goalKeywords.contains { keyword in
                text.contains(keyword)
            }
            
            if hasGoalKeyword {
                // 检查句子结构是否合理（名字在关键词附近）
                let isValidStructure = checkSentenceStructure(text: text, name: nameVariant, keywords: goalKeywords)
                
                if isValidStructure {
                    // 创建事件
                    let event = MatchEvent(
                        eventType: .goal,
                        timestamp: Date(),
                        match: match,
                        scorer: player,
                        assistant: nil
                    )
                    
                    // 设置事件所属队伍
                    if let stats = match.playerStats.first(where: { $0.player?.id == player.id }) {
                        event.isHomeTeam = stats.isHomeTeam
                    }
                    
                    return event
                }
            }
        }
        return nil
    }
    
    private static func parseSaveCommand(_ text: String, match: Match) -> MatchEvent? {
        // 获取主队和客队的球员
        let homeTeamPlayers = match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
        let awayTeamPlayers = match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
        
        // 为每个球员创建可能的名字变体（包括同音字和昵称）
        let playerNameVariants = (homeTeamPlayers + awayTeamPlayers).flatMap { player -> [(Player, String)] in
            var variants = [
                (player, player.name),
                (player, player.name.lowercased()),
                // 添加常见的同音字变体
                (player, player.name.replacingOccurrences(of: "华", with: "花")),
                (player, player.name.replacingOccurrences(of: "伟", with: "威")),
                // 如果有号码，添加号码识别
                (player, "\(player.number ?? 0)号")
            ]
            // 如果有昵称，添加昵称识别
            if let nickname = player.nickname {
                variants.append((player, nickname))
            }
            return variants
        }
        
        // 分析句子结构
        for (player, nameVariant) in playerNameVariants {
            // 检查球员名字是否在文本中
            guard text.contains(nameVariant.lowercased()) else { continue }
            
            // 检查是否包含扑救相关关键词
            let hasSaveKeyword = saveKeywords.contains { keyword in
                text.contains(keyword)
            }
            
            if hasSaveKeyword {
                // 检查句子结构是否合理（名字在关键词附近）
                let isValidStructure = checkSentenceStructure(text: text, name: nameVariant, keywords: saveKeywords)
                
                if isValidStructure {
                    // 创建事件
                    let event = MatchEvent(
                        eventType: .save,
                        timestamp: Date(),
                        match: match,
                        scorer: player,
                        assistant: nil
                    )
                    
                    // 设置事件所属队伍
                    if let stats = match.playerStats.first(where: { $0.player?.id == player.id }) {
                        event.isHomeTeam = stats.isHomeTeam
                    }
                    
                    return event
                }
            }
        }
        return nil
    }
    
    // 检查句子结构
    private static func checkSentenceStructure(text: String, name: String, keywords: [String]) -> Bool {
        // 将句子分割成词组
        let words = text.components(separatedBy: CharacterSet(charactersIn: " ,，.。!！"))
        
        // 找到球员名字和关键词的位置
        guard let nameIndex = words.firstIndex(where: { $0.contains(name.lowercased()) }) else {
            return false
        }
        
        // 检查关键词是否在名字附近（前后5个词以内）
        let range = max(0, nameIndex - 5)...min(words.count - 1, nameIndex + 5)
        let nearbyWords = Array(words[range])
        
        return keywords.contains { keyword in
            nearbyWords.contains { $0.contains(keyword) }
        }
    }
} 