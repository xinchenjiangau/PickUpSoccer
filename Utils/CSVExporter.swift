import Foundation

struct CSVExporter {
    /// 将所有 Player 对象转换为 CSV 字符串，可选择按赛季筛选
    static func exportPlayers(_ players: [Player], season: Season? = nil) -> String {
        // 修改 CSV 表头，调整字段顺序
        let header = "姓名,号码,位置,电话,邮箱,年龄,性别,身高(cm),体重(kg),总进球,总助攻,总扑救,总比赛,比赛进球,比赛助攻,比赛扑救,比赛场次,导入进球,导入助攻,导入扑救,导入比赛,赛季\n"
        
        var csv = header
        for player in players {
            // 处理可能包含逗号的字段
            let name = "\"\(player.name)\""  // 用引号包裹，避免逗号分隔问题
            
            // 格式化数值
            let heightStr = player.height.map { String(format: "%.1f", $0) } ?? "0.0"
            let weightStr = player.weight.map { String(format: "%.1f", $0) } ?? "0.0"
            
            // 如果指定了赛季，使用按赛季筛选的统计数据
            let totalGoals = season != nil ? player.totalGoalsForSeason(season) : player.totalGoals
            let totalAssists = season != nil ? player.totalAssistsForSeason(season) : player.totalAssists
            let totalSaves = season != nil ? player.totalSavesForSeason(season) : player.totalSaves
            let totalMatches = season != nil ? player.totalMatchesForSeason(season) : player.totalMatches
            
            let matchGoals = season != nil ? player.matchGoalsForSeason(season) : player.matchGoals
            let matchAssists = season != nil ? player.matchAssistsForSeason(season) : player.matchAssists
            let matchSaves = season != nil ? player.matchSavesForSeason(season) : player.matchSaves
            let matchCount = season != nil ? player.matchCountForSeason(season) : player.matchCount
            
            let importedGoals = season != nil ? player.importedGoalsForSeason(season) : player.importedGoals
            let importedAssists = season != nil ? player.importedAssistsForSeason(season) : player.importedAssists
            let importedSaves = season != nil ? player.importedSavesForSeason(season) : player.importedSaves
            let importedMatchCount = season != nil ? player.importedMatchCountForSeason(season) : player.importedMatchCount
            
            // 生成 CSV 行，调整字段顺序
            let row = [
                name,
                "\(player.number ?? 0)",
                player.position.rawValue,
                player.phone ?? "",
                player.email ?? "",
                "\(player.age ?? 0)",
                player.gender ?? "",
                heightStr,
                weightStr,
                "\(totalGoals)",      // 总进球
                "\(totalAssists)",    // 总助攻
                "\(totalSaves)",      // 总扑救
                "\(totalMatches)",    // 总比赛
                "\(matchGoals)",      // 比赛进球
                "\(matchAssists)",    // 比赛助攻
                "\(matchSaves)",      // 比赛扑救
                "\(matchCount)",      // 比赛场次
                "\(importedGoals)",   // 导入进球
                "\(importedAssists)", // 导入助攻
                "\(importedSaves)",   // 导入扑救
                "\(importedMatchCount)", // 导入比赛
                season?.name ?? ""    // 赛季名称
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        return csv
    }
    
    /// 将 CSV 字符串写入文件并返回文件 URL
    static func writeToFile(_ csvString: String, season: Season? = nil) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 创建文件名
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        let seasonName = season?.name.replacingOccurrences(of: " ", with: "_") ?? "全部"
        let fileName = "球员列表_\(seasonName)_\(dateString).csv"
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // 添加 BOM 标记，确保 Excel 正确识别 UTF-8 编码
        let bomString = "\u{FEFF}"
        let fullText = bomString + csvString
        
        do {
            try fullText.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("写入文件失败: \(error)")
            return nil
        }
    }
} 