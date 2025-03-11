import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.number) private var players: [Player]
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    @State private var showingAddPlayer = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var csvString: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importSuccess = false
    @State private var importedCount = 0
    @State private var showingMergeConfirmation = false
    @State private var currentMergePlayer: Player?
    @State private var currentMergeData: [String: Any] = [:]
    @State private var mergeCompletionHandler: ((MergeStrategy) -> Void)?
    @State private var pendingImportData: String?
    @State private var showingSeasonSelection = false
    @State private var selectedSeason: Season?
    @State private var isExporting = false
    @State private var showingExportSeasonSelection = false
    @State private var exportSeason: Season?
    
    // 导入处理状态
    @State private var isImporting = false
    @State private var importQueue: [(player: Player, data: [String: Any], completion: (MergeStrategy) -> Void)] = []
    
    var body: some View {
        List {
            ForEach(players) { player in
                NavigationLink(destination: PlayerDetailView(player: player)) {
                    HStack {
                        Text("\(player.number ?? 0)")
                            .frame(width: 30)
                            .foregroundColor(.secondary)
                        Text(player.name)
                        Spacer()
                        Text(player.position.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deletePlayers)
        }
        .navigationTitle("球员名单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingAddPlayer = true }) {
                        Label("添加球员", systemImage: "person.badge.plus")
                    }
                    
                    Button(action: { showingExportSeasonSelection = true }) {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImportSheet = true }) {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: CSVFile(initialText: csvString),
            contentType: .commaSeparatedText,
            defaultFilename: exportSeason != nil ? "球员列表_\(exportSeason!.name)_\(formattedDate).csv" : "球员列表_全部_\(formattedDate).csv"
        ) { result in
            switch result {
            case .success(let url):
                print("成功导出到: \(url)")
            case .failure(let error):
                print("导出失败: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            switch result {
            case .success(let url):
                importCSV(from: url)
            case .failure(let error):
                errorMessage = "导入失败: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("导入成功", isPresented: $importSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("成功导入 \(importedCount) 名球员")
        }
        .sheet(isPresented: $showingMergeConfirmation) {
            if let player = currentMergePlayer {
                MergeConfirmationView(
                    existingPlayer: player,
                    importedData: currentMergeData,
                    onComplete: { strategy in
                        if let handler = mergeCompletionHandler {
                            handler(strategy)
                            mergeCompletionHandler = nil
                            
                            // 处理完当前球员后，检查队列中是否还有待处理的球员
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                processNextMergeConfirmation()
                            }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingSeasonSelection) {
            SeasonSelectionView(
                seasons: seasons,
                selectedSeason: $selectedSeason,
                onComplete: { season in
                    selectedSeason = season
                    if let content = pendingImportData {
                        startImport(content: content)
                    }
                }
            )
        }
        .sheet(isPresented: $showingExportSeasonSelection) {
            SeasonSelectionView(
                seasons: seasons,
                selectedSeason: $exportSeason,
                title: "选择要导出的赛季",
                onComplete: { season in
                    exportSeason = season
                    exportPlayerData()
                }
            )
        }
        .onChange(of: showingMergeConfirmation) { oldValue, newValue in
            // 当确认对话框关闭且没有处理程序时，检查队列
            if oldValue && !newValue && mergeCompletionHandler == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    processNextMergeConfirmation()
                }
            }
        }
    }
    
    // 处理下一个合并确认
    private func processNextMergeConfirmation() {
        guard !importQueue.isEmpty else {
            // 队列为空，导入完成
            return
        }
        
        // 取出队列中的下一个待处理项
        let next = importQueue.removeFirst()
        
        // 设置当前处理的球员和数据
        currentMergePlayer = next.player
        currentMergeData = next.data
        mergeCompletionHandler = next.completion
        
        // 显示确认对话框
        showingMergeConfirmation = true
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    private func deletePlayers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(players[index])
            }
        }
    }
    
    private func exportPlayerData() {
        csvString = CSVExporter.exportPlayers(players, season: exportSeason)
        showingExportSheet = true
    }
    
    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "无法访问选择的文件"
            showError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw CSVImporter.ImportError.invalidData
            }
            
            // 保存导入数据，以便在选择赛季后继续处理
            pendingImportData = content
            
            // 显示赛季选择对话框
            showingSeasonSelection = true
        } catch {
            errorMessage = "导入失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func startImport(content: String) {
        // 清空导入队列
        importQueue = []
        isImporting = true
        
        CSVImporter.importPlayers(
            from: content,
            modelContext: modelContext,
            season: selectedSeason,
            showMergeConfirmation: { player, data, completion in
                // 将需要确认的球员添加到队列中
                importQueue.append((player: player, data: data, completion: completion))
                
                // 如果当前没有显示确认对话框，则处理队列中的第一个
                if !showingMergeConfirmation {
                    processNextMergeConfirmation()
                }
            }
        ) { result in
            isImporting = false
            
            switch result {
            case .success(let count):
                importedCount = count
                importSuccess = true
                pendingImportData = nil
            case .failure(let error):
                errorMessage = "导入失败: \(error.localizedDescription)"
                showError = true
                pendingImportData = nil
            }
        }
    }
}

// 赛季选择视图
struct SeasonSelectionView: View {
    let seasons: [Season]
    @Binding var selectedSeason: Season?
    var title: String = "选择赛季"
    let onComplete: (Season?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button("不关联赛季") {
                    selectedSeason = nil
                    onComplete(nil)
                    dismiss()
                }
                
                Section("选择赛季") {
                    ForEach(seasons) { season in
                        Button(action: {
                            selectedSeason = season
                            onComplete(season)
                            dismiss()
                        }) {
                            HStack {
                                Text(season.name)
                                Spacer()
                                if selectedSeason?.id == season.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 球员详情视图
struct PlayerDetailView: View {
    @Bindable var player: Player
    @Query private var seasons: [Season]
    @State private var selectedSeason: Season?
    
    var body: some View {
        Form {
            if !seasons.isEmpty {
                Section {
                    Picker("选择赛季", selection: $selectedSeason) {
                        Text("全部赛季").tag(nil as Season?)
                        ForEach(seasons) { season in
                            Text(season.name).tag(season as Season?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Section(header: Text("基本信息")) {
                LabeledContent("姓名", value: player.name)
                LabeledContent("号码", value: "\(player.number ?? 0)")
                LabeledContent("位置", value: player.position.rawValue)
                
                if let phone = player.phone {
                    LabeledContent("电话", value: phone)
                }
                
                if let email = player.email {
                    LabeledContent("邮箱", value: email)
                }
                
                if let age = player.age {
                    LabeledContent("年龄", value: "\(age)岁")
                }
                
                if let gender = player.gender {
                    LabeledContent("性别", value: gender)
                }
                
                if let height = player.height {
                    LabeledContent("身高", value: "\(height)cm")
                }
                
                if let weight = player.weight {
                    LabeledContent("体重", value: "\(weight)kg")
                }
            }
            
            Section(header: Text("比赛统计")) {
                LabeledContent("比赛场次", value: "\(player.matchCountForSeason(selectedSeason))")
                LabeledContent("进球", value: "\(player.matchGoalsForSeason(selectedSeason))")
                LabeledContent("助攻", value: "\(player.matchAssistsForSeason(selectedSeason))")
                LabeledContent("扑救", value: "\(player.matchSavesForSeason(selectedSeason))")
            }
            
            if !player.importedStats.isEmpty {
                Section(header: Text("导入数据")) {
                    LabeledContent("导入比赛场次", value: "\(player.importedMatchCountForSeason(selectedSeason))")
                    LabeledContent("导入进球", value: "\(player.importedGoalsForSeason(selectedSeason))")
                    LabeledContent("导入助攻", value: "\(player.importedAssistsForSeason(selectedSeason))")
                    LabeledContent("导入扑救", value: "\(player.importedSavesForSeason(selectedSeason))")
                }
                
                Section(header: Text("导入记录")) {
                    let filteredStats = selectedSeason == nil 
                        ? player.importedStats 
                        : player.importedStats.filter { $0.season?.id == selectedSeason?.id }
                    
                    ForEach(filteredStats) { stats in
                        VStack(alignment: .leading) {
                            Text("导入时间: \(stats.importDate.formatted())")
                                .font(.caption)
                            if let season = stats.season {
                                Text("赛季: \(season.name)")
                                    .font(.caption)
                            } else {
                                Text("赛季: 未关联")
                                    .font(.caption)
                            }
                            Text("来源: \(stats.source ?? "未知")")
                                .font(.caption)
                            Text("数据: \(stats.goals)进球, \(stats.assists)助攻, \(stats.saves)扑救, \(stats.matches)场比赛")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section(header: Text("总计")) {
                LabeledContent("总比赛场次", value: "\(player.totalMatchesForSeason(selectedSeason))")
                LabeledContent("总进球", value: "\(player.totalGoalsForSeason(selectedSeason))")
                LabeledContent("总助攻", value: "\(player.totalAssistsForSeason(selectedSeason))")
                LabeledContent("总扑救", value: "\(player.totalSavesForSeason(selectedSeason))")
            }
        }
        .navigationTitle(player.name)
    }
}

// 用于文件导出的文档类型
struct CSVFile: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText]
    
    var text: String
    
    init(initialText: String = "") {
        self.text = initialText
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let bomString = "\u{FEFF}"
        let fullText = bomString + text
        guard let data = fullText.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return .init(regularFileWithContents: data)
    }
}

#Preview {
    PlayerListView()
        .modelContainer(for: Player.self, inMemory: true)
} 