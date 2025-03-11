import Foundation
import SwiftData

struct CSVImporter {
    enum ImportError: Error, LocalizedError {
        case emptyFile
        case invalidData
        case missingRequiredFields
        case invalidLine(Int, String)
        
        var errorDescription: String? {
            switch self {
            case .emptyFile:
                return "导入文件为空"
            case .invalidData:
                return "无效的数据格式"
            case .missingRequiredFields:
                return "缺少必需字段"
            case .invalidLine(let line, let reason):
                return "第 \(line) 行数据无效: \(reason)"
            }
        }
    }
    
    typealias MergeConfirmationHandler = (Player, [String: Any], @escaping (MergeStrategy) -> Void) -> Void
    
    static func importPlayers(
        from csvString: String,
        modelContext: ModelContext,
        season: Season? = nil,
        showMergeConfirmation: MergeConfirmationHandler? = nil,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        print("开始导入 CSV 数据...")
        
        // 移除 BOM 标记并清理字符串
        let cleanString = csvString.replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 按行分割
        var lines = cleanString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !lines.isEmpty else {
            print("错误：文件为空")
            completion(.failure(ImportError.emptyFile))
            return
        }
        
        // 获取并验证表头
        let header = lines.removeFirst().split(separator: ",").map(String.init)
        print("表头: \(header)")
        
        // 验证必需的字段
        let requiredFields = ["姓名", "号码", "位置"]
        for field in requiredFields {
            guard header.contains(field) else {
                print("错误：缺少必需字段 '\(field)'")
                completion(.failure(ImportError.missingRequiredFields))
                return
            }
        }
        
        // 创建导入队列
        let importQueue = DispatchQueue(label: "com.pickupsoccer.csvimport")
        var importedCount = 0
        var pendingPlayers: [(PlayerData, Int)] = []
        
        // 首先解析所有行
        for (index, line) in lines.enumerated() {
            do {
                let fields = parseCSVLine(line)
                print("解析第 \(index + 1) 行: \(fields)")
                
                guard fields.count >= 3 else {
                    throw ImportError.invalidLine(index + 1, "字段数量不足")
                }
                
                // 解析球员数据
                let playerData = try parsePlayerData(from: fields)
                pendingPlayers.append((playerData, index + 1))
                
            } catch {
                print("解析第 \(index + 1) 行时出错: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
        }
        
        // 处理导入队列
        processImportQueue(
            pendingPlayers: pendingPlayers,
            modelContext: modelContext,
            season: season,
            showMergeConfirmation: showMergeConfirmation
        ) { result in
            switch result {
            case .success(let count):
                do {
                    try modelContext.save()
                    print("CSV 导入完成，成功导入 \(count) 名球员")
                    completion(.success(count))
                } catch {
                    print("保存数据时出错: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 处理导入队列
    private static func processImportQueue(
        pendingPlayers: [(PlayerData, Int)],
        modelContext: ModelContext,
        season: Season? = nil,
        showMergeConfirmation: MergeConfirmationHandler?,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        var remainingPlayers = pendingPlayers
        var importedCount = 0
        var processingPlayer = false
        
        // 递归处理每个球员
        func processNext() {
            // 如果正在处理球员或队列为空，则返回
            guard !processingPlayer, !remainingPlayers.isEmpty else {
                if remainingPlayers.isEmpty {
                    // 所有球员处理完成
                    completion(.success(importedCount))
                }
                return
            }
            
            let (playerData, lineNumber) = remainingPlayers.removeFirst()
            
            // 检查是否存在同名球员
            let existingPlayer = findExistingPlayer(name: playerData.name, modelContext: modelContext)
            
            if let existingPlayer = existingPlayer, let showMergeConfirmation = showMergeConfirmation {
                // 标记正在处理球员
                processingPlayer = true
                
                // 提取导入的统计数据
                let importedStats: [String: Any] = [
                    "goals": playerData.goals,
                    "assists": playerData.assists,
                    "saves": playerData.saves,
                    "matches": playerData.matches,
                    "season": season,
                    "lineNumber": lineNumber
                ]
                
                // 显示合并确认对话框
                showMergeConfirmation(existingPlayer, importedStats) { strategy in
                    do {
                        try handleMergeStrategy(
                            strategy: strategy,
                            existingPlayer: existingPlayer,
                            playerData: playerData,
                            season: season,
                            modelContext: modelContext
                        )
                        
                        if strategy != .skip {
                            importedCount += 1
                        }
                        
                        // 标记处理完成
                        processingPlayer = false
                        
                        // 处理下一个球员
                        processNext()
                    } catch {
                        processingPlayer = false
                        completion(.failure(error))
                    }
                }
            } else {
                do {
                    // 创建新球员
                    let player = createPlayer(from: playerData)
                    modelContext.insert(player)
                    
                    // 如果有统计数据，创建导入统计记录
                    if playerData.goals > 0 || playerData.assists > 0 || playerData.saves > 0 || playerData.matches > 0 {
                        let importedStats = ImportedPlayerStats(
                            player: player,
                            season: season,
                            goals: playerData.goals,
                            assists: playerData.assists,
                            saves: playerData.saves,
                            matches: playerData.matches,
                            source: "CSV导入"
                        )
                        modelContext.insert(importedStats)
                        player.importedStats.append(importedStats)
                    }
                    
                    importedCount += 1
                    print("成功创建球员: \(player.name)")
                    
                    // 处理下一个球员
                    processNext()
                } catch {
                    print("处理第 \(lineNumber) 行时出错: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        
        // 开始处理第一个球员
        processNext()
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if !insideQuotes {
                    fields.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            default:
                currentField.append(char)
            }
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }
    
    // 球员数据结构
    private struct PlayerData {
        let name: String
        let number: Int
        let position: PlayerPosition
        let phone: String?
        let email: String?
        let age: Int?
        let gender: String?
        let height: Double?
        let weight: Double?
        let goals: Int
        let assists: Int
        let saves: Int
        let matches: Int
    }
    
    private static func parsePlayerData(from fields: [String]) throws -> PlayerData {
        // 解析必需字段
        let name = fields[0].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw ImportError.invalidLine(0, "姓名不能为空")
        }
        
        guard let number = Int(fields[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ImportError.invalidLine(0, "号码必须是数字")
        }
        
        let positionStr = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let position = PlayerPosition(rawValue: positionStr) else {
            throw ImportError.invalidLine(0, "无效的位置: \(positionStr)")
        }
        
        // 解析可选字段
        let phone = fields.count > 3 ? (fields[3].isEmpty ? nil : fields[3]) : nil
        let email = fields.count > 4 ? (fields[4].isEmpty ? nil : fields[4]) : nil
        let age = fields.count > 5 ? Int(fields[5]) : nil
        let gender = fields.count > 6 ? (fields[6].isEmpty ? nil : fields[6]) : nil
        let height = fields.count > 7 ? Double(fields[7]) : nil
        let weight = fields.count > 8 ? Double(fields[8]) : nil
        
        // 解析统计数据
        let goals = fields.count > 9 ? (Int(fields[9]) ?? 0) : 0
        let assists = fields.count > 10 ? (Int(fields[10]) ?? 0) : 0
        let saves = fields.count > 11 ? (Int(fields[11]) ?? 0) : 0
        let matches = fields.count > 12 ? (Int(fields[12]) ?? 0) : 0
        
        return PlayerData(
            name: name,
            number: number,
            position: position,
            phone: phone,
            email: email,
            age: age,
            gender: gender,
            height: height,
            weight: weight,
            goals: goals,
            assists: assists,
            saves: saves,
            matches: matches
        )
    }
    
    private static func findExistingPlayer(name: String, modelContext: ModelContext) -> Player? {
        let descriptor = FetchDescriptor<Player>(
            predicate: #Predicate<Player> { player in
                player.name == name
            }
        )
        
        do {
            let players = try modelContext.fetch(descriptor)
            return players.first
        } catch {
            print("查找球员失败: \(error)")
            return nil
        }
    }
    
    private static func createPlayer(from data: PlayerData) -> Player {
        let player = Player(
            name: data.name,
            number: data.number,
            position: data.position
        )
        
        // 设置可选字段
        player.phone = data.phone
        player.email = data.email
        player.age = data.age
        player.gender = data.gender
        player.height = data.height
        player.weight = data.weight
        
        return player
    }
    
    private static func handleMergeStrategy(
        strategy: MergeStrategy,
        existingPlayer: Player,
        playerData: PlayerData,
        season: Season? = nil,
        modelContext: ModelContext
    ) throws {
        switch strategy {
        case .sum:
            // 创建新的导入统计记录，数据会自动合并
            let importedStats = ImportedPlayerStats(
                player: existingPlayer,
                season: season,
                goals: playerData.goals,
                assists: playerData.assists,
                saves: playerData.saves,
                matches: playerData.matches,
                source: "CSV导入(合并)"
            )
            modelContext.insert(importedStats)
            existingPlayer.importedStats.append(importedStats)
            
            // 更新球员基本信息（如果导入数据有更多信息）
            updatePlayerInfo(existingPlayer, with: playerData)
            
        case .replace:
            // 如果指定了赛季，只删除该赛季的导入统计记录
            if let season = season {
                for stats in existingPlayer.importedStats where stats.season?.id == season.id {
                    modelContext.delete(stats)
                    if let index = existingPlayer.importedStats.firstIndex(where: { $0.id == stats.id }) {
                        existingPlayer.importedStats.remove(at: index)
                    }
                }
            } else {
                // 否则删除所有导入统计记录
                for stats in existingPlayer.importedStats {
                    modelContext.delete(stats)
                }
                existingPlayer.importedStats = []
            }
            
            // 创建新的导入统计记录
            let importedStats = ImportedPlayerStats(
                player: existingPlayer,
                season: season,
                goals: playerData.goals,
                assists: playerData.assists,
                saves: playerData.saves,
                matches: playerData.matches,
                source: "CSV导入(覆盖)"
            )
            modelContext.insert(importedStats)
            existingPlayer.importedStats.append(importedStats)
            
            // 更新球员基本信息
            updatePlayerInfo(existingPlayer, with: playerData)
            
        case .skip:
            // 不做任何操作
            break
        }
    }
    
    private static func updatePlayerInfo(_ player: Player, with data: PlayerData) {
        // 只更新球员的空字段
        if player.phone == nil { player.phone = data.phone }
        if player.email == nil { player.email = data.email }
        if player.age == nil { player.age = data.age }
        if player.gender == nil { player.gender = data.gender }
        if player.height == nil { player.height = data.height }
        if player.weight == nil { player.weight = data.weight }
    }
} 