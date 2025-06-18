import Foundation

struct CSVExporter {
    /// 将所有 Player 对象转换为 CSV 字符串
    static func exportPlayers(_ players: [Player]) -> String {
        // 修改 CSV 表头，调整字段顺序
        let header = "姓名,号码,位置,电话,邮箱,年龄,性别,身高(cm),体重(kg),总进球,总助攻,总扑救,总比赛\n"
        
        var csv = header
        for player in players {
            // 处理可能包含逗号的字段
            let name = "\"\(player.name)\""  // 用引号包裹，避免逗号分隔问题
            
            // 格式化数值
            let heightStr = player.height.map { String(format: "%.1f", $0) } ?? "0.0"
            let weightStr = player.weight.map { String(format: "%.1f", $0) } ?? "0.0"
            
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
                "\(player.totalGoals)",      // 总进球
                "\(player.totalAssists)",    // 总助攻
                "\(player.totalSaves)",      // 总扑救
                "\(player.totalMatches)"     // 总比赛
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        return csv
    }
    
    /// 将 CSV 字符串写入文件并返回文件 URL
    static func saveToFile(_ csv: String) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "球员列表_\(timestamp).csv"
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // 添加 BOM 以支持中文
            if let bomData = "\u{FEFF}".data(using: .utf8),
               let csvData = csv.data(using: .utf8) {
                let data = bomData + csvData
                try data.write(to: url)
                return url
            }
        } catch {
            print("写入 CSV 文件失败: \(error)")
        }
        return nil
    }
} 